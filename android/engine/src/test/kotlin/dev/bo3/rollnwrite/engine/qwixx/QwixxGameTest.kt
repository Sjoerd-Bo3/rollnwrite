package dev.bo3.rollnwrite.engine.qwixx

import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Direct unit tests for engine behaviour the JSON fixtures can't express:
 * serialization round-trips and internal isLast-helper / redo-stack
 * bookkeeping. Rule semantics themselves are covered by
 * [QwixxFixtureRunnerTest].
 */
class QwixxGameTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `restore round-trips state through kotlinx-serialization JSON`() {
        val game = QwixxGame()
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)
        game.markBonus(BonusRowId.REDYELLOW, 0)
        game.addPenalty()

        val encoded = json.encodeToString(QwixxState.serializer(), game.state)
        val decoded = json.decodeFromString(QwixxState.serializer(), encoded)

        val restored = QwixxGame()
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
        val decoded = json.decodeFromString(QwixxState.serializer(), minimalJson)

        assertEquals(QwixxState(), decoded)
    }

    @Test
    fun `reset clears the redo stack`() {
        val game = QwixxGame()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.reset()

        assertFalse(game.canRedo)
        assertFalse(game.canUndo)
        assertEquals(QwixxState(), game.state)
    }

    @Test
    fun `restore also clears the redo stack`() {
        val game = QwixxGame()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.restore(QwixxState())

        assertFalse(game.canRedo)
    }

    @Test
    fun `isLastColorMark is true only for the most recent color mark`() {
        val game = QwixxGame()
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)

        assertTrue(game.isLastColorMark(GameColor.RED, 1))
        assertFalse(game.isLastColorMark(GameColor.RED, 0))
        assertFalse(game.isLastColorMark(GameColor.YELLOW, 1))
    }

    @Test
    fun `isLastBonusMark and isLastPenalty follow strict LIFO history`() {
        val game = QwixxGame()
        game.markColor(GameColor.RED, 0)
        game.markBonus(BonusRowId.REDYELLOW, 0)

        assertTrue(game.isLastBonusMark(BonusRowId.REDYELLOW, 0))
        assertFalse(game.isLastPenalty())
        assertFalse(game.isLastColorMark(GameColor.RED, 0))

        game.addPenalty()

        assertTrue(game.isLastPenalty())
        assertFalse(game.isLastBonusMark(BonusRowId.REDYELLOW, 0))
    }

    @Test
    fun `isLastConcede reflects the most recent concede action`() {
        val game = QwixxGame()
        game.concedeRow(GameColor.GREEN)

        assertTrue(game.isLastConcede(GameColor.GREEN))
        assertFalse(game.isLastConcede(GameColor.BLUE))
    }
}
