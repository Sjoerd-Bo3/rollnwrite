package dev.bo3.rollnwrite.engine.lucky15

import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.TriangularScoring
import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor

/**
 * The Qwixx "Lucky 15" engine: holds state, enforces the rules, and computes
 * the score through an injected [ScoringStrategy].
 *
 * Mirrors `RollnWrite/Games/QwixxLucky15/Lucky15Game.swift` name-for-name
 * (Kotlin conventions). Pure JVM, no Android imports. The colour-row rules
 * are identical to classic Qwixx (cap 12, no bonus rows); the Lucky 15
 * track is the variant-specific addition.
 *
 * Persistence lives OUTSIDE the engine (an Android app-layer concern), same
 * layering as [dev.bo3.rollnwrite.engine.qwixx.QwixxGame].
 */
class Lucky15Game(
    /** Classic Qwixx scoring: up to 12 valued crosses per colour (78 points). */
    private val scoring: ScoringStrategy = TriangularScoring(cap = 12),
) : Scoreboard {

    var state: Lucky15State = Lucky15State()
        private set

    /**
     * Actions undone via [undo], most-recently-undone last, so [redo] can
     * re-apply them in LIFO order. Deliberately NOT part of [state] (kept
     * outside so it is never serialised) - redo is an in-memory,
     * per-session convenience. Any new forward move (via `recordAction`)
     * clears it, matching standard undo/redo semantics.
     */
    private var redoStack: List<Lucky15Action> = emptyList()

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

    val lucky: Lucky15Track get() = state.lucky

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
        recordAction(Lucky15Action.ColorMark(color, index, didLock))
    }

    // --- Rule enforcement (Lucky 15 track) ---

    /**
     * The Lucky 15 track is crossed strictly left -> right; a field is
     * legal while the game is live and the track still has room.
     */
    fun canMarkLucky(): Boolean = !isGameOver && state.lucky.hasRoomLeft

    fun markLucky() {
        if (!canMarkLucky()) return
        state = state.copy(lucky = state.lucky.copy(crossed = state.lucky.crossed + 1))
        recordAction(Lucky15Action.Lucky15Mark)
    }

    // --- Penalties ---

    fun canAddPenalty(): Boolean = !isGameOver && state.penalties < Lucky15State.MAX_PENALTIES

    fun addPenalty() {
        if (!canAddPenalty()) return
        state = state.copy(penalties = state.penalties + 1)
        recordAction(Lucky15Action.Penalty)
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
        recordAction(Lucky15Action.Concede(color))
    }

    fun isLastConcede(color: GameColor): Boolean {
        val last = state.history.lastOrNull() as? Lucky15Action.Concede ?: return false
        return last.color == color
    }

    /** End the game by hand - e.g. another player crossed the final lock. */
    fun canFinishManually(): Boolean = !isGameOver

    fun finishGame() {
        if (!canFinishManually()) return
        state = state.copy(manuallyFinished = true)
        recordAction(Lucky15Action.Finish)
    }

    // --- Scoreboard ---

    /** Crosses counted toward a colour's score: its own marks plus the lock. */
    fun crosses(color: GameColor): Int = row(color).scoringCrosses

    fun points(color: GameColor): Int = scoring.points(forCrosses = crosses(color))

    /** The Lucky 15 bonus: the value of the highest crossed track field. */
    val luckyPoints: Int get() = state.lucky.points

    val penaltyPoints: Int get() = state.penalties * 5

    override val totalScore: Int
        get() = GameColor.entries.sumOf { points(it) } + luckyPoints - penaltyPoints

    /**
     * Ends when two rows are locked, the 4th penalty is taken, or the
     * player ends it by hand.
     */
    override val isGameOver: Boolean
        get() = state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= Lucky15State.MAX_PENALTIES

    override val canUndo: Boolean get() = state.history.isNotEmpty()

    // --- Tap-to-undo ---

    fun isLastColorMark(color: GameColor, index: Int): Boolean {
        val last = state.history.lastOrNull() as? Lucky15Action.ColorMark ?: return false
        return last.color == color && last.index == index
    }

    /** Whether the right-most crossed Lucky 15 field is the most-recent action. */
    fun isLastLuckyMark(): Boolean = state.history.lastOrNull() is Lucky15Action.Lucky15Mark

    fun isLastPenalty(): Boolean = state.history.lastOrNull() is Lucky15Action.Penalty

    /** Reverse the most recent action. Strictly LIFO. */
    override fun undo() {
        val last = state.history.lastOrNull() ?: return
        state = state.copy(history = state.history.dropLast(1))
        when (last) {
            is Lucky15Action.ColorMark -> {
                var r = row(last.color)
                r = r.copy(marks = r.marks - last.index)
                if (last.didLock) r = r.copy(locked = false)
                setRow(r)
            }
            is Lucky15Action.Lucky15Mark -> {
                state = state.copy(lucky = state.lucky.copy(crossed = maxOf(0, state.lucky.crossed - 1)))
            }
            is Lucky15Action.Penalty -> {
                state = state.copy(penalties = maxOf(0, state.penalties - 1))
            }
            is Lucky15Action.Concede -> {
                val r = row(last.color)
                setRow(r.copy(locked = false))
            }
            is Lucky15Action.Finish -> {
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
                is Lucky15Action.ColorMark -> markColor(next.color, next.index)
                is Lucky15Action.Lucky15Mark -> markLucky()
                is Lucky15Action.Penalty -> addPenalty()
                is Lucky15Action.Concede -> concedeRow(next.color)
                is Lucky15Action.Finish -> finishGame()
            }
        } finally {
            isRedoing = false
        }
    }

    override fun reset() {
        state = Lucky15State()
        redoStack = emptyList()
    }

    /** Replace the engine's state wholesale, e.g. after loading a persisted snapshot. */
    fun restore(state: Lucky15State) {
        // Copy the collections defensively: the marks fields are typed
        // Set<Int>, so a caller holding a MutableSet reference could
        // otherwise mutate engine state from outside.
        this.state = state.copy(
            red = state.red.copy(marks = state.red.marks.toSet()),
            yellow = state.yellow.copy(marks = state.yellow.marks.toSet()),
            green = state.green.copy(marks = state.green.marks.toSet()),
            blue = state.blue.copy(marks = state.blue.marks.toSet()),
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
    private fun recordAction(action: Lucky15Action) {
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
