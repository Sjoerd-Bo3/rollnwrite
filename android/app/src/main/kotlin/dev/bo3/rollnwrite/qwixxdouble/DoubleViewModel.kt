package dev.bo3.rollnwrite.qwixxdouble

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
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.engine.qwixxdouble.DoubleColorRow
import dev.bo3.rollnwrite.engine.qwixxdouble.DoubleGame
import dev.bo3.rollnwrite.engine.qwixxdouble.DoubleState
import kotlinx.serialization.json.Json

/**
 * App-layer host for [DoubleGame]: owns persistence (SharedPreferences) and
 * exposes engine state as Compose-observable so the board recomposes on
 * every mutation.
 *
 * Mirrors `RollnWrite/Games/QwixxDouble/DoubleGame.swift`'s persistence
 * section, but layered outside the engine (see `DoubleGame` docs) - the
 * engine stays pure JVM/no-Android, this class is the Android host that
 * wires it to `SharedPreferences`. Structurally identical to
 * `dev.bo3.rollnwrite.qwixx.QwixxViewModel` (no bonus rows here).
 *
 * Views must NEVER enforce rules directly: they call the `can*` getters
 * forwarded below and the mutators, exactly like the engine's own contract.
 */
class DoubleViewModel(
    context: Context,
    private val persistenceKey: String,
    scoring: ScoringStrategy = TriangularScoring(cap = DoubleGame.SCORING_CAP),
) : ViewModel(), Scoreboard {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val engine = DoubleGame(scoring = scoring)

    /**
     * Compose-observable snapshot of the engine's state. Reassigned (never
     * mutated in place) after every mutator call below so Compose sees a
     * new value and recomposes. Uses `neverEqualPolicy()` because the redo
     * stack lives outside `DoubleState` (in-memory in the engine) - a commit
     * can change engine-visible behaviour (e.g. `canRedo`) while leaving a
     * structurally-equal `DoubleState` (e.g. reset() after an undo), and a
     * structural-equality policy would then fail to invalidate readers.
     *
     * Every accessor below reads `snapshot` (not just `engine.state`) before
     * delegating so that any composable calling them subscribes to this
     * state and recomposes on every `commit()`. `engine.state === snapshot`
     * after every commit, so delegating to the engine afterwards is safe.
     */
    var snapshot: DoubleState by mutableStateOf(engine.state, neverEqualPolicy())
        private set

    init {
        loadFromPrefs()
    }

    // --- Accessors (forwarded; views read these, never engine internals) ---
    // Each touches `snapshot` first so callers subscribe to it in Compose.

    fun row(color: GameColor): DoubleColorRow { snapshot; return engine.row(color) }

    val penalties: Int get() { snapshot; return engine.penalties }

    val lockedRowCount: Int get() { snapshot; return engine.lockedRowCount }

    fun canMarkColor(color: GameColor, index: Int): Boolean {
        snapshot
        return engine.canMarkColor(color, index)
    }

    fun canDoubleColor(color: GameColor, index: Int): Boolean {
        snapshot
        return engine.canDoubleColor(color, index)
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

    fun isLastDoubleMark(color: GameColor, index: Int): Boolean {
        snapshot
        return engine.isLastDoubleMark(color, index)
    }

    fun isLastPenalty(): Boolean { snapshot; return engine.isLastPenalty() }

    fun isLastConcede(color: GameColor): Boolean { snapshot; return engine.isLastConcede(color) }

    // --- Mutators: apply through the engine, refresh the snapshot, persist ---

    fun markColor(color: GameColor, index: Int) {
        engine.markColor(color, index)
        commit()
    }

    fun doubleColor(color: GameColor, index: Int) {
        engine.doubleColor(color, index)
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
        val encoded = json.encodeToString(DoubleState.serializer(), engine.state)
        prefs.edit().putString(persistenceKey, encoded).apply()
    }

    /**
     * Tolerant load: missing or corrupt JSON leaves the fresh engine state
     * in place rather than crashing - mirrors the Swift `load()`'s
     * `try?`-and-fall-through behaviour. `ignoreUnknownKeys` lets an older
     * build read a blob written by a newer one (extra fields) and vice
     * versa, since every `DoubleState`/row field carries a default.
     */
    private fun loadFromPrefs() {
        val raw = prefs.getString(persistenceKey, null) ?: return
        val restored = runCatching { json.decodeFromString(DoubleState.serializer(), raw) }
            .getOrNull() ?: return
        engine.restore(restored)
        snapshot = engine.state
    }

    companion object {
        private const val PREFS_NAME = "rollnwrite"

        /** Mirrors the iOS persistence key (`DoubleGame.swift`'s default). */
        const val DEFAULT_KEY_PLAYER_ONE = "rollnwrite.qwixx.double.state"

        /** Player 2's independent board (two-player mirrored mode). */
        const val DEFAULT_KEY_PLAYER_TWO = "$DEFAULT_KEY_PLAYER_ONE.p2"

        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
        }
    }
}

/**
 * Builds a [ViewModelProvider.Factory] for a [DoubleViewModel] bound to a
 * specific [persistenceKey], so two independent instances (player 1 / player
 * 2 in two-player mode) can be created in the same screen — each needs its
 * own key, so the stock no-arg factory can't be used.
 */
fun doubleViewModelFactory(
    context: Context,
    persistenceKey: String,
    scoring: ScoringStrategy = TriangularScoring(cap = DoubleGame.SCORING_CAP),
): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
        @Suppress("UNCHECKED_CAST")
        return DoubleViewModel(
            context = context,
            persistenceKey = persistenceKey,
            scoring = scoring,
        ) as T
    }
}
