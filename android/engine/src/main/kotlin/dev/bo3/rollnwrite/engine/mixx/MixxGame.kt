package dev.bo3.rollnwrite.engine.mixx

import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.TriangularScoring

/**
 * The Qwixx "gemixxt" (Mixx) engine: holds the state of ONE board (the
 * caller picks Variant A or Variant B at construction time; switching boards
 * means constructing/holding a second instance - see [MixxViewModel] on the
 * Android app layer, mirroring iOS's `stateA`/`stateB` pair), enforces the
 * per-row rules, and computes the score through an injected [ScoringStrategy].
 *
 * Mirrors `RollnWrite/Games/QwixxMixx/MixxGame.swift` name-for-name (Kotlin
 * conventions), adapted to Kotlin's per-instance-board split: the Swift
 * engine owns BOTH boards' state in one object and switches via `board`:
 * `didSet`; this port keeps ONE board per engine instance (matching
 * `QwixxGame`'s pure-JVM, no-Android, no-persistence-in-the-engine shape) so
 * app-layer persistence (two independent `SharedPreferences` keys, one per
 * board) stays a thin, explicit wrapper rather than living in the engine.
 *
 * Both boards share the classic Qwixx rule set (rows crossed strictly
 * left-to-right; the right-most cell locks the row but only after >=5 earlier
 * crosses; four -5 penalties; game ends at two locks or the 4th penalty).
 * They differ only in their printed cell layout ([MixxLayout]), so one engine
 * class serves both - `board` just selects which layout `rowLayout` reports.
 *
 * Persistence lives OUTSIDE the engine (an Android app-layer concern): this
 * class exposes [state] as a get-only snapshot and [restore] to load one back
 * in, but never touches `SharedPreferences`/files itself.
 */
