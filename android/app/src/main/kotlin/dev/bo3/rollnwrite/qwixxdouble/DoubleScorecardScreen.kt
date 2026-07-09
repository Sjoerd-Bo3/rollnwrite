package dev.bo3.rollnwrite.qwixxdouble

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
import dev.bo3.rollnwrite.catalogue.qwixxDice
import dev.bo3.rollnwrite.core.DiceRollerStrip
import dev.bo3.rollnwrite.core.GameHeader
import dev.bo3.rollnwrite.core.ImmersiveGameEffect
import dev.bo3.rollnwrite.core.rememberDiceVisibility

/**
 * Hosts one Qwixx Double board: compact in-board header (back, title, dice
 * toggle, 2-player toggle, rules), NO system app bar, per-screen landscape
 * lock, and the optional mirrored two-player layout. Mirrors
 * `dev.bo3.rollnwrite.qwixx.QwixxScorecardScreen` /
 * `RollnWrite/Games/QwixxDouble/DoubleScorecardView.swift`.
 *
 * Qwixx Double has no bonus rows but uses the standard Qwixx dice (issue #30).
 */
@Composable
fun DoubleScorecardScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    // rememberSaveable: defence in depth for any activity recreation beyond
    // the orientation-lock case (process death, split-screen resize) so the
    // two-player toggle and rules sheet survive alongside `screen` in
    // MainActivity.
    var twoPlayer by rememberSaveable { mutableStateOf(false) }
    var showRules by rememberSaveable { mutableStateOf(false) }
    val title = stringResource(R.string.qwixx_double_title)
    val dice = rememberDiceVisibility(title)

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

    val playerOneViewModel: DoubleViewModel = viewModel(
        key = "qwixx-double-p1",
        factory = doubleViewModelFactory(context, DoubleViewModel.DEFAULT_KEY_PLAYER_ONE),
    )
    val playerTwoViewModel: DoubleViewModel = viewModel(
        key = "qwixx-double-p2",
        factory = doubleViewModelFactory(context, DoubleViewModel.DEFAULT_KEY_PLAYER_TWO),
    )

    Surface(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            GameHeader(
                title = title,
                twoPlayer = twoPlayer,
                onBack = onBack,
                onToggleTwoPlayer = { twoPlayer = !twoPlayer },
                onShowRules = { showRules = true },
                diceShown = dice.shown,
                onToggleDice = dice.toggle,
            )
            if (dice.shown) {
                DiceRollerStrip(dice = qwixxDice)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                if (twoPlayer) {
                    TwoPlayerDoubleBoards(playerOneViewModel, playerTwoViewModel)
                } else {
                    DoubleBoardView(playerOneViewModel)
                }
            }
        }
    }

    if (showRules) {
        DoubleRulesDialog(onDismiss = { showRules = false })
    }
}

/**
 * Across-the-table mirror: portrait stacks the two boards vertically
 * (opponent rotated 180 on top); landscape places them side by side —
 * mirrors `TwoPlayerBoards` in `dev.bo3.rollnwrite.qwixx.QwixxScorecardScreen`.
 */
@Composable
private fun TwoPlayerDoubleBoards(playerOne: DoubleViewModel, playerTwo: DoubleViewModel) {
    val configuration = LocalConfiguration.current
    val landscape = configuration.screenWidthDp > configuration.screenHeightDp
    if (landscape) {
        Row(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                DoubleBoardView(playerTwo)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                DoubleBoardView(playerOne)
            }
        }
    } else {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                DoubleBoardView(playerTwo)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                DoubleBoardView(playerOne)
            }
        }
    }
}

