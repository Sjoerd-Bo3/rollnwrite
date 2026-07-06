package dev.bo3.rollnwrite.engine.connected

import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.Serializable

/**
 * One end of a printed chain: a circled space identified by colour + the
 * 0-based column index (0…10) of the number it sits on.
 *
 * Mirrors `RollnWrite/Games/QwixxConnected/ConnectedModels.swift`'s `ChainEnd`.
 */
@Serializable
data class ChainEnd(val color: GameColor, val index: Int)

/** A printed chain links two circled spaces in vertically-adjacent rows. */
data class Chain(val a: ChainEnd, val b: ChainEnd) {
    /** Given one end, return the partner end (or null if [end] isn't part of it). */
    fun partner(end: ChainEnd): ChainEnd? = when (end) {
        a -> b
        b -> a
        else -> null
    }

    fun contains(end: ChainEnd): Boolean = end == a || end == b
}

/**
 * Static layout of Qwixx "Connected" (The Chain, version B, sheet A): the six
 * printed chains linking circled spaces in adjacent colour rows.
 *
 * Mirrors `ConnectedModels.swift`'s `ConnectedLayout`. Transcribed from the
 * official "Qwixx connected" score sheet (art. 088 19900030):
 *
 *   - red 6  <-> yellow 6   (column index 4)
 *   - red 11 <-> yellow 11  (column index 9)
 *   - yellow 3  <-> green 11 (column index 1)
 *   - yellow 8  <-> green 6  (column index 6)
 *   - green 9 <-> blue 9    (column index 3)
 *   - green 4 <-> blue 4    (column index 8)
 *
 * No space belongs to more than one chain, so an automatic co-mark never
 * cascades into a third field.
 */
object ConnectedLayout {
    val chains: List<Chain> = listOf(
        Chain(ChainEnd(GameColor.RED, 4), ChainEnd(GameColor.YELLOW, 4)),
        Chain(ChainEnd(GameColor.RED, 9), ChainEnd(GameColor.YELLOW, 9)),
        Chain(ChainEnd(GameColor.YELLOW, 1), ChainEnd(GameColor.GREEN, 1)),
        Chain(ChainEnd(GameColor.YELLOW, 6), ChainEnd(GameColor.GREEN, 6)),
        Chain(ChainEnd(GameColor.GREEN, 3), ChainEnd(GameColor.BLUE, 3)),
        Chain(ChainEnd(GameColor.GREEN, 8), ChainEnd(GameColor.BLUE, 8)),
    )

    /** The chain containing [end], if any. */
    fun chain(end: ChainEnd): Chain? = chains.firstOrNull { it.contains(end) }

    /** The partner space of ([color], [index]) on its chain, if it is a chain end. */
    fun partner(color: GameColor, index: Int): ChainEnd? {
        val end = ChainEnd(color, index)
        return chain(end)?.partner(end)
    }

    /** Whether the given colour/index is a circled chain space. */
    fun isChainSpace(color: GameColor, index: Int): Boolean = chain(ChainEnd(color, index)) != null
}

/**
 * A reversible user action, recorded so [ConnectedGame.undo] is exact and
 * strictly LIFO.
 *
 * When a deliberate colour mark triggers an automatic partner cross, the
 * partner space — and the fact that marking it was a NEW mark — is recorded
 * inline (`auto`) so a single undo removes both crosses together. If the
 * partner was already crossed, `auto` is null so undo leaves it alone.
 *
 * Mirrors `ConnectedModels.swift`'s `ConnectedAction`.
 */
@Serializable
sealed class ConnectedAction {
    @Serializable
    data class ColorMark(
        val color: GameColor,
        val index: Int,
        val didLock: Boolean,
        val auto: ChainEnd?,
    ) : ConnectedAction()

    @Serializable
    data object Penalty : ConnectedAction()

    /** Conceded a colour (closed the row for free after another player locked it). */
    @Serializable
    data class Concede(val color: GameColor) : ConnectedAction()

    /** Ended the game manually. */
    @Serializable
    data object Finish : ConnectedAction()
}

/**
 * Full serialisable snapshot of a Qwixx Connected (The Chain) game.
 *
 * Mirrors `ConnectedModels.swift`'s `ConnectedState`. The engine itself does
 * NOT persist (see `ConnectedGame` docs) - persistence is an Android
 * app-layer concern - but this type is the exact wire/state shape a host app
 * should persist with `kotlinx.serialization`, decoding with
 * `Json { ignoreUnknownKeys = true }` for forward/backward tolerance.
 */
@Serializable
data class ConnectedState(
    val red: ColorRow = ColorRow(color = GameColor.RED),
    val yellow: ColorRow = ColorRow(color = GameColor.YELLOW),
    val green: ColorRow = ColorRow(color = GameColor.GREEN),
    val blue: ColorRow = ColorRow(color = GameColor.BLUE),
    val penalties: Int = 0,
    /**
     * Set when the player ends the game manually (e.g. another player
     * crossed the final lock).
     */
    val manuallyFinished: Boolean = false,
    val history: List<ConnectedAction> = emptyList(),
) {
    companion object {
        /** Maximum penalties allowed (the 4th ends the game). */
        const val MAX_PENALTIES = 4
    }
}
