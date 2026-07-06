package dev.bo3.rollnwrite

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import dev.bo3.rollnwrite.catalogue.GameCatalogueEntry
import dev.bo3.rollnwrite.catalogue.GameRegistry
import dev.bo3.rollnwrite.qwixx.QwixxScorecardScreen
import dev.bo3.rollnwrite.xchange.XChangeScorecardScreen

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
 * shows a card per game; tapping it swaps to that game's scorecard screen.
 * System back returns to the catalogue. Mirrors iOS `RootView`'s role as the
 * game catalogue, ahead of a `GameDefinition`/registry equivalent landing on
 * this platform.
 */
private enum class Screen {
    Catalogue,
    QwixxBigPoints,
    QwixxXChange,
}

/**
 * Maps a smoke-test game id to its `Screen`. A `when` over a small set of
 * known ids — the same OCP seam as iOS's `GameRegistry.playable.first {
 * $0.id == id }` lookup: adding a game means extending this `when`, not
 * touching the caller. Unknown/missing ids fall through to the catalogue.
 */
private fun screenForSmokeTestGame(id: String?): Screen? = when (id) {
    "qwixx-big-points" -> Screen.QwixxBigPoints
    "qwixx-xchange" -> Screen.QwixxXChange
    else -> null
}

/** Maps a [GameCatalogueEntry.id] to its `Screen` — the tap-to-open counterpart of [screenForSmokeTestGame]. */
private fun screenForGameId(id: String): Screen? = when (id) {
    "qwixx-big-points" -> Screen.QwixxBigPoints
    "qwixx-xchange" -> Screen.QwixxXChange
    else -> null
}

@Composable
private fun RootScreen(smokeTestGame: String? = null) {
    // rememberSaveable (not remember): the scorecard's orientation lock is a
    // configuration change and, absent `android:configChanges` on the
    // activity, or on any other recreation (process death), plain `remember`
    // would reset navigation back to the catalogue mid-game. The smoke-test
    // destination (if any) only seeds the initial value — it must not
    // re-trigger navigation on every recomposition/config change.
    var screen by rememberSaveable {
        mutableStateOf(screenForSmokeTestGame(smokeTestGame) ?: Screen.Catalogue)
    }

    BackHandler(enabled = screen != Screen.Catalogue) {
        screen = Screen.Catalogue
    }

    when (screen) {
        Screen.Catalogue -> CatalogueScreen(onOpenGame = { id -> screenForGameId(id)?.let { screen = it } })
        Screen.QwixxBigPoints -> QwixxScorecardScreen(onBack = { screen = Screen.Catalogue })
        Screen.QwixxXChange -> XChangeScorecardScreen(onBack = { screen = Screen.Catalogue })
    }
}

/**
 * Renders one card per [GameRegistry.games] entry (OCP: adding a game means
 * adding a registry entry + a `Screen` case, not touching this composable) —
 * mirrors iOS `RootView` iterating `GameRegistry.games`.
 */
@Composable
private fun CatalogueScreen(onOpenGame: (String) -> Unit) {
    Scaffold { innerPadding ->
        Surface(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            Column(
                modifier = Modifier.fillMaxSize().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            ) {
                Text(
                    text = stringResource(R.string.catalogue_title),
                    style = MaterialTheme.typography.headlineLarge,
                )
                GameRegistry.games.forEach { entry ->
                    GameCatalogueCard(entry = entry, onClick = { onOpenGame(entry.id) })
                }
            }
        }
    }
}

@Composable
private fun GameCatalogueCard(entry: GameCatalogueEntry, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        onClick = onClick,
    ) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Text(text = stringResource(entry.titleRes), style = MaterialTheme.typography.titleMedium)
            Text(text = stringResource(entry.subtitleRes), style = MaterialTheme.typography.bodyMedium)
        }
    }
}
