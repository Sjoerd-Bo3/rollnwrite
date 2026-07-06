package dev.bo3.rollnwrite.engine.qwixx

import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.TriangularScoring

/**
 * The Qwixx Big Points engine: holds state, enforces the official rules,
 * and computes the score through an injected [ScoringStrategy].
 *
 * Mirrors `RollnWrite/Games/Qwixx/QwixxGame.swift` name-for-name (Kotlin
 * conventions). Pure JVM, no Android imports - this module unit-tests fast
 * and is reusable by any Android UI layer.
 *
 * Persistence lives OUTSIDE the engine (an Android app-layer concern):
 * this class exposes [state] as a get-only snapshot and [restore] to load
 * one back in, but never touches `SharedPreferences`/files itself - unlike
 * the Swift engine, which owns `UserDefaults` load/save directly because
 * iOS has no equivalent layering pressure.
 */
class QwixxGame(
    private val scoring: ScoringStrategy = TriangularScoring(cap = 15),
    /**
     * Whether this variant has the two two-colour bonus rows (Big Points)
     * or not (classic Qwixx). When `false`, bonus marking is disallowed
     * and bonus crosses never contribute to scoring.
     */
    val hasBonusRows: Boolean = true,
) : Scoreboard {

    var state: QwixxState = QwixxState()
        private set

    /**
     * Actions undone via [undo], most-recently-undone last, so [redo] can
     * re-apply them in LIFO order. Deliberately NOT part of [state] (kept
     * outside so it is never serialised) - redo is an in-memory,
     * per-session convenience, like most editors. Any new forward move
     * (via `recordAction`) clears it, matching standard undo/redo
     * semantics.
     */
    private var redoStack: List<GameAction> = emptyList()

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

    fun bonus(id: BonusRowId): BonusRow =
        if (id == BonusRowId.REDYELLOW) state.redYellowBonus else state.greenBlueBonus

    val penalties: Int get() = state.penalties

    val lockedRowCount: Int
        get() = GameColor.entries.count { row(it).locked }

    // --- Rule enforcement (colour rows) ---

    /**
     * Whether crossing [index] in [color] is a legal move right now.
     *
     * Enforces: game not over, row not locked, not already marked,
     * left-to-right (no marking left of an existing cross), and the
     * right-most number requires at least 5 earlier crosses before it can
     * lock the row.
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
        recordAction(GameAction.ColorMark(color, index, didLock))
    }

    // --- Rule enforcement (bonus rows) ---

    /**
     * A bonus space is legal when the game is live, it isn't already
     * marked, an adjacent same-number colour space is already crossed (the
     * activation rule), AND it lies right of every existing bonus cross.
     * The official rules are explicit that the general ordering rule
     * applies to the bonus rows too: "For both of the bonus rows the
     * general rule also applies: numbers must be crossed out from left to
     * right and previously skipped bonus fields may not be crossed out
     * later on." So a lower bonus stays available only until a higher one
     * is crossed - skipping past it forfeits it.
     */
    fun canMarkBonus(id: BonusRowId, index: Int): Boolean {
        if (!hasBonusRows || isGameOver) return false
        val b = bonus(id)
        if (index in b.marks || index <= b.maxMarkedIndex) return false
        val (a, c) = id.colors
        return index in row(a).marks || index in row(c).marks
    }

    fun markBonus(id: BonusRowId, index: Int) {
        if (!canMarkBonus(id, index)) return
        val b = bonus(id)
        setBonus(b.copy(marks = b.marks + index))
        recordAction(GameAction.BonusMark(id, index))
    }

    // --- Penalties ---

    fun canAddPenalty(): Boolean = !isGameOver && state.penalties < QwixxState.MAX_PENALTIES

    fun addPenalty() {
        if (!canAddPenalty()) return
        state = state.copy(penalties = state.penalties + 1)
        recordAction(GameAction.Penalty)
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
        recordAction(GameAction.Concede(color))
    }

    fun isLastConcede(color: GameColor): Boolean {
        val last = state.history.lastOrNull() as? GameAction.Concede ?: return false
        return last.color == color
    }

    /** End the game by hand - e.g. another player crossed the final lock. */
    fun canFinishManually(): Boolean = !isGameOver

    fun finishGame() {
        if (!canFinishManually()) return
        state = state.copy(manuallyFinished = true)
        recordAction(GameAction.Finish)
    }

    // --- Scoreboard ---

    /**
     * Crosses counted toward a colour's score: its own marks, the lock
     * bonus, and every crossed bonus space adjacent to that colour.
     */
    fun crosses(color: GameColor): Int {
        if (!hasBonusRows) return row(color).scoringCrosses
        val bonusId = if (color == GameColor.RED || color == GameColor.YELLOW) {
            BonusRowId.REDYELLOW
        } else {
            BonusRowId.GREENBLUE
        }
        return row(color).scoringCrosses + bonus(bonusId).marks.size
    }

    fun points(color: GameColor): Int = scoring.points(forCrosses = crosses(color))

    val penaltyPoints: Int get() = state.penalties * 5

    override val totalScore: Int
        get() = GameColor.entries.sumOf { points(it) } - penaltyPoints

    /**
     * Ends when two rows are locked, the 4th penalty is taken, or the
     * player ends it by hand.
     */
    override val isGameOver: Boolean
        get() = state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= QwixxState.MAX_PENALTIES

    override val canUndo: Boolean get() = state.history.isNotEmpty()

    // --- Tap-to-undo ---
    //
    // Tapping the most-recent mark un-checks it. Undo is strictly LIFO, so
    // only the *last* action is reversible this way - these tell the UI
    // layer which cell that is.

    fun isLastColorMark(color: GameColor, index: Int): Boolean {
        val last = state.history.lastOrNull() as? GameAction.ColorMark ?: return false
        return last.color == color && last.index == index
    }

    fun isLastBonusMark(id: BonusRowId, index: Int): Boolean {
        val last = state.history.lastOrNull() as? GameAction.BonusMark ?: return false
        return last.row == id && last.index == index
    }

    fun isLastPenalty(): Boolean = state.history.lastOrNull() is GameAction.Penalty

    /**
     * Reverse the most recent action. Strictly LIFO so a bonus mark is
     * always undone before the colour mark that authorised it - state
     * stays legal. The undone action moves onto the (in-memory only) redo
     * stack.
     */
    override fun undo() {
        val last = state.history.lastOrNull() ?: return
        state = state.copy(history = state.history.dropLast(1))
        when (last) {
            is GameAction.ColorMark -> {
                var r = row(last.color)
                r = r.copy(marks = r.marks - last.index)
                if (last.didLock) r = r.copy(locked = false)
                setRow(r)
            }
            is GameAction.BonusMark -> {
                val b = bonus(last.row)
                setBonus(b.copy(marks = b.marks - last.index))
            }
            is GameAction.Penalty -> {
                state = state.copy(penalties = maxOf(0, state.penalties - 1))
            }
            is GameAction.Concede -> {
                val r = row(last.color)
                setRow(r.copy(locked = false))
            }
            is GameAction.Finish -> {
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
                is GameAction.ColorMark -> markColor(next.color, next.index)
                is GameAction.BonusMark -> markBonus(next.row, next.index)
                is GameAction.Penalty -> addPenalty()
                is GameAction.Concede -> concedeRow(next.color)
                is GameAction.Finish -> finishGame()
            }
        } finally {
            isRedoing = false
        }
    }

    override fun reset() {
        state = QwixxState()
        redoStack = emptyList()
    }

    /** Replace the engine's state wholesale, e.g. after loading a persisted snapshot. */
    fun restore(state: QwixxState) {
        // Copy the collections defensively: the marks fields are typed Set<Int>,
        // so a caller holding a MutableSet reference could otherwise mutate
        // engine state from outside — impossible in Swift, where the rows are
        // value-semantic structs copied on assignment.
        this.state = state.copy(
            red = state.red.copy(marks = state.red.marks.toSet()),
            yellow = state.yellow.copy(marks = state.yellow.marks.toSet()),
            green = state.green.copy(marks = state.green.marks.toSet()),
            blue = state.blue.copy(marks = state.blue.marks.toSet()),
            redYellowBonus = state.redYellowBonus.copy(marks = state.redYellowBonus.marks.toSet()),
            greenBlueBonus = state.greenBlueBonus.copy(marks = state.greenBlueBonus.marks.toSet()),
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
    private fun recordAction(action: GameAction) {
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

    private fun setBonus(b: BonusRow) {
        state = when (b.id) {
            BonusRowId.REDYELLOW -> state.copy(redYellowBonus = b)
            BonusRowId.GREENBLUE -> state.copy(greenBlueBonus = b)
        }
    }
}
