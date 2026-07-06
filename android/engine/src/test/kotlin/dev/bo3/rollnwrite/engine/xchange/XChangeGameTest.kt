package dev.bo3.rollnwrite.engine.xchange

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
 * [XChangeFixtureRunnerTest]. Mirrors `QwixxGameTest.kt`'s structure.
 */
class XChangeGameTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `restore round-trips state through kotlinx-serialization JSON`() {
        val game = XChangeGame()
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)
        game.markXChange(0)
        game.addPenalty()

        val encoded = json.encodeToString(XChangeState.serializer(), game.state)
        val decoded = json.decodeFromString(XChangeState.serializer(), encoded)

        val restored = XChangeGame()
        restored.restore(decoded)

        assertEquals(game.state, restored.state)
        assertEquals(game.crosses(GameColor.RED), restored.crosses(GameColor.RED))
        assertEquals(game.totalScore, restored.totalScore)
        assertEquals(game.xchange.marks, restored.xchange.marks)
    }

    @Test
    fun `restore accepts JSON missing newer fields, defaulting them`() {
        val minimalJson = "{}"
        val decoded = json.decodeFromString(XChangeState.serializer(), minimalJson)

        assertEquals(XChangeState(), decoded)
    }

    @Test
    fun `reset clears the redo stack`() {
        val game = XChangeGame()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.reset()

        assertFalse(game.canRedo)
        assertFalse(game.canUndo)
        assertEquals(XChangeState(), game.state)
    }

    @Test
    fun `restore also clears the redo stack`() {
        val game = XChangeGame()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.restore(XChangeState())

        assertFalse(game.canRedo)
    }

    @Test
    fun `isLastColorMark is true only for the most recent color mark`() {
        val game = XChangeGame()
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)

        assertTrue(game.isLastColorMark(GameColor.RED, 1))
        assertFalse(game.isLastColorMark(GameColor.RED, 0))
        assertFalse(game.isLastColorMark(GameColor.YELLOW, 1))
    }

    @Test
    fun `isLastXChangeMark and isLastPenalty follow strict LIFO history`() {
        val game = XChangeGame()
        game.markColor(GameColor.RED, 0)
        game.markXChange(0)

        assertTrue(game.isLastXChangeMark(0))
        assertFalse(game.isLastPenalty())
        assertFalse(game.isLastColorMark(GameColor.RED, 0))

        game.addPenalty()

        assertTrue(game.isLastPenalty())
        assertFalse(game.isLastXChangeMark(0))
    }

    @Test
    fun `isLastConcede reflects the most recent concede action`() {
        val game = XChangeGame()
        game.concedeRow(GameColor.GREEN)

        assertTrue(game.isLastConcede(GameColor.GREEN))
        assertFalse(game.isLastConcede(GameColor.BLUE))
    }

    @Test
    fun `the X-Change row never contributes to totalScore`() {
        val game = XChangeGame()
        game.markXChange(0)
        game.markXChange(1)
        game.markXChange(2)

        assertEquals(0, game.totalScore, "totalScore must be unaffected by X-Change crosses alone")

        game.markColor(GameColor.RED, 0)
        val scoreWithOneRedMark = game.totalScore

        game.markXChange(3)
        assertEquals(
            scoreWithOneRedMark,
            game.totalScore,
            "a further X-Change cross must not change totalScore",
        )
    }

    @Test
    fun `X-Change row is its own independent left-to-right track, unaffected by colour marks`() {
        val game = XChangeGame()
        game.markXChange(3)
        game.markColor(GameColor.RED, 0)
        game.markColor(GameColor.RED, 1)

        // Field 1 was never crossed on the X-Change track, but is still
        // forfeited because it lies left of the already-crossed field 3 -
        // marking colour rows must not reset or interact with that track.
        assertFalse(game.canMarkXChange(1))
        assertTrue(game.canMarkXChange(4))
    }
}
