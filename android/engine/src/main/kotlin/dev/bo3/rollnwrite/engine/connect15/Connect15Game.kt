package dev.bo3.rollnwrite.engine.connect15

import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.TriangularScoring
import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor

/**
 * The Qwixx "Connect 15" engine: holds state, enforces the rules, and
 * computes the score through an injected [ScoringStrategy].
 *
 * Mirrors `RollnWrite/Games/QwixxConnect15/Connect15Game.swift` name-for-name
 * (Kotlin conventions). Pure JVM, no Android imports. The colour-row rules
 * are classic Qwixx; the variant twist is that each row's three connection
 * fields join the row's ONE left-to-right sequence. Legality of every mark
 * - number or connection field - is "its interleaved position is right of
 * the row's highest marked position" ([Connect15Layout] positions: number ->
 * 2*column, connection field -> 2*column + 1). Skipped spaces of either kind
 * are forfeited implicitly. Crossed connection fields count as extra crosses
 * toward the row's total (raising the cap from 12 to 15).
 *
 * Persistence lives OUTSIDE the engine (an Android app-layer concern), same
 * layering as [dev.bo3.rollnwrite.engine.qwixx.QwixxGame] / `Lucky15Game`.
 */
class Connect15Game(
    /** Connect 15 scoring: up to 15 valued crosses per colour (120 points). */
    private val scoring: ScoringStrategy = TriangularScoring(cap = 15),
) : Scoreboard {

    var state: Connect15State = Connect15State()
        private set

    /**
     * Actions undone via [undo], most-recently-undone last, so [redo] can
     * re-apply them in LIFO order. Deliberately NOT part of [state] (kept
     * outside so it is never serialised) - redo is an in-memory,
     * per-session convenience. Any new forward move (via `recordAction`)
     * clears it, matching standard undo/redo semantics.
     */
    private var redoStack: List<Connect15Action> = emptyList()

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

    fun connections(color: GameColor): ConnectionFields = when (color) {
        GameColor.RED -> state.redConnections
        GameColor.YELLOW -> state.yellowConnections
        GameColor.GREEN -> state.greenConnections
        GameColor.BLUE -> state.blueConnections
    }

    val penalties: Int get() = state.penalties

    val lockedRowCount: Int
        get() = GameColor.entries.count { row(it).locked }

    // --- The interleaved left-to-right rule ---

    /**
     * The row's highest marked interleaved position - numbers AND
     * connection fields combined ([Connect15Layout] doubled positions), or
     * -1 if the row is empty. Any new mark must sit strictly right of this.
     */
    fun maxMarkedPosition(color: GameColor): Int {
        val numberMax = row(color).marks
            .map { Connect15Layout.numberPosition(it) }
            .maxOrNull() ?: -1
        val columns = Connect15Layout.columns(color)
        val fieldMax = connections(color).marks
            .mapNotNull { field ->
                if (field < columns.size) Connect15Layout.connectionPosition(columns[field]) else null
            }
            .maxOrNull() ?: -1
        return maxOf(numberMax, fieldMax)
    }

    // --- Rule enforcement (colour rows) ---

    /**
     * Whether crossing number [index] in [color] is a legal move right now.
     *
     * Enforces: game not over, row not locked, strictly right of the row's
     * highest marked position (numbers and connection fields form one
     * left-to-right sequence, so this also rejects already-marked numbers
     * and implicitly forfeits skipped connection fields), the right-most
     * number needs >=5 earlier NUMBER crosses to lock.
     */
    fun canMarkColor(color: GameColor, index: Int): Boolean {
        if (isGameOver) return false
        val r = row(color)
        if (r.locked || Connect15Layout.numberPosition(index) <= maxMarkedPosition(color)) return false
        if (index == ColorRow.LOCK_INDEX) {
            // Confirmed by the game's owner against the paper rules: locking
            // needs at least 5 crossed NUMBERS in the row - connection
            // fields do not count toward the five ("just count normally").
            return r.marks.size >= 5
        }
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
        recordAction(Connect15Action.ColorMark(color, index, didLock))
    }

    // --- Rule enforcement (connection fields) ---

    /**
     * Whether crossing connection field [field] (0-based ordinal, left ->
     * right) of [color] is legal: game live, row not locked (locking or
     * conceding a row closes its remaining connection fields), field not
     * already marked, and its interleaved position strictly right of the
     * row's highest marked position - crossing it forfeits every skipped
     * space to its left, and any field left of an existing mark is itself
     * forfeited.
     */
    fun canMarkConnection(color: GameColor, field: Int): Boolean {
        if (isGameOver) return false
        val columns = Connect15Layout.columns(color)
        if (field < 0 || field >= columns.size) return false
        if (row(color).locked || field in connections(color).marks) return false
        return Connect15Layout.connectionPosition(columns[field]) > maxMarkedPosition(color)
    }

    fun markConnection(color: GameColor, field: Int) {
        if (!canMarkConnection(color, field)) return
        val f = connections(color)
        setConnections(f.copy(marks = f.marks + field), color)
        recordAction(Connect15Action.ConnectionMark(color, field))
    }

    // --- Penalties ---

    fun canAddPenalty(): Boolean = !isGameOver && state.penalties < Connect15State.MAX_PENALTIES

    fun addPenalty() {
        if (!canAddPenalty()) return
        state = state.copy(penalties = state.penalties + 1)
        recordAction(Connect15Action.Penalty)
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
        recordAction(Connect15Action.Concede(color))
    }

    fun isLastConcede(color: GameColor): Boolean {
        val last = state.history.lastOrNull() as? Connect15Action.Concede ?: return false
        return last.color == color
    }

    /** End the game by hand - e.g. another player crossed the final lock. */
    fun canFinishManually(): Boolean = !isGameOver

    fun finishGame() {
        if (!canFinishManually()) return
        state = state.copy(manuallyFinished = true)
        recordAction(Connect15Action.Finish)
    }

    // --- Scoreboard ---

    /**
     * Crosses counted toward a colour's score: its number marks, the lock
     * cross, plus any crossed connection fields. Capped by the scoring
     * strategy (15).
     */
    fun crosses(color: GameColor): Int = row(color).scoringCrosses + connections(color).marks.size

    fun points(color: GameColor): Int = scoring.points(forCrosses = crosses(color))

    val penaltyPoints: Int get() = state.penalties * 5

    override val totalScore: Int
        get() = GameColor.entries.sumOf { points(it) } - penaltyPoints

    /**
     * Ends when two rows are locked, the 4th penalty is taken, or the
     * player ends it by hand.
     */
    override val isGameOver: Boolean
        get() = state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= Connect15State.MAX_PENALTIES

    override val canUndo: Boolean get() = state.history.isNotEmpty()

    // --- Tap-to-undo helpers ---
    //
    // Mirror `QwixxGame`/`Lucky15Game`: report whether a given mark is the
    // single most-recent action, so the view can ring it and let a tap
    // un-check it (strictly LIFO).

    fun isLastColorMark(color: GameColor, index: Int): Boolean {
        val last = state.history.lastOrNull() as? Connect15Action.ColorMark ?: return false
        return last.color == color && last.index == index
    }

    fun isLastConnectionMark(color: GameColor, field: Int): Boolean {
        val last = state.history.lastOrNull() as? Connect15Action.ConnectionMark ?: return false
        return last.color == color && last.field == field
    }

    fun isLastPenalty(): Boolean = state.history.lastOrNull() is Connect15Action.Penalty

    /** Reverse the most recent action. Strictly LIFO. */
    override fun undo() {
        val last = state.history.lastOrNull() ?: return
        state = state.copy(history = state.history.dropLast(1))
        when (last) {
            is Connect15Action.ColorMark -> {
                var r = row(last.color)
                r = r.copy(marks = r.marks - last.index)
                if (last.didLock) r = r.copy(locked = false)
                setRow(r)
            }
            is Connect15Action.ConnectionMark -> {
                val f = connections(last.color)
                setConnections(f.copy(marks = f.marks - last.field), last.color)
            }
            is Connect15Action.Penalty -> {
                state = state.copy(penalties = maxOf(0, state.penalties - 1))
            }
            is Connect15Action.Concede -> {
                val r = row(last.color)
                setRow(r.copy(locked = false))
            }
            is Connect15Action.Finish -> {
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
                is Connect15Action.ColorMark -> markColor(next.color, next.index)
                is Connect15Action.ConnectionMark -> markConnection(next.color, next.field)
                is Connect15Action.Penalty -> addPenalty()
                is Connect15Action.Concede -> concedeRow(next.color)
                is Connect15Action.Finish -> finishGame()
            }
        } finally {
            isRedoing = false
        }
    }

    override fun reset() {
        state = Connect15State()
        redoStack = emptyList()
    }

    /** Replace the engine's state wholesale, e.g. after loading a persisted snapshot. */
    fun restore(state: Connect15State) {
        // Copy the collections defensively: the marks fields are typed
        // Set<Int>, so a caller holding a MutableSet reference could
        // otherwise mutate engine state from outside.
        this.state = state.copy(
            red = state.red.copy(marks = state.red.marks.toSet()),
            yellow = state.yellow.copy(marks = state.yellow.marks.toSet()),
            green = state.green.copy(marks = state.green.marks.toSet()),
            blue = state.blue.copy(marks = state.blue.marks.toSet()),
            redConnections = state.redConnections.copy(marks = state.redConnections.marks.toSet()),
            yellowConnections = state.yellowConnections.copy(marks = state.yellowConnections.marks.toSet()),
            greenConnections = state.greenConnections.copy(marks = state.greenConnections.marks.toSet()),
            blueConnections = state.blueConnections.copy(marks = state.blueConnections.marks.toSet()),
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
    private fun recordAction(action: Connect15Action) {
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

    private fun setConnections(f: ConnectionFields, color: GameColor) {
        state = when (color) {
            GameColor.RED -> state.copy(redConnections = f)
            GameColor.YELLOW -> state.copy(yellowConnections = f)
            GameColor.GREEN -> state.copy(greenConnections = f)
            GameColor.BLUE -> state.copy(blueConnections = f)
        }
    }
}
