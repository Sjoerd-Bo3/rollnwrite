package dev.bo3.rollnwrite.connected

import android.app.Activity
import android.content.pm.ActivityInfo
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
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
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.bo3.rollnwrite.R
import dev.bo3.rollnwrite.core.GameHeader
import dev.bo3.rollnwrite.core.ImmersiveGameEffect

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
    ImmersiveGameEffect()

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
            GameHeader(
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

