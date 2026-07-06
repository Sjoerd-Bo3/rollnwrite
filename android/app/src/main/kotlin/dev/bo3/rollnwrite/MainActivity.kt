package dev.bo3.rollnwrite

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
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
import dev.bo3.rollnwrite.catalogue.GameEntry
import dev.bo3.rollnwrite.catalogue.GameRegistry
import dev.bo3.rollnwrite.mixx.MixxScorecardScreen
import dev.bo3.rollnwrite.qwixx.QwixxScorecardScreen

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
    QwixxMixx,
}

/**
 * Maps a `GameEntry.id` to its `Screen`. A `when` over a small set of known
 * ids — the same OCP seam as iOS's `GameRegistry.playable.first { $0.id ==
 * id }` lookup: adding a game means extending this `when` (and adding one
 * `GameRegistry` entry), not touching the catalogue rendering.
 */
private fun screenForGameId(id: String?): Screen? = when (id) {
    "qwixx-big-points" -> Screen.QwixxBigPoints
    "qwixx-mixx" -> Screen.QwixxMixx
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
        mutableStateOf(screenForGameId(smokeTestGame) ?: Screen.Catalogue)
    }

    BackHandler(enabled = screen != Screen.Catalogue) {
        screen = Screen.Catalogue
    }

    when (screen) {
        Screen.Catalogue -> CatalogueScreen(onOpenGame = { id ->
            screenForGameId(id)?.let { screen = it }
        })
        Screen.QwixxBigPoints -> QwixxScorecardScreen(onBack = { screen = Screen.Catalogue })
        Screen.QwixxMixx -> MixxScorecardScreen(onBack = { screen = Screen.Catalogue })
    }
}

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
                    GameCard(entry = entry, onClick = { onOpenGame(entry.id) })
                }
            }
        }
    }
}

@Composable
private fun GameCard(entry: GameEntry, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(20.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = entry.icon,
                contentDescription = null,
                tint = entry.accent,
                modifier = Modifier.size(32.dp),
            )
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(text = entry.title(), style = MaterialTheme.typography.titleMedium)
                Text(text = entry.subtitle(), style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}
