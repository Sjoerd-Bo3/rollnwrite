package dev.bo3.rollnwrite.xchange

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Redo
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
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
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.engine.xchange.XChangeRow
import dev.bo3.rollnwrite.engine.xchange.XChangeState
import dev.bo3.rollnwrite.qwixx.QwixxGameOverOverlay
import dev.bo3.rollnwrite.qwixx.displayName
import dev.bo3.rollnwrite.qwixx.tint
import kotlin.math.min

/**
 * The pure banded board for one X-Change player - no navigation chrome,
 * mirroring `XChangeBoardView` in
 * `RollnWrite/Games/QwixxXChange/XChangeScorecardView.swift` name-for-name.
 * Fills all available space edge-to-edge with no scrolling; rule enforcement
 * lives entirely in [XChangeViewModel]/the engine - this file only asks
 * `can*`/`isLast*` and renders.
 */
private const val TILE_GAP = 4
private const val ROW_GAP = 4
private const val OUTER_PAD = 4 // gap to the container edge
private const val BAND_PAD = 4 // coloured border inside each band
private const val COLUMNS = 14f // chevron + 11 numbers + lock + score

/** The X-Change row's deep magenta (presentation only). Mirrors `XChangeBoardView.xchangeTint`. */
val xchangeTint = Color(red = 0.55f, green = 0.10f, blue = 0.42f)

