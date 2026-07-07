package dev.bo3.rollnwrite.bonus

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
import dev.bo3.rollnwrite.engine.bonus.BonusLayout
import dev.bo3.rollnwrite.engine.bonus.BonusState
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.qwixx.QwixxGameOverOverlay
import dev.bo3.rollnwrite.qwixx.displayName
import dev.bo3.rollnwrite.qwixx.tint
import kotlin.math.min

/**
 * The pure banded board for one player — no navigation chrome, mirroring
 * `BonusBoardView` in `RollnWrite/Games/QwixxBonus/BonusScorecardView.swift`
 * name-for-name. Fills all available space edge-to-edge with no scrolling;
 * rule enforcement lives entirely in [BonusViewModel]/the engine — this file
 * only asks `can*`/`isLast*` and renders.
 *
 * Variant twist preserved from iOS: the twelve black-boxed cells wear a heavy
 * outline; the bonus bar (one row below the four colour bands) is rendered
 * read-only — the engine advances it automatically, so this view never marks
 * it directly (no `markBonus`-equivalent tap target exists).
 */
private const val TILE_GAP = 4
private const val ROW_GAP = 4
private const val OUTER_PAD = 4 // gap to the container edge
private const val BAND_PAD = 4 // coloured border inside each band
private const val COLUMNS = 14f // chevron + 11 numbers + lock + score

@Composable
fun BonusBoardView(viewModel: BonusViewModel) {
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
            val barH = th.dp * 0.82f
            val bottomH = th.dp * 1.05f
            Column(verticalArrangement = Arrangement.spacedBy(ROW_GAP.dp)) {
                ColourBandRow(viewModel, GameColor.RED, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.YELLOW, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.GREEN, w.dp, th.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.BLUE, w.dp, th.dp) { confirmConcede = it }
                BonusBarRow(viewModel, w.dp, barH)
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
 * (boxed cells wear a heavy outline, matching the printed sheet), the lock,
 * and that colour's running score. Mirrors `band(_:w:tile:)`.
 */
@Composable
private fun ColourBandRow(
    viewModel: BonusViewModel,
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
                // Boxed bonus numbers wear a heavy black outline, matching the
                // printed sheet. Decorative only — never blocks taps (the
                // NumberTile above already owns the clickable modifier).
                if (viewModel.isBoxed(color, i)) {
                    val s = min(w.value, th.value)
                    Canvas(modifier = Modifier.width(w).height(th)) {
                        drawRoundRect(
                            color = Color.Black,
                            style = Stroke(width = BoardStroke.small(s).dp.toPx()),
                            cornerRadius = CornerRadius((s * 0.18f).dp.toPx()),
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
 * The snaking bonus bar: twelve coloured fields, earned left-to-right as
 * boxed numbers are hit — skipping any field forfeited because its colour
 * row was completed. Aligned under the number tiles (offset past the
 * chevron column), mirroring `bonusBar(w:h:)`. Read-only: the engine
 * advances it automatically, so fields carry no tap handler.
 */
@Composable
private fun BonusBarRow(viewModel: BonusViewModel, w: Dp, h: Dp) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = BAND_PAD.dp),
        horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Spacer(modifier = Modifier.width(w)) // chevron column
        BonusLayout.barColors.forEachIndexed { idx, color ->
            BarField(idx = idx, color = color, viewModel = viewModel, w = w, h = h)
        }
        // Remaining columns: pad out to the full 11-number + lock + score grid.
        val used = BonusLayout.barCount
        val remainingUnits = (COLUMNS - 1) - used // minus the chevron column
        if (remainingUnits > 0) {
            Spacer(modifier = Modifier.width(w * remainingUnits + TILE_GAP.dp * (remainingUnits - 1)))
        }
    }
}

@Composable
private fun BarField(idx: Int, color: GameColor, viewModel: BonusViewModel, w: Dp, h: Dp) {
    val s = min(w.value, h.value)
    val isEarned = idx in viewModel.bar.earned
    val isForfeited = idx in viewModel.bar.forfeited
    val stateDescription = when {
        isEarned -> stringResource(R.string.bonus_bar_field_state_earned)
        isForfeited -> stringResource(R.string.bonus_bar_field_state_forfeited)
        else -> stringResource(R.string.bonus_bar_field_state_open)
    }
    val contentDescription = stringResource(R.string.bonus_bar_field_content_description, color.displayName())
    Box(
        modifier = Modifier
            .width(w)
            .height(h)
            .clip(RoundedCornerShape((s * 0.18f).dp))
            .background(Color.White.copy(alpha = 0.9f))
            .background(color.tint.copy(alpha = if (isEarned) 1f else 0.3f))
            .semantics {
                this.contentDescription = "$contentDescription: $stateDescription"
            },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            drawRoundRect(
                color = if (isEarned) Color.Black.copy(alpha = 0.25f) else color.tint.copy(alpha = 0.9f),
                style = Stroke(width = BoardStroke.small(s).dp.toPx()),
                cornerRadius = CornerRadius((s * 0.18f).dp.toPx()),
            )
        }
        when {
            isEarned -> Text(
                "✕",
                color = color.textColorForBar(),
                fontWeight = FontWeight.Black,
                fontSize = (s * 0.6f).sp,
            )
            isForfeited -> Text(
                "/",
                color = color.tint,
                fontWeight = FontWeight.Normal,
                fontSize = (s * 0.7f).sp,
            )
        }
    }
}

/** Legible glyph colour over an earned field's solid tint (mirrors `GameColor.textColor`). */
private fun GameColor.textColorForBar(): Color = if (this == GameColor.YELLOW) Color.Black else Color.White

/**
 * Controls (undo, redo, reset, finish) on the left, penalties + running total
 * on the right. Mirrors `bottomBar(w:h:)`.
 */
@Composable
private fun BottomBar(
    viewModel: BonusViewModel,
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
        repeat(BonusState.MAX_PENALTIES) { i ->
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
 * Tile sizing, mirroring `BonusBoardView.init`'s `BoardMetrics.tile(...)`
 * call: 4 colour bands (1.18 units each) + 1 bonus bar (0.82 units) + bottom
 * bar (1.05 units) — width fills the full container width; height fills the
 * container but is capped at the width (square is the MAX) and floored at a
 * readable MIN.
 *
 * `availWidthDp`/`availHeightDp` are the `BoxWithConstraints` measurements,
 * already reduced by the caller's `.padding(OUTER_PAD.dp)` — do NOT subtract
 * `OUTER_PAD` again here (mirrors `QwixxBoardView.sizing`'s same caveat).
 */
private fun sizing(availWidthDp: Float, availHeightDp: Float): Pair<Float, Float> {
    val bandCount = 4f
    val children = bandCount + 1f + 1f // colour bands + bonus bar + bottom bar
    val gaps = maxOf(0f, children - 1f)

    val w = maxOf(14f, (availWidthDp - (COLUMNS - 1) * TILE_GAP - 2 * BAND_PAD) / COLUMNS)

    // Row height units: colour band = 1.18·th, bonus bar = 0.82·th, bottom bar = 1.05·th.
    val units = bandCount * 1.18f + 0.82f + 1.05f
    val fill = (availHeightDp - gaps * ROW_GAP) / units
    val th = maxOf(20f, minOf(fill, w))
    return w to th
}
