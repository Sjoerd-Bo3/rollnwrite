package dev.bo3.rollnwrite.catalogue

import androidx.annotation.StringRes
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.GridOn
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import dev.bo3.rollnwrite.R

/**
 * Catalogue metadata for one game/variant, analogous to iOS's
 * `GameDefinition` (`RollnWrite/Core/GameDefinition.swift`): a stable [id]
 * (matches the iOS `GameDefinition.id` and the `-smokeTestGame`/
 * `--es smokeTestGame` launch-argument values on both platforms), the
 * catalogue row's title/subtitle string resources, accent and icon, and
 * nothing else - screen construction and navigation stay in
 * `MainActivity`'s `when` (see `screenForSmokeTestGame`), which is the
 * Android analogue of iOS's `GameRegistry.playable.first { $0.id == id }`
 * lookup.
 *
 * [titleRes]/[subtitleRes] are `@StringRes` ids (not raw strings) so every
 * catalogue row stays localised (nl/de) exactly like the rest of the app —
 * resolve them with `stringResource(...)` at render time.
 *
 * This is intentionally a plain data holder, not a `makeScorecardView()`
 * factory like the Swift `GameDefinition` - Compose navigation here is a
 * simple `Screen` enum switch (see `MainActivity.kt`), so the OCP seam for
 * "add a game" is: add an entry to [GameRegistry.games] here, add a `Screen`
 * case, and extend the two `when`s in `MainActivity.kt`.
 */
data class GameCatalogueEntry(
    val id: String,
    @param:StringRes val titleRes: Int,
    @param:StringRes val subtitleRes: Int,
    val accent: Color,
    val icon: ImageVector,
)

/**
 * The single source of truth for which games appear in the catalogue and in
 * what order - mirrors iOS's `GameRegistry.games`
 * (`RollnWrite/Core/GameDefinition.swift`).
 */
object GameRegistry {
    val games: List<GameCatalogueEntry> = listOf(
        GameCatalogueEntry(
            id = "qwixx-big-points",
            titleRes = R.string.qwixx_big_points_title,
            subtitleRes = R.string.qwixx_big_points_subtitle,
            accent = Color(red = 0.86f, green = 0.18f, blue = 0.18f),
            icon = Icons.Filled.GridOn,
        ),
        GameCatalogueEntry(
            id = "qwixx-xchange",
            titleRes = R.string.qwixx_xchange_title,
            subtitleRes = R.string.qwixx_xchange_subtitle,
            // Matches QwixxXChangeGame.swift's accent (deep magenta) and the
            // iOS catalogue row's arrow.triangle.2.circlepath icon.
            accent = Color(red = 0.55f, green = 0.10f, blue = 0.42f),
            icon = Icons.Filled.SwapHoriz,
        ),
    )
}
