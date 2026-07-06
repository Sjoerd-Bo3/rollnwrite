package dev.bo3.rollnwrite.catalogue

import androidx.annotation.StringRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import dev.bo3.rollnwrite.R
import dev.bo3.rollnwrite.bonus.BonusScorecardScreen
import dev.bo3.rollnwrite.qwixx.QwixxScorecardScreen

/**
 * Describes one roll-and-write game (or variant) for the catalogue and
 * routing. Android's first-cut analogue of `RollnWrite/Core/
 * GameDefinition.swift`'s `GameDefinition` protocol/`GameRegistry` enum —
 * scoped to what the catalogue screen and `MainActivity`'s smoke-test
 * routing need today (title/subtitle/accent + a screen factory), not yet
 * the full iOS surface (icon asset, rules document, dice set). Extend this
 * type as more variants land rather than duplicating the registry pattern.
 *
 * OCP: adding a game means adding one [GameEntry] to [GameRegistry.games] —
 * no existing entry or call site changes.
 */
data class GameEntry(
    /** Stable identifier — also the `-smokeTestGame`/`--es smokeTestGame` value. */
    val id: String,
    @param:StringRes val titleRes: Int,
    @param:StringRes val subtitleRes: Int,
    /** Brand colour for the catalogue row, matching the iOS `GameDefinition.accent`. */
    val accent: Color,
    /** Factory for the game's scorecard screen. */
    val screen: @Composable (onBack: () -> Unit) -> Unit,
)

/**
 * The single source of truth for which games exist on Android. Mirrors the
 * intent of iOS's `GameRegistry.games`; kept in its own `catalogue` package
 * so it can grow independently of any one variant's package.
 */
object GameRegistry {
    val games: List<GameEntry> = listOf(
        GameEntry(
            id = "qwixx-big-points",
            titleRes = R.string.qwixx_big_points_title,
            subtitleRes = R.string.qwixx_big_points_subtitle,
            // Matches `QwixxBigPointsGame.accent` (RollnWrite/Games/Qwixx/QwixxBigPointsGame.swift).
            accent = Color(red = 0.86f, green = 0.18f, blue = 0.18f),
            screen = { onBack -> QwixxScorecardScreen(onBack = onBack) },
        ),
        GameEntry(
            id = "qwixx-bonus",
            titleRes = R.string.qwixx_bonus_title,
            subtitleRes = R.string.qwixx_bonus_subtitle,
            // Matches `QwixxBonusGame.accent` (RollnWrite/Games/QwixxBonus/QwixxBonusGame.swift).
            accent = Color(red = 0.93f, green = 0.45f, blue = 0.13f),
            screen = { onBack -> BonusScorecardScreen(onBack = onBack) },
        ),
        // Future variants slot in here with zero changes elsewhere.
    )

    fun find(id: String): GameEntry? = games.firstOrNull { it.id == id }
}
