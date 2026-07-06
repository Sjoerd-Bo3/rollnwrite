package dev.bo3.rollnwrite.lucky15

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
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
import dev.bo3.rollnwrite.engine.lucky15.Lucky15State
import dev.bo3.rollnwrite.engine.lucky15.Lucky15Track
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.qwixx.QwixxGameOverOverlay
import dev.bo3.rollnwrite.qwixx.displayName
import dev.bo3.rollnwrite.qwixx.tint
import kotlin.math.min

/**
 * The pure banded board for one Lucky15 player — no navigation chrome,
 * mirroring `Lucky15BoardView` in
 * `RollnWrite/Games/QwixxLucky15/Lucky15ScorecardView.swift`. Fills all
 * available space edge-to-edge with no scrolling; rule enforcement lives
 * entirely in [Lucky15ViewModel]/the engine — this file only asks
 * `can*`/`isLast*` and renders.
 *
 * Four classic colour bands (identical layout to [dev.bo3.rollnwrite.qwixx.QwixxBoardView],
 * no bonus rows) plus a fifth orange "Lucky 15" band of four diamond fields,
 * then the bottom bar — six rows total, matching the iOS `rowUnits = 4 +
 * 0.82 + 1.05` / `rowCount = 6` derivation exactly.
 */
private const val TILE_GAP = 4
private const val ROW_GAP = 4
private const val OUTER_PAD = 4 // gap to the container edge
private const val BAND_PAD = 4 // coloured border inside each band
private const val COLUMNS = 14f // chevron + 11 numbers + lock + score

/** Orange tint of the Lucky 15 track, matching the official sheet (iOS `Lucky15BoardView.luckyTint`). */
val luckyTint = Color(red = 0.93f, green = 0.45f, blue = 0.13f)

