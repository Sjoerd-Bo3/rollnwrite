package dev.bo3.rollnwrite.qwixx

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.bo3.rollnwrite.R
import dev.bo3.rollnwrite.core.BandChevron
import dev.bo3.rollnwrite.core.BoardControlButton
import dev.bo3.rollnwrite.core.BonusTile
import dev.bo3.rollnwrite.core.LockTile
import dev.bo3.rollnwrite.core.NumberTile
import dev.bo3.rollnwrite.core.PenaltyBox
import dev.bo3.rollnwrite.core.ScoreTile
import dev.bo3.rollnwrite.core.colourBand
import dev.bo3.rollnwrite.engine.qwixx.BonusRowId
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.engine.qwixx.QwixxState
import kotlin.math.min

/**
 * The pure banded board for one player — no navigation chrome, mirroring
 * `QwixxBoardView` in `RollnWrite/Games/Qwixx/QwixxScorecardView.swift`
 * name-for-name. Fills all available space edge-to-edge with no scrolling;
 * rule enforcement lives entirely in [QwixxViewModel]/the engine — this file
 * only asks `can*`/`isLast*` and renders.
 */
private const val TILE_GAP = 4
private const val ROW_GAP = 4
private const val OUTER_PAD = 4 // gap to the container edge
private const val BAND_PAD = 4 // coloured border inside each band
private const val COLUMNS = 14f // chevron + 11 numbers + lock + score

@Composable
fun QwixxBoardView(viewModel: QwixxViewModel) {
    var confirmReset by remember { mutableStateOf(false) }
    var confirmFinish by remember { mutableStateOf(false) }
    var confirmConcede by remember { mutableStateOf<GameColor?>(null) }
    var showResults by remember { mutableStateOf(viewModel.isGameOver) }

    // Mirrors the iOS `.onChange(of: game.isGameOver)`: show the overlay the
    // moment the engine reports game-over, hide it when a new game starts.
    LaunchedEffect(viewModel.isGameOver) { showResults = viewModel.isGameOver }

    // The window paints edge-to-edge behind this board, but its interactive
    // controls (bottom bar, trailing score tiles) must stay clear of the
    // gesture/nav bar and display cutout in the pinned landscape orientation
    // - mirrors iOS keeping the bottom bar inside the bottom safe area.
    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Bottom))
            .padding(OUTER_PAD.dp),
    ) {
        val (w, th) = sizing(
            availWidthDp = maxWidth.value,
            availHeightDp = maxHeight.value,
            hasBonusRows = viewModel.hasBonusRows,
        )
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            val bonusH = th.dp * 0.82f
            val bottomH = th.dp * 1.05f
            Column(verticalArrangement = Arrangement.spacedBy(ROW_GAP.dp)) {
                ColourBandRow(viewModel, GameColor.RED, w.dp, th.dp) { confirmConcede = it }
                if (viewModel.hasBonusRows) BonusBandRow(viewModel, BonusRowId.REDYELLOW, w.dp, bonusH)
                ColourBandRow(viewModel, GameColor.YELLOW, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.GREEN, w.dp, th.dp) { confirmConcede = it }
                if (viewModel.hasBonusRows) BonusBandRow(viewModel, BonusRowId.GREENBLUE, w.dp, bonusH)
                ColourBandRow(viewModel, GameColor.BLUE, w.dp, th.dp) { confirmConcede = it }
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

/**
 * One full-width colour band: a direction chevron, the eleven number tiles,
 * the lock, and that colour's running score. Mirrors `band(_:w:tile:)`.
 */
@Composable
private fun ColourBandRow(
    viewModel: QwixxViewModel,
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
 * Big-Points bonus row: the two-colour spaces, aligned under the number
 * tiles (offset past the chevron column). Mirrors `bonusBand(_:w:h:vPad:)` —
 * `vPad` is the same 0.09·th the colour bands use (expressed relative to the
 * bonus row's own height `h = 0.82·th`), keeping one vertical rhythm.
 */
@Composable
private fun BonusBandRow(viewModel: QwixxViewModel, id: BonusRowId, w: Dp, h: Dp) {
    val bonus = viewModel.bonus(id)
    val (a, b) = id.colors
    val vPad = (h.value / 0.82f) * 0.09f
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = BAND_PAD.dp, vertical = vPad.dp),
        horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Spacer(modifier = Modifier.width(w)) // chevron column
        val aRow = viewModel.row(a)
        val bRow = viewModel.row(b)
        bonus.numbers.forEachIndexed { i, number ->
            val marked = i in bonus.marks
            val undoable = marked && viewModel.isLastBonusMark(id, i)
            BonusTile(
                text = "$number",
                tintA = a.tint,
                tintB = b.tint,
                marked = marked,
                legal = viewModel.canMarkBonus(id, i),
                aActive = i in aRow.marks,
                bActive = i in bRow.marks,
                undoable = undoable,
                w = w,
                h = h,
                onTap = { if (undoable) viewModel.undo() else viewModel.markBonus(id, i) },
            )
        }
        Spacer(modifier = Modifier.width(w * 2 + TILE_GAP.dp)) // lock + score columns
    }
}

/**
 * Controls (undo, redo, reset, finish) on the left, penalties + running total
 * on the right. Mirrors `bottomBar(w:h:)`.
 */
@Composable
private fun BottomBar(
    viewModel: QwixxViewModel,
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
        // below the minimum. `widthIn(min=)` alone doesn't grow — it only sets a
        // floor — so the bar stayed packed to the leading edge without `weight`.
        Spacer(modifier = Modifier.weight(1f).widthIn(min = w * 0.1f))
        repeat(QwixxState.MAX_PENALTIES) { i ->
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
 * Tile sizing, mirroring the iOS `sizing(for:)`: width fills the full
 * container width; height fills the container but is capped at the width
 * (square is the MAX — never tall-skinny) and floored at a readable MIN.
 *
 * `availWidthDp`/`availHeightDp` are the `BoxWithConstraints` measurements,
 * which are already reduced by the caller's `.padding(OUTER_PAD.dp)` — do
 * NOT subtract `OUTER_PAD` again here (that double-counts the outer padding,
 * shrinking every tile and leaving dead slack at the band's trailing edge).
 * Mirrors iOS: `GeometryReader` measures the full size and `boardStack`
 * applies `outerPad` inside, so only one subtraction ever happens.
 */
private fun sizing(availWidthDp: Float, availHeightDp: Float, hasBonusRows: Boolean): Pair<Float, Float> {
    val bonusRows = if (hasBonusRows) 2f else 0f
    val bandCount = 4f
    val children = bandCount + bonusRows + 1f // colour bands + bonus rows + bottom bar
    val gaps = maxOf(0f, children - 1f)

    val w = maxOf(14f, (availWidthDp - (COLUMNS - 1) * TILE_GAP - 2 * BAND_PAD) / COLUMNS)

    // Row height units, matching the iOS derivation:
    //   colour band = 1.18·th, bonus row = 1.00·th, bottom bar = 1.05·th.
    val units = bandCount * 1.18f + bonusRows * 1.00f + 1.05f
    val fill = (availHeightDp - gaps * ROW_GAP) / units
    val th = maxOf(20f, minOf(fill, w))
    return w to th
}

@Composable
private fun colourLabel(color: GameColor): String = color.displayName()
