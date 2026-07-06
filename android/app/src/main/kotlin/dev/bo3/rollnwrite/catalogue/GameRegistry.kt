package dev.bo3.rollnwrite.catalogue

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Shuffle
import androidx.compose.material.icons.filled.ViewModule
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.runtime.Composable
import dev.bo3.rollnwrite.R

/**
 * Catalogue metadata for one playable game/variant: id, localised
 * title/subtitle, icon, and accent colour. Mirrors
 * `RollnWrite/Core/GameDefinition.swift`'s catalogue-facing fields (`id`,
 * `title`, `subtitle`, `iconSystemName`, `accent`), scoped to what the
 * Android catalogue needs today — routing to a screen composable is still
 * `MainActivity`'s `Screen` enum/`when` (see its docs on being "ahead of a
 * GameDefinition/registry equivalent"); this registry is the single source
 * of truth for the CARD content shown for each entry, so `CatalogueScreen`
 * renders from data instead of one hand-written `Card` per game.
 *
 * `title`/`subtitle` are `@Composable` (not plain `String`) since they need
 * `stringResource` for localisation — evaluated at render time in the
 * catalogue list, exactly like `GameColor.displayName()` on the Qwixx side.
 */
data class GameEntry(
    val id: String,
    val title: @Composable () -> String,
    val subtitle: @Composable () -> String,
    val icon: ImageVector,
    val accent: Color,
)

/**
 * The single source of truth for which games the Android catalogue shows.
 * Adding a new game/variant means adding ONE entry here — the embodiment of
 * the Open/Closed Principle for this app, mirroring iOS's `GameRegistry`.
 *
 * Only lists games this Android port has actually built a screen for
 * (`qwixx-big-points`, `qwixx-mixx`) — unlike the iOS registry, which lists
 * every variant in the app. Future ports add their entry here in the same
 * PR that adds their screen.
 */
object GameRegistry {
    val games: List<GameEntry> = listOf(
        GameEntry(
            id = "qwixx-big-points",
            title = { stringResource(R.string.qwixx_big_points_title) },
            subtitle = { stringResource(R.string.qwixx_big_points_subtitle) },
            icon = Icons.Filled.ViewModule,
            // Matches `QwixxBigPointsGame.swift`'s accent (Color(red: 0.86, green: 0.18, blue: 0.18)).
            accent = Color(red = 0.86f, green = 0.18f, blue = 0.18f),
        ),
        GameEntry(
            id = "qwixx-mixx",
            title = { stringResource(R.string.qwixx_mixx_title) },
            subtitle = { stringResource(R.string.qwixx_mixx_subtitle) },
            icon = Icons.Filled.Shuffle,
            // Matches `QwixxMixxGame.swift`'s accent (Color(red: 0.86, green: 0.18, blue: 0.18)).
            accent = Color(red = 0.86f, green = 0.18f, blue = 0.18f),
        ),
        // Future variants slot in here with zero changes elsewhere.
    )
}
