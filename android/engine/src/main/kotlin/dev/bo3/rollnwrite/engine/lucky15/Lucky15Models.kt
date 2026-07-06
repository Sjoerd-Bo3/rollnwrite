package dev.bo3.rollnwrite.engine.lucky15

import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.Serializable

/**
 * Value types for the Qwixx "Lucky 15" variant (White Goblin Games, NSV).
 *
 * Mirrors `RollnWrite/Games/QwixxLucky15/Lucky15Models.swift` name-for-name.
 * Lucky15 plays like classic Qwixx — four colour rows (red/yellow 2->12,
 * green/blue 12->2, lock on the right-most number after >=5 crosses), four
 * penalties — PLUS an extra orange "Lucky 15" track. This module reuses
 * [GameColor] and [ColorRow] from the base Qwixx engine package (they are
 * game-agnostic value types) but keeps its own state/engine, exactly like
 * the Swift module reuses `GameColor`/`ColorRow` from `Games/Qwixx/` while
 * keeping its own `Lucky15Game`/`Lucky15State`.
 */

/**
 * The orange "Lucky 15" track: four diamond fields, crossed left -> right,
 * each worth more than the last. Values verified against a photo of the
 * physical scorepad (5, 11, 18, 25) - a published review claiming 36 was
 * wrong.
 *
 * Because the track is strictly left-to-right, a simple crossed-count fully
 * describes its state — mirrors `Lucky15Track` (Swift).
 */
@Serializable
data class Lucky15Track(
    /** Number of fields crossed so far (0...[VALUES].size). */
    val crossed: Int = 0,
) {
    companion object {
        /** Printed point values of the diamond fields, left -> right. */
        val VALUES = listOf(5, 11, 18, 25)
    }

    /** How many fields exist on the track. */
    val capacity: Int get() = VALUES.size

    /** Whether another field can still be crossed. */
    val hasRoomLeft: Boolean get() = crossed < capacity

    /** The Lucky 15 bonus = the value of the highest crossed field, or 0 if none. */
    val points: Int get() = if (crossed > 0) VALUES[crossed - 1] else 0
}

/**
 * A reversible user action, recorded so `undo()` is exact and LIFO. Mirrors
 * `Lucky15Action` (Swift). Sealed class + `kotlinx.serialization`
 * polymorphism, exactly like the base Qwixx `GameAction` — this is
 * engine-internal state, never exchanged with the Swift side directly.
 */
@Serializable
sealed class Lucky15Action {
    @Serializable
    data class ColorMark(val color: GameColor, val index: Int, val didLock: Boolean) : Lucky15Action()

    @Serializable
    data object Lucky15Mark : Lucky15Action()

    @Serializable
    data object Penalty : Lucky15Action()

    /** Conceded a colour (closed the row for free after another player locked it). */
    @Serializable
    data class Concede(val color: GameColor) : Lucky15Action()

    /** Ended the game manually. */
    @Serializable
    data object Finish : Lucky15Action()
}

/**
 * Full serialisable snapshot of a Lucky15 game. Mirrors `Lucky15State`
 * (Swift). Every field carries a default (tolerant-decode analogue to the
 * Swift custom `init(from:)`); a host restoring persisted state MUST decode
 * with `Json { ignoreUnknownKeys = true }`.
 */
@Serializable
data class Lucky15State(
    val red: ColorRow = ColorRow(color = GameColor.RED),
    val yellow: ColorRow = ColorRow(color = GameColor.YELLOW),
    val green: ColorRow = ColorRow(color = GameColor.GREEN),
    val blue: ColorRow = ColorRow(color = GameColor.BLUE),
    val lucky: Lucky15Track = Lucky15Track(),
    val penalties: Int = 0,
    /**
     * Set when the player ends the game manually (e.g. another player
     * crossed the final lock).
     */
    val manuallyFinished: Boolean = false,
    val history: List<Lucky15Action> = emptyList(),
) {
    companion object {
        /** Maximum penalties allowed (the 4th ends the game). */
        const val MAX_PENALTIES = 4
    }
}
