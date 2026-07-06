package dev.bo3.rollnwrite.connected

import android.app.Activity
import android.content.pm.ActivityInfo
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.People
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.bo3.rollnwrite.R

/**
 * Hosts one Qwixx Connected board: compact in-board header (back, title,
 * 2-player toggle, rules), NO system app bar, per-screen landscape lock, and
 * the optional mirrored two-player layout. Mirrors
 * `RollnWrite/Games/QwixxConnected/ConnectedScorecardView.swift`
 * (`QwixxConnectedScorecardView`) and `dev.bo3.rollnwrite.bonus.BonusScorecardScreen`'s wiring.
 *
 * This variant has no header accessory beyond the standard back/title/
 * 2-player/rules set — its dice are the standard Qwixx set, surfaced only
 * via the (not-yet-ported) dice-roller strip, so nothing extra is wired here.
 */
@Composable
fun ConnectedScorecardScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    var twoPlayer by rememberSaveable { mutableStateOf(false) }
    var showRules by rememberSaveable { mutableStateOf(false) }

    // Single-player on a phone (smallest width < 600dp) pins landscape;
    // two-player or tablet rotates freely — mirrors `landscapeLockediPhone(when:)`.
    val isPhone = configuration.smallestScreenWidthDp < 600
    val locksLandscape = isPhone && !twoPlayer

    DisposableEffect(locksLandscape) {
        val activity = context as? Activity
        activity?.requestedOrientation = if (locksLandscape) {
            ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        } else {
            ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
        onDispose {
            activity?.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
        }
    }

    val playerOneViewModel: ConnectedViewModel = viewModel(
        key = "qwixx-connected-p1",
        factory = connectedViewModelFactory(context, ConnectedViewModel.DEFAULT_KEY_PLAYER_ONE),
    )
    val playerTwoViewModel: ConnectedViewModel = viewModel(
        key = "qwixx-connected-p2",
        factory = connectedViewModelFactory(context, ConnectedViewModel.DEFAULT_KEY_PLAYER_TWO),
    )

    Surface(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            ConnectedScorecardHeader(
                title = stringResource(R.string.qwixx_connected_title),
                twoPlayer = twoPlayer,
                onBack = onBack,
                onToggleTwoPlayer = { twoPlayer = !twoPlayer },
                onShowRules = { showRules = true },
            )
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                if (twoPlayer) {
                    TwoPlayerConnectedBoards(playerOneViewModel, playerTwoViewModel)
                } else {
                    ConnectedBoardView(playerOneViewModel)
                }
            }
        }
    }

    if (showRules) {
        ConnectedRulesDialog(onDismiss = { showRules = false })
    }
}

/**
 * Across-the-table mirror: portrait stacks the two boards vertically
 * (opponent rotated 180° on top); landscape places them side by side —
 * mirrors `TwoPlayerBoards` in `dev.bo3.rollnwrite.qwixx.QwixxScorecardScreen`.
 */
@Composable
private fun TwoPlayerConnectedBoards(playerOne: ConnectedViewModel, playerTwo: ConnectedViewModel) {
    val configuration = LocalConfiguration.current
    val landscape = configuration.screenWidthDp > configuration.screenHeightDp
    if (landscape) {
        Row(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                ConnectedBoardView(playerTwo)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                ConnectedBoardView(playerOne)
            }
        }
    } else {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                ConnectedBoardView(playerTwo)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                ConnectedBoardView(playerOne)
            }
        }
    }
}

@Composable
private fun ConnectedScorecardHeader(
    title: String,
    twoPlayer: Boolean,
    onBack: () -> Unit,
    onToggleTwoPlayer: () -> Unit,
    onShowRules: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Top))
            .padding(horizontal = 12.dp, vertical = 4.dp),
        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
        }
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        IconButton(onClick = onToggleTwoPlayer) {
            Icon(
                imageVector = if (twoPlayer) Icons.Filled.Person else Icons.Outlined.People,
                contentDescription = stringResource(
                    if (twoPlayer) R.string.single_player else R.string.two_players,
                ),
            )
        }
        IconButton(onClick = onShowRules) {
            Icon(Icons.Filled.Info, contentDescription = stringResource(R.string.rules))
        }
    }
}
