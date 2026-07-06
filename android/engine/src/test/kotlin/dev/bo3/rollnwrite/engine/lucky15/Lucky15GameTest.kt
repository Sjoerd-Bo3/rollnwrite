package dev.bo3.rollnwrite.engine.lucky15

import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Direct unit tests for [Lucky15Game] covering things the golden fixtures
 * (which only exercise the shared cross-platform vocabulary) can't express:
 * `kotlinx.serialization` round-tripping of [Lucky15State] and the
 * defensive-copy behaviour of `restore()`. Rule/scoring behaviour itself is
 * covered exhaustively by [Lucky15FixtureRunnerTest] against
 * `spec/fixtures/qwixx-lucky15/`.
 */
class Lucky15GameTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `state round-trips through kotlinx serialization`() {
        val game = Lucky15Game()
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)
        game.markLucky()
        game.markLucky()
        game.addPenalty()

        val encoded = json.encodeToString(Lucky15State.serializer(), game.state)
        val decoded = json.decodeFromString(Lucky15State.serializer(), encoded)

        assertEquals(game.state, decoded)
        assertEquals(setOf(0, 1), decoded.red.marks)
        assertEquals(2, decoded.lucky.crossed)
        assertEquals(1, decoded.penalties)
    }

    @Test
    fun `decoding tolerates missing fields with defaults`() {
        // Simulates an older persisted blob predating a field (e.g. the
        // Lucky 15 track added after `history`) — every field must default.
        val minimal = """{"red":{"color":"red","marks":[0],"locked":false}}"""
        val decoded = json.decodeFromString(Lucky15State.serializer(), minimal)

        assertEquals(setOf(0), decoded.red.marks)
        assertEquals(0, decoded.lucky.crossed)
        assertEquals(0, decoded.penalties)
        assertFalse(decoded.manuallyFinished)
        assertTrue(decoded.history.isEmpty())
    }

    @Test
    fun `restore defensively copies mutable collections`() {
        val game = Lucky15Game()
        val marks = mutableSetOf(0, 1, 2)
        val state = Lucky15State(red = game.row(GameColor.RED).copy(marks = marks))

        game.restore(state)
        marks.add(9) // mutate the caller's set after restoring

        assertEquals(
            setOf(0, 1, 2),
            game.row(GameColor.RED).marks,
            "engine state must not be affected by later mutation of the caller's collection",
        )
    }

    @Test
    fun `restore clears any in-memory redo stack`() {
        val game = Lucky15Game()
        game.markLucky()
        game.undo()
        assertTrue(game.canRedo)

        game.restore(Lucky15State())

        assertFalse(game.canRedo, "restoring a fresh snapshot must not leave a stale redo stack behind")
    }

    @Test
    fun `reset clears state and redo stack`() {
        val game = Lucky15Game()
        game.markColor(GameColor.GREEN, 0)
        game.markLucky()
        game.addPenalty()
        game.undo()
        assertTrue(game.canRedo)

        game.reset()

        assertEquals(Lucky15State(), game.state)
        assertFalse(game.canUndo)
        assertFalse(game.canRedo)
    }

    @Test
    fun `lucky track points reflect only the highest crossed field`() {
        val game = Lucky15Game()
        assertEquals(0, game.luckyPoints)

        game.markLucky()
        assertEquals(5, game.luckyPoints)
        game.markLucky()
        assertEquals(11, game.luckyPoints)
        game.markLucky()
        assertEquals(18, game.luckyPoints)
        game.markLucky()
        assertEquals(25, game.luckyPoints)

        assertFalse(game.canMarkLucky())
        game.markLucky() // no-op: track full
        assertEquals(25, game.luckyPoints)
    }
}
