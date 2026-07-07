package dev.bo3.rollnwrite.engine.connect15

import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Direct unit tests for [Connect15Game] covering things the golden fixtures
 * (which only exercise the shared cross-platform vocabulary) can't express:
 * `kotlinx.serialization` round-tripping of [Connect15State] and the
 * defensive-copy behaviour of `restore()`. Rule/scoring behaviour itself is
 * covered exhaustively by [Connect15FixtureRunnerTest] against
 * `spec/fixtures/qwixx-connect15/`.
 */
class Connect15GameTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `state round-trips through kotlinx serialization`() {
        val game = Connect15Game()
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)
        game.markConnection(GameColor.RED, 0)
        game.addPenalty()

        val encoded = json.encodeToString(Connect15State.serializer(), game.state)
        val decoded = json.decodeFromString(Connect15State.serializer(), encoded)

        assertEquals(game.state, decoded)
        assertEquals(setOf(0, 1), decoded.red.marks)
        assertEquals(setOf(0), decoded.redConnections.marks)
        assertEquals(1, decoded.penalties)
    }

    @Test
    fun `decoding tolerates missing fields with defaults`() {
        // Simulates an older persisted blob predating a field (e.g. the
        // connection fields added after `history`) — every field must default.
        val minimal = """{"red":{"color":"red","marks":[0],"locked":false}}"""
        val decoded = json.decodeFromString(Connect15State.serializer(), minimal)

        assertEquals(setOf(0), decoded.red.marks)
        assertTrue(decoded.redConnections.marks.isEmpty())
        assertEquals(0, decoded.penalties)
        assertFalse(decoded.manuallyFinished)
        assertTrue(decoded.history.isEmpty())
    }

    @Test
    fun `restore defensively copies mutable collections`() {
        val game = Connect15Game()
        val marks = mutableSetOf(0, 1, 2)
        val connectionMarks = mutableSetOf(0)
        val state = Connect15State(
            red = game.row(GameColor.RED).copy(marks = marks),
            redConnections = ConnectionFields(marks = connectionMarks),
        )

        game.restore(state)
        marks.add(9) // mutate the caller's set after restoring
        connectionMarks.add(2)

        assertEquals(
            setOf(0, 1, 2),
            game.row(GameColor.RED).marks,
            "engine state must not be affected by later mutation of the caller's collection",
        )
        assertEquals(
            setOf(0),
            game.connections(GameColor.RED).marks,
            "engine connection-field state must not be affected by later mutation of the caller's collection",
        )
    }

    @Test
    fun `restore clears any in-memory redo stack`() {
        val game = Connect15Game()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.restore(Connect15State())

        assertFalse(game.canRedo, "restoring a fresh snapshot must not leave a stale redo stack behind")
    }

    @Test
    fun `reset clears state and redo stack`() {
        val game = Connect15Game()
        game.markColor(GameColor.GREEN, 0)
        game.markConnection(GameColor.GREEN, 0)
        game.addPenalty()
        game.undo()
        assertTrue(game.canRedo)

        game.reset()

        assertEquals(Connect15State(), game.state)
        assertFalse(game.canUndo)
        assertFalse(game.canRedo)
    }

    @Test
    fun `connection fields raise a row's scoring cap from 12 to 15`() {
        val game = Connect15Game()
        // Interleave numbers 0..9 with all three connection fields (columns
        // 1, 4, 8 for red) so nothing is skipped/forfeited.
        for (col in 0..9) {
            game.markColor(GameColor.RED, col)
            val field = Connect15Layout.columns(GameColor.RED).indexOf(col)
            if (field >= 0) game.markConnection(GameColor.RED, field)
        }
        assertEquals(10, game.row(GameColor.RED).marks.size)
        assertTrue(game.canMarkColor(GameColor.RED, 10))
        game.markColor(GameColor.RED, 10)

        assertEquals(15, game.crosses(GameColor.RED))
        assertEquals(120, game.points(GameColor.RED))
        assertTrue(game.row(GameColor.RED).locked)
    }

    @Test
    fun `jumping ahead forfeits skipped numbers and connection fields`() {
        val game = Connect15Game()
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)
        // Jump straight to connection field 1 (after column 4, doubled pos 9),
        // skipping field 0 (pos 3) and numbers at columns 2, 3, 4 (pos 4, 6, 8).
        game.markConnection(GameColor.RED, 1)

        assertFalse(game.canMarkConnection(GameColor.RED, 0), "field 0 must be forfeited forever")
        assertFalse(game.canMarkColor(GameColor.RED, 2), "number at column 2 must be forfeited")
        assertFalse(game.canMarkColor(GameColor.RED, 3), "number at column 3 must be forfeited")
        assertFalse(game.canMarkColor(GameColor.RED, 4), "number at column 4 must be forfeited")
        assertTrue(game.canMarkColor(GameColor.RED, 5), "number at column 5 (pos 10) is still ahead of pos 9")
    }

    @Test
    fun `locking requires 5 crossed numbers regardless of connection fields crossed`() {
        val game = Connect15Game()
        game.markColor(GameColor.YELLOW, 0)
        game.markColor(GameColor.YELLOW, 1)
        game.markConnection(GameColor.YELLOW, 0) // column 3, doubled pos 7 > current max pos 2
        assertEquals(2, game.row(GameColor.YELLOW).marks.size)
        assertFalse(game.canMarkColor(GameColor.YELLOW, 10), "only 2 numbers crossed so far")
    }
}
