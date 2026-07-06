package dev.bo3.rollnwrite.engine.qwixx

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * A Qwixx colour row. Red & yellow ascend 2->12; green & blue descend 12->2.
 *
 * Mirrors `RollnWrite/Games/Qwixx/GameColor.swift` (`GameColor`). Serial
 * names are lowercase to match the Swift `Codable` raw values exactly, so a
 * fixture/state JSON blob is interpreted identically on both platforms.
 */
@Serializable
enum class GameColor {
    @SerialName("red") RED,
    @SerialName("yellow") YELLOW,
    @SerialName("green") GREEN,
    @SerialName("blue") BLUE,

    ;

    /** Red and yellow run 2...12 left-to-right; green and blue run 12...2. */
    val isAscending: Boolean
        get() = this == RED || this == YELLOW

    /** The 11 numbers of this row, in printed left-to-right order. */
    val numbers: List<Int>
        get() = if (isAscending) (2..12).toList() else (2..12).toList().asReversed()
}

/**
 * One coloured number row. 11 numbers at indices 0...10; index 10 is the
 * right-most number whose crossing locks the row.
 *
 * Immutable value type — mutation is always `copy(...)`, mirroring the
 * Swift `struct` semantics of `ColorRow`.
 *
 * Every field carries a default so a persisted blob missing newer fields
 * still decodes (the tolerant-decode analogue to the Swift custom
 * `init(from:)`); callers restoring persisted state MUST decode with
 * `Json { ignoreUnknownKeys = true }` so older/newer builds' extra fields
 * don't break decoding either.
 */
@Serializable
data class ColorRow(
    val color: GameColor,
    /** Indices (0...10) that have been crossed out. */
    val marks: Set<Int> = emptySet(),
    /**
     * `true` once the row is closed - either the right-most number was
     * crossed (a *scored* lock) or it was conceded after another player
     * locked the colour (a *free* lock, no points).
     */
    val locked: Boolean = false,
) {
    companion object {
        /** Index of the right-most number, whose crossing locks the row. */
        const val LOCK_INDEX = 10
    }

    /** Printed numbers in left-to-right order. */
    val numbers: List<Int> get() = color.numbers

    /** Highest crossed index, or -1 if none - used for the left-to-right rule. */
    val maxMarkedIndex: Int get() = marks.maxOrNull() ?: -1

    /**
     * Crosses that count for scoring: the marked numbers plus the lock
     * bonus - but the lock bonus is earned only if the right-most number
     * was actually crossed. A conceded row (closed because another player
     * locked the colour) is `locked` yet scores no bonus, because its lock
     * number was never crossed.
     */
    val scoringCrosses: Int
        get() = marks.size + (if (LOCK_INDEX in marks) 1 else 0)
}

/**
 * Identifies the two two-colour bonus rows of Big Points.
 *
 * Mirrors `QwixxModels.swift` (`BonusRowID`). Serial names match the Swift
 * `Codable` raw values (`redYellow` / `greenBlue`).
 */
@Serializable
enum class BonusRowId {
    @SerialName("redYellow") REDYELLOW,
    @SerialName("greenBlue") GREENBLUE,

    ;

    /** The two colour rows this bonus row sits between / scores for. */
    val colors: Pair<GameColor, GameColor>
        get() = when (this) {
            REDYELLOW -> GameColor.RED to GameColor.YELLOW
            GREENBLUE -> GameColor.GREEN to GameColor.BLUE
        }
}

/**
 * A bonus row of 11 two-colour spaces, aligned by number with its colour
 * rows. A space may be crossed only after an adjacent same-number colour
 * space is crossed; once crossed it counts for *both* adjacent colour rows.
 */
@Serializable
data class BonusRow(
    val id: BonusRowId,
    val marks: Set<Int> = emptySet(),
) {
    /**
     * Numbers follow the first adjacent colour's ordering (ascending for
     * red/yellow, descending for green/blue) so columns line up by number.
     */
    val numbers: List<Int> get() = id.colors.first.numbers

    val maxMarkedIndex: Int get() = marks.maxOrNull() ?: -1
}

/**
 * A reversible user action, recorded so `undo()` is exact and
 * dependency-safe.
 *
 * Undo is strictly LIFO, which guarantees a bonus space is always undone
 * before the colour space that authorised it.
 *
 * Mirrors `QwixxModels.swift` (`GameAction`). `kotlinx.serialization`
 * polymorphic serialization is used for the sealed class; this is engine
 * state, never exchanged with the Swift side directly, so the exact wire
 * shape is a Kotlin-internal concern (unlike the enum serial names above).
 */
@Serializable
sealed class GameAction {
    @Serializable
    data class ColorMark(val color: GameColor, val index: Int, val didLock: Boolean) : GameAction()

    @Serializable
    data class BonusMark(val row: BonusRowId, val index: Int) : GameAction()

    @Serializable
    data object Penalty : GameAction()

    /** Conceded a colour (closed the row for free after another player locked it). */
    @Serializable
    data class Concede(val color: GameColor) : GameAction()

    /** Ended the game manually. */
    @Serializable
    data object Finish : GameAction()
}

/**
 * Full serialisable snapshot of a game.
 *
 * Mirrors `QwixxModels.swift` (`QwixxState`). The engine itself does NOT
 * persist (see `QwixxGame` docs) - persistence is an Android app-layer
 * concern - but this type is the exact wire/state shape a host app should
 * persist with `kotlinx.serialization`. As with the Swift `Codable`
 * tolerant `init(from:)`, every field has a default here; the host MUST
 * decode with `Json { ignoreUnknownKeys = true }` so a state blob missing
 * fields added by a later build (or carrying fields a rolled-back build no
 * longer knows) still restores instead of failing outright.
 */
@Serializable
data class QwixxState(
    val red: ColorRow = ColorRow(color = GameColor.RED),
    val yellow: ColorRow = ColorRow(color = GameColor.YELLOW),
    val green: ColorRow = ColorRow(color = GameColor.GREEN),
    val blue: ColorRow = ColorRow(color = GameColor.BLUE),
    val redYellowBonus: BonusRow = BonusRow(id = BonusRowId.REDYELLOW),
    val greenBlueBonus: BonusRow = BonusRow(id = BonusRowId.GREENBLUE),
    val penalties: Int = 0,
    /**
     * Set when the player ends the game manually (e.g. another player
     * crossed the final lock).
     */
    val manuallyFinished: Boolean = false,
    val history: List<GameAction> = emptyList(),
) {
    companion object {
        /** Maximum penalties allowed (the 4th ends the game). */
        const val MAX_PENALTIES = 4
    }
}
