package dev.bo3.rollnwrite.qwixx

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
import dev.bo3.rollnwrite.engine.qwixx.BonusRow
import dev.bo3.rollnwrite.engine.qwixx.BonusRowId
import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.engine.qwixx.QwixxGame
import dev.bo3.rollnwrite.engine.qwixx.QwixxState
import kotlinx.serialization.json.Json

/**
 * App-layer host for [QwixxGame]: owns persistence (SharedPreferences) and
 * exposes engine state as Compose-observable so the board recomposes on
 * every mutation.
 *
 * Mirrors `RollnWrite/Games/Qwixx/QwixxGame.swift`'s persistence section,
 * but layered outside the engine (see `QwixxGame` docs) - the engine stays
 * pure JVM/no-Android, this class is the Android host that wires it to
 * `SharedPreferences`.
 *
 * Views must NEVER enforce rules directly: they call the `can*` getters
 * forwarded below and the mutators, exactly like the engine's own contract.
 */
class QwixxViewModel(
    context: Context,
    private val persistenceKey: String,
    scoring: ScoringStrategy = TriangularScoring(cap = 15),
    hasBonusRows: Boolean = true,
) : ViewModel(), Scoreboard {

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val engine = QwixxGame(scoring = scoring, hasBonusRows = hasBonusRows)

    /**
     * Compose-observable snapshot of the engine's state. Reassigned (never
     * mutated in place) after every mutator call below so Compose sees a
     * new value and recomposes. Uses `neverEqualPolicy()` because the redo
     * stack lives outside `QwixxState` (in-memory in the engine) - a commit
     * can change engine-visible behaviour (e.g. `canRedo`) while leaving a
     * structurally-equal `QwixxState` (e.g. reset() after an undo), and a
     * structural-equality policy would then fail to invalidate readers.
     *
     * Every accessor below reads `snapshot` (not just `engine.state`) before
     * delegating so that any composable calling them subscribes to this
     * state and recomposes on every `commit()`. `engine.state === snapshot`
     * after every commit, so delegating to the engine afterwards is safe.
     */
    var snapshot: QwixxState by mutableStateOf(engine.state, neverEqualPolicy())
        private set

    init {
        loadFromPrefs()
    }

    // --- Accessors (forwarded; views read these, never engine internals) ---
    // Each touches `snapshot` first so callers subscribe to it in Compose.

    fun row(color: GameColor): ColorRow { snapshot; return engine.row(color) }

    fun bonus(id: BonusRowId): BonusRow { snapshot; return engine.bonus(id) }

    val penalties: Int get() { snapshot; return engine.penalties }

    val lockedRowCount: Int get() { snapshot; return engine.lockedRowCount }

    val hasBonusRows: Boolean get() = engine.hasBonusRows

    fun canMarkColor(color: GameColor, index: Int): Boolean {
        snapshot
        return engine.canMarkColor(color, index)
    }

    fun canMarkBonus(id: BonusRowId, index: Int): Boolean {
        snapshot
        return engine.canMarkBonus(id, index)
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

    fun isLastBonusMark(id: BonusRowId, index: Int): Boolean {
        snapshot
        return engine.isLastBonusMark(id, index)
    }

    fun isLastPenalty(): Boolean { snapshot; return engine.isLastPenalty() }

    fun isLastConcede(color: GameColor): Boolean { snapshot; return engine.isLastConcede(color) }

    // --- Mutators: apply through the engine, refresh the snapshot, persist ---

    fun markColor(color: GameColor, index: Int) {
        engine.markColor(color, index)
        commit()
    }

    fun markBonus(id: BonusRowId, index: Int) {
        engine.markBonus(id, index)
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
        val encoded = json.encodeToString(QwixxState.serializer(), engine.state)
        prefs.edit().putString(persistenceKey, encoded).apply()
    }

    /**
     * Tolerant load: missing or corrupt JSON leaves the fresh engine state
     * in place rather than crashing - mirrors the Swift `load()`'s
     * `try?`-and-fall-through behaviour. `ignoreUnknownKeys` lets an older
     * build read a blob written by a newer one (extra fields) and vice
     * versa, since every `QwixxState`/row field carries a default.
     */
    private fun loadFromPrefs() {
        val raw = prefs.getString(persistenceKey, null) ?: return
        val restored = runCatching { json.decodeFromString(QwixxState.serializer(), raw) }
            .getOrNull() ?: return
        engine.restore(restored)
        snapshot = engine.state
    }

    companion object {
        private const val PREFS_NAME = "rollnwrite"

        /** Mirrors the iOS persistence key (`QwixxGame.swift`'s default). */
        const val KEY_BIG_POINTS_PLAYER_ONE = "rollnwrite.qwixx.bigpoints.state"

        /** Player 2's independent board (two-player mirrored mode) — mirrors iOS's "rollnwrite.qwixx.bigpoints.p2.state". */
        const val KEY_BIG_POINTS_PLAYER_TWO = "rollnwrite.qwixx.bigpoints.p2.state"

        /** Mirrors the iOS classic-Qwixx persistence key (`QwixxClassicScorecardView`'s construction). */
        const val KEY_CLASSIC_PLAYER_ONE = "rollnwrite.qwixx.classic.state"

        /** Player 2's independent classic board (two-player mirrored mode) — mirrors iOS's ".p2.state" sibling. */
        const val KEY_CLASSIC_PLAYER_TWO = "rollnwrite.qwixx.classic.p2.state"

        private val json = Json {
            ignoreUnknownKeys = true
            encodeDefaults = true
        }
    }
}

/**
 * Builds a [ViewModelProvider.Factory] for a [QwixxViewModel] bound to a
 * specific [persistenceKey], so two independent instances (player 1 / player
 * 2 in two-player mode) can be created in the same screen — each needs its
 * own key, so the stock no-arg factory can't be used.
 */
fun qwixxViewModelFactory(
    context: Context,
    persistenceKey: String,
    scoring: ScoringStrategy = TriangularScoring(cap = 15),
    hasBonusRows: Boolean = true,
): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
    override fun <T : ViewModel> create(modelClass: Class<T>, extras: CreationExtras): T {
        @Suppress("UNCHECKED_CAST")
        return QwixxViewModel(
            context = context,
            persistenceKey = persistenceKey,
            scoring = scoring,
            hasBonusRows = hasBonusRows,
        ) as T
    }
}
