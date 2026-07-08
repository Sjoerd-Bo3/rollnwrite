package dev.bo3.rollnwrite.core

import android.app.Activity
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.ui.platform.LocalContext
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

/**
 * Hides the status bar AND navigation bar for the lifetime of the calling
 * composable, restoring them on dispose. Mirrors the iOS boards, which run
 * with the status bar hidden entirely (see `RollnWrite/Core/ScorecardScaffold.swift`).
 *
 * Bars are swipe-revealable (`BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE`): a swipe
 * from a screen edge peeks them, then they auto-hide again — never a hard
 * lockout of system UI.
 *
 * Only the game/scorecard screens call this (one call per screen, in the same
 * `DisposableEffect` neighbourhood as that screen's orientation lock). The
 * catalogue and settings screens never call it, so bars stay normal there.
 *
 * Does NOT touch `setDecorFitsSystemWindows` — `MainActivity.onCreate` already
 * calls `enableEdgeToEdge()` once, app-wide, for both catalogue and game
 * screens; this effect only hides/shows the bars themselves, so content still
 * draws edge-to-edge everywhere and callers still consult
 * `WindowInsets.displayCutout`/`safeDrawing` for their own top padding, since
 * hiding the system bars does NOT remove a punch-hole camera cutout.
 */
@Composable
fun ImmersiveGameEffect() {
    val context = LocalContext.current
    DisposableEffect(Unit) {
        val activity = context as? Activity
        val window = activity?.window
        val controller = window?.let { WindowCompat.getInsetsController(it, it.decorView) }

        controller?.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        controller?.hide(WindowInsetsCompat.Type.systemBars())

        onDispose {
            controller?.show(WindowInsetsCompat.Type.systemBars())
        }
    }
}
