package dev.bo3.rollnwrite.connected

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Redo
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.bo3.rollnwrite.R
import dev.bo3.rollnwrite.core.BandChevron
import dev.bo3.rollnwrite.core.BoardControlButton
import dev.bo3.rollnwrite.core.BoardStroke
import dev.bo3.rollnwrite.core.LockTile
import dev.bo3.rollnwrite.core.NumberTile
import dev.bo3.rollnwrite.core.PenaltyBox
import dev.bo3.rollnwrite.core.ScoreTile
import dev.bo3.rollnwrite.core.colourBand
import dev.bo3.rollnwrite.engine.connected.ConnectedLayout
import dev.bo3.rollnwrite.engine.connected.ConnectedState
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.qwixx.QwixxGameOverOverlay
import dev.bo3.rollnwrite.qwixx.displayName
import dev.bo3.rollnwrite.qwixx.tint
import kotlin.math.min

/**
 * The pure banded board for one player — no navigation chrome, mirroring
 * `ConnectedBoardView` in
 * `RollnWrite/Games/QwixxConnected/ConnectedScorecardView.swift` name-for-name.
 * Fills all available space edge-to-edge with no scrolling; rule enforcement
 * lives entirely in [ConnectedViewModel]/the engine — this file only asks
 * `can*`/`isLast*` and renders.
 *
 * Variant twist preserved from iOS: circled chain cells wear a dashed ring in
 * their row's tint, and each printed pair is joined by a short dashed
 * connector line drawn on top of the whole board — decorative only, drawn
 * with `allowsHitTesting`-equivalent behaviour (no pointer input), so it
 * never intercepts taps. Crossing one chain space automatically crosses its
 * partner — handled entirely by the engine.
 */
private const val TILE_GAP = 4
private const val ROW_GAP = 4
private const val OUTER_PAD = 4 // gap to the container edge
private const val BAND_PAD = 4 // coloured border inside each band
private const val COLUMNS = 14f // chevron + 11 numbers + lock + score

