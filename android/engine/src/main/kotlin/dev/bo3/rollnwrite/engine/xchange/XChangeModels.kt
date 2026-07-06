package dev.bo3.rollnwrite.engine.xchange

import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.Serializable

/**
 * The "X-Change" row: nine diamond fields, each a (top, bottom) number pair.
 * Crossed strictly left -> right (skipping allowed, skipped fields lost). The
 * row scores no points - it is a swap tool - so its state is just the set of
 * crossed field indices plus the printed pairs (the source of truth, read
 * from the official NSV Qwixx X-Change scoresheet PDF).
 *
 * Mirrors `RollnWrite/Games/QwixxXChange/XChangeModels.swift` (`XChangeRow`).
 */
@Serializable
data class XChangeRow(
    /** Indices (0...8) of crossed diamond fields. */
    val marks: Set<Int> = emptySet(),
) {
    companion object {
        /** Printed (top, bottom) number pairs, left -> right, from the official
         * NSV Qwixx X-Change scoresheet (QwixxXChange_EN.pdf). */
        val PAIRS: List<Pair<Int, Int>> = listOf(
            8 to 5, 9 to 7, 11 to 3, 7 to 4, 10 to 3, 8 to 6, 10 to 5, 11 to 9, 6 to 4,
        )

        /** How many diamond fields exist. */
        val COUNT: Int get() = PAIRS.size

        /** The two numbers of field [index] as a convenience pair. */
        fun pair(index: Int): Pair<Int, Int> = PAIRS[index]
    }

    /** Highest crossed index, or -1 if none - used for the left-to-right rule. */
    val maxMarkedIndex: Int get() = marks.maxOrNull() ?: -1

    /** Number of X-Change fields crossed (informational only - no points). */
    val crossed: Int get() = marks.size
}

/**
 * A reversible user action, recorded so `undo()` is exact and LIFO.
 *
 * Mirrors `XChangeModels.swift` (`XChangeAction`).
 */
@Serializable
sealed class XChangeAction {
    @Serializable
    data class ColorMark(val color: GameColor, val index: Int, val didLock: Boolean) : XChangeAction()

    @Serializable
    data class XChangeMark(val index: Int) : XChangeAction()

    @Serializable
    data object Penalty : XChangeAction()

    /** Conceded a colour (closed the row for free after another player locked it). */
    @Serializable
    data class Concede(val color: GameColor) : XChangeAction()

    /** Ended the game manually. */
    @Serializable
    data object Finish : XChangeAction()
}

/**
 * Full serialisable snapshot of an X-Change game.
 *
 * Mirrors `XChangeModels.swift` (`XChangeState`). The engine itself does NOT
 * persist (persistence is an Android app-layer concern, see `XChangeGame`
 * docs) - this type is the exact wire/state shape a host app should persist
 * with `kotlinx.serialization`. Every field carries a default, mirroring the
 * Swift tolerant `init(from:)`, so a state blob missing fields still
 * restores; the host MUST decode with `Json { ignoreUnknownKeys = true }`.
 */
@Serializable
data class XChangeState(
    val red: ColorRow = ColorRow(color = GameColor.RED),
    val yellow: ColorRow = ColorRow(color = GameColor.YELLOW),
    val green: ColorRow = ColorRow(color = GameColor.GREEN),
    val blue: ColorRow = ColorRow(color = GameColor.BLUE),
    val xchange: XChangeRow = XChangeRow(),
    val penalties: Int = 0,
    /**
     * Set when the player ends the game manually (e.g. another player
     * crossed the final lock).
     */
    val manuallyFinished: Boolean = false,
    val history: List<XChangeAction> = emptyList(),
) {
    companion object {
        /** Maximum penalties allowed (the 4th ends the game). */
        const val MAX_PENALTIES = 4
    }
}
