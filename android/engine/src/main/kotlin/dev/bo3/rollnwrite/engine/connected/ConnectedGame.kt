package dev.bo3.rollnwrite.engine.connected

import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.TriangularScoring
import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor

/**
 * The Qwixx "Connected" (The Chain) engine: holds state, enforces the rules,
 * and computes the score through an injected [ScoringStrategy].
 *
 * Mirrors `RollnWrite/Games/QwixxConnected/ConnectedGame.swift` name-for-name
 * (Kotlin conventions). Pure JVM, no Android imports.
 *
 * The colour-row rules are identical to classic Qwixx. The variant-specific
 * twist is the printed *chains*: crossing a circled chain space automatically
 * crosses its partner space too, ignoring the normal left-to-right rule and
 * applying even when the partner row is already locked. The four colour rows
 * are scored unchanged — the auto-crossed partner just counts as one more
 * cross in its own row.
 *
 * Persistence lives OUTSIDE the engine (an Android app-layer concern), same
 * layering as `QwixxGame`/`BonusGame`.
 */
class ConnectedGame(
    /** Classic Qwixx scoring: up to 12 valued crosses per colour (78 points). */
    private val scoring: ScoringStrategy = TriangularScoring(cap = 12),
) : Scoreboard {

    var state: ConnectedState = ConnectedState()
        private set

    /**
     * Actions undone via [undo], most-recently-undone last, so [redo] can
     * re-apply them in LIFO order. Deliberately NOT part of [state] - redo is
     * an in-memory, per-session convenience, like most editors. Any new
     * forward move (via `recordAction`) clears it.
     */
    private var redoStack: List<ConnectedAction> = emptyList()

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

    val penalties: Int get() = state.penalties

    val lockedRowCount: Int
        get() = GameColor.entries.count { row(it).locked }

    /** Whether the cell at ([color], [index]) is a circled chain space. */
    fun isChainSpace(color: GameColor, index: Int): Boolean = ConnectedLayout.isChainSpace(color, index)

    /** The partner of a chain space, for drawing the connecting link. */
    fun chainPartner(color: GameColor, index: Int): ChainEnd? = ConnectedLayout.partner(color, index)

    /** Whether ([color], [index]) is currently crossed in its row. */
    fun isMarked(color: GameColor, index: Int): Boolean = index in row(color).marks

    // --- Rule enforcement (colour rows) ---

    /**
     * Whether crossing [index] in [color] is a legal *deliberate* move now.
     *
     * Enforces: game not over, row not locked, not already marked,
     * left-to-right, and the right-most number needs >=5 earlier crosses to
     * lock. (Automatic partner crosses are NOT gated by this - see
     * [markColor].)
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

        // Automatic chain co-mark: crossing a circled space forces its
        // partner. This ignores the normal rules and applies even to a
        // locked row. It is recorded only if it was a NEW mark, so undo
        // restores exactly.
        var auto: ChainEnd? = null
        val partner = ConnectedLayout.partner(color, index)
        if (partner != null) {
            var pr = row(partner.color)
            if (partner.index !in pr.marks) {
                pr = pr.copy(marks = pr.marks + partner.index)
                // A forced co-mark never locks a row, even on the right-most cell.
                setRow(pr)
                auto = partner
            }
        }

        recordAction(ConnectedAction.ColorMark(color, index, didLock, auto))
    }

    // --- Penalties ---

    fun canAddPenalty(): Boolean = !isGameOver && state.penalties < ConnectedState.MAX_PENALTIES

    fun addPenalty() {
        if (!canAddPenalty()) return
        state = state.copy(penalties = state.penalties + 1)
        recordAction(ConnectedAction.Penalty)
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
        recordAction(ConnectedAction.Concede(color))
    }

    fun isLastConcede(color: GameColor): Boolean {
        val last = state.history.lastOrNull() as? ConnectedAction.Concede ?: return false
        return last.color == color
    }

    /** End the game by hand - e.g. another player crossed the final lock. */
    fun canFinishManually(): Boolean = !isGameOver

    fun finishGame() {
        if (!canFinishManually()) return
        state = state.copy(manuallyFinished = true)
        recordAction(ConnectedAction.Finish)
    }

    // --- Scoreboard ---

    /**
     * Crosses counted toward a colour's score: its own marks plus the lock.
     * Automatically chained marks live in `marks` and so are already
     * included.
     */
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
        get() = state.manuallyFinished || lockedRowCount >= 2 || state.penalties >= ConnectedState.MAX_PENALTIES

    override val canUndo: Boolean get() = state.history.isNotEmpty()

    // --- Tap-to-undo ---
    //
    // Tapping your most-recent mark un-checks it. Undo is strictly LIFO, so
    // only the *last* action is reversible this way. A deliberate chain cross
    // and its forced partner co-mark are ONE action, so only the
    // deliberately-crossed cell is tap-undoable; tapping it reverses both
    // crosses together.

    fun isLastColorMark(color: GameColor, index: Int): Boolean {
        val last = state.history.lastOrNull() as? ConnectedAction.ColorMark ?: return false
        return last.color == color && last.index == index
    }

    fun isLastPenalty(): Boolean = state.history.lastOrNull() is ConnectedAction.Penalty

    /**
     * Reverse the most recent action. Strictly LIFO, so an automatic partner
     * cross is always undone together with the deliberate mark that caused
     * it.
     */
    override fun undo() {
        val last = state.history.lastOrNull() ?: return
        state = state.copy(history = state.history.dropLast(1))
        when (last) {
            is ConnectedAction.ColorMark -> {
                var r = row(last.color)
                r = r.copy(marks = r.marks - last.index)
                if (last.didLock) r = r.copy(locked = false)
                setRow(r)
                last.auto?.let { auto ->
                    var pr = row(auto.color)
                    pr = pr.copy(marks = pr.marks - auto.index)
                    setRow(pr)
                }
            }
            is ConnectedAction.Penalty -> {
                state = state.copy(penalties = maxOf(0, state.penalties - 1))
            }
            is ConnectedAction.Concede -> {
                val r = row(last.color)
                setRow(r.copy(locked = false))
            }
            is ConnectedAction.Finish -> {
                state = state.copy(manuallyFinished = false)
            }
        }
        redoStack = redoStack + last
    }

    override val canRedo: Boolean get() = redoStack.isNotEmpty()

    /**
     * Re-apply the most recently undone action through the SAME mutator a
     * fresh move takes, so scores/locks/derived state stay exact - never
     * re-implement the effect here. [markColor] re-derives the chain partner
     * itself (deterministic from [ConnectedLayout] + current marks, both of
     * which [undo] restored), so it reproduces the same `auto` co-mark.
     */
    override fun redo() {
        val next = redoStack.lastOrNull() ?: return
        redoStack = redoStack.dropLast(1)
        isRedoing = true
        try {
            when (next) {
                is ConnectedAction.ColorMark -> markColor(next.color, next.index)
                is ConnectedAction.Penalty -> addPenalty()
                is ConnectedAction.Concede -> concedeRow(next.color)
                is ConnectedAction.Finish -> finishGame()
            }
        } finally {
            isRedoing = false
        }
    }

    override fun reset() {
        state = ConnectedState()
        redoStack = emptyList()
    }

    /** Replace the engine's state wholesale, e.g. after loading a persisted snapshot. */
    fun restore(state: ConnectedState) {
        // Copy the collections defensively: `marks` is a typed Set<Int>, so a
        // caller holding a MutableSet reference could otherwise mutate engine
        // state from outside.
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
    private fun recordAction(action: ConnectedAction) {
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
