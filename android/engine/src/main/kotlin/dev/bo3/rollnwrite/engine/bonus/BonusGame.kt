package dev.bo3.rollnwrite.engine.bonus

import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.TriangularScoring
import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor

/**
 * The Qwixx "Bonus" (version A) engine: holds state, enforces the rules, and
 * computes the score through an injected [ScoringStrategy].
 *
 * Mirrors `RollnWrite/Games/QwixxBonus/BonusGame.swift` name-for-name (Kotlin
 * conventions). Pure JVM, no Android imports.
 *
 * The colour-row rules are identical to classic Qwixx. The variant-specific
 * twist is the bonus bar: crossing a boxed number automatically earns the
 * next free bar field, whose colour tells the player which free extra cross
 * to make (the player makes that cross by hand, via another [markColor] call
 * - the engine never auto-applies it). When a colour is completed (self-lock
 * or concede) its remaining bar fields are forfeited at once and skipped
 * from then on (official forfeit rule). The bar awards no points itself
 * (version A scores like classic Qwixx: [crosses] never adds bar marks).
 *
 * Persistence lives OUTSIDE the engine (an Android app-layer concern), same
 * layering as `QwixxGame`.
 */
class BonusGame(
    /** Classic Qwixx scoring: up to 12 valued crosses per colour (78 points). */
    private val scoring: ScoringStrategy = TriangularScoring(cap = 12),
) : Scoreboard {

    var state: BonusState = BonusState()
        private set

    /**
     * Actions undone via [undo], most-recently-undone last, so [redo] can
     * re-apply them in LIFO order. Deliberately NOT part of [state] - redo is
     * an in-memory, per-session convenience, like most editors. Any new
     * forward move (via `recordAction`) clears it.
     */
    private var redoStack: List<BonusAction> = emptyList()

    /**
     * `true` while [redo] is re-applying an action through its original
     * mutator, so `recordAction` (called by that mutator) knows NOT to treat
     * it as a fresh move and clear the rest of the redo stack.
     */
    private var isRedoing = false

    // --- Accessors ---

    fun row(color: GameColor): ColorRow = when (color) {
        GameColor.RED -> state.red
        GameColor.YELLOW -> state.yellow
        GameColor.GREEN -> state.green
        GameColor.BLUE -> state.blue
    }

    val bar: BonusBar get() = state.bar

    val penalties: Int get() = state.penalties

    val lockedRowCount: Int
        get() = GameColor.entries.count { row(it).locked }

    /** Whether the cell at [index] of [color] is a boxed bonus number. */
    fun isBoxed(color: GameColor, index: Int): Boolean = BonusLayout.isBoxedIndex(color, index)

    // --- Rule enforcement (colour rows) ---

    /**
     * Whether crossing [index] in [color] is a legal move right now.
     *
     * Enforces: game not over, row not locked, not already marked,
     * left-to-right, and the right-most number needs >=5 earlier crosses to
     * lock. Identical to classic Qwixx - the bonus bar plays no part in
     * legality.
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

        // Boxed numbers earn the next bar field: the lowest-index field that
        // is neither earned nor forfeited (forfeited fields are simply
        // skipped). The field's colour drives the reward, so record exactly
        // which one.
        var barAdvance: BarAdvance = BarAdvance.None
        if (isBoxed(color, index)) {
            val field = state.bar.nextEarnableIndex
            if (field != null) {
                state = state.copy(bar = state.bar.copy(earned = state.bar.earned + field))
                barAdvance = BarAdvance.Earned(field)
            }
        }

        // Official rule: once a colour is completed, its remaining
        // bonus-bar fields are immediately crossed out as forfeited - same
        // action.
        var forfeited: List<Int> = emptyList()
        if (didLock) {
            forfeited = forfeitBarFields(color)
        }

        recordAction(BonusAction.ColorMark(color, index, didLock, barAdvance, forfeited))
    }

    // --- Penalties ---

    fun canAddPenalty(): Boolean = !isGameOver && state.penalties < BonusState.MAX_PENALTIES

    fun addPenalty() {
        if (!canAddPenalty()) return
        state = state.copy(penalties = state.penalties + 1)
        recordAction(BonusAction.Penalty)
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
        // A conceded colour is completed too, so its remaining bonus-bar
        // fields are forfeited immediately - same as a self-lock.
        val forfeited = forfeitBarFields(color)
        recordAction(BonusAction.Concede(color, forfeited))
    }

    /**
     * Official forfeit rule: cross out every still-unearned bonus-bar field
     * of a just-completed [color]. Those fields no longer count and are
     * skipped by future earned crosses. Returns the forfeited indices for
     * exact undo.
     */
    private fun forfeitBarFields(color: GameColor): List<Int> {
        val indices = BonusLayout.barColors.indices.filter {
            BonusLayout.barColors[it] == color &&
                it !in state.bar.earned &&
                it !in state.bar.forfeited
        }
        state = state.copy(bar = state.bar.copy(forfeited = state.bar.forfeited + indices))
        return indices
    }

    fun isLastConcede(color: GameColor): Boolean {
        val last = state.history.lastOrNull() as? BonusAction.Concede ?: return false
        return last.color == color
    }

    /** End the game by hand - e.g. another player crossed the final lock. */
    fun canFinishManually(): Boolean = !isGameOver

    fun finishGame() {
        if (!canFinishManually()) return
        state = state.copy(manuallyFinished = true)
        recordAction(BonusAction.Finish)
    }

    // --- Scoreboard ---

    /** Crosses counted toward a colour's score: its own marks plus the lock. */
    fun crosses(color: GameColor): Int = row(color).scoringCrosses

    fun points(color: GameColor): Int = scoring.points(forCrosses = crosses(color))

    val penaltyPoints: Int get() = state.penalties * 5

    override val totalScore: Int
        get() = GameColor.entries.sumOf { points(it) } - penaltyPoints

    /**
     * Ends when two rows are locked, the 4th penalty is taken, or the player
     * ends it by hand.
     */
    override val isGameOver: Boolean
        get() = state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= BonusState.MAX_PENALTIES

    override val canUndo: Boolean get() = state.history.isNotEmpty()

    // --- Tap-to-undo ---

    fun isLastColorMark(color: GameColor, index: Int): Boolean {
        val last = state.history.lastOrNull() as? BonusAction.ColorMark ?: return false
        return last.color == color && last.index == index
    }

    fun isLastPenalty(): Boolean = state.history.lastOrNull() is BonusAction.Penalty

    /**
     * Reverse the most recent action. Strictly LIFO. Reverses the colour
     * mark, the bar earn (if any) and any bar forfeiture atomically.
     */
    override fun undo() {
        val last = state.history.lastOrNull() ?: return
        state = state.copy(history = state.history.dropLast(1))
        when (last) {
            is BonusAction.ColorMark -> {
                var r = row(last.color)
                r = r.copy(marks = r.marks - last.index)
                if (last.didLock) r = r.copy(locked = false)
                setRow(r)
                when (val adv = last.bar) {
                    is BarAdvance.Earned -> {
                        state = state.copy(bar = state.bar.copy(earned = state.bar.earned - adv.field))
                    }
                    is BarAdvance.Legacy -> {
                        // Pre-forfeit saves filled the bar strictly left to
                        // right, so the newest cross is the highest earned
                        // index. Never produced by this engine, kept for
                        // wire-shape parity only.
                        val top = state.bar.earned.maxOrNull()
                        if (top != null) {
                            state = state.copy(bar = state.bar.copy(earned = state.bar.earned - top))
                        }
                    }
                    is BarAdvance.None -> {}
                }
                state = state.copy(bar = state.bar.copy(forfeited = state.bar.forfeited - last.forfeited.toSet()))
            }
            is BonusAction.Penalty -> {
                state = state.copy(penalties = maxOf(0, state.penalties - 1))
            }
            is BonusAction.Concede -> {
                val r = row(last.color)
                setRow(r.copy(locked = false))
                state = state.copy(bar = state.bar.copy(forfeited = state.bar.forfeited - last.forfeited.toSet()))
            }
            is BonusAction.Finish -> {
                state = state.copy(manuallyFinished = false)
            }
        }
        redoStack = redoStack + last
    }

    override val canRedo: Boolean get() = redoStack.isNotEmpty()

    /**
     * Re-apply the most recently undone action through the SAME mutator a
     * fresh move takes, so scores/locks/derived state (including the bonus
     * bar's earned/forfeited fields) stay exact - never re-implement the
     * effect here.
     */
    override fun redo() {
        val next = redoStack.lastOrNull() ?: return
        redoStack = redoStack.dropLast(1)
        isRedoing = true
        try {
            when (next) {
                is BonusAction.ColorMark -> markColor(next.color, next.index)
                is BonusAction.Penalty -> addPenalty()
                is BonusAction.Concede -> concedeRow(next.color)
                is BonusAction.Finish -> finishGame()
            }
        } finally {
            isRedoing = false
        }
    }

    override fun reset() {
        state = BonusState()
        redoStack = emptyList()
    }

    /** Replace the engine's state wholesale, e.g. after loading a persisted snapshot. */
    fun restore(state: BonusState) {
        // Copy the collections defensively: the marks/bar fields are typed
        // Set<Int>, so a caller holding a MutableSet reference could
        // otherwise mutate engine state from outside.
        this.state = state.copy(
            red = state.red.copy(marks = state.red.marks.toSet()),
            yellow = state.yellow.copy(marks = state.yellow.marks.toSet()),
            green = state.green.copy(marks = state.green.marks.toSet()),
            blue = state.blue.copy(marks = state.blue.marks.toSet()),
            bar = state.bar.copy(earned = state.bar.earned.toSet(), forfeited = state.bar.forfeited.toSet()),
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
    private fun recordAction(action: BonusAction) {
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
