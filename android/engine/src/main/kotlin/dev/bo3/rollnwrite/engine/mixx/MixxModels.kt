package dev.bo3.rollnwrite.engine.mixx

import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Which of the two Mixx boards is in play.
 *
 * Mirrors `MixxModels.swift` (`MixxBoard`). Serial names match the Swift
 * `Codable` raw values exactly.
 */
@Serializable
enum class MixxBoard {
    @SerialName("variantA") VARIANT_A,
    @SerialName("variantB") VARIANT_B,
}

/**
 * One printed cell on a Mixx row: the number shown, and the die colour of its
 * little segment (Variant A) - in Variant B every cell carries the row colour.
 *
 * Mirrors `MixxModels.swift` (`MixxCell`). Not `@Serializable` - like the
 * Swift `MixxCell`, this is static printed layout data, never persisted.
 */
data class MixxCell(val number: Int, val color: GameColor)

/**
 * A printed row of a Mixx board: its 11 cells (left -> right) plus the colour
 * of the lock at the right end (the die removed from play when the row is
 * closed).
 *
 * Mirrors `MixxModels.swift` (`MixxRowLayout`).
 */
data class MixxRowLayout(val lockColor: GameColor, val cells: List<MixxCell>) {
    init {
        require(cells.size == 11) { "Mixx rows must have exactly 11 cells" }
    }
}

/**
 * The exact, transcribed-from-the-sheet layout of both Mixx boards.
 *
 * Mirrors `MixxModels.swift` (`MixxLayout`) cell-for-cell.
 */
object MixxLayout {

    /**
     * Variante A - numbers ascending/descending like the original, rows split
     * into colour segments. Lock colour = the row's own band colour.
     *
     * Row 1 (red lock, 2->12): yellow 2*3*4 | blue 5*6*7 | green 8*9*10 | red 11*12
     * Row 2 (yellow lock, 2->12): red 2*3 | green 4*5*6*7 | blue 8*9 | yellow 10*11*12
     * Row 3 (green lock, 12->2): blue 12*11*10 | yellow 9*8*7 | red 6*5*4 | green 3*2
     * Row 4 (blue lock, 12->2): green 12*11 | red 10*9*8*7 | yellow 6*5 | blue 4*3*2
     */
    val variantA: List<MixxRowLayout> = listOf(
        MixxRowLayout(
            lockColor = GameColor.RED,
            cells = listOf(
                MixxCell(2, GameColor.YELLOW),
                MixxCell(3, GameColor.YELLOW),
                MixxCell(4, GameColor.YELLOW),
                MixxCell(5, GameColor.BLUE),
                MixxCell(6, GameColor.BLUE),
                MixxCell(7, GameColor.BLUE),
                MixxCell(8, GameColor.GREEN),
                MixxCell(9, GameColor.GREEN),
                MixxCell(10, GameColor.GREEN),
                MixxCell(11, GameColor.RED),
                MixxCell(12, GameColor.RED),
            ),
        ),
        MixxRowLayout(
            lockColor = GameColor.YELLOW,
            cells = listOf(
                MixxCell(2, GameColor.RED),
                MixxCell(3, GameColor.RED),
                MixxCell(4, GameColor.GREEN),
                MixxCell(5, GameColor.GREEN),
                MixxCell(6, GameColor.GREEN),
                MixxCell(7, GameColor.GREEN),
                MixxCell(8, GameColor.BLUE),
                MixxCell(9, GameColor.BLUE),
                MixxCell(10, GameColor.YELLOW),
                MixxCell(11, GameColor.YELLOW),
                MixxCell(12, GameColor.YELLOW),
            ),
        ),
        MixxRowLayout(
            lockColor = GameColor.GREEN,
            cells = listOf(
                MixxCell(12, GameColor.BLUE),
                MixxCell(11, GameColor.BLUE),
                MixxCell(10, GameColor.BLUE),
                MixxCell(9, GameColor.YELLOW),
                MixxCell(8, GameColor.YELLOW),
                MixxCell(7, GameColor.YELLOW),
                MixxCell(6, GameColor.RED),
                MixxCell(5, GameColor.RED),
                MixxCell(4, GameColor.RED),
                MixxCell(3, GameColor.GREEN),
                MixxCell(2, GameColor.GREEN),
            ),
        ),
        MixxRowLayout(
            lockColor = GameColor.BLUE,
            cells = listOf(
                MixxCell(12, GameColor.GREEN),
                MixxCell(11, GameColor.GREEN),
                MixxCell(10, GameColor.RED),
                MixxCell(9, GameColor.RED),
                MixxCell(8, GameColor.RED),
                MixxCell(7, GameColor.RED),
                MixxCell(6, GameColor.YELLOW),
                MixxCell(5, GameColor.YELLOW),
                MixxCell(4, GameColor.BLUE),
                MixxCell(3, GameColor.BLUE),
                MixxCell(2, GameColor.BLUE),
            ),
        ),
    )

