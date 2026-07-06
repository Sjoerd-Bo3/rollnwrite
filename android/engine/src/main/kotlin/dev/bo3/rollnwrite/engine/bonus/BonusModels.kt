package dev.bo3.rollnwrite.engine.bonus

import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.Serializable

/**
 * Static layout of Qwixx "Bonus" version A (NSV art. 4105): which numbers are
 * "boxed" (bonus) in each row, and the colour reward of each field on the
 * bonus bar.
 *
 * Mirrors `RollnWrite/Games/QwixxBonus/BonusModels.swift` (`BonusLayout`).
 * Transcribed from the official score sheet; boxed numbers are the *printed
 * value*, mapped to a column index via [GameColor.numbers].
 */
object BonusLayout {

    /**
     * The three boxed (bonus) numbers in each colour row, by printed value.
     * Red & yellow ascend 2->12; green & blue descend 12->2 (printed order
     * does not matter here - these are matched by value).
     */
    fun boxedNumbers(color: GameColor): List<Int> = when (color) {
        GameColor.RED -> listOf(3, 6, 9)
        GameColor.YELLOW -> listOf(5, 8, 11)
        GameColor.GREEN -> listOf(11, 7, 4)
        GameColor.BLUE -> listOf(10, 8, 5)
    }

    /** Whether the printed number [value] is a boxed bonus number in [color]. */
    fun isBoxed(color: GameColor, value: Int): Boolean = value in boxedNumbers(color)

    /** Whether the cell at column [index] of [color] is a boxed bonus number. */
    fun isBoxedIndex(color: GameColor, index: Int): Boolean = isBoxed(color, color.numbers[index])

    /**
     * The colour reward of each bonus-bar field, left -> right. There are
     * twelve fields - one for every boxed number on the sheet - so the bar
     * can be filled exactly if every bonus number is eventually crossed.
     * The bar snakes: red, yellow, green, blue, green, red, blue, yellow,
     * red, yellow, blue, green.
     */
    val barColors: List<GameColor> = listOf(
        GameColor.RED, GameColor.YELLOW, GameColor.GREEN, GameColor.BLUE,
        GameColor.GREEN, GameColor.RED, GameColor.BLUE, GameColor.YELLOW,
        GameColor.RED, GameColor.YELLOW, GameColor.BLUE, GameColor.GREEN,
    )

    /** Number of fields on the bonus bar. */
    val barCount: Int get() = barColors.size
}

/**
 * The bonus bar: a left -> right chain of coloured fields. A field is
 * *earned* automatically every time a boxed number is crossed; the colour of
 * the freshly earned field tells the player which row gets the free extra
 * cross.
 *
 * Official forfeit rule: once a colour has been completed (locked), all its
 * remaining fields in the bonus bar are immediately crossed out as
 * *forfeited*. They no longer count and are simply skipped - future earned
 * crosses land on the next non-forfeited free field, so every field is one
 * of three states: unearned, earned, or forfeited (modelled as two disjoint
 * index sets).
 *
 * Mirrors `BonusModels.swift` (`BonusBar`). Every field carries a default so
 * a persisted blob missing newer fields still decodes.
 */
@Serializable
data class BonusBar(
    /** Indices of fields crossed as earned rewards (each granted an extra cross). */
    val earned: Set<Int> = emptySet(),
    /** Indices crossed out as forfeited because their colour row was completed. */
    val forfeited: Set<Int> = emptySet(),
) {
    /** How many fields have been earned so far (drives reward/score bookkeeping). */
    val earnedCount: Int get() = earned.size

    /**
     * The lowest-index field that is neither earned nor forfeited - the
     * field the next boxed cross will earn - or `null` if the bar is used up.
     */
    val nextEarnableIndex: Int?
        get() = (0 until BonusLayout.barCount).firstOrNull { it !in earned && it !in forfeited }

    /** Whether another field can still be earned. */
    val hasRoomLeft: Boolean get() = nextEarnableIndex != null
}

/**
 * How a colour mark advanced the bonus bar, recorded in history for exact
 * undo. Mirrors `BonusModels.swift` (`BarAdvance`); the `Legacy` case exists
 * on iOS for pre-forfeit save migration only and is never produced by this
 * engine (Android has no such legacy saves), but is kept here for wire-shape
 * parity with the Swift `Codable` encoding this type mirrors.
 */
@Serializable
sealed class BarAdvance {
    /** The mark was not boxed (or the bar was used up) - nothing earned. */
    @Serializable
    data object None : BarAdvance()

    /** The mark earned exactly this bar field (forfeited fields were skipped). */
    @Serializable
    data class Earned(val field: Int) : BarAdvance()

    /** Never produced by this engine; kept for parity with the Swift wire shape. */
    @Serializable
    data object Legacy : BarAdvance()
}

/**
 * A reversible user action, recorded so `undo()` is exact and strictly LIFO.
 *
 * The `bar` payload records which field the mark earned, and `forfeited`
 * which bar indices a locking action crossed out, so undo reverses the
 * colour mark, the bar advance and any forfeiture atomically.
 *
 * Mirrors `BonusModels.swift` (`BonusAction`). This is engine-internal state,
 * never exchanged with the Swift side directly - the exact wire shape is a
 * Kotlin-internal concern (unlike `GameColor`'s serial names).
 */
@Serializable
sealed class BonusAction {
    @Serializable
    data class ColorMark(
        val color: GameColor,
        val index: Int,
        val didLock: Boolean,
        val bar: BarAdvance,
        val forfeited: List<Int>,
    ) : BonusAction()

    @Serializable
    data object Penalty : BonusAction()

    /** Conceded a colour (closed the row for free after another player locked it). */
    @Serializable
    data class Concede(val color: GameColor, val forfeited: List<Int>) : BonusAction()

    /** Ended the game manually. */
    @Serializable
    data object Finish : BonusAction()
}

/**
 * Full serialisable snapshot of a Qwixx Bonus (version A) game.
 *
 * Mirrors `BonusModels.swift` (`BonusState`). The engine itself does NOT
 * persist (see `BonusGame` docs) - persistence is an Android app-layer
 * concern - but this type is the exact wire/state shape a host app should
 * persist with `kotlinx.serialization`, decoding with
 * `Json { ignoreUnknownKeys = true }` for forward/backward tolerance.
 */
@Serializable
data class BonusState(
    val red: ColorRow = ColorRow(color = GameColor.RED),
    val yellow: ColorRow = ColorRow(color = GameColor.YELLOW),
    val green: ColorRow = ColorRow(color = GameColor.GREEN),
    val blue: ColorRow = ColorRow(color = GameColor.BLUE),
    val bar: BonusBar = BonusBar(),
    val penalties: Int = 0,
    /**
     * Set when the player ends the game manually (e.g. another player
     * crossed the final lock).
     */
    val manuallyFinished: Boolean = false,
    val history: List<BonusAction> = emptyList(),
) {
    companion object {
        /** Maximum penalties allowed (the 4th ends the game). */
        const val MAX_PENALTIES = 4
    }
}
