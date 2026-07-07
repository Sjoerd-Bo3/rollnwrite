package dev.bo3.rollnwrite.engine.qwixxdouble

import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.TriangularScoring
import dev.bo3.rollnwrite.engine.qwixx.GameColor

/**
 * The Qwixx Double (Variant A - "double crosses") engine: holds state,
 * enforces the rules, and computes the score through an injected
 * [ScoringStrategy].
 *
 * Mirrors `RollnWrite/Games/QwixxDouble/DoubleGame.swift` name-for-name
 * (Kotlin conventions). Pure JVM, no Android imports - this module
 * unit-tests fast and is reusable by any Android UI layer.
 *
 * The variant-specific additions over classic Qwixx are: a second cross on
 * the most-recently-crossed space, and a 7-cross (not 5) threshold before a
 * row may be locked.
 *
 * Persistence lives OUTSIDE the engine (an Android app-layer concern): this
 * class exposes [state] as a get-only snapshot and [restore] to load one back
 * in, but never touches `SharedPreferences`/files itself - unlike the Swift
 * engine, which owns `UserDefaults` load/save directly because iOS has no
 * equivalent layering pressure.
 */
class DoubleGame(
    private val scoring: ScoringStrategy = TriangularScoring(cap = SCORING_CAP),
) : Scoreboard {

    var state: DoubleState = DoubleState()
        private set

    /**
     * Actions undone via [undo], most-recently-undone last, so [redo] can
     * re-apply them in LIFO order. Deliberately NOT part of [state] (kept
     * outside so it is never serialised) - redo is an in-memory,
     * per-session convenience, like most editors. Any new forward move
     * (via `recordAction`) clears it, matching standard undo/redo
     * semantics.
     */
    private var redoStack: List<DoubleAction> = emptyList()

    /**
     * `true` while [redo] is re-applying an action through its original
     * mutator, so `recordAction` (called by that mutator) knows NOT to
     * treat it as a fresh move and clear the rest of the redo stack.
     */
    private var isRedoing = false

    // --- Accessors ---

    fun row(color: GameColor): DoubleColorRow = when (color) {
        GameColor.RED -> state.red
        GameColor.YELLOW -> state.yellow
        GameColor.GREEN -> state.green
        GameColor.BLUE -> state.blue
    }

    val penalties: Int get() = state.penalties

    val lockedRowCount: Int
        get() = GameColor.entries.count { row(it).locked }

    // --- Rule enforcement (first crosses) ---

    /**
     * Whether crossing [index] in [color] for the *first* time is legal now.
     *
     * Enforces: game not over - row not locked - not already marked -
     * strictly left-to-right - the right-most number needs >=7 earlier
     * crosses (counting doubles too, via [DoubleColorRow.crossCount]).
     */
    fun canMarkColor(color: GameColor, index: Int): Boolean {
        if (isGameOver) return false
        val r = row(color)
        if (r.locked || index in r.marks || index <= r.maxMarkedIndex) return false
        if (index == DoubleColorRow.LOCK_INDEX) return r.crossCount >= DoubleColorRow.CROSSES_TO_LOCK
        return true
    }

    fun markColor(color: GameColor, index: Int) {
        if (!canMarkColor(color, index)) return
        var r = row(color)
        r = r.copy(marks = r.marks + index)
        var didLock = false
        if (index == DoubleColorRow.LOCK_INDEX) {
            r = r.copy(locked = true)
            didLock = true
        }
        setRow(r)
        recordAction(DoubleAction.Mark(color, index, didLock))
    }

    // --- Rule enforcement (second / double crosses) ---

    /**
     * Whether a *second* cross on [index] is legal now.
     *
     * Only the **most recently crossed** space may be doubled, it must not
     * be already doubled, the lock space is never doubled, and the game
     * must be live.
     */
    fun canDoubleColor(color: GameColor, index: Int): Boolean {
        if (isGameOver) return false
        val r = row(color)
        if (r.locked) return false
        if (index !in r.marks || index in r.doubles) return false
        if (index != r.maxMarkedIndex) return false // most-recent only
        if (index == DoubleColorRow.LOCK_INDEX) return false // lock isn't doubled
        return true
    }

    fun doubleColor(color: GameColor, index: Int) {
        if (!canDoubleColor(color, index)) return
        val r = row(color)
        setRow(r.copy(doubles = r.doubles + index))
        recordAction(DoubleAction.Double(color, index))
    }

    // --- Penalties ---

    fun canAddPenalty(): Boolean = !isGameOver && state.penalties < DoubleState.MAX_PENALTIES

    fun addPenalty() {
        if (!canAddPenalty()) return
        state = state.copy(penalties = state.penalties + 1)
        recordAction(DoubleAction.Penalty)
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
        recordAction(DoubleAction.Concede(color))
    }

    fun isLastConcede(color: GameColor): Boolean {
        val last = state.history.lastOrNull() as? DoubleAction.Concede ?: return false
        return last.color == color
    }

    /** End the game by hand - e.g. another player crossed the final lock. */
    fun canFinishManually(): Boolean = !isGameOver

    fun finishGame() {
        if (!canFinishManually()) return
        state = state.copy(manuallyFinished = true)
        recordAction(DoubleAction.Finish)
    }

    // --- Scoreboard ---

    /**
     * Crosses counted toward a colour's score: first crosses + second
     * crosses + the lock bonus cross (before the scoring cap is applied).
     */
    fun crosses(color: GameColor): Int = row(color).crossCount

    fun points(color: GameColor): Int = scoring.points(forCrosses = crosses(color))

    val penaltyPoints: Int get() = state.penalties * 5

    override val totalScore: Int
        get() = GameColor.entries.sumOf { points(it) } - penaltyPoints

    /**
     * Ends when two rows are locked, the 4th penalty is taken, or the
     * player ends it by hand.
     */
    override val isGameOver: Boolean
        get() = state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= DoubleState.MAX_PENALTIES

    override val canUndo: Boolean get() = state.history.isNotEmpty()

    // --- Tap-to-undo helpers ---
    //
    // These report whether a given mark is the single most-recent action, so
    // the UI layer can ring it and let a tap un-check it (LIFO undo). Only
    // the very last action is tap-undoable.

    /** Whether the most recent action was a *first* cross on [index] in [color]. */
    fun isLastColorMark(color: GameColor, index: Int): Boolean {
        val last = state.history.lastOrNull() as? DoubleAction.Mark ?: return false
        return last.color == color && last.index == index
    }

    /** Whether the most recent action was a *second* cross on [index] in [color]. */
    fun isLastDoubleMark(color: GameColor, index: Int): Boolean {
        val last = state.history.lastOrNull() as? DoubleAction.Double ?: return false
        return last.color == color && last.index == index
    }

    /** Whether the most recent action was taking a penalty. */
    fun isLastPenalty(): Boolean = state.history.lastOrNull() is DoubleAction.Penalty

    /**
     * Reverse the most recent action. Strictly LIFO, which guarantees a
     * second cross is always undone before the first cross that authorised
     * it.
     */
    override fun undo() {
        val last = state.history.lastOrNull() ?: return
        state = state.copy(history = state.history.dropLast(1))
        when (last) {
            is DoubleAction.Mark -> {
                var r = row(last.color)
                r = r.copy(marks = r.marks - last.index, doubles = r.doubles - last.index)
                if (last.didLock) r = r.copy(locked = false)
                setRow(r)
            }
            is DoubleAction.Double -> {
                val r = row(last.color)
                setRow(r.copy(doubles = r.doubles - last.index))
            }
            is DoubleAction.Penalty -> {
                state = state.copy(penalties = maxOf(0, state.penalties - 1))
            }
            is DoubleAction.Concede -> {
                val r = row(last.color)
                setRow(r.copy(locked = false))
            }
            is DoubleAction.Finish -> {
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
                is DoubleAction.Mark -> markColor(next.color, next.index)
                is DoubleAction.Double -> doubleColor(next.color, next.index)
                is DoubleAction.Penalty -> addPenalty()
                is DoubleAction.Concede -> concedeRow(next.color)
                is DoubleAction.Finish -> finishGame()
            }
        } finally {
            isRedoing = false
        }
    }

    override fun reset() {
        state = DoubleState()
        redoStack = emptyList()
    }

    /** Replace the engine's state wholesale, e.g. after loading a persisted snapshot. */
    fun restore(state: DoubleState) {
        // Copy the collections defensively: the marks/doubles fields are
        // typed Set<Int>, so a caller holding a MutableSet reference could
        // otherwise mutate engine state from outside — impossible in Swift,
        // where the rows are value-semantic structs copied on assignment.
        this.state = state.copy(
            red = state.red.copy(marks = state.red.marks.toSet(), doubles = state.red.doubles.toSet()),
            yellow = state.yellow.copy(marks = state.yellow.marks.toSet(), doubles = state.yellow.doubles.toSet()),
            green = state.green.copy(marks = state.green.marks.toSet(), doubles = state.green.doubles.toSet()),
            blue = state.blue.copy(marks = state.blue.marks.toSet(), doubles = state.blue.doubles.toSet()),
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
    private fun recordAction(action: DoubleAction) {
        state = state.copy(history = state.history + action)
        if (!isRedoing) redoStack = emptyList()
    }

    private fun setRow(r: DoubleColorRow) {
        state = when (r.color) {
            GameColor.RED -> state.copy(red = r)
            GameColor.YELLOW -> state.copy(yellow = r)
            GameColor.GREEN -> state.copy(green = r)
            GameColor.BLUE -> state.copy(blue = r)
        }
    }

    companion object {
        /** Maximum valued crosses scored per row (16 -> 136 points). */
        const val SCORING_CAP = 16
    }
}