@Composable
fun ConnectedBoardView(viewModel: ConnectedViewModel) {
    var confirmReset by remember { mutableStateOf(false) }
    var confirmFinish by remember { mutableStateOf(false) }
    var confirmConcede by remember { mutableStateOf<GameColor?>(null) }
    var showResults by remember { mutableStateOf(viewModel.isGameOver) }

    // Mirrors the iOS `.onChange(of: game.isGameOver)`: show the overlay the
    // moment the engine reports game-over, hide it when a new game starts.
    LaunchedEffect(viewModel.isGameOver) { showResults = viewModel.isGameOver }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Bottom))
            .padding(OUTER_PAD.dp),
    ) {
        val (w, th) = sizing(availWidthDp = maxWidth.value, availHeightDp = maxHeight.value)
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            val bottomH = th.dp * 1.05f
            Box {
                Column(verticalArrangement = Arrangement.spacedBy(ROW_GAP.dp)) {
                    ColourBandRow(viewModel, GameColor.RED, w.dp, th.dp) { confirmConcede = it }
                    ColourBandRow(viewModel, GameColor.YELLOW, w.dp, th.dp) { confirmConcede = it }
                    ColourBandRow(viewModel, GameColor.GREEN, w.dp, th.dp) { confirmConcede = it }
                    ColourBandRow(viewModel, GameColor.BLUE, w.dp, th.dp) { confirmConcede = it }
                    BottomBar(
                        viewModel = viewModel,
                        w = w.dp,
                        h = bottomH,
                        onRequestReset = { confirmReset = true },
                        onRequestFinish = { confirmFinish = true },
                    )
                }
                // The printed sheet joins each circled chain pair with a
                // short line — draw the connectors on top of the whole
                // stack (never intercepts taps).
                ChainLinks(w = w.dp, th = th.dp)
            }
        }

        if (showResults) {
            val lines = buildList {
                GameColor.entries.forEach { color ->
                    add(Triple(color.displayName(), viewModel.points(color), color.tint))
                }
                if (viewModel.penaltyPoints > 0) {
                    add(Triple(stringResource(R.string.penalties), -viewModel.penaltyPoints, Color(0xFFDC2626)))
                }
            }
            QwixxGameOverOverlay(
                lines = lines,
                total = viewModel.totalScore,
                onNewGame = {
                    viewModel.reset()
                    showResults = false
                },
                onDismiss = { showResults = false },
            )
        }
    }

    if (confirmReset) {
        AlertDialog(
            onDismissRequest = { confirmReset = false },
            title = { Text(stringResource(R.string.start_new_game_question)) },
            text = { Text(stringResource(R.string.start_new_game_message)) },
            confirmButton = {
                TextButton(onClick = { viewModel.reset(); confirmReset = false }) {
                    Text(stringResource(R.string.new_game))
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmReset = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }

    if (confirmFinish) {
        AlertDialog(
            onDismissRequest = { confirmFinish = false },
            title = { Text(stringResource(R.string.finish_game_question)) },
            text = { Text(stringResource(R.string.finish_game_message)) },
            confirmButton = {
                TextButton(onClick = { viewModel.finishGame(); confirmFinish = false }) {
                    Text(stringResource(R.string.finish_game))
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmFinish = false }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }

    confirmConcede?.let { color ->
        AlertDialog(
            onDismissRequest = { confirmConcede = null },
            title = { Text(stringResource(R.string.close_colour_question)) },
            text = { Text(stringResource(R.string.close_colour_message, color.displayName())) },
            confirmButton = {
                TextButton(onClick = { viewModel.concedeRow(color); confirmConcede = null }) {
                    Text(stringResource(R.string.close_colour_action, color.displayName()))
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmConcede = null }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

/**
 * One full-width colour band: a direction chevron, the eleven number tiles
 * (chain spaces ringed), the lock, and that colour's running score. Mirrors
 * `band(_:w:tile:)`.
 */
@Composable
private fun ColourBandRow(
    viewModel: ConnectedViewModel,
    color: GameColor,
    w: Dp,
    th: Dp,
    onRequestConcede: (GameColor) -> Unit,
) {
    val row = viewModel.row(color)
    val corner = min(w.value, th.value) * 0.3f
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .colourBand(tint = color.tint, corner = corner.dp)
            .padding(horizontal = BAND_PAD.dp, vertical = (th.value * 0.09f).dp),
        horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BandChevron(w = w, h = th)
        color.numbers.forEachIndexed { i, number ->
            val marked = i in row.marks
            val undoable = marked && viewModel.isLastColorMark(color, i)
            val forfeited = !marked && (i < row.maxMarkedIndex || row.locked)
            val isChain = viewModel.isChainSpace(color, i)
            Box {
                NumberTile(
                    text = "$number",
                    tint = color.tint,
                    marked = marked,
                    legal = viewModel.canMarkColor(color, i),
                    undoable = undoable,
                    forfeited = forfeited,
                    w = w,
                    h = th,
                    onTap = { if (undoable) viewModel.undo() else viewModel.markColor(color, i) },
                )
                // Dashed chain ring in the row's own tint — matches the
                // printed circled chain field. Decorative only.
                if (isChain) {
                    val s = min(w.value, th.value)
                    Canvas(modifier = Modifier.width(w).height(th)) {
                        drawCircle(
                            color = color.tint,
                            radius = (s / 2f).dp.toPx() - 1.dp.toPx(),
                            style = Stroke(
                                width = BoardStroke.small(s).dp.toPx(),
                                pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f.dp.toPx(), 2.5f.dp.toPx())),
                            ),
                        )
                    }
                }
            }
        }
        val lockUndoable = row.locked && viewModel.isLastConcede(color)
        LockTile(
            tint = color.tint,
            locked = row.locked,
            undoable = lockUndoable,
            w = w,
            h = th,
            contentDescription = stringResource(R.string.lock_content_description, color.displayName()),
            onTap = {
                if (viewModel.isLastConcede(color)) {
                    viewModel.undo()
                } else if (viewModel.canConcedeRow(color)) {
                    onRequestConcede(color)
                }
            },
        )
        ScoreTile(viewModel.points(color), w = w, h = th)
    }
}

/**
 * Dashed connector lines between the two dashed rings of every chain, like
 * the printed sheet. All six chains join ADJACENT rows in the SAME column,
 * so each connector is a short vertical dashed segment from the bottom edge
 * of the upper ring to the top edge of the lower ring. Mirrors
 * `chainLinks(w:th:)`'s geometry: a band is `1.18·th` tall (tile + 2×0.09
 * vertical padding) and starts at `row·(1.18·th + rowGap)`; within it, column
 * `c`'s tile centre sits at `bandPad + (c+1)·(w+tileGap) + w/2` (chevron
 * occupies column 0). The ring's diameter is `min(w, th)`.
 */
@Composable
private fun ChainLinks(w: Dp, th: Dp) {
    val bandH = th * 1.18f
    val dia = min(w.value, th.value)
    val colors = GameColor.entries
    Canvas(modifier = Modifier.fillMaxSize()) {
        for (chain in ConnectedLayout.chains) {
            val rowA = colors.indexOf(chain.a.color)
            val rowB = colors.indexOf(chain.b.color)
            if (rowA < 0 || rowB < 0) continue
            val top = min(rowA, rowB)
            val bottom = maxOf(rowA, rowB)
            val x = (BAND_PAD.dp + (w + TILE_GAP.dp) * (chain.a.index + 1) + w / 2).toPx()
            val tileCentre = (th.value * 0.09f + th.value / 2f).dp.toPx()
            val bandHPx = bandH.toPx()
            val rowGapPx = ROW_GAP.dp.toPx()
            val diaPx = dia.dp.toPx()
            val yTop = top * (bandHPx + rowGapPx) + tileCentre + diaPx / 2f - 1.dp.toPx()
            val yBottom = bottom * (bandHPx + rowGapPx) + tileCentre - diaPx / 2f + 1.dp.toPx()
            drawLine(
                color = Color(0xFF1C1C1E).copy(alpha = 0.55f),
                start = Offset(x, yTop),
                end = Offset(x, yBottom),
                strokeWidth = 2.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(3f.dp.toPx(), 2.5f.dp.toPx())),
            )
        }
    }
}

/**
 * Controls (undo, redo, reset, finish) on the left, penalties + running
 * total on the right. Mirrors `bottomBar(w:h:)`.
 */
@Composable
private fun BottomBar(
    viewModel: ConnectedViewModel,
    w: Dp,
    h: Dp,
    onRequestReset: () -> Unit,
    onRequestFinish: () -> Unit,
) {
    val b = min(h.value, 64f).dp
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(h)
            .padding(horizontal = BAND_PAD.dp),
        horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BoardControlButton(
            icon = Icons.AutoMirrored.Filled.Undo,
            size = b,
            contentDescription = stringResource(R.string.undo),
            enabled = viewModel.canUndo,
            action = { viewModel.undo() },
        )
        BoardControlButton(
            icon = Icons.AutoMirrored.Filled.Redo,
            size = b,
            contentDescription = stringResource(R.string.redo),
            enabled = viewModel.canRedo,
            action = { viewModel.redo() },
        )
        BoardControlButton(
            icon = Icons.Filled.Delete,
            size = b,
            contentDescription = stringResource(R.string.new_game),
            action = onRequestReset,
        )
        BoardControlButton(
            icon = Icons.Filled.Flag,
            size = b,
            contentDescription = stringResource(R.string.finish_game),
            enabled = !viewModel.isGameOver,
            action = onRequestFinish,
        )
        Spacer(
            modifier = Modifier.weight(1f).widthIn(min = w * 0.1f),
        )
        repeat(ConnectedState.MAX_PENALTIES) { i ->
            val isNext = i == viewModel.penalties && viewModel.canAddPenalty()
            val undoable = i == viewModel.penalties - 1 && viewModel.isLastPenalty()
            PenaltyBox(
                filled = i < viewModel.penalties,
                isNext = isNext,
                undoable = undoable,
                size = b,
                contentDescription = stringResource(R.string.penalty_n, i + 1),
                onTap = { if (isNext) viewModel.addPenalty() else viewModel.undo() },
            )
        }
        Text(
            stringResource(R.string.total),
            fontSize = (b.value * 0.34f).sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
        )
        Text(
            "${viewModel.totalScore}",
            fontSize = (b.value * 0.55f).sp,
            fontWeight = FontWeight.Black,
            maxLines = 1,
        )
    }
}

/**
 * Tile sizing, mirroring the established Android convention for a
 * no-extra-row Qwixx board (`QwixxBoardView`/`XChangeBoardView`'s colour
 * band weight of 1.18·th, bottom bar 1.05·th): width fills the full
 * container width; height fills the container but is capped at the width
 * (square is the MAX) and floored at a readable MIN.
 *
 * `availWidthDp`/`availHeightDp` are the `BoxWithConstraints` measurements,
 * already reduced by the caller's `.padding(OUTER_PAD.dp)` — do NOT subtract
 * `OUTER_PAD` again here (mirrors `QwixxBoardView.sizing`'s same caveat).
 */
private fun sizing(availWidthDp: Float, availHeightDp: Float): Pair<Float, Float> {
    val bandCount = 4f
    val children = bandCount + 1f // colour bands + bottom bar
    val gaps = maxOf(0f, children - 1f)

    val w = maxOf(14f, (availWidthDp - (COLUMNS - 1) * TILE_GAP - 2 * BAND_PAD) / COLUMNS)

    val units = bandCount * 1.18f + 1.05f
    val fill = (availHeightDp - gaps * ROW_GAP) / units
    val th = maxOf(20f, minOf(fill, w))
    return w to th
}
