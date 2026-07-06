package dev.bo3.rollnwrite.engine.connect15

import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.Serializable

/**
 * Value types for the Qwixx "Connect 15" variant (White Goblin Games, NSV).
 *
 * Mirrors `RollnWrite/Games/QwixxConnect15/Connect15Models.swift` name-for-name.
 * Connect 15 plays like classic Qwixx — four colour rows (red/yellow 2->12,
 * green/blue 12->2, lock on the right-most number after >=5 crossed numbers),
 * four penalties — PLUS three "connection" fields woven into every colour
 * row. Numbers and connection fields form ONE left-to-right sequence per
 * row: crossing anything to the right of an unmarked space (number OR
 * connection field) forfeits that space forever. Crossed connection fields
 * count as ordinary crosses toward the row's total, raising the cap from 12
 * to 15 (120 points) - hence "Connect 15". This module reuses [GameColor]
 * and [ColorRow] from the base Qwixx engine package (game-agnostic value
 * types) but keeps its own state/engine, exactly like the Swift module
 * reuses `GameColor`/`ColorRow` from `Games/Qwixx/` while keeping its own
 * `Connect15Game`/`Connect15State`.
 */
object Connect15Layout {
    /**
     * Connection-field positions per colour, as "after this number column",
     * left -> right (so the list index is the field's 0-based ordinal).
     * Transcribed from the official Connect 15 score sheet (corroborated
     * against two published reviews). Every row has exactly three fields.
     */
    val connectionColumns: Map<GameColor, List<Int>> = mapOf(
        GameColor.RED to listOf(1, 4, 8),      // between 3-4, 6-7 and 10-11
        GameColor.YELLOW to listOf(3, 5, 7),   // between 5-6, 7-8 and 9-10
        GameColor.GREEN to listOf(2, 6, 8),    // between 10-9, 6-5 and 4-3
        GameColor.BLUE to listOf(1, 4, 7),     // between 11-10, 8-7 and 5-4
    )

    /** The row's connection-field columns (always three). */
    fun columns(color: GameColor): List<Int> = connectionColumns.getValue(color)

    // --- Interleaved left-to-right positions ---
    //
    // Numbers and connection fields share one sequence: the number at
    // column j sits at position j, the connection field after column i at
    // position i + 0.5. To stay in integer maths both are doubled:
    // number -> 2*j, connection field -> 2*i + 1. A mark is legal only if
    // its position exceeds the row's highest marked position - forfeiture
    // of skipped spaces (numbers AND connection fields) then falls out for
    // free.

    /** Interleaved position of the number at [column] (doubled: 2*column). */
    fun numberPosition(column: Int): Int = 2 * column

    /**
     * Interleaved position of the connection field printed after [column]
     * (doubled: 2*column + 1, i.e. "column + 0.5").
     */
    fun connectionPosition(afterColumn: Int): Int = 2 * afterColumn + 1
}

/**
 * The three "connection" fields woven into a single colour row. Connection
 * fields carry no printed number; each sits between two specific adjacent
 * numbers ([Connect15Layout.connectionColumns]) and takes part in the row's
 * single left-to-right sequence, so any individual field may be crossed or
 * forfeited - a per-field marked set is required (a count is not enough).
 *
 * Every field carries a default (tolerant-decode analogue to the Swift
 * custom `init(from:)`); a host restoring persisted state MUST decode with
 * `Json { ignoreUnknownKeys = true }`.
 */
@Serializable
data class ConnectionFields(
    /**
     * Marked field ordinals (0...[CAPACITY]-1, left -> right). The field's
     * board position comes from `Connect15Layout.columns(color)[ordinal]`.
     */
    val marks: Set<Int> = emptySet(),
) {
    companion object {
        /** How many connection fields each colour row has (3 -> 12 + 3 = 15 crosses). */
        const val CAPACITY = 3
    }
}

/**
 * A reversible user action, recorded so `undo()` is exact and LIFO. Mirrors
 * `Connect15Action` (Swift).
 */
@Serializable
sealed class Connect15Action {
    @Serializable
    data class ColorMark(val color: GameColor, val index: Int, val didLock: Boolean) : Connect15Action()

    /** Crossed the connection field with 0-based ordinal [field] in [color]. */
    @Serializable
    data class ConnectionMark(val color: GameColor, val field: Int) : Connect15Action()

    @Serializable
    data object Penalty : Connect15Action()

    /** Conceded a colour (closed the row for free after another player locked it). */
    @Serializable
    data class Concede(val color: GameColor) : Connect15Action()

    /** Ended the game manually. */
    @Serializable
    data object Finish : Connect15Action()
}

/**
 * Full serialisable snapshot of a Connect15 game. Mirrors `Connect15State`
 * (Swift). Every field carries a default; a host restoring persisted state
 * MUST decode with `Json { ignoreUnknownKeys = true }`.
 */
@Serializable
data class Connect15State(
    val red: ColorRow = ColorRow(color = GameColor.RED),
    val yellow: ColorRow = ColorRow(color = GameColor.YELLOW),
    val green: ColorRow = ColorRow(color = GameColor.GREEN),
    val blue: ColorRow = ColorRow(color = GameColor.BLUE),
    val redConnections: ConnectionFields = ConnectionFields(),
    val yellowConnections: ConnectionFields = ConnectionFields(),
    val greenConnections: ConnectionFields = ConnectionFields(),
    val blueConnections: ConnectionFields = ConnectionFields(),
    val penalties: Int = 0,
    /**
     * Set when the player ends the game manually (e.g. another player
     * crossed the final lock).
     */
    val manuallyFinished: Boolean = false,
    val history: List<Connect15Action> = emptyList(),
) {
    companion object {
        /** Maximum penalties allowed (the 4th ends the game). */
        const val MAX_PENALTIES = 4
    }
}
