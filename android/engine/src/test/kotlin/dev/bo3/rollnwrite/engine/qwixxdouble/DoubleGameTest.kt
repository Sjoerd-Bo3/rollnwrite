package dev.bo3.rollnwrite.engine.qwixxdouble

import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Direct unit tests for engine behaviour the JSON fixtures can't express:
 * serialization round-trips and internal isLast-helper / redo-stack
 * bookkeeping. Rule semantics themselves are covered by
 * [DoubleFixtureRunnerTest]. Mirrors `QwixxGameTest`'s structure.
 */
class DoubleGameTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `restore round-trips state through kotlinx-serialization JSON`() {
        val game = DoubleGame()
        game.markColor(GameColor.RED, 0)
        game.doubleColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)
        game.addPenalty()

        val encoded = json.encodeToString(DoubleState.serializer(), game.state)
        val decoded = json.decodeFromString(DoubleState.serializer(), encoded)

        val restored = DoubleGame()
        restored.restore(decoded)

        assertEquals(game.state, restored.state)
        assertEquals(game.crosses(GameColor.RED), restored.crosses(GameColor.RED))
        assertEquals(game.totalScore, restored.totalScore)
    }

    @Test
    fun `restore accepts JSON missing newer fields, defaulting them`() {
        // Simulates an older persisted blob predating a hypothetical new
        // field: with ignoreUnknownKeys + per-field defaults, a state
        // object missing keys entirely still decodes to sane defaults.
        val minimalJson = "{}"
        val decoded = json.decodeFromString(DoubleState.serializer(), minimalJson)

        assertEquals(DoubleState(), decoded)
    }

    @Test
    fun `reset clears the redo stack`() {
        val game = DoubleGame()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.reset()

        assertFalse(game.canRedo)
        assertFalse(game.canUndo)
        assertEquals(DoubleState(), game.state)
    }

    @Test
    fun `restore also clears the redo stack`() {
        val game = DoubleGame()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.restore(DoubleState())

        assertFalse(game.canRedo)
    }

    @Test
    fun `isLastColorMark and isLastDoubleMark follow strict LIFO history`() {
        val game = DoubleGame()
        game.markColor(GameColor.RED, 0)
        game.doubleColor(GameColor.RED, 0)

        assertTrue(game.isLastDoubleMark(GameColor.RED, 0))
        assertFalse(game.isLastColorMark(GameColor.RED, 0))

        game.undo() // undoes the double
        assertTrue(game.isLastColorMark(GameColor.RED, 0))
        assertFalse(game.isLastDoubleMark(GameColor.RED, 0))
    }

    @Test
    fun `isLastPenalty and isLastConcede follow strict LIFO history`() {
        val game = DoubleGame()
        game.concedeRow(GameColor.GREEN)

        assertTrue(game.isLastConcede(GameColor.GREEN))
        assertFalse(game.isLastConcede(GameColor.BLUE))
        assertFalse(game.isLastPenalty())

        game.addPenalty()

        assertTrue(game.isLastPenalty())
        assertFalse(game.isLastConcede(GameColor.GREEN))
    }

    @Test
    fun `doubling is only ever legal on the single most-recently-marked index`() {
        val game = DoubleGame()
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 3)

        assertFalse(game.canDoubleColor(GameColor.RED, 0))
        assertTrue(game.canDoubleColor(GameColor.RED, 3))

        game.doubleColor(GameColor.RED, 3)
        assertFalse(game.canDoubleColor(GameColor.RED, 3), "already doubled once")
    }

    @Test
    fun `lock threshold is 7 crosses, counting doubles toward crossCount`() {
        val game = DoubleGame()
        // 3 marks + 3 doubles = 6 crosses: below the 7-cross threshold.
        listOf(0, 1, 2).forEach { i ->
            game.markColor(GameColor.RED, i)
            game.doubleColor(GameColor.RED, i)
        }
        assertEquals(6, game.crosses(GameColor.RED))
        assertFalse(game.canMarkColor(GameColor.RED, DoubleColorRow.LOCK_INDEX))

        // A 4th mark (no double) brings crossCount to 7 - the lock unlocks.
        game.markColor(GameColor.RED, 3)
        assertEquals(7, game.crosses(GameColor.RED))
        assertTrue(game.canMarkColor(GameColor.RED, DoubleColorRow.LOCK_INDEX))
    }

    @Test
    fun `the lock index itself can never be doubled`() {
        val game = DoubleGame()
        listOf(0, 1, 2, 3, 4, 5, 6).forEach { game.markColor(GameColor.RED, it) }
        game.markColor(GameColor.RED, DoubleColorRow.LOCK_INDEX)

        assertTrue(game.row(GameColor.RED).locked)
        assertFalse(game.canDoubleColor(GameColor.RED, DoubleColorRow.LOCK_INDEX))
    }
}