@Composable
fun XChangeBoardView(viewModel: XChangeViewModel) {
    var confirmReset by remember { mutableStateOf(false) }
    var confirmFinish by remember { mutableStateOf(false) }
    var confirmConcede by remember { mutableStateOf<GameColor?>(null) }
    var showResults by remember { mutableStateOf(viewModel.isGameOver) }

    LaunchedEffect(viewModel.isGameOver) { showResults = viewModel.isGameOver }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Bottom))
            .padding(OUTER_PAD.dp),
    ) {
        val (w, th) = sizing(availWidthDp = maxWidth.value, availHeightDp = maxHeight.value)
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            val xchangeH = th.dp * 1.15f
            val bottomH = th.dp * 1.05f
            Column(verticalArrangement = Arrangement.spacedBy(ROW_GAP.dp)) {
                ColourBandRow(viewModel, GameColor.RED, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.YELLOW, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.GREEN, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.BLUE, w.dp, th.dp) { confirmConcede = it }
                XChangeBandRow(viewModel, w.dp, xchangeH)
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
                    add(Triple(colourLabel(color), viewModel.points(color), color.tint))
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
            text = { Text(stringResource(R.string.close_colour_message, colourLabel(color))) },
            confirmButton = {
                TextButton(onClick = { viewModel.concedeRow(color); confirmConcede = null }) {
                    Text(stringResource(R.string.close_colour_action, colourLabel(color)))
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmConcede = null }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

/** One full-width colour band, identical structure to `QwixxBoardView`'s `ColourBandRow`. */
@Composable
private fun ColourBandRow(
    viewModel: XChangeViewModel,
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
            contentDescription = stringResource(R.string.lock_content_description, colourLabel(color)),
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
 * The X-Change swap row: nine two-number diamonds, distributed evenly across
 * the full band width like the printed sheet, with a leading direction
 * chevron aligned with the colour bands' chevron column. Mirrors
 * `xchangeBand(w:h:)`. Scores no points - a swap tool.
 */
@Composable
private fun XChangeBandRow(viewModel: XChangeViewModel, w: Dp, h: Dp) {
    val xchange = viewModel.xchange
    val corner = min(w.value, h.value) * 0.3f
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .colourBand(tint = xchangeTint, corner = corner.dp)
            .padding(horizontal = BAND_PAD.dp, vertical = (h.value * 0.07f).dp),
        horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BandChevron(w = w, h = h)
        Row(modifier = Modifier.weight(1f), horizontalArrangement = Arrangement.SpaceEvenly) {
            for (i in 0 until XChangeRow.COUNT) {
                val marked = i in xchange.marks
                val undoable = marked && viewModel.isLastXChangeMark(i)
                val forfeited = !marked && i < xchange.maxMarkedIndex
                XChangeTile(
                    pair = XChangeRow.pair(i),
                    tint = xchangeTint,
                    marked = marked,
                    legal = viewModel.canMarkXChange(i),
                    undoable = undoable,
                    forfeited = forfeited,
                    w = w,
                    h = h,
                    onTap = { if (undoable) viewModel.undo() else viewModel.markXChange(i) },
                )
            }
        }
    }
}

/**
 * A single X-Change diamond: a white diamond with the deep-magenta border,
 * the top number above the swap glyph and the bottom number below, crossed
 * when marked. Mirrors `XChangeTile` in `XChangeScorecardView.swift`.
 */
@Composable
private fun XChangeTile(
    pair: Pair<Int, Int>,
    tint: Color,
    marked: Boolean,
    legal: Boolean,
    undoable: Boolean,
    forfeited: Boolean,
    w: Dp,
    h: Dp,
    onTap: () -> Unit,
) {
    val d = min(w.value, h.value)
    val interactive = legal || undoable
    val stateDescription = when {
        marked -> stringResource(R.string.tile_state_crossed)
        legal -> stringResource(R.string.tile_state_available)
        forfeited -> stringResource(R.string.tile_state_forfeited)
        else -> stringResource(R.string.tile_state_blocked)
    }
    val xchangeDescription = stringResource(R.string.xchange_content_description, pair.first, pair.second)
    Box(
        modifier = Modifier
            .size(w, h)
            .clickable(enabled = interactive, onClick = onTap)
            .semantics {
                contentDescription = "$xchangeDescription $stateDescription"
                if (!interactive) disabled()
            },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.size(w, h)) {
            val cx = size.width / 2f
            val cy = size.height / 2f
            val half = min(size.width, size.height) / 2f
            val path = Path().apply {
                moveTo(cx, cy - half)
                lineTo(cx + half, cy)
                lineTo(cx, cy + half)
                lineTo(cx - half, cy)
                close()
            }
            drawPath(path, color = Color.White.copy(alpha = 0.95f))
            drawPath(path, color = tint.copy(alpha = 0.85f), style = Stroke(width = BoardStroke.small(d).dp.toPx()))
            if (undoable) {
                drawPath(path, color = tint, style = Stroke(width = BoardStroke.medium(d).dp.toPx()))
            }
        }
        val dimmed = !marked && !legal
        val alpha = if (dimmed) 0.4f else 1f
        // The stacked top/arrows/bottom content must fit inside the diamond's
        // narrow vertical extent `d`, so numbers use a TIGHT line height (no
        // platform font-padding leading) — otherwise Android's default text
        // metrics push the bottom number past the diamond's lower point and
        // it gets clipped by the band's rounded-rect mask. Mirrors iOS, where
        // SwiftUI's tighter default text metrics never hit this ceiling.
        val numberStyle = TextStyle(
            fontWeight = FontWeight.Black,
            fontSize = (d * 0.23f).sp,
            lineHeight = (d * 0.23f).sp,
            lineHeightStyle = LineHeightStyle(
                alignment = LineHeightStyle.Alignment.Center,
                trim = LineHeightStyle.Trim.Both,
            ),
            platformStyle = PlatformTextStyle(includeFontPadding = false),
        )
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.size(width = d.dp, height = d.dp),
        ) {
            Text(
                text = "${pair.first}",
                color = tint.copy(alpha = alpha),
                style = numberStyle,
                maxLines = 1,
            )
            Icon(
                imageVector = Icons.Filled.SwapVert,
                contentDescription = null,
                tint = tint.copy(alpha = 0.7f * alpha),
                modifier = Modifier.size((d * 0.16f).dp),
            )
            Text(
                text = "${pair.second}",
                color = tint.copy(alpha = alpha),
                style = numberStyle,
                maxLines = 1,
            )
        }
        if (forfeited && !marked) {
            Canvas(modifier = Modifier.size(w, h)) {
                val inset = size.minDimension * 0.22f
                drawLine(
                    color = tint.copy(alpha = 0.5f),
                    start = Offset(inset, size.height - inset),
                    end = Offset(size.width - inset, inset),
                    strokeWidth = BoardStroke.small(d).dp.toPx(),
                )
            }
        }
        if (marked) {
            Text(
                text = "✕",
                color = tint.copy(alpha = alpha),
                fontWeight = FontWeight.Black,
                fontSize = (d * 0.5f).sp,
            )
        }
    }
}

/** Controls (undo, redo, reset, finish) on the left, penalties + running total on the right. */
@Composable
private fun BottomBar(
    viewModel: XChangeViewModel,
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
        repeat(XChangeState.MAX_PENALTIES) { i ->
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
 * Tile sizing, mirroring the iOS derivation in `XChangeBoardView` (see its
 * `rowUnits` doc comment): width fills the full container width; height
 * fills the container but is capped at the width and floored at a readable
 * MIN. Row height units: 4 colour bands x 1.18 + X-Change band x (1.15 x
 * 1.14) + bottom bar x 1.05 = 7.081 units across 6 rows (5 gaps).
 */
private fun sizing(availWidthDp: Float, availHeightDp: Float): Pair<Float, Float> {
    val bandCount = 4f
    val children = bandCount + 1f + 1f // colour bands + xchange band + bottom bar
    val gaps = maxOf(0f, children - 1f)

    val w = maxOf(14f, (availWidthDp - (COLUMNS - 1) * TILE_GAP - 2 * BAND_PAD) / COLUMNS)

    val units = bandCount * 1.18f + 1.15f * 1.14f + 1.05f
    val fill = (availHeightDp - gaps * ROW_GAP) / units
    val th = maxOf(20f, minOf(fill, w))
    return w to th
}

@Composable
private fun colourLabel(color: GameColor): String = color.displayName()
