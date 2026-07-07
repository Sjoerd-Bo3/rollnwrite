package dev.bo3.rollnwrite.engine.connected

import dev.bo3.rollnwrite.engine.qwixx.ColorRow
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotSame
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Direct unit coverage for [ConnectedGame]/[ConnectedModels] behaviour that
 * the golden fixtures (`spec/fixtures/qwixx-connected/`) don't exercise: the
 * chain layout transcription, the serialization round-trip (the exact wire
 * shape a host app persists), and [ConnectedGame.restore]'s defensive copy of
 * mutable collections.
 */
class ConnectedGameTest {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    @Test
    fun `chain layout matches the official score sheet transcription`() {
        assertEquals(6, ConnectedLayout.chains.size)

        assertTrue(ConnectedLayout.isChainSpace(GameColor.RED, 4))
        assertEquals(ChainEnd(GameColor.YELLOW, 4), ConnectedLayout.partner(GameColor.RED, 4))
        assertEquals(ChainEnd(GameColor.RED, 4), ConnectedLayout.partner(GameColor.YELLOW, 4))

        assertTrue(ConnectedLayout.isChainSpace(GameColor.RED, 9))
        assertEquals(ChainEnd(GameColor.YELLOW, 9), ConnectedLayout.partner(GameColor.RED, 9))

        assertTrue(ConnectedLayout.isChainSpace(GameColor.YELLOW, 1))
        assertEquals(ChainEnd(GameColor.GREEN, 1), ConnectedLayout.partner(GameColor.YELLOW, 1))

        assertTrue(ConnectedLayout.isChainSpace(GameColor.YELLOW, 6))
        assertEquals(ChainEnd(GameColor.GREEN, 6), ConnectedLayout.partner(GameColor.YELLOW, 6))

        assertTrue(ConnectedLayout.isChainSpace(GameColor.GREEN, 3))
        assertEquals(ChainEnd(GameColor.BLUE, 3), ConnectedLayout.partner(GameColor.GREEN, 3))

        assertTrue(ConnectedLayout.isChainSpace(GameColor.GREEN, 8))
        assertEquals(ChainEnd(GameColor.BLUE, 8), ConnectedLayout.partner(GameColor.GREEN, 8))

        // Non-chain cells have no partner.
        assertFalse(ConnectedLayout.isChainSpace(GameColor.RED, 0))
        assertNull(ConnectedLayout.partner(GameColor.RED, 0))

        // No cell belongs to more than one chain.
        val allEnds = ConnectedLayout.chains.flatMap { listOf(it.a, it.b) }
        assertEquals(allEnds.size, allEnds.toSet().size)
    }

    @Test
    fun `marking a chain space auto-crosses its partner as one atomic action`() {
        val game = ConnectedGame()
        game.markColor(GameColor.RED, 4) // red 6, chained to yellow 6

        assertTrue(game.isMarked(GameColor.RED, 4))
        assertTrue(game.isMarked(GameColor.YELLOW, 4))
        assertEquals(1, game.crosses(GameColor.RED))
        assertEquals(1, game.crosses(GameColor.YELLOW))

        // A single undo reverses BOTH the deliberate cross and its forced partner.
        game.undo()
        assertFalse(game.isMarked(GameColor.RED, 4))
        assertFalse(game.isMarked(GameColor.YELLOW, 4))
    }

    @Test
    fun `auto co-mark reaches into an already-locked partner row`() {
        val game = ConnectedGame()
        game.concedeRow(GameColor.BLUE)
        assertTrue(game.row(GameColor.BLUE).locked)

        // green 4 (index 8) is chained to blue 4 (index 8); blue is locked but
        // the forced co-mark applies unconditionally.
        game.markColor(GameColor.GREEN, 8)
        assertTrue(game.isMarked(GameColor.BLUE, 8))
        assertTrue(game.row(GameColor.BLUE).locked)
    }

    @Test
    fun `auto co-mark never locks a row by itself`() {
        val game = ConnectedGame()
        // Bring yellow to 5 marks WITHOUT touching index 4, then trigger the
        // chain from red so the co-mark lands on yellow's already-eligible-
        // to-lock row - it must still not flip `locked`.
        game.markColor(GameColor.YELLOW, 0)
        game.markColor(GameColor.YELLOW, 1)
        game.markColor(GameColor.YELLOW, 2)
        game.markColor(GameColor.YELLOW, 3)
        game.markColor(GameColor.RED, 4) // auto-crosses yellow[4]

        assertTrue(game.isMarked(GameColor.YELLOW, 4))
        assertFalse(game.row(GameColor.YELLOW).locked)
    }

    @Test
    fun `state round-trips through kotlinx serialization`() {
        val game = ConnectedGame()
        game.markColor(GameColor.RED, 4) // chain -> also marks yellow[4]
        game.addPenalty()

        val encoded = json.encodeToString(ConnectedState.serializer(), game.state)
        val decoded = json.decodeFromString(ConnectedState.serializer(), encoded)

        assertEquals(game.state, decoded)
        assertEquals(setOf(4), decoded.red.marks)
        assertEquals(setOf(4), decoded.yellow.marks)
        assertEquals(1, decoded.penalties)
    }

    @Test
    fun `restore defensively copies mutable collections`() {
        val mutableMarks = mutableSetOf(0, 1)
        val state = ConnectedState(
            red = ColorRow(color = GameColor.RED, marks = mutableMarks),
        )

        val game = ConnectedGame()
        game.restore(state)

        // Mutating the caller's original collection must NOT affect engine state.
        mutableMarks.add(9)

        assertEquals(setOf(0, 1), game.row(GameColor.RED).marks)
        assertNotSame(mutableMarks, game.row(GameColor.RED).marks)
    }

    @Test
    fun `restore clears any pending redo stack`() {
        val game = ConnectedGame()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.restore(ConnectedState())
        assertFalse(game.canRedo)
    }
}
