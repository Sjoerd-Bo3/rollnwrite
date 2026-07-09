package dev.bo3.rollnwrite.connect15

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
import dev.bo3.rollnwrite.R
import dev.bo3.rollnwrite.catalogue.qwixxDice
import dev.bo3.rollnwrite.core.DiceRollerStrip
import dev.bo3.rollnwrite.core.GameHeader
import dev.bo3.rollnwrite.core.ImmersiveGameEffect
import dev.bo3.rollnwrite.core.rememberDiceVisibility

/**
 * Hosts one Qwixx Connect15 board: compact in-board header (back, title,
 * 2-player toggle, rules), NO system app bar, per-screen landscape lock, and
 * the optional mirrored two-player layout. Mirrors
 * `RollnWrite/Games/QwixxConnect15/Connect15ScorecardView.swift`
 * (`QwixxConnect15ScorecardView`) and the wiring pattern of
 * `dev.bo3.rollnwrite.lucky15.Lucky15ScorecardScreen`.
 *
 * Connect15 gets its own screen (rather than reusing the shared
 * `QwixxScorecardScreen`) because its board renders three connection-field
 * squares overlaid on each colour band's number strip that the shared Qwixx
 * board doesn't know about — same reason iOS has a separate
 * `Connect15BoardView`/`QwixxConnect15ScorecardView` instead of reusing
 * `QwixxBoardView`.
 */
@Composable
fun Connect15ScorecardScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    var twoPlayer by rememberSaveable { mutableStateOf(false) }
    var showRules by rememberSaveable { mutableStateOf(false) }
    val title = stringResource(R.string.qwixx_connect15_title)
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

    val (playerOneViewModel, playerTwoViewModel) = connect15ViewModels()

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
                    TwoPlayerBoards(playerOneViewModel, playerTwoViewModel)
                } else {
                    Connect15BoardView(playerOneViewModel)
                }
            }
        }
    }

    if (showRules) {
        Connect15RulesDialog(onDismiss = { showRules = false })
    }
}

/**
 * Across-the-table mirror: portrait stacks the two boards vertically
 * (opponent rotated 180° on top); landscape places them side by side —
 * mirrors `Lucky15ScorecardScreen.TwoPlayerBoards`.
 */
@Composable
private fun TwoPlayerBoards(playerOne: Connect15ViewModel, playerTwo: Connect15ViewModel) {
    val configuration = LocalConfiguration.current
    val landscape = configuration.screenWidthDp > configuration.screenHeightDp
    if (landscape) {
        Row(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                Connect15BoardView(playerTwo)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                Connect15BoardView(playerOne)
            }
        }
    } else {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                Connect15BoardView(playerTwo)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                Connect15BoardView(playerOne)
            }
        }
    }
}

