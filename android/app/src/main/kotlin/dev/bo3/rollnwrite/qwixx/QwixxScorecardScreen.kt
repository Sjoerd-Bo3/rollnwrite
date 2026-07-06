package dev.bo3.rollnwrite.qwixx

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
 * Hosts one Qwixx board: compact in-board header (back, title, undo/redo,
 * 2-player toggle, rules), NO system app bar, per-screen landscape lock, and
 * the optional mirrored two-player layout. Mirrors
 * `RollnWrite/Games/Qwixx/QwixxScorecardView.swift` /
 * `RollnWrite/Core/ScorecardScaffold.swift`.
 */
@Composable
fun QwixxScorecardScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    // rememberSaveable: defence in depth for any activity recreation beyond
    // the orientation-lock case (process death, split-screen resize) so the
    // two-player toggle and rules sheet survive alongside `screen` in
    // MainActivity.
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

    val playerOneViewModel: QwixxViewModel = viewModel(
        key = "qwixx-big-points-p1",
        factory = qwixxViewModelFactory(context, QwixxViewModel.DEFAULT_KEY_PLAYER_ONE),
    )
    val playerTwoViewModel: QwixxViewModel = viewModel(
        key = "qwixx-big-points-p2",
        factory = qwixxViewModelFactory(context, QwixxViewModel.DEFAULT_KEY_PLAYER_TWO),
    )

    Surface(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScorecardHeader(
                title = stringResource(R.string.qwixx_big_points_title),
                twoPlayer = twoPlayer,
                onBack = onBack,
                onToggleTwoPlayer = { twoPlayer = !twoPlayer },
                onShowRules = { showRules = true },
            )
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                if (twoPlayer) {
                    TwoPlayerBoards(playerOneViewModel, playerTwoViewModel)
                } else {
                    QwixxBoardView(playerOneViewModel)
                }
            }
        }
    }

    if (showRules) {
        QwixxRulesDialog(onDismiss = { showRules = false })
    }
}

/**
 * Across-the-table mirror: portrait stacks the two boards vertically
 * (opponent rotated 180° on top); landscape places them side by side —
 * mirrors `ScorecardScaffold`'s `content` branch.
 */
@Composable
private fun TwoPlayerBoards(playerOne: QwixxViewModel, playerTwo: QwixxViewModel) {
    val configuration = LocalConfiguration.current
    val landscape = configuration.screenWidthDp > configuration.screenHeightDp
    if (landscape) {
        Row(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                QwixxBoardView(playerTwo)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                QwixxBoardView(playerOne)
            }
        }
    } else {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                QwixxBoardView(playerTwo)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                QwixxBoardView(playerOne)
            }
        }
    }
}

@Composable
private fun ScorecardHeader(
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
