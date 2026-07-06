package dev.bo3.rollnwrite.engine

/**
 * Maps a number of marks ("crosses") to a point value for a single track.
 *
 * Different roll-and-write games (and even different rows within a game) score
 * crosses differently. Implement a new type to plug in new behaviour without
 * modifying the engines that consume it.
 *
 * Mirrors `RollnWrite/Core/ScoringStrategy.swift` (`ScoringStrategy`).
 */
interface ScoringStrategy {
    /** Points awarded for [crosses] marks on a single track. */
    fun points(forCrosses: Int): Int
}

/**
 * Classic Qwixx scoring: the *n*-th cross is worth a cumulative triangular
 * total `n * (n + 1) / 2` — i.e. 1, 3, 6, 10, 15, 21, ... points.
 *
 * In *Qwixx Big Points* a colour may earn up to 15 valued crosses (120 points),
 * so the strategy is capped. The base game caps at 12 (78 points).
 *
 * Mirrors `RollnWrite/Core/ScoringStrategy.swift` (`TriangularScoring`).
 */
class TriangularScoring(val cap: Int) : ScoringStrategy {
    override fun points(forCrosses: Int): Int {
        val n = forCrosses.coerceIn(0, cap)
        return n * (n + 1) / 2
    }
}

/**
 * Common surface every game's score model exposes to generic UI/host code.
 *
 * Deliberately tiny — hosts that only need a headline score and a game-over
 * flag don't have to know any game-specific detail.
 *
 * Mirrors `RollnWrite/Core/ScoringStrategy.swift` (`Scoreboard`). `canRedo`/
 * `redo()` default so adding them never breaks an existing conformer.
 */
interface Scoreboard {
    /** The current overall score. */
    val totalScore: Int

    /** Whether the game has reached an end condition. */
    val isGameOver: Boolean

    /** Whether there is an action available to undo. */
    val canUndo: Boolean

    /** Reverse the most recent action. */
    fun undo()

    /** Whether there is an undone action available to redo. */
    val canRedo: Boolean
        get() = false

    /** Re-apply the most recently undone action. */
    fun redo() {}

    /** Clear the card back to a fresh game. */
    fun reset()
}
