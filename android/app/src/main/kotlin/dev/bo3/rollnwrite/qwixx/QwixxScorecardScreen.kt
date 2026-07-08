package dev.bo3.rollnwrite.qwixx

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
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.bo3.rollnwrite.core.GameHeader
import dev.bo3.rollnwrite.core.ImmersiveGameEffect
import dev.bo3.rollnwrite.engine.TriangularScoring

/** Which official rules text to show — the two Qwixx flavours differ only in copy, never in engine code. */
enum class QwixxRulesVariant { BIG_POINTS, CLASSIC }

/**
 * Builds the player 1 / player 2 view models for Qwixx Big Points (cap 15,
 * bonus rows on) under their own persistence keys.
 */
@Composable
fun qwixxBigPointsViewModels(): Pair<QwixxViewModel, QwixxViewModel> {
    val context = LocalContext.current
    val p1: QwixxViewModel = viewModel(
        key = "qwixx-big-points-p1",
        factory = qwixxViewModelFactory(
            context = context,
            persistenceKey = QwixxViewModel.KEY_BIG_POINTS_PLAYER_ONE,
            scoring = TriangularScoring(cap = 15),
            hasBonusRows = true,
        ),
    )
    val p2: QwixxViewModel = viewModel(
        key = "qwixx-big-points-p2",
        factory = qwixxViewModelFactory(
            context = context,
            persistenceKey = QwixxViewModel.KEY_BIG_POINTS_PLAYER_TWO,
            scoring = TriangularScoring(cap = 15),
            hasBonusRows = true,
        ),
    )
    return p1 to p2
}

/**
 * Builds the player 1 / player 2 view models for classic Qwixx (cap 12, no
 * bonus rows) under their own persistence keys — mirrors iOS
 * `QwixxClassicGame`'s construction (same engine, different configuration).
 */
@Composable
fun qwixxClassicViewModels(): Pair<QwixxViewModel, QwixxViewModel> {
    val context = LocalContext.current
    val p1: QwixxViewModel = viewModel(
        key = "qwixx-classic-p1",
        factory = qwixxViewModelFactory(
            context = context,
            persistenceKey = QwixxViewModel.KEY_CLASSIC_PLAYER_ONE,
            scoring = TriangularScoring(cap = 12),
            hasBonusRows = false,
        ),
    )
    val p2: QwixxViewModel = viewModel(
        key = "qwixx-classic-p2",
        factory = qwixxViewModelFactory(
            context = context,
            persistenceKey = QwixxViewModel.KEY_CLASSIC_PLAYER_TWO,
            scoring = TriangularScoring(cap = 12),
            hasBonusRows = false,
        ),
    )
    return p1 to p2
}

/**
 * Hosts one Qwixx board: compact in-board header (back, title, undo/redo,
 * 2-player toggle, rules), NO system app bar, per-screen landscape lock, and
 * the optional mirrored two-player layout. Mirrors
 * `RollnWrite/Games/Qwixx/QwixxScorecardView.swift` /
 * `RollnWrite/Core/ScorecardScaffold.swift`.
 *
 * Takes its view models and title from the caller (the [dev.bo3.rollnwrite.catalogue.GameRegistry]
 * entry) rather than constructing them itself, so this single screen serves
 * every Qwixx variant (Big Points, classic, future ones) with no per-game
 * branching inside the screen.
 */
@Composable
fun QwixxScorecardScreen(
    title: String,
    playerOne: QwixxViewModel,
    playerTwo: QwixxViewModel,
    rulesVariant: QwixxRulesVariant,
    onBack: () -> Unit,
) {
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
    ImmersiveGameEffect()

    Surface(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            GameHeader(
                title = title,
                twoPlayer = twoPlayer,
                onBack = onBack,
                onToggleTwoPlayer = { twoPlayer = !twoPlayer },
                onShowRules = { showRules = true },
            )
            Box(modifier = Modifier.weight(1f).fillMaxSize()) {
                if (twoPlayer) {
                    TwoPlayerBoards(playerOne, playerTwo)
                } else {
                    QwixxBoardView(playerOne)
                }
            }
        }
    }

    if (showRules) {
        QwixxRulesDialog(variant = rulesVariant, onDismiss = { showRules = false })
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
