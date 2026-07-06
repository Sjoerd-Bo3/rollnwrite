package dev.bo3.rollnwrite.mixx

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.neverEqualPolicy
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.CreationExtras
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.ScoringStrategy
import dev.bo3.rollnwrite.engine.TriangularScoring
import dev.bo3.rollnwrite.engine.mixx.MixxBoard
import dev.bo3.rollnwrite.engine.mixx.MixxGame
import dev.bo3.rollnwrite.engine.mixx.MixxRowLayout
import dev.bo3.rollnwrite.engine.mixx.MixxState
import kotlinx.serialization.json.Json

/**
 * App-layer host for [MixxGame]: owns persistence (SharedPreferences) and
 * exposes engine state as Compose-observable so the board recomposes on
 * every mutation.
 *
 * Mirrors `RollnWrite/Games/QwixxMixx/MixxGame.swift`'s persistence section
 * and `QwixxViewModel`'s shape, but where the Swift `MixxGame` holds BOTH
 * boards in one object (`stateA`/`stateB`, switched via `board: didSet`),
 * this ViewModel owns exactly ONE board (the Kotlin engine, like
 * `QwixxGame`, is one-board-per-instance — see `MixxGame` docs) - the A/B
 * toggle in the UI layer switches which of TWO `MixxViewModel` instances
 * (one per board, each with its own persistence key) is shown, mirroring the
 * Swift UI's `Picker(selection: $game.board)` at the state-ownership level
 * instead of inside a single engine instance.
 */
class MixxViewModel(
    context: Context,
    private val persistenceKey: String,
    val board: MixxBoard,
    scoring: ScoringStrategy = TriangularScoring(cap = 12),
) : ViewModel(), Scoreboard {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val engine = MixxGame(board = board, scoring = scoring)

    /**
     * Compose-observable snapshot of the engine's state. Reassigned (never
     * mutated in place) after every mutator call below so Compose sees a
     * new value and recomposes. `neverEqualPolicy()` for the same reason as
     * `QwixxViewModel`: the redo stack lives outside `MixxState` (in-memory
     * in the engine), so a structural-equality policy could fail to
     * invalidate readers after e.g. `reset()` following an `undo()`.
     */
    var snapshot: MixxState by mutableStateOf(engine.state, neverEqualPolicy())
        private set

    init {
        loadFromPrefs()
    }

    val layout: List<MixxRowLayout> get() = engine.layout

    // --- Accessors (forwarded; views read these, never engine internals) ---
    // Each touches `snapshot` first so callers subscribe to it in Compose.

    fun rowState(rowIndex: Int) = run { snapshot; engine.rowState(rowIndex) }

    fun rowLayout(rowIndex: Int): MixxRowLayout = engine.rowLayout(rowIndex)

    val penalties: Int get() { snapshot; return engine.penalties }

    val lockedRowCount: Int get() { snapshot; return engine.lockedRowCount }

    fun canMark(rowIndex: Int, index: Int): Boolean {
        snapshot
        return engine.canMark(rowIndex, index)
    }

    fun canAddPenalty(): Boolean { snapshot; return engine.canAddPenalty() }

    fun canConcedeRow(rowIndex: Int): Boolean { snapshot; return engine.canConcedeRow(rowIndex) }

    fun canFinishManually(): Boolean { snapshot; return engine.canFinishManually() }

    fun crosses(rowIndex: Int): Int { snapshot; return engine.crosses(rowIndex) }

    fun points(rowIndex: Int): Int { snapshot; return engine.points(rowIndex) }

    val penaltyPoints: Int get() { snapshot; return engine.penaltyPoints }

    override val totalScore: Int get() { snapshot; return engine.totalScore }

    override val isGameOver: Boolean get() { snapshot; return engine.isGameOver }

    override val canUndo: Boolean get() { snapshot; return engine.canUndo }

    override val canRedo: Boolean get() { snapshot; return engine.canRedo }

    fun isLastMark(rowIndex: Int, index: Int): Boolean {
        snapshot
        return engine.isLastMark(rowIndex, index)
    }

    fun isLastPenalty(): Boolean { snapshot; return engine.isLastPenalty() }

    fun isLastConcede(rowIndex: Int): Boolean { snapshot; return engine.isLastConcede(rowIndex) }

    // --- Mutators: apply through the engine, refresh the snapshot, persist ---

    fun mark(rowIndex: Int, index: Int) {
        engine.mark(rowIndex, index)
        commit()
    }

    fun addPenalty() {
        engine.addPenalty()
        commit()
    }

    fun concedeRow(rowIndex: Int) {
        engine.concedeRow(rowIndex)
        commit()
    }

    fun finishGame() {
        engine.finishGame()
        commit()
    }

    override fun undo() {
        engine.undo()
        commit()
    }

    override fun redo() {
        engine.redo()
        commit()
    }

    override fun reset() {
        engine.reset()
        commit()
    }

    /** Refresh the observable snapshot and persist after every mutation. */
    private fun commit() {
        snapshot = engine.state
        saveToPrefs()
    }

    // --- Persistence ---

    private fun saveToPrefs() {
        val encoded = json.encodeToString(MixxState.serializer(), engine.state)
        prefs.edit().putString(persistenceKey, encoded).apply()
    }

    /**
     * Tolerant load: missing or corrupt JSON leaves the fresh engine state
     * in place rather than crashing - mirrors the Swift `load()`'s
     * `try?`-and-fall-through behaviour.
     */
    private fun loadFromPrefs() {
        val raw = prefs.getString(persistenceKey, null) ?: return
        val restored = runCatching { json.decodeFromString(MixxState.serializer(), raw) }
            .getOrNull() ?: return
        engine.restore(restored)
        snapshot = engine.state
    }

    companion object {
        private const val PREFS_NAME = "rollnwrite"

        /** Mirrors the iOS persistence key derivation (`MixxGame.swift`'s `stateKey(_:)`). */
        private const val PERSISTENCE_PREFIX = "rollnwrite.qwixx.mixx"

        fun stateKey(board: MixxBoard, playerSuffix: String = ""): String {
            val boardSegment = if (board == MixxBoard.VARIANT_A) "variantA" else "variantB"
            return "$PERSISTENCE_PREFIX.$boardSegment.state$playerSuffix"
        }

        /** Player 2's independent boards (two-player mirrored mode). */
        const val PLAYER_TWO_SUFFIX = ".p2"

        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
        }
    }
}

/**
 * Builds a [ViewModelProvider.Factory] for a [MixxViewModel] bound to a
 * specific board/persistence key, so four independent instances (board A/B x
 * player 1/2) can be created in the same screen.
 */
fun mixxViewModelFactory(
    context: Context,
    persistenceKey: String,
    board: MixxBoard,
    scoring: ScoringStrategy = TriangularScoring(cap = 12),
): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
        @Suppress("UNCHECKED_CAST")
        return MixxViewModel(
            context = context,
            persistenceKey = persistenceKey,
            board = board,
            scoring = scoring,
        ) as T
    }
}
