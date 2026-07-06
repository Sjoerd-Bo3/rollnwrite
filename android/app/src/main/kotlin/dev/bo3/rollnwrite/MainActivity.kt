package dev.bo3.rollnwrite

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import dev.bo3.rollnwrite.catalogue.CatalogueScreen
import dev.bo3.rollnwrite.catalogue.GameRegistry
import dev.bo3.rollnwrite.catalogue.SettingsScreen

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MaterialTheme {
                RootScreen(smokeTestGame = smokeTestGameId())
            }
        }
    }

    /**
     * Android twin of iOS's `-smokeTestGame <id>` launch argument (see
     * `RollnWrite/App/RootView.swift`): the "9. Android Smoke Test" workflow
     * drives this via `am start --es smokeTestGame <id>` so a headless runner
     * can screenshot a board directly, without UI-scripting the catalogue tap.
     * `BuildConfig.DEBUG` keeps it out of release/Play builds, matching the
     * iOS `#if DEBUG` gate.
     */
    private fun smokeTestGameId(): String? {
        if (!BuildConfig.DEBUG) return null
        return intent?.getStringExtra("smokeTestGame")
    }
}

/**
 * Simple state-based navigation (no navigation dependency): the catalogue
 * shows a row per [GameRegistry] entry; tapping it swaps to that game's
 * scorecard screen. System back returns to the catalogue. Mirrors iOS
 * `RootView`'s role as the game catalogue.
 *
 * Represented as a plain string rather than a sealed class so it survives
 * `rememberSaveable` with no custom `Saver`: `"catalogue"`, `"settings"`, or
 * a game id (looked up in [GameRegistry]).
 */
private const val SCREEN_CATALOGUE = "catalogue"
private const val SCREEN_SETTINGS = "settings"

@Composable
private fun RootScreen(smokeTestGame: String? = null) {
    // rememberSaveable (not remember): the scorecard's orientation lock is a
    // configuration change and, absent `android:configChanges` on the
    // activity, or on any other recreation (process death), plain `remember`
    // would reset navigation back to the catalogue mid-game. The smoke-test
    // destination (if any) only seeds the initial value — it must not
    // re-trigger navigation on every recomposition/config change.
    var screen: String by rememberSaveable {
        val initial = smokeTestGame?.takeIf { id -> GameRegistry.find(id) != null } ?: SCREEN_CATALOGUE
        mutableStateOf(initial)
    }

    BackHandler(enabled = screen != SCREEN_CATALOGUE) {
        screen = SCREEN_CATALOGUE
    }

    when (screen) {
        SCREEN_CATALOGUE -> CatalogueScreen(
            onOpenGame = { id -> screen = id },
            onOpenSettings = { screen = SCREEN_SETTINGS },
        )
        SCREEN_SETTINGS -> SettingsScreen(onBack = { screen = SCREEN_CATALOGUE })
        else -> {
            val game = GameRegistry.find(screen)
            if (game != null) {
                game.makeScreen { screen = SCREEN_CATALOGUE }
            } else {
                // Unknown/stale id (e.g. a removed game restored from a saved
                // instance state) — fall back to the catalogue rather than crash.
                // Render the catalogue for this frame and defer the state
                // write to a SideEffect so this stays a forward write (state
                // written after composition, not read-then-written within
                // it) — avoids a Compose "backward write" on the stale-id path.
                SideEffect { screen = SCREEN_CATALOGUE }
                CatalogueScreen(
                    onOpenGame = { id -> screen = id },
                    onOpenSettings = { screen = SCREEN_SETTINGS },
                )
            }
        }
    }
}
