package dev.bo3.rollnwrite.connect15

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.neverEqualPolicy
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewmodel.CreationExtras
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.bo3.rollnwrite.engine.Scoreboard
import dev.bo3.rollnwrite.engine.connect15.Connect15Game
import dev.bo3.rollnwrite.engine.connect15.Connect15State
import dev.bo3.rollnwrite.engine.connect15.ConnectionFields
import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.json.Json

/**
 * App-layer host for [Connect15Game]: owns persistence (SharedPreferences)
 * and exposes engine state as Compose-observable so the board recomposes on
 * every mutation.
 *
 * Mirrors `RollnWrite/Games/QwixxConnect15/Connect15Game.swift`'s
 * persistence section and the Android `Lucky15ViewModel`'s layering (engine
 * stays pure JVM/no-Android; this class is the Android host wiring it to
 * `SharedPreferences`).
 *
 * Views must NEVER enforce rules directly: they call the `can*` getters
 * forwarded below and the mutators, exactly like the engine's own contract.
 */
class Connect15ViewModel(
    context: Context,
    private val persistenceKey: String,
) : ViewModel(), Scoreboard {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val engine = Connect15Game()

    /**
     * Compose-observable snapshot of the engine's state. Reassigned (never
     * mutated in place) after every mutator call so Compose sees a new value
     * and recomposes. Uses `neverEqualPolicy()` because the redo stack lives
     * outside `Connect15State` (in-memory in the engine) - a commit can
     * change engine-visible behaviour (e.g. `canRedo`) while leaving a
     * structurally-equal `Connect15State`, and a structural-equality policy
     * would then fail to invalidate readers. Mirrors `Lucky15ViewModel`.
     */
    var snapshot: Connect15State by mutableStateOf(engine.state, neverEqualPolicy())
        private set

    init {
        loadFromPrefs()
    }

    // --- Accessors (forwarded; views read these, never engine internals) ---
    // Each touches `snapshot` first so callers subscribe to it in Compose.

    fun row(color: GameColor): ColorRow { snapshot; return engine.row(color) }

    fun connections(color: GameColor): ConnectionFields { snapshot; return engine.connections(color) }

    val penalties: Int get() { snapshot; return engine.penalties }

    val lockedRowCount: Int get() { snapshot; return engine.lockedRowCount }

    fun maxMarkedPosition(color: GameColor): Int { snapshot; return engine.maxMarkedPosition(color) }

    fun canMarkColor(color: GameColor, index: Int): Boolean {
        snapshot
        return engine.canMarkColor(color, index)
    }

    fun canMarkConnection(color: GameColor, field: Int): Boolean {
        snapshot
        return engine.canMarkConnection(color, field)
    }

    fun canAddPenalty(): Boolean { snapshot; return engine.canAddPenalty() }

    fun canConcedeRow(color: GameColor): Boolean { snapshot; return engine.canConcedeRow(color) }

    fun canFinishManually(): Boolean { snapshot; return engine.canFinishManually() }

    fun crosses(color: GameColor): Int { snapshot; return engine.crosses(color) }

    fun points(color: GameColor): Int { snapshot; return engine.points(color) }

    val penaltyPoints: Int get() { snapshot; return engine.penaltyPoints }

    override val totalScore: Int get() { snapshot; return engine.totalScore }

    override val isGameOver: Boolean get() { snapshot; return engine.isGameOver }

    override val canUndo: Boolean get() { snapshot; return engine.canUndo }

    override val canRedo: Boolean get() { snapshot; return engine.canRedo }

    fun isLastColorMark(color: GameColor, index: Int): Boolean {
        snapshot
        return engine.isLastColorMark(color, index)
    }

    fun isLastConnectionMark(color: GameColor, field: Int): Boolean {
        snapshot
        return engine.isLastConnectionMark(color, field)
    }

    fun isLastPenalty(): Boolean { snapshot; return engine.isLastPenalty() }

    fun isLastConcede(color: GameColor): Boolean { snapshot; return engine.isLastConcede(color) }

    // --- Mutators: apply through the engine, refresh the snapshot, persist ---

    fun markColor(color: GameColor, index: Int) {
        engine.markColor(color, index)
        commit()
    }

    fun markConnection(color: GameColor, field: Int) {
        engine.markConnection(color, field)
        commit()
    }

    fun addPenalty() {
        engine.addPenalty()
        commit()
    }

    fun concedeRow(color: GameColor) {
        engine.concedeRow(color)
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
        val encoded = json.encodeToString(Connect15State.serializer(), engine.state)
        prefs.edit().putString(persistenceKey, encoded).apply()
    }

    /**
     * Tolerant load: missing or corrupt JSON leaves the fresh engine state
     * in place rather than crashing - mirrors the Swift `load()`'s
     * `try?`-and-fall-through behaviour.
     */
    private fun loadFromPrefs() {
        val raw = prefs.getString(persistenceKey, null) ?: return
        val restored = runCatching { json.decodeFromString(Connect15State.serializer(), raw) }
            .getOrNull() ?: return
        engine.restore(restored)
        snapshot = engine.state
    }

    companion object {
        private const val PREFS_NAME = "rollnwrite"

        /** Mirrors the iOS persistence key (`Connect15Game.swift`'s default). */
        const val KEY_PLAYER_ONE = "rollnwrite.qwixx.connect15.state"

        /** Player 2's independent board (two-player mirrored mode). */
        const val KEY_PLAYER_TWO = "$KEY_PLAYER_ONE.p2"

        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
        }
    }
}

/**
 * Builds a [ViewModelProvider.Factory] for a [Connect15ViewModel] bound to a
 * specific [persistenceKey], so two independent instances (player 1 / player
 * 2 in two-player mode) can be created in the same screen - each needs its
 * own key, so the stock no-arg factory can't be used. Mirrors
 * `lucky15ViewModelFactory`.
 */
fun connect15ViewModelFactory(
    context: Context,
    persistenceKey: String,
): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
        @Suppress("UNCHECKED_CAST")
        return Connect15ViewModel(context = context, persistenceKey = persistenceKey) as T
    }
}

/**
 * Builds the player 1 / player 2 view models for Qwixx Connect15 under their
 * own persistence keys — mirrors `lucky15ViewModels`.
 */
@Composable
fun connect15ViewModels(): Pair<Connect15ViewModel, Connect15ViewModel> {
    val context = LocalContext.current
    val p1: Connect15ViewModel = viewModel(
        key = "qwixx-connect15-p1",
        factory = connect15ViewModelFactory(context, Connect15ViewModel.KEY_PLAYER_ONE),
    )
    val p2: Connect15ViewModel = viewModel(
        key = "qwixx-connect15-p2",
        factory = connect15ViewModelFactory(context, Connect15ViewModel.KEY_PLAYER_TWO),
    )
    return p1 to p2
}
