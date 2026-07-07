package dev.bo3.rollnwrite.mixx

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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.People
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
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
import dev.bo3.rollnwrite.engine.mixx.MixxBoard

/**
 * Hosts the Qwixx Mixx board: compact in-board header (back, title, an A/B
 * board segmented toggle as the header accessory, 2-player toggle, rules),
 * NO system app bar, per-screen landscape lock, and the optional mirrored
 * two-player layout. Mirrors
 * `RollnWrite/Games/QwixxMixx/MixxScorecardView.swift`'s
 * `QwixxMixxScorecardView` (the A/B `headerAccessory` picker) and
 * `QwixxScorecardScreen` (the chrome/orientation/two-player wiring pattern).
 */
@Composable
fun MixxScorecardScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val configuration = LocalConfiguration.current
    var board by rememberSaveable { mutableStateOf(MixxBoard.VARIANT_A) }
    var twoPlayer by rememberSaveable { mutableStateOf(false) }
    var showRules by rememberSaveable { mutableStateOf(false) }

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

    // One ViewModel per board x player, mirroring `QwixxScorecardScreen`'s
    // player-1/player-2 pair, doubled for the two independent Mixx boards
    // (the Swift `MixxGame` holds both in one object via `stateA`/`stateB`;
    // this Kotlin engine is one-board-per-instance, so the UI layer owns the
    // 2x2 matrix of instances instead - see `MixxViewModel` docs).
    val playerOneA: MixxViewModel = viewModel(
        key = "qwixx-mixx-p1-a",
        factory = mixxViewModelFactory(context, MixxViewModel.stateKey(MixxBoard.VARIANT_A), MixxBoard.VARIANT_A),
    )
    val playerOneB: MixxViewModel = viewModel(
        key = "qwixx-mixx-p1-b",
        factory = mixxViewModelFactory(context, MixxViewModel.stateKey(MixxBoard.VARIANT_B), MixxBoard.VARIANT_B),
    )
    val playerTwoA: MixxViewModel = viewModel(
        key = "qwixx-mixx-p2-a",
        factory = mixxViewModelFactory(
            context,
            MixxViewModel.stateKey(MixxBoard.VARIANT_A, MixxViewModel.PLAYER_TWO_SUFFIX),
            MixxBoard.VARIANT_A,
        ),
    )
    val playerTwoB: MixxViewModel = viewModel(
        key = "qwixx-mixx-p2-b",
        factory = mixxViewModelFactory(
            context,
            MixxViewModel.stateKey(MixxBoard.VARIANT_B, MixxViewModel.PLAYER_TWO_SUFFIX),
            MixxBoard.VARIANT_B,
        ),
    )

    val playerOne = if (board == MixxBoard.VARIANT_A) playerOneA else playerOneB
    val playerTwo = if (board == MixxBoard.VARIANT_A) playerTwoA else playerTwoB

    Surface(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            MixxHeader(
                title = stringResource(R.string.qwixx_mixx_title),
                board = board,
                onBoardChange = { board = it },
                twoPlayer = twoPlayer,
                onBack = onBack,
                onToggleTwoPlayer = { twoPlayer = !twoPlayer },
                onShowRules = { showRules = true },
            )
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                if (twoPlayer) {
                    TwoPlayerBoards(playerOne, playerTwo)
                } else {
                    MixxBoardView(playerOne, scoreTitle = stringResource(R.string.qwixx_mixx_title))
                }
            }
        }
    }

    if (showRules) {
        MixxRulesDialog(onDismiss = { showRules = false })
    }
}

/** Across-the-table mirror: portrait stacks the two boards vertically; landscape places them side by side. */
@Composable
private fun TwoPlayerBoards(playerOne: MixxViewModel, playerTwo: MixxViewModel) {
    val configuration = LocalConfiguration.current
    val landscape = configuration.screenWidthDp > configuration.screenHeightDp
    val title = stringResource(R.string.qwixx_mixx_title)
    if (landscape) {
        Row(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                MixxBoardView(playerTwo, scoreTitle = title)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                MixxBoardView(playerOne, scoreTitle = title)
            }
        }
    } else {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f).fillMaxSize().rotate(180f)) {
                MixxBoardView(playerTwo, scoreTitle = title)
            }
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                MixxBoardView(playerOne, scoreTitle = title)
            }
        }
    }
}

@Composable
private fun MixxHeader(
    title: String,
    board: MixxBoard,
    onBoardChange: (MixxBoard) -> Unit,
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
        // The A/B board switch, centred as the header accessory - mirrors
        // iOS's `headerAccessory` segmented Picker in `QwixxMixxScorecardView`.
        SingleChoiceSegmentedButtonRow(modifier = Modifier.widthIn(max = 160.dp)) {
            MixxBoard.entries.forEachIndexed { index, option ->
                SegmentedButton(
                    selected = board == option,
                    onClick = { onBoardChange(option) },
                    shape = SegmentedButtonDefaults.itemShape(index = index, count = MixxBoard.entries.size),
                    label = {
                        Text(
                            if (option == MixxBoard.VARIANT_A) {
                                stringResource(R.string.mixx_board_a_short)
                            } else {
                                stringResource(R.string.mixx_board_b_short)
                            },
                        )
                    },
                )
            }
        }
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