@Composable
fun Lucky15BoardView(viewModel: Lucky15ViewModel) {
    var confirmReset by remember { mutableStateOf(false) }
    var confirmFinish by remember { mutableStateOf(false) }
    var confirmConcede by remember { mutableStateOf<GameColor?>(null) }
    var showResults by remember { mutableStateOf(viewModel.isGameOver) }

    // Mirrors the iOS `.onChange(of: game.isGameOver)`.
    LaunchedEffect(viewModel.isGameOver) { showResults = viewModel.isGameOver }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Bottom))
            .padding(OUTER_PAD.dp),
    ) {
        val (w, th) = sizing(maxWidth.value, maxHeight.value)
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            val luckyH = th.dp * 0.82f
            val bottomH = th.dp * 1.05f
            Column(verticalArrangement = Arrangement.spacedBy(ROW_GAP.dp)) {
                ColourBandRow(viewModel, GameColor.RED, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.YELLOW, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.GREEN, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.BLUE, w.dp, th.dp) { confirmConcede = it }
                LuckyBandRow(viewModel, w.dp, luckyH)
                BottomBar(
                    viewModel = viewModel,
                    w = w.dp,
                    h = bottomH,
                    onRequestReset = { confirmReset = true },
                    onRequestFinish = { confirmFinish = true },
                )
            }
        }

        if (showResults) {
            val lines = buildList {
                GameColor.entries.forEach { color ->
                    add(Triple(color.displayName(), viewModel.points(color), color.tint))
                }
                add(Triple(stringResource(R.string.lucky15_track_title), viewModel.luckyPoints, luckyTint))
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
 * One full-width colour band: a direction chevron, the eleven number tiles,
 * the lock, and that colour's running score. Identical to
 * `QwixxBoardView.ColourBandRow` (classic Qwixx rules: no bonus rows).
 */
@Composable
private fun ColourBandRow(
    viewModel: Lucky15ViewModel,
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
 * The orange Lucky 15 bonus track: four diamond-value fields (the printed
 * sheet's diamonds) crossed strictly left → right. Only the next uncrossed
 * field is legal; the right-most crossed field is the tap-to-undo cell.
 * Mirrors iOS `luckyBand(w:h:)`: chevron column matches the colour bands',
 * diamonds distribute evenly across the band, trailing score-chip column.
 */
@Composable
private fun LuckyBandRow(viewModel: Lucky15ViewModel, w: Dp, h: Dp) {
    val corner = min(w.value, h.value) * 0.3f
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .colourBand(tint = luckyTint, corner = corner.dp)
            .padding(horizontal = BAND_PAD.dp, vertical = (h.value * 0.09f).dp),
        horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BandChevron(w = w, h = h)
        Row(
            modifier = Modifier.weight(1f).fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Lucky15Track.VALUES.forEachIndexed { idx, value ->
                val marked = idx < viewModel.lucky.crossed
                val isNext = idx == viewModel.lucky.crossed && viewModel.canMarkLucky()
                val undoable = marked && idx == viewModel.lucky.crossed - 1 && viewModel.isLastLuckyMark()
                LuckyDiamondTile(
                    value = value,
                    tint = luckyTint,
                    marked = marked,
                    legal = isNext,
                    undoable = undoable,
                    w = w,
                    h = h,
                    onTap = { if (undoable) viewModel.undo() else viewModel.markLucky() },
                )
            }
        }
        ScoreTile(viewModel.luckyPoints, w = w, h = h)
    }
}

/**
 * A Lucky 15 track field: a white diamond carrying the field's point value,
 * crossed when marked. Mirrors iOS `LuckyDiamondTile` — same sizing/
 * crossed-out/undo-ring conventions as the shared Core tiles, but the
 * diamond geometry is local to this variant (no shared `Diamond` shape
 * exists on Android's Core yet — X-Change, the other diamond-using variant,
 * hasn't landed either).
 */
@Composable
private fun LuckyDiamondTile(
    value: Int,
    tint: Color,
    marked: Boolean,
    legal: Boolean,
    undoable: Boolean,
    w: Dp,
    h: Dp,
    onTap: () -> Unit,
) {
    val s = min(w.value, h.value)
    val interactive = legal || undoable
    val alpha = if (marked || legal) 1f else 0.4f
    val stateDescription = if (marked) {
        stringResource(R.string.tile_state_crossed)
    } else if (legal) {
        stringResource(R.string.tile_state_available)
    } else {
        stringResource(R.string.tile_state_blocked)
    }
    Box(
        modifier = Modifier
            .widthIn(min = w, max = w)
            .height(h)
            .clickable(enabled = interactive) { onTap() },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.widthIn(min = w, max = w).height(h)) {
            // Point-to-point extent equals the square's diagonal, matching
            // iOS `Diamond`'s geometry (a square rotated 45 degrees); this
            // draws the diamond outline directly rather than rotating a
            // rounded-rect path.
            val d = min(size.width, size.height)
            val cx = size.width / 2f
            val cy = size.height / 2f
            val path = Path().apply {
                moveTo(cx, cy - d / 2f)
                lineTo(cx + d / 2f, cy)
                lineTo(cx, cy + d / 2f)
                lineTo(cx - d / 2f, cy)
                close()
            }
            drawPath(path, color = Color.White.copy(alpha = 0.95f))
            drawPath(
                path,
                color = tint.copy(alpha = 0.85f),
                style = Stroke(width = BoardStroke.small(s).dp.toPx()),
            )
            if (undoable) {
                drawPath(path, color = tint, style = Stroke(width = BoardStroke.medium(s).dp.toPx()))
            }
        }
        Text(
            text = "$value",
            color = tint.copy(alpha = alpha),
            fontWeight = FontWeight.Black,
            fontSize = (s * 0.32f).sp,
            maxLines = 1,
        )
        if (marked) {
            Text(
                text = "✕",
                color = tint.copy(alpha = alpha),
                fontWeight = FontWeight.Black,
                fontSize = (s * 0.5f).sp,
            )
        }
    }
}

/**
 * Controls (undo, redo, reset, finish) on the left, penalties + running total
 * on the right. Identical to `QwixxBoardView.BottomBar`.
 */
@Composable
private fun BottomBar(
    viewModel: Lucky15ViewModel,
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
        Spacer(modifier = Modifier.weight(1f).widthIn(min = w * 0.1f))
        repeat(Lucky15State.MAX_PENALTIES) { i ->
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
 * Tile sizing, mirroring the iOS derivation exactly: width fills the full
 * container width; height fills the container but is capped at the width
 * (square is the MAX) and floored at a readable MIN. Row units: 4 colour
 * bands (1.18·th each, matching `QwixxBoardView.sizing`) + the Lucky 15 band
 * (0.82·th, matching iOS's `luckyH = th * 0.82`) + the bottom bar
 * (1.05·th) = the iOS `rowUnits = 4 + 0.82 + 1.05` derivation.
 */
private fun sizing(availWidthDp: Float, availHeightDp: Float): Pair<Float, Float> {
    val bandCount = 4f
    val children = bandCount + 1f + 1f // colour bands + lucky band + bottom bar
    val gaps = maxOf(0f, children - 1f)

    val w = maxOf(14f, (availWidthDp - (COLUMNS - 1) * TILE_GAP - 2 * BAND_PAD) / COLUMNS)

    val units = bandCount * 1.18f + 0.82f + 1.05f
    val fill = (availHeightDp - gaps * ROW_GAP) / units
    val th = maxOf(20f, minOf(fill, w))
    return w to th
}
