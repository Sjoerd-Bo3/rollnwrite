package dev.bo3.rollnwrite.qwixx

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import dev.bo3.rollnwrite.R
import dev.bo3.rollnwrite.engine.qwixx.GameColor

/**
 * UI-layer presentation for [GameColor] — display name and tint are drawn
 * concerns, so (like the engine itself) they live outside `:engine`. Mirrors
 * `RollnWrite/Games/Qwixx/GameColor.swift`'s `tint`/`displayName` exactly
 * (same RGB values), just relocated to the Android view layer.
 */
val GameColor.tint: Color
    get() = when (this) {
        GameColor.RED -> Color(red = 0.86f, green = 0.18f, blue = 0.18f)
        GameColor.YELLOW -> Color(red = 0.98f, green = 0.80f, blue = 0.10f)
        GameColor.GREEN -> Color(red = 0.18f, green = 0.62f, blue = 0.30f)
        GameColor.BLUE -> Color(red = 0.16f, green = 0.40f, blue = 0.78f)
    }

/** Localised display name — a composable function (not a property) since it needs [stringResource]. */
@Composable
fun GameColor.displayName(): String = stringResource(
    when (this) {
        GameColor.RED -> R.string.colour_red
        GameColor.YELLOW -> R.string.colour_yellow
        GameColor.GREEN -> R.string.colour_green
        GameColor.BLUE -> R.string.colour_blue
    }
)
