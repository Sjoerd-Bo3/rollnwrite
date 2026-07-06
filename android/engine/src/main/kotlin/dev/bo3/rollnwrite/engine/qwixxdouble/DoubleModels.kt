package dev.bo3.rollnwrite.engine.qwixxdouble

import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.Serializable

/**
 * One Qwixx Double colour row. 11 numbers at indices 0...10; index 10 is the
 * right-most number whose crossing locks the row.
 *
 * Mirrors `RollnWrite/Games/QwixxDouble/DoubleModels.swift` (`DoubleColorRow`).
 * Each number can be crossed once or twice: `marks` holds every index crossed
 * at least once (left-to-right, like classic Qwixx); `doubles` holds indices
 * crossed a *second* time. The variant only lets you double the
 * most-recently-crossed space, so in practice only the current right-most
 * mark is ever doubled - but the full set is stored so undo and scoring stay
 * exact.
 *
 * Immutable value type - mutation is always `copy(...)`, mirroring the Swift
 * `struct` semantics of `DoubleColorRow`.
 */
@Serializable
data class DoubleColorRow(
    val color: GameColor,
    /** Indices (0...10) crossed at least once. */
    val marks: Set<Int> = emptySet(),
    /** Indices (0...10) crossed a *second* time (always a subset of [marks]). */
    val doubles: Set<Int> = emptySet(),
    /** `true` once the right-most number has been crossed (row + lock). */
    val locked: Boolean = false,
) {
    companion object {
        /** Index of the right-most number, whose crossing locks the row. */
        const val LOCK_INDEX = 10

        /** Crosses required in the row before the right-most number may be crossed. */
        const val CROSSES_TO_LOCK = 7
    }

    /** Printed numbers in left-to-right order. */
    val numbers: List<Int> get() = color.numbers

    /**
     * Highest crossed index, or -1 if none - used both for the left-to-right
     * rule and to identify the "most recently crossed" (right-most) space.
     */
    val maxMarkedIndex: Int get() = marks.maxOrNull() ?: -1

    /**
     * Total crosses written in the row: first crosses + second crosses, plus
     * the lock bonus cross - but the lock bonus is earned only if YOU crossed
     * the right-most number. A conceded row (closed because another player
     * locked the colour) is `locked` yet scores no bonus, because its lock
     * number was never crossed.
     */
    val crossCount: Int
        get() = marks.size + doubles.size + (if (LOCK_INDEX in marks) 1 else 0)
}

/**
 * A reversible user action, recorded so `undo()` is exact and strictly LIFO.
 *
 * Mirrors `DoubleModels.swift` (`DoubleAction`). `kotlinx.serialization`
 * polymorphic serialization is used for the sealed class; this is engine
 * state, never exchanged with the Swift side directly, so the exact wire
 * shape is a Kotlin-internal concern (unlike the enum serial names in
 * `dev.bo3.rollnwrite.engine.qwixx.GameColor`).
 */
@Serializable
sealed class DoubleAction {
    /** A *first* cross on [index] (may have locked the row). */
    @Serializable
    data class Mark(val color: GameColor, val index: Int, val didLock: Boolean) : DoubleAction()

    /** A *second* cross on the most-recent space [index]. */
    @Serializable
    data class Double(val color: GameColor, val index: Int) : DoubleAction()

    @Serializable
    data object Penalty : DoubleAction()

    /** Conceded a colour (closed the row for free after another player locked it). */
    @Serializable
    data class Concede(val color: GameColor) : DoubleAction()

    /** Ended the game manually. */
    @Serializable
    data object Finish : DoubleAction()
}

/**
 * Full serialisable snapshot of a Qwixx Double game.
 *
 * Mirrors `DoubleModels.swift` (`DoubleState`). The engine itself does NOT
 * persist (see `DoubleGame` docs) - persistence is an Android app-layer
 * concern - but this type is the exact wire/state shape a host app should
 * persist with `kotlinx.serialization`. As with the Swift `Codable` tolerant
 * `init(from:)`, every field has a default here; the host MUST decode with
 * `Json { ignoreUnknownKeys = true }` so a state blob missing fields added by
 * a later build (or carrying fields a rolled-back build no longer knows)
 * still restores instead of failing outright.
 */
@Serializable
data class DoubleState(
    val red: DoubleColorRow = DoubleColorRow(color = GameColor.RED),
    val yellow: DoubleColorRow = DoubleColorRow(color = GameColor.YELLOW),
    val green: DoubleColorRow = DoubleColorRow(color = GameColor.GREEN),
    val blue: DoubleColorRow = DoubleColorRow(color = GameColor.BLUE),
    val penalties: Int = 0,
    /**
     * Set when the player ends the game manually (e.g. another player
     * crossed the final lock).
     */
    val manuallyFinished: Boolean = false,
    val history: List<DoubleAction> = emptyList(),
) {
    companion object {
        /** Maximum penalties allowed (the 4th ends the game). */
        const val MAX_PENALTIES = 4
    }
}
