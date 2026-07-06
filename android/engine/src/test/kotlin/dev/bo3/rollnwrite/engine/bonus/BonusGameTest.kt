package dev.bo3.rollnwrite.engine.bonus

import dev.bo3.rollnwrite.engine.qwixx.GameColor
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertNotSame
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

/**
 * Direct unit coverage for [BonusGame]/[BonusModels] behaviour that the
 * golden fixtures (`spec/fixtures/qwixx-bonus/`) don't exercise: the
 * serialization round-trip (the exact wire shape a host app persists) and
 * [BonusGame.restore]'s defensive copy of mutable collections.
 */
class BonusGameTest {

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    @Test
    fun `boxed layout matches the official score sheet transcription`() {
        // Printed values 3, 6, 9 for red map to indices 1, 4, 7 (red ascends 2..12).
        assertTrue(BonusLayout.isBoxedIndex(GameColor.RED, 1))
        assertTrue(BonusLayout.isBoxedIndex(GameColor.RED, 4))
        assertTrue(BonusLayout.isBoxedIndex(GameColor.RED, 7))
        assertFalse(BonusLayout.isBoxedIndex(GameColor.RED, 0))

        // Green descends 12..2; printed values 11, 7, 4 map to indices 1, 5, 8.
        assertTrue(BonusLayout.isBoxedIndex(GameColor.GREEN, 1))
        assertTrue(BonusLayout.isBoxedIndex(GameColor.GREEN, 5))
        assertTrue(BonusLayout.isBoxedIndex(GameColor.GREEN, 8))

        assertEquals(12, BonusLayout.barCount)
        // Every colour owns exactly 3 bar fields (matching its 3 boxed cells).
        for (color in GameColor.entries) {
            assertEquals(3, BonusLayout.barColors.count { it == color })
        }
    }

    @Test
    fun `bonus bar tracks next earnable index and room left`() {
        var bar = BonusBar()
        assertEquals(0, bar.nextEarnableIndex)
        assertTrue(bar.hasRoomLeft)

        bar = bar.copy(earned = setOf(0, 1))
        assertEquals(2, bar.nextEarnableIndex)

        bar = bar.copy(forfeited = setOf(2, 3))
        assertEquals(4, bar.nextEarnableIndex)

        // Fill every field via earned/forfeited - no room left.
        val full = BonusBar(earned = (0..5).toSet(), forfeited = (6..11).toSet())
        assertNull(full.nextEarnableIndex)
        assertFalse(full.hasRoomLeft)
        assertEquals(6, full.earnedCount)
    }

    @Test
    fun `state round-trips through kotlinx serialization`() {
        val game = BonusGame()
        game.markColor(GameColor.RED, 1) // boxed -> earns bar field 0
        game.markColor(GameColor.YELLOW, 0)
        game.addPenalty()

        val encoded = json.encodeToString(BonusState.serializer(), game.state)
        val decoded = json.decodeFromString(BonusState.serializer(), encoded)

        assertEquals(game.state, decoded)
        assertEquals(setOf(0), decoded.bar.earned)
        assertEquals(1, decoded.penalties)
    }

    @Test
    fun `restore defensively copies mutable collections`() {
        val mutableMarks = mutableSetOf(0, 1)
        val mutableEarned = mutableSetOf(0)
        val state = BonusState(
            red = dev.bo3.rollnwrite.engine.qwixx.ColorRow(color = GameColor.RED, marks = mutableMarks),
            bar = BonusBar(earned = mutableEarned),
        )

        val game = BonusGame()
        game.restore(state)

        // Mutating the caller's original collections must NOT affect engine state.
        mutableMarks.add(9)
        mutableEarned.add(5)

        assertEquals(setOf(0, 1), game.row(GameColor.RED).marks)
        assertEquals(setOf(0), game.bar.earned)
        assertNotSame(mutableMarks, game.row(GameColor.RED).marks)
    }

    @Test
    fun `restore clears any pending redo stack`() {
        val game = BonusGame()
        game.markColor(GameColor.RED, 0)
        game.undo()
        assertTrue(game.canRedo)

        game.restore(BonusState())
        assertFalse(game.canRedo)
    }

    @Test
    fun `marking a boxed cell without room left earns nothing`() {
        val game = BonusGame()
        game.restore(BonusState(bar = BonusBar(earned = (0..11).toSet())))
        assertEquals(12, game.bar.earnedCount)

        game.markColor(GameColor.RED, 1) // boxed, but bar is full
        assertEquals(12, game.bar.earnedCount)
        assertEquals(1, game.crosses(GameColor.RED))
    }
}
