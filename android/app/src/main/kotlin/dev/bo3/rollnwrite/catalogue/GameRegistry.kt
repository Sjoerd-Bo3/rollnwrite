package dev.bo3.rollnwrite.catalogue

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.outlined.Casino
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import dev.bo3.rollnwrite.R
import dev.bo3.rollnwrite.lucky15.Lucky15ScorecardScreen
import dev.bo3.rollnwrite.qwixx.QwixxRulesVariant
import dev.bo3.rollnwrite.qwixx.QwixxScorecardScreen
import dev.bo3.rollnwrite.qwixx.qwixxBigPointsViewModels
import dev.bo3.rollnwrite.qwixx.qwixxClassicViewModels
import dev.bo3.rollnwrite.bonus.BonusScorecardScreen
import dev.bo3.rollnwrite.mixx.MixxScorecardScreen
import dev.bo3.rollnwrite.qwixxdouble.DoubleScorecardScreen
import dev.bo3.rollnwrite.xchange.XChangeScorecardScreen

/**
 * One catalogue entry: metadata for the menu row plus a factory for its
 * scorecard screen. Mirrors `RollnWrite/Core/GameDefinition.swift` — the
 * catalogue UI and the `smokeTestGame` hook both iterate [GameRegistry.games],
 * so adding a game means adding ONE entry here, never touching the menu or
 * the smoke-test lookup (Open/Closed).
 */
data class GameDefinition(
    val id: String,
    val title: @Composable () -> String,
    val subtitle: @Composable () -> String,
    val accent: Color,
    val icon: ImageVector,
    val family: String,
    val makeScreen: @Composable (onBack: () -> Unit) -> Unit,
)

/**
 * Central catalogue, the Android twin of `GameRegistry.swift`. New variants
 * (qwixx-lucky15, clever, …) slot in as additional entries — no edits to
 * `MainActivity` or the catalogue composable required.
 */
object GameRegistry {
    val games: List<GameDefinition> = listOf(
        GameDefinition(
            id = "qwixx-big-points",
            title = { stringResource(R.string.qwixx_big_points_title) },
            subtitle = { stringResource(R.string.qwixx_big_points_subtitle) },
            accent = RollnWriteRed,
            icon = Icons.Filled.Casino,
            family = "Qwixx",
            makeScreen = { onBack ->
                val (p1, p2) = qwixxBigPointsViewModels()
                QwixxScorecardScreen(
                    title = stringResource(R.string.qwixx_big_points_title),
                    playerOne = p1,
                    playerTwo = p2,
                    rulesVariant = QwixxRulesVariant.BIG_POINTS,
                    onBack = onBack,
                )
            },
        ),
        GameDefinition(
            id = "qwixx-classic",
            title = { stringResource(R.string.qwixx_classic_title) },
            subtitle = { stringResource(R.string.qwixx_classic_subtitle) },
            accent = Color(red = 0.93f, green = 0.55f, blue = 0.13f),
            icon = Icons.Outlined.Casino,
            family = "Qwixx",
            makeScreen = { onBack ->
                val (p1, p2) = qwixxClassicViewModels()
                QwixxScorecardScreen(
                    title = stringResource(R.string.qwixx_classic_title),
                    playerOne = p1,
                    playerTwo = p2,
                    rulesVariant = QwixxRulesVariant.CLASSIC,
                    onBack = onBack,
                )
            },
        ),
        GameDefinition(
            id = "qwixx-lucky15",
            title = { stringResource(R.string.qwixx_lucky15_title) },
            subtitle = { stringResource(R.string.qwixx_lucky15_subtitle) },
            // Mirrors iOS `QwixxLucky15Game.accent` (Color(red: 0.93, green: 0.45, blue: 0.13)).
            accent = Color(red = 0.93f, green = 0.45f, blue = 0.13f),
            icon = Icons.Filled.Casino,
            family = "Qwixx",
            makeScreen = { onBack -> Lucky15ScorecardScreen(onBack = onBack) },
        ),
        GameDefinition(
            id = "qwixx-xchange",
            title = { stringResource(R.string.qwixx_xchange_title) },
            subtitle = { stringResource(R.string.qwixx_xchange_subtitle) },
            // Mirrors iOS QwixxXChangeGame's deep-magenta accent and swap icon.
            accent = Color(red = 0.55f, green = 0.10f, blue = 0.42f),
            icon = Icons.Filled.SwapHoriz,
            family = "Qwixx",
            makeScreen = { onBack -> XChangeScorecardScreen(onBack = onBack) },
        ),
        GameDefinition(
            id = "qwixx-double",
            title = { stringResource(R.string.qwixx_double_title) },
            subtitle = { stringResource(R.string.qwixx_double_subtitle) },
            // Mirrors iOS QwixxDoubleGame's red accent and boxed-x icon.
            accent = Color(red = 0.86f, green = 0.18f, blue = 0.18f),
            icon = Icons.Filled.Close,
            family = "Qwixx",
            makeScreen = { onBack -> DoubleScorecardScreen(onBack = onBack) },
        ),
        GameDefinition(
            id = "qwixx-bonus",
            title = { stringResource(R.string.qwixx_bonus_title) },
            subtitle = { stringResource(R.string.qwixx_bonus_subtitle) },
            // Matches QwixxBonusGame.swift's orange accent; boxed-grid icon.
            accent = Color(red = 0.93f, green = 0.45f, blue = 0.13f),
            icon = Icons.Filled.GridOn,
            family = "Qwixx",
            makeScreen = { onBack -> BonusScorecardScreen(onBack = onBack) },
        ),
        GameDefinition(
            id = "qwixx-mixx",
            title = { stringResource(R.string.qwixx_mixx_title) },
            subtitle = { stringResource(R.string.qwixx_mixx_subtitle) },
            // Matches QwixxMixxGame.swift's red accent and shuffle icon.
            accent = Color(red = 0.86f, green = 0.18f, blue = 0.18f),
            icon = Icons.Filled.Shuffle,
            family = "Qwixx",
            makeScreen = { onBack -> MixxScorecardScreen(onBack = onBack) },
        ),
    )

    /** Games grouped by family in a fixed display order (extra families sort alphabetically after). */
    fun families(): List<Pair<String, List<GameDefinition>>> {
        val order = listOf("Qwixx", "Clever")
        val grouped = games.groupBy { it.family }
        val known = order.mapNotNull { key -> grouped[key]?.let { key to it } }
        val extra = grouped.keys.filter { it !in order }.sorted().map { it to grouped.getValue(it) }
        return known + extra
    }

    /** Looks up a game by id — used by the `smokeTestGame` launch-argument hook. */
    fun find(id: String?): GameDefinition? = games.firstOrNull { it.id == id }
}
