package dev.bo3.rollnwrite.engine.mixx

import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Direct unit tests for engine behaviour the JSON fixtures can't express:
 * serialization round-trips, internal isLast-helper/redo-stack bookkeeping,
 * and the transcribed board layouts. Rule semantics themselves are covered
 * by [MixxFixtureRunnerTest]. Mirrors `QwixxGameTest` name-for-name.
 */
class MixxGameTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun `restore round-trips state through kotlinx-serialization JSON`() {
        val game = MixxGame(board = MixxBoard.VARIANT_A)
        game.mark(0, 0)
        game.mark(0, 1)
        game.addPenalty()

        val encoded = json.encodeToString(MixxState.serializer(), game.state)
        val decoded = json.decodeFromString(MixxState.serializer(), encoded)

        val restored = MixxGame(board = MixxBoard.VARIANT_A)
        restored.restore(decoded)

        assertEquals(game.state, restored.state)
        assertEquals(game.crosses(0), restored.crosses(0))
        assertEquals(game.totalScore, restored.totalScore)
    }

    @Test
    fun `restore accepts JSON missing newer fields, defaulting them`() {
        // Simulates an older persisted blob predating a hypothetical new
        // field: with ignoreUnknownKeys + per-field defaults, a state
        // object missing keys entirely still decodes to sane defaults.
        val minimalJson = "{}"
        val decoded = json.decodeFromString(MixxState.serializer(), minimalJson)

        assertEquals(MixxState(), decoded)
    }

    @Test
    fun `reset clears the redo stack`() {
        val game = MixxGame()
        game.mark(0, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.reset()

        assertFalse(game.canRedo)
        assertFalse(game.canUndo)
        assertEquals(MixxState(), game.state)
    }

    @Test
    fun `restore also clears the redo stack`() {
        val game = MixxGame()
        game.mark(0, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.restore(MixxState())

        assertFalse(game.canRedo)
    }

    @Test
    fun `isLastMark is true only for the most recent mark`() {
        val game = MixxGame()
        game.mark(0, 0)
        game.mark(0, 1)

        assertTrue(game.isLastMark(0, 1))
        assertFalse(game.isLastMark(0, 0))
        assertFalse(game.isLastMark(1, 1))
    }

    @Test
    fun `isLastPenalty follows strict LIFO history`() {
        val game = MixxGame()
        game.mark(0, 0)

        assertFalse(game.isLastPenalty())
        assertTrue(game.isLastMark(0, 0))

        game.addPenalty()

        assertTrue(game.isLastPenalty())
    }

    @Test
    fun `isLastConcede reflects the most recent concede action`() {
        val game = MixxGame()
        game.concedeRow(2)

        assertTrue(game.isLastConcede(2))
        assertFalse(game.isLastConcede(3))
    }

    @Test
    fun `restore defends against external mutation of a caller-held marks set`() {
        val mutable = HashSet(setOf(0, 1, 2))
        val state = MixxState(rows = listOf(MixxRow(marks = mutable), MixxRow(), MixxRow(), MixxRow()))
        val game = MixxGame()
        game.restore(state)

        mutable.add(9)

        assertEquals(setOf(0, 1, 2), game.rowState(0).marks)
    }

    // --- Layout data integrity: each board is 4 rows of 11 cells, transcribed
    // exactly from the official sheet. Mirrors the Swift `MixxLayout`'s
    // documented numbers; a divergence here means a transcription bug.

    @Test
    fun `variantA has 4 rows of 11 cells each with the documented lock colours`() {
        val rows = MixxLayout.variantA
        assertEquals(4, rows.size)
        rows.forEach { assertEquals(11, it.cells.size) }
        assertEquals(
            listOf(GameColor.RED, GameColor.YELLOW, GameColor.GREEN, GameColor.BLUE),
            rows.map { it.lockColor },
        )
    }

    @Test
    fun `variantA row 1 segments match the transcribed sheet`() {
        val row = MixxLayout.variantA[0]
        assertEquals(
            listOf(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12),
            row.cells.map { it.number },
        )
        assertEquals(
            listOf(
                GameColor.YELLOW, GameColor.YELLOW, GameColor.YELLOW,
                GameColor.BLUE, GameColor.BLUE, GameColor.BLUE,
                GameColor.GREEN, GameColor.GREEN, GameColor.GREEN,
                GameColor.RED, GameColor.RED,
            ),
            row.cells.map { it.color },
        )
    }

    @Test
    fun `variantB has 4 rows of 11 cells each, one solid colour per row`() {
        val rows = MixxLayout.variantB
        assertEquals(4, rows.size)
        rows.forEach { row ->
            assertEquals(11, row.cells.size)
            assertTrue(row.cells.all { it.color == row.lockColor })
        }
        assertEquals(
            listOf(GameColor.RED, GameColor.YELLOW, GameColor.GREEN, GameColor.BLUE),
            rows.map { it.lockColor },
        )
    }

    @Test
    fun `variantB red row numbers match the transcribed sheet`() {
        val row = MixxLayout.variantB[0]
        assertEquals(listOf(10, 6, 2, 8, 3, 4, 12, 5, 9, 7, 11), row.cells.map { it.number })
    }

    @Test
    fun `rows(for a board) selects the matching layout`() {
        assertEquals(MixxLayout.variantA, MixxLayout.rows(MixxBoard.VARIANT_A))
        assertEquals(MixxLayout.variantB, MixxLayout.rows(MixxBoard.VARIANT_B))
    }
}
