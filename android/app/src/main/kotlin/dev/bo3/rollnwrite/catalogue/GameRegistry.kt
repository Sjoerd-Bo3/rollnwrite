package dev.bo3.rollnwrite.catalogue

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.Composable
import dev.bo3.rollnwrite.R

/**
 * Describes one roll-and-write game (or variant) for the catalogue. Mirrors
 * `RollnWrite/Core/GameDefinition.swift` (`GameDefinition`) - the OCP
 * extension point of the app: adding a game means adding one [GameEntry] to
 * [GameRegistry.games], never touching the catalogue screen or navigation.
 *
 * Simpler than the iOS protocol: this is a plain data holder for
 * title/subtitle/accent/icon (the metadata the catalogue card needs). Rules
 * text and the scorecard composable stay in each variant's own package
 * (`dev.bo3.rollnwrite.qwixxdouble`, etc.) and are wired by [MainActivity]'s
 * `screenForSmokeTestGame`/`Screen` navigation - the string-id lookup plays
 * the same OCP role as iOS's `GameRegistry.playable.first { $0.id == id }`.
 */
data class GameEntry(
    val id: String,
    val titleRes: Int,
    val subtitleRes: Int,
    val accent: Color,
    val icon: ImageVector,
)

/** The single source of truth for which games appear in the catalogue. */
object GameRegistry {
    val games: List<GameEntry> = listOf(
        GameEntry(
            id = "qwixx-big-points",
            titleRes = R.string.qwixx_big_points_title,
            subtitleRes = R.string.qwixx_big_points_subtitle,
            accent = Color(red = 0.86f, green = 0.18f, blue = 0.18f),
            icon = Icons.Filled.GridOn,
        ),
        GameEntry(
            id = "qwixx-double",
            titleRes = R.string.qwixx_double_title,
            subtitleRes = R.string.qwixx_double_subtitle,
            accent = Color(red = 0.86f, green = 0.18f, blue = 0.18f),
            icon = Icons.Filled.Close,
        ),

        // Future variants slot in here with zero changes elsewhere.
    )
}

@Composable
fun GameEntry.title(): String = stringResource(titleRes)

@Composable
fun GameEntry.subtitle(): String = stringResource(subtitleRes)
