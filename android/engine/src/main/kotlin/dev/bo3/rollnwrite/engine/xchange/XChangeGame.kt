package dev.bo3.rollnwrite.engine.xchange

import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.TriangularScoring
import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor

/**
 * The Qwixx "X-Change" engine: holds state, enforces the official rules, and
 * computes the score through an injected [ScoringStrategy].
 *
 * Mirrors `RollnWrite/Games/QwixxXChange/XChangeGame.swift` name-for-name
 * (Kotlin conventions). Pure JVM, no Android imports. The colour-row rules
 * are identical to classic Qwixx (cap 12, no bonus rows); the X-Change row
 * is the variant-specific addition and scores no points on its own.
 *
 * Persistence lives OUTSIDE the engine (an Android app-layer concern), same
 * as `QwixxGame`: this class exposes [state] as a get-only snapshot and
 * [restore] to load one back in, but never touches `SharedPreferences`/files
 * itself.
 */
class XChangeGame(
    private val scoring: ScoringStrategy = TriangularScoring(cap = 12),
) : Scoreboard {

    var state: XChangeState = XChangeState()
        private set

    /**
     * Actions undone via [undo], most-recently-undone last, so [redo] can
     * re-apply them in LIFO order. Deliberately NOT part of [state] - redo
     * is an in-memory, per-session convenience, like most editors. Any new
     * forward move (via `recordAction`) clears it, matching standard
     * undo/redo semantics.
     */
    private var redoStack: List<XChangeAction> = emptyList()

    /**
     * `true` while [redo] is re-applying an action through its original
     * mutator, so `recordAction` (called by that mutator) knows NOT to
     * treat it as a fresh move and clear the rest of the redo stack.
     */
    private var isRedoing = false

    // --- Accessors ---

    fun row(color: GameColor): ColorRow = when (color) {
        GameColor.RED -> state.red
        GameColor.YELLOW -> state.yellow
        GameColor.GREEN -> state.green
        GameColor.BLUE -> state.blue
    }

    val xchange: XChangeRow get() = state.xchange

    val penalties: Int get() = state.penalties

    val lockedRowCount: Int
        get() = GameColor.entries.count { row(it).locked }

    // --- Rule enforcement (colour rows) ---

    /**
     * Whether crossing [index] in [color] is a legal move right now.
     *
     * Enforces: game not over, row not locked, not already marked,
     * left-to-right, and the right-most number requires at least 5 earlier
     * crosses before it can lock the row.
     */
    fun canMarkColor(color: GameColor, index: Int): Boolean {
        if (isGameOver) return false
        val r = row(color)
        if (r.locked || index in r.marks || index <= r.maxMarkedIndex) return false
        if (index == ColorRow.LOCK_INDEX) return r.marks.size >= 5
        return true
    }

    fun markColor(color: GameColor, index: Int) {
        if (!canMarkColor(color, index)) return
        var r = row(color)
        r = r.copy(marks = r.marks + index)
        var didLock = false
        if (index == ColorRow.LOCK_INDEX) {
            r = r.copy(locked = true)
            didLock = true
        }
        setRow(r)
        recordAction(XChangeAction.ColorMark(color, index, didLock))
    }

    // --- Rule enforcement (X-Change row) ---

    /**
     * The X-Change row is crossed strictly left -> right, on its OWN
     * independent track (never tied to any colour row's marks): a field is
     * legal while the game is live, it isn't already crossed, and it lies
     * to the right of every existing cross (skipping is allowed but skipped
     * fields are then permanently blocked).
     */
    fun canMarkXChange(index: Int): Boolean {
        if (isGameOver) return false
        val row = state.xchange
        if (index in row.marks || index <= row.maxMarkedIndex) return false
        return true
    }

    fun markXChange(index: Int) {
        if (!canMarkXChange(index)) return
        state = state.copy(xchange = state.xchange.copy(marks = state.xchange.marks + index))
        recordAction(XChangeAction.XChangeMark(index))
    }

    // --- Penalties ---

    fun canAddPenalty(): Boolean = !isGameOver && state.penalties < XChangeState.MAX_PENALTIES

    fun addPenalty() {
        if (!canAddPenalty()) return
        state = state.copy(penalties = state.penalties + 1)
        recordAction(XChangeAction.Penalty)
    }

    // --- Concede a colour / finish manually ---

    /**
     * You may close (concede) a colour that another player locked: the row
     * closes for you, but you score no lock bonus - you never crossed its
     * final number. Allowed on any still-open row while the game is live.
     */
    fun canConcedeRow(color: GameColor): Boolean = !isGameOver && !row(color).locked

    fun concedeRow(color: GameColor) {
        if (!canConcedeRow(color)) return
        val r = row(color)
        setRow(r.copy(locked = true))
        recordAction(XChangeAction.Concede(color))
    }

    fun isLastConcede(color: GameColor): Boolean {
        val last = state.history.lastOrNull() as? XChangeAction.Concede ?: return false
        return last.color == color
    }

    /** End the game by hand - e.g. another player crossed the final lock. */
    fun canFinishManually(): Boolean = !isGameOver

    fun finishGame() {
        if (!canFinishManually()) return
        state = state.copy(manuallyFinished = true)
        recordAction(XChangeAction.Finish)
    }

    // --- Scoreboard ---

    /** Crosses counted toward a colour's score: its own marks plus the lock. */
    fun crosses(color: GameColor): Int = row(color).scoringCrosses

    fun points(color: GameColor): Int = scoring.points(forCrosses = crosses(color))

    val penaltyPoints: Int get() = state.penalties * 5

    /**
     * Total = red + yellow + green + blue - penalties. The X-Change row
     * scores nothing on its own (it only enables extra colour marks).
     */
    override val totalScore: Int
        get() = GameColor.entries.sumOf { points(it) } - penaltyPoints

    /**
     * Ends when two rows are locked, the 4th penalty is taken, or the
     * player ends it by hand.
     */
    override val isGameOver: Boolean
        get() = state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= XChangeState.MAX_PENALTIES

    override val canUndo: Boolean get() = state.history.isNotEmpty()

    // --- Tap-to-undo ---

    fun isLastColorMark(color: GameColor, index: Int): Boolean {
        val last = state.history.lastOrNull() as? XChangeAction.ColorMark ?: return false
        return last.color == color && last.index == index
    }

    fun isLastXChangeMark(index: Int): Boolean {
        val last = state.history.lastOrNull() as? XChangeAction.XChangeMark ?: return false
        return last.index == index
    }

    fun isLastPenalty(): Boolean = state.history.lastOrNull() is XChangeAction.Penalty

    /**
     * Reverse the most recent action. Strictly LIFO. The undone action
     * moves onto the (in-memory only) redo stack.
     */
    override fun undo() {
        val last = state.history.lastOrNull() ?: return
        state = state.copy(history = state.history.dropLast(1))
        when (last) {
            is XChangeAction.ColorMark -> {
                var r = row(last.color)
                r = r.copy(marks = r.marks - last.index)
                if (last.didLock) r = r.copy(locked = false)
                setRow(r)
            }
            is XChangeAction.XChangeMark -> {
                state = state.copy(xchange = state.xchange.copy(marks = state.xchange.marks - last.index))
            }
            is XChangeAction.Penalty -> {
                state = state.copy(penalties = maxOf(0, state.penalties - 1))
            }
            is XChangeAction.Concede -> {
                val r = row(last.color)
                setRow(r.copy(locked = false))
            }
            is XChangeAction.Finish -> {
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
                is XChangeAction.ColorMark -> markColor(next.color, next.index)
                is XChangeAction.XChangeMark -> markXChange(next.index)
                is XChangeAction.Penalty -> addPenalty()
                is XChangeAction.Concede -> concedeRow(next.color)
                is XChangeAction.Finish -> finishGame()
            }
        } finally {
            isRedoing = false
        }
    }

    override fun reset() {
        state = XChangeState()
        redoStack = emptyList()
    }

    /** Replace the engine's state wholesale, e.g. after loading a persisted snapshot. */
    fun restore(state: XChangeState) {
        // Copy the collections defensively: the marks fields are typed
        // Set<Int>, so a caller holding a MutableSet reference could
        // otherwise mutate engine state from outside.
        this.state = state.copy(
            red = state.red.copy(marks = state.red.marks.toSet()),
            yellow = state.yellow.copy(marks = state.yellow.marks.toSet()),
            green = state.green.copy(marks = state.green.marks.toSet()),
            blue = state.blue.copy(marks = state.blue.marks.toSet()),
            xchange = state.xchange.copy(marks = state.xchange.marks.toSet()),
            history = state.history.toList(),
        )
        redoStack = emptyList()
    }

    // --- Mutation helpers ---

    /**
     * Appends a new action to the history. Any FORWARD move - i.e. every
     * call site except [redo] re-applying an undone one - invalidates the
     * redo stack.
     */
    private fun recordAction(action: XChangeAction) {
        state = state.copy(history = state.history + action)
        if (!isRedoing) redoStack = emptyList()
    }

    private fun setRow(r: ColorRow) {
        state = when (r.color) {
            GameColor.RED -> state.copy(red = r)
            GameColor.YELLOW -> state.copy(yellow = r)
            GameColor.GREEN -> state.copy(green = r)
            GameColor.BLUE -> state.copy(blue = r)
        }
    }
}