class MixxGame(
    val board: MixxBoard = MixxBoard.VARIANT_A,
    /** Classic Qwixx scoring: up to 12 valued crosses per row (78 points). */
    private val scoring: ScoringStrategy = TriangularScoring(cap = 12),
) : Scoreboard {

    var state: MixxState = MixxState()
        private set

    /**
     * Actions undone via [undo], most-recently-undone last, so [redo] can
     * re-apply them in LIFO order. Deliberately NOT part of [state] (kept
     * outside so it is never serialised) - redo is an in-memory,
     * per-session convenience. Any new forward move (via `recordAction`)
     * clears it.
     */
    private var redoStack: List<MixxAction> = emptyList()

    /**
     * `true` while [redo] is re-applying an action through its original
     * mutator, so `recordAction` (called by that mutator) knows NOT to
     * treat it as a fresh move and clear the rest of the redo stack.
     */
    private var isRedoing = false

    // --- Layout ---

    /** The printed layout of this engine's board. */
    val layout: List<MixxRowLayout> get() = MixxLayout.rows(board)

    // --- Accessors ---

    fun rowState(rowIndex: Int): MixxRow = state.rows[rowIndex]

    fun rowLayout(rowIndex: Int): MixxRowLayout = layout[rowIndex]

    val penalties: Int get() = state.penalties

    val lockedRowCount: Int get() = state.rows.count { it.locked }

    // --- Rule enforcement ---

    /**
     * Whether crossing [index] in row [rowIndex] is a legal move right now.
     *
     * Enforces: game not over, row not locked, cell not already marked,
     * left-to-right, and the right-most cell needs >=5 earlier crosses to
     * lock.
     */
    fun canMark(rowIndex: Int, index: Int): Boolean {
        if (isGameOver) return false
        val r = state.rows[rowIndex]
        if (r.locked || index in r.marks || index <= r.maxMarkedIndex) return false
        if (index == MixxRow.LOCK_INDEX) return r.marks.size >= 5
        return true
    }

    fun mark(rowIndex: Int, index: Int) {
        if (!canMark(rowIndex, index)) return
        var r = state.rows[rowIndex]
        r = r.copy(marks = r.marks + index)
        var didLock = false
        if (index == MixxRow.LOCK_INDEX) {
            r = r.copy(locked = true)
            didLock = true
        }
        setRow(rowIndex, r)
        recordAction(MixxAction.Mark(rowIndex, index, didLock))
    }

    // --- Penalties ---

    fun canAddPenalty(): Boolean = !isGameOver && state.penalties < MixxState.MAX_PENALTIES

    fun addPenalty() {
        if (!canAddPenalty()) return
        state = state.copy(penalties = state.penalties + 1)
        recordAction(MixxAction.Penalty)
    }

    // --- Concede a row / finish manually ---

    /**
     * You may close (concede) a row whose colour another player locked: the
     * row closes for you, but you score no lock bonus - you never crossed
     * its final cell. Allowed on any still-open row while the game is live.
     */
    fun canConcedeRow(rowIndex: Int): Boolean = !isGameOver && !state.rows[rowIndex].locked

    fun concedeRow(rowIndex: Int) {
        if (!canConcedeRow(rowIndex)) return
        val r = state.rows[rowIndex]
        setRow(rowIndex, r.copy(locked = true))
        recordAction(MixxAction.Concede(rowIndex))
    }

    fun isLastConcede(rowIndex: Int): Boolean {
        val last = state.history.lastOrNull() as? MixxAction.Concede ?: return false
        return last.row == rowIndex
    }

    /** End the game by hand - e.g. another player crossed the final lock. */
    fun canFinishManually(): Boolean = !isGameOver

    fun finishGame() {
        if (!canFinishManually()) return
        state = state.copy(manuallyFinished = true)
        recordAction(MixxAction.Finish)
    }

    // --- Scoreboard ---

    /** Crosses counted toward a row's score: its own marks plus the lock. */
    fun crosses(rowIndex: Int): Int = state.rows[rowIndex].scoringCrosses

    fun points(rowIndex: Int): Int = scoring.points(forCrosses = crosses(rowIndex))

    val penaltyPoints: Int get() = state.penalties * 5

    override val totalScore: Int
        get() = state.rows.indices.sumOf { points(it) } - penaltyPoints

    /**
     * Ends when two rows are locked, the 4th penalty is taken, or the
     * player ends it by hand.
     */
    override val isGameOver: Boolean
        get() = state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= MixxState.MAX_PENALTIES

    override val canUndo: Boolean get() = state.history.isNotEmpty()

    // --- Tap-to-undo (strictly LIFO: only the most-recent action qualifies) ---

    /**
     * `true` if the most-recent action is crossing [index] in row
     * [rowIndex], so tapping that cell un-checks it (a second way to undo).
     */
    fun isLastMark(rowIndex: Int, index: Int): Boolean {
        val last = state.history.lastOrNull() as? MixxAction.Mark ?: return false
        return last.row == rowIndex && last.index == index
    }

    /** `true` if the most-recent action is the last penalty, so tapping it undoes it. */
    fun isLastPenalty(): Boolean = state.history.lastOrNull() is MixxAction.Penalty

    /**
     * Reverse the most recent action. Strictly LIFO. The undone action moves
     * onto the (in-memory only) redo stack.
     */
    override fun undo() {
        val last = state.history.lastOrNull() ?: return
        state = state.copy(history = state.history.dropLast(1))
        when (last) {
            is MixxAction.Mark -> {
                var r = state.rows[last.row]
                r = r.copy(marks = r.marks - last.index)
                if (last.didLock) r = r.copy(locked = false)
                setRow(last.row, r)
            }
            is MixxAction.Penalty -> {
                state = state.copy(penalties = maxOf(0, state.penalties - 1))
            }
            is MixxAction.Concede -> {
                val r = state.rows[last.row]
                setRow(last.row, r.copy(locked = false))
            }
            is MixxAction.Finish -> {
                state = state.copy(manuallyFinished = false)
            }
        }
        redoStack = redoStack + last
    }

    override val canRedo: Boolean get() = redoStack.isNotEmpty()

    /**
     * Re-apply the most recently undone action through the SAME mutator a
     * fresh move takes, so scores/locks/derived state stay exact - never
     * re-implement the effect here.
     */
    override fun redo() {
        val next = redoStack.lastOrNull() ?: return
        redoStack = redoStack.dropLast(1)
        isRedoing = true
        try {
            when (next) {
                is MixxAction.Mark -> mark(next.row, next.index)
                is MixxAction.Penalty -> addPenalty()
                is MixxAction.Concede -> concedeRow(next.row)
                is MixxAction.Finish -> finishGame()
            }
        } finally {
            isRedoing = false
        }
    }

    override fun reset() {
        state = MixxState()
        redoStack = emptyList()
    }

    /** Replace the engine's state wholesale, e.g. after loading a persisted snapshot. */
    fun restore(state: MixxState) {
        // Copy the collections defensively: `marks` is typed Set<Int>, so a
        // caller holding a MutableSet reference could otherwise mutate
        // engine state from outside - impossible in Swift, where rows are
        // value-semantic structs copied on assignment.
        this.state = state.copy(
            rows = state.rows.map { it.copy(marks = it.marks.toSet()) },
            history = state.history.toList(),
        )
        redoStack = emptyList()
    }

    // --- Mutation helpers ---

    /**
     * Appends a new action to the history. Any FORWARD move - i.e. every
     * call site except [redo] re-applying an undone one - invalidates the
     * redo stack (standard editor semantics: making a new move after
     * undoing forecloses the redone future).
     */
    private fun recordAction(action: MixxAction) {
        state = state.copy(history = state.history + action)
        if (!isRedoing) redoStack = emptyList()
    }

    private fun setRow(rowIndex: Int, r: MixxRow) {
        state = state.copy(rows = state.rows.toMutableList().also { it[rowIndex] = r })
    }
}
