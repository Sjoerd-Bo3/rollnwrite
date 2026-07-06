package dev.bo3.rollnwrite.xchange

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
import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.engine.xchange.XChangeGame
import dev.bo3.rollnwrite.engine.xchange.XChangeRow
import dev.bo3.rollnwrite.engine.xchange.XChangeState
import kotlinx.serialization.json.Json

/**
 * App-layer host for [XChangeGame]: owns persistence (SharedPreferences) and
 * exposes engine state as Compose-observable so the board recomposes on
 * every mutation.
 *
 * Mirrors `RollnWrite/Games/QwixxXChange/XChangeGame.swift`'s persistence
 * section, but layered outside the engine (see `QwixxViewModel` for the same
 * pattern on the base game) - the engine stays pure JVM/no-Android, this
 * class is the Android host that wires it to `SharedPreferences`.
 *
 * Views must NEVER enforce rules directly: they call the `can*` getters
 * forwarded below and the mutators, exactly like the engine's own contract.
 */
class XChangeViewModel(
    context: Context,
    private val persistenceKey: String,
    scoring: ScoringStrategy = TriangularScoring(cap = 12),
) : ViewModel(), Scoreboard {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val engine = XChangeGame(scoring = scoring)

    /**
     * Compose-observable snapshot of the engine's state. Reassigned (never
     * mutated in place) after every mutator call below so Compose sees a new
     * value and recomposes. Uses `neverEqualPolicy()` because the redo stack
     * lives outside `XChangeState` (in-memory in the engine) - mirrors
     * `QwixxViewModel.snapshot`'s rationale exactly.
     */
    var snapshot: XChangeState by mutableStateOf(engine.state, neverEqualPolicy())
        private set

    init {
        loadFromPrefs()
    }

    // --- Accessors (forwarded; views read these, never engine internals) ---
    // Each touches `snapshot` first so callers subscribe to it in Compose.

    fun row(color: GameColor): ColorRow { snapshot; return engine.row(color) }

    val xchange: XChangeRow get() { snapshot; return engine.xchange }

    val penalties: Int get() { snapshot; return engine.penalties }

    val lockedRowCount: Int get() { snapshot; return engine.lockedRowCount }

    fun canMarkColor(color: GameColor, index: Int): Boolean {
        snapshot
        return engine.canMarkColor(color, index)
    }

    fun canMarkXChange(index: Int): Boolean {
        snapshot
        return engine.canMarkXChange(index)
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

    fun isLastXChangeMark(index: Int): Boolean {
        snapshot
        return engine.isLastXChangeMark(index)
    }

    fun isLastPenalty(): Boolean { snapshot; return engine.isLastPenalty() }

    fun isLastConcede(color: GameColor): Boolean { snapshot; return engine.isLastConcede(color) }

    // --- Mutators: apply through the engine, refresh the snapshot, persist ---

    fun markColor(color: GameColor, index: Int) {
        engine.markColor(color, index)
        commit()
    }

    fun markXChange(index: Int) {
        engine.markXChange(index)
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
        val encoded = json.encodeToString(XChangeState.serializer(), engine.state)
        prefs.edit().putString(persistenceKey, encoded).apply()
    }

    /**
     * Tolerant load: missing or corrupt JSON leaves the fresh engine state in
     * place rather than crashing - mirrors the Swift `load()`'s
     * `try?`-and-fall-through behaviour.
     */
    private fun loadFromPrefs() {
        val raw = prefs.getString(persistenceKey, null) ?: return
        val restored = runCatching { json.decodeFromString(XChangeState.serializer(), raw) }
            .getOrNull() ?: return
        engine.restore(restored)
        snapshot = engine.state
    }

    companion object {
        private const val PREFS_NAME = "rollnwrite"

        /** Mirrors the iOS persistence key (`XChangeGame.swift`'s default). */
        const val DEFAULT_KEY_PLAYER_ONE = "rollnwrite.qwixx.xchange.state"

        /** Player 2's independent board (two-player mirrored mode). */
        const val DEFAULT_KEY_PLAYER_TWO = "$DEFAULT_KEY_PLAYER_ONE.p2"

        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
        }
    }
}

/**
 * Builds a [ViewModelProvider.Factory] for an [XChangeViewModel] bound to a
 * specific [persistenceKey], so two independent instances (player 1 / player
 * 2 in two-player mode) can be created in the same screen.
 */
fun xchangeViewModelFactory(
    context: Context,
    persistenceKey: String,
    scoring: ScoringStrategy = TriangularScoring(cap = 12),
): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
        @Suppress("UNCHECKED_CAST")
        return XChangeViewModel(
            context = context,
            persistenceKey = persistenceKey,
            scoring = scoring,
        ) as T
    }
}