    /**
     * Variante B - one row per die colour, numbers scrambled. Every cell
     * carries the row colour; the lock colour is that same colour.
     *
     * Red:    10 6 2 8 3 4 12 5 9 7 11
     * Yellow:  9 12 4 6 7 2 5 8 11 3 10
     * Green:   8 2 10 12 6 9 7 4 5 11 3
     * Blue:    5 7 11 9 12 3 8 10 2 6 4
     */
    val variantB: List<MixxRowLayout> = listOf(
        row(GameColor.RED, listOf(10, 6, 2, 8, 3, 4, 12, 5, 9, 7, 11)),
        row(GameColor.YELLOW, listOf(9, 12, 4, 6, 7, 2, 5, 8, 11, 3, 10)),
        row(GameColor.GREEN, listOf(8, 2, 10, 12, 6, 9, 7, 4, 5, 11, 3)),
        row(GameColor.BLUE, listOf(5, 7, 11, 9, 12, 3, 8, 10, 2, 6, 4)),
    )

    /** Builds a single-colour row for Variant B. */
    private fun row(color: GameColor, numbers: List<Int>): MixxRowLayout =
        MixxRowLayout(lockColor = color, cells = numbers.map { MixxCell(it, color) })

    /** The four row layouts for a given board. */
    fun rows(board: MixxBoard): List<MixxRowLayout> = when (board) {
        MixxBoard.VARIANT_A -> variantA
        MixxBoard.VARIANT_B -> variantB
    }
}

/**
 * State of one Mixx row. Left-to-right marking; index 10 is the lock cell.
 *
 * Immutable value type - mutation is always `copy(...)`. Mirrors
 * `MixxModels.swift` (`MixxRow`).
 */
@Serializable
data class MixxRow(
    /** Crossed cell indices (0...10). */
    val marks: Set<Int> = emptySet(),
    /** `true` once the right-most cell (index 10) has been crossed. */
    val locked: Boolean = false,
) {
    companion object {
        /** Index of the lock cell (right-most). */
        const val LOCK_INDEX = 10
    }

    /** Highest crossed index, or -1 if none - used for the left-to-right rule. */
    val maxMarkedIndex: Int get() = marks.maxOrNull() ?: -1

    /** Crosses that count for scoring: marked numbers plus the lock bonus. */
    val scoringCrosses: Int get() = marks.size + (if (locked) 1 else 0)
}

/**
 * A reversible user action, recorded so `undo()` is exact and strictly LIFO.
 *
 * Mirrors `MixxModels.swift` (`MixxAction`).
 */
@Serializable
sealed class MixxAction {
    @Serializable
    data class Mark(val row: Int, val index: Int, val didLock: Boolean) : MixxAction()

    @Serializable
    data object Penalty : MixxAction()

    /** Conceded a row (closed it for free after another player locked the colour). */
    @Serializable
    data class Concede(val row: Int) : MixxAction()

    /** Ended the game manually. */
    @Serializable
    data object Finish : MixxAction()
}

/**
 * Full serialisable snapshot of a Mixx game on one board.
 *
 * Mirrors `MixxModels.swift` (`MixxState`). Every field carries a default so
 * a persisted blob missing newer fields still decodes; callers restoring
 * persisted state MUST decode with `Json { ignoreUnknownKeys = true }`.
 */
@Serializable
data class MixxState(
    /** The four rows, indexed 0...3 in printed top-to-bottom order. */
    val rows: List<MixxRow> = List(4) { MixxRow() },
    val penalties: Int = 0,
    /**
     * Set when the player ends the game manually (e.g. another player
     * crossed the final lock).
     */
    val manuallyFinished: Boolean = false,
    val history: List<MixxAction> = emptyList(),
) {
    companion object {
        /** Maximum penalties allowed (the 4th ends the game). */
        const val MAX_PENALTIES = 4
    }
}
