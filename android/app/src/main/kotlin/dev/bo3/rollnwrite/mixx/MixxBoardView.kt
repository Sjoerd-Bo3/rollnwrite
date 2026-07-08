package dev.bo3.rollnwrite.mixx

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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.bo3.rollnwrite.R
import dev.bo3.rollnwrite.core.BandChevron
import dev.bo3.rollnwrite.core.BoardControlButton
import dev.bo3.rollnwrite.core.LockTile
import dev.bo3.rollnwrite.core.NumberTile
import dev.bo3.rollnwrite.core.PenaltyBox
import dev.bo3.rollnwrite.core.ScoreTile
import dev.bo3.rollnwrite.core.segmentedColourBand
import dev.bo3.rollnwrite.engine.mixx.MixxState
import dev.bo3.rollnwrite.qwixx.displayName
import dev.bo3.rollnwrite.qwixx.QwixxGameOverOverlay
import dev.bo3.rollnwrite.qwixx.tint
import kotlin.math.min

/**
 * The pure banded board for the currently selected Mixx board (Variant A or
 * B) - no navigation chrome, mirroring `MixxBoardView` in
 * `RollnWrite/Games/QwixxMixx/MixxScorecardView.swift` name-for-name. Every
 * `NumberTile` is tinted per-cell (Variant A's colour segments, or Variant
 * B's uniform row colour) and the band background is segmented to match -
 * this is the one structural difference from `QwixxBoardView`, whose bands
 * are a single flat colour.
 */
private const val TILE_GAP = 4
private const val ROW_GAP = 4
private const val OUTER_PAD = 4 // gap to the container edge
private const val BAND_PAD = 4 // coloured border inside each band
private const val COLUMNS = 14f // chevron + 11 numbers + lock + score

@Composable
fun MixxBoardView(viewModel: MixxViewModel, scoreTitle: String) {
    var confirmReset by remember { mutableStateOf(false) }
    var confirmFinish by remember { mutableStateOf(false) }
    var confirmConcede by remember { mutableStateOf<Int?>(null) }
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
            val bottomH = th.dp * 1.05f
            Column(verticalArrangement = Arrangement.spacedBy(ROW_GAP.dp)) {
                for (rowIndex in 0 until 4) {
                    MixxRowBand(viewModel, rowIndex, w.dp, th.dp) { confirmConcede = it }
                }
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
                for (rowIndex in 0 until 4) {
                    val lock = viewModel.rowLayout(rowIndex).lockColor
                    add(Triple(lock.displayName(), viewModel.points(rowIndex), lock.tint))
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
            text = { Text(stringResource(R.string.mixx_start_new_game_message)) },
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

    confirmConcede?.let { rowIndex ->
        val name = viewModel.rowLayout(rowIndex).lockColor.displayName()
        AlertDialog(
            onDismissRequest = { confirmConcede = null },
            title = { Text(stringResource(R.string.close_colour_question)) },
            text = { Text(stringResource(R.string.close_colour_message, name)) },
            confirmButton = {
                TextButton(onClick = { viewModel.concedeRow(rowIndex); confirmConcede = null }) {
                    Text(stringResource(R.string.close_colour_action, name))
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmConcede = null }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

/**
 * One full-width Mixx row: a direction chevron, the eleven per-cell-tinted
 * number tiles, the lock (row's lock colour) and the running score. Mirrors
 * `band(_:w:tile:)` in `MixxScorecardView.swift`. The band background is
 * SEGMENTED per-cell colour (Variant A) rather than one flat tint (Variant
 * B's cells all share the row colour, so segmentation is a visual no-op
 * there) - this is the one board-specific rendering difference from
 * `ColourBandRow` in the base Qwixx board.
 */
@Composable
private fun MixxRowBand(
    viewModel: MixxViewModel,
    rowIndex: Int,
    w: Dp,
    th: Dp,
    onRequestConcede: (Int) -> Unit,
) {
    val layout = viewModel.rowLayout(rowIndex)
    val row = viewModel.rowState(rowIndex)
    val lock = layout.lockColor
    val corner = min(w.value, th.value) * 0.3f
    // One "band" colour per column, in order: chevron * 11 numbers * lock * score.
    // Segmented per-cell colour (Variant A's colour segments show on the bar
    // itself, matching iOS's `segmentedColourBand`; Variant B's cells all share
    // the row colour, so this renders as a flat band there, same as before).
    val segments = remember(layout, lock) {
        listOf(lock.tint) + layout.cells.map { it.color.tint } + listOf(lock.tint, lock.tint)
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .segmentedColourBand(columns = segments, columnWidth = w, gap = TILE_GAP.dp, hPad = BAND_PAD.dp, corner = corner.dp)
            .padding(horizontal = BAND_PAD.dp, vertical = (th.value * 0.09f).dp),
        horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BandChevron(w = w, h = th)
        layout.cells.forEachIndexed { i, cell ->
            val marked = i in row.marks
            val undoable = marked && viewModel.isLastMark(rowIndex, i)
            val forfeited = !marked && (i < row.maxMarkedIndex || row.locked)
            NumberTile(
                text = "${cell.number}",
                tint = cell.color.tint,
                marked = marked,
                legal = viewModel.canMark(rowIndex, i),
                undoable = undoable,
                forfeited = forfeited,
                w = w,
                h = th,
                onTap = { if (undoable) viewModel.undo() else viewModel.mark(rowIndex, i) },
            )
        }
        val lockUndoable = row.locked && viewModel.isLastConcede(rowIndex)
        LockTile(
            tint = lock.tint,
            locked = row.locked,
            undoable = lockUndoable,
            w = w,
            h = th,
            contentDescription = stringResource(R.string.lock_content_description, lock.displayName()),
            onTap = {
                if (viewModel.isLastConcede(rowIndex)) {
                    viewModel.undo()
                } else if (viewModel.canConcedeRow(rowIndex)) {
                    onRequestConcede(rowIndex)
                }
            },
        )
        ScoreTile(viewModel.points(rowIndex), w = w, h = th)
    }
}

/** Controls (undo, redo, reset, finish) on the left, penalties + running total on the right. */
@Composable
private fun BottomBar(
    viewModel: MixxViewModel,
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
        // Flexible spacer (mirrors iOS's `Spacer(minLength: w * 0.1)`): grows to
        // push the penalty boxes + Total to the trailing edge, never shrinking
        // below the minimum.
        Spacer(modifier = Modifier.weight(1f).widthIn(min = w * 0.1f))
        repeat(MixxState.MAX_PENALTIES) { i ->
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
 * Tile sizing, mirroring the iOS `sizing(for:)` / `QwixxBoardView`'s
 * `sizing(...)`: width fills the full container width; height fills the
 * container but is capped at the width (square is the MAX) and floored at a
 * readable MIN. Mixx has no bonus rows, so the row-count math is simpler
 * than the base Qwixx board's (4 colour bands + bottom bar only).
 */
private fun sizing(availWidthDp: Float, availHeightDp: Float): Pair<Float, Float> {
    val bandCount = 4f
    val children = bandCount + 1f // colour bands + bottom bar
    val gaps = maxOf(0f, children - 1f)

    val w = maxOf(14f, (availWidthDp - (COLUMNS - 1) * TILE_GAP - 2 * BAND_PAD) / COLUMNS)

    // Row height units: colour band = 1.18*th (matches QwixxBoardView), bottom bar = 1.05*th.
    val units = bandCount * 1.18f + 1.05f
    val fill = (availHeightDp - gaps * ROW_GAP) / units
    val th = maxOf(20f, minOf(fill, w))
    return w to th
}
