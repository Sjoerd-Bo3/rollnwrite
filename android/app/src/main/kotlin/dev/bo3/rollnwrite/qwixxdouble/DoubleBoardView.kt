package dev.bo3.rollnwrite.qwixxdouble

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
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
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
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.engine.qwixxdouble.DoubleColorRow
import dev.bo3.rollnwrite.engine.qwixxdouble.DoubleState
import dev.bo3.rollnwrite.qwixx.QwixxGameOverOverlay
import dev.bo3.rollnwrite.qwixx.displayName
import dev.bo3.rollnwrite.qwixx.tint
import kotlin.math.min

/**
 * The pure banded board for one player — no navigation chrome, mirroring
 * `DoubleBoardView` in `RollnWrite/Games/QwixxDouble/DoubleScorecardView.swift`
 * name-for-name. Fills all available space edge-to-edge with no scrolling;
 * rule enforcement lives entirely in [DoubleViewModel]/the engine — this file
 * only asks `can*`/`isLast*` and renders.
 *
 * Each colour band is a full-width coloured band of number tiles (the
 * canonical Qwixx look), with a thin "second cross" strip directly beneath,
 * mirroring the printed sheet where the second cross is drawn below the
 * number. Only the most-recently-crossed space's second-cross cell is
 * tappable.
 */
private const val TILE_GAP = 4
private const val ROW_GAP = 4
private const val OUTER_PAD = 4 // gap to the container edge
private const val BAND_PAD = 4 // coloured border inside each band
private const val COLUMNS = 14f // chevron + 11 numbers + lock + score

@Composable
fun DoubleBoardView(viewModel: DoubleViewModel) {
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
            // 12pt legibility floor; inert while th >= minTile (22 * 0.55 >= 12), so
            // the sizing derivation stays exact — mirrors the iOS `stripH`.
            val stripH = maxOf(12f, th * 0.55f)
            val bottomH = th * 1.05f
            Column(verticalArrangement = Arrangement.spacedBy(ROW_GAP.dp)) {
                ColourBandRow(viewModel, GameColor.RED, w.dp, th.dp, stripH.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.YELLOW, w.dp, th.dp, stripH.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.GREEN, w.dp, th.dp, stripH.dp) { confirmConcede = it }
                ColourBandRow(viewModel, GameColor.BLUE, w.dp, th.dp, stripH.dp) { confirmConcede = it }
                BottomBar(
                    viewModel = viewModel,
                    w = w.dp,
                    h = bottomH.dp,
                    onRequestReset = { confirmReset = true },
                    onRequestFinish = { confirmFinish = true },
                )
            }
        }

        if (showResults) {
            val lines = buildList {
                GameColor.entries.forEach { color ->
                    add(Triple(colourLabelText(color), viewModel.points(color), color.tint))
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
            text = { Text(stringResource(R.string.close_colour_message, colourLabelText(color))) },
            confirmButton = {
                TextButton(onClick = { viewModel.concedeRow(color); confirmConcede = null }) {
                    Text(stringResource(R.string.close_colour_action, colourLabelText(color)))
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
 * the lock, and that colour's running score, PLUS the second-cross strip
 * drawn directly beneath. Mirrors `band(_:w:tile:strip:)`.
 */
@Composable
private fun ColourBandRow(
    viewModel: DoubleViewModel,
    color: GameColor,
    w: Dp,
    th: Dp,
    stripH: Dp,
    onRequestConcede: (GameColor) -> Unit,
) {
    val row = viewModel.row(color)
    val corner = min(w.value, th.value) * 0.3f
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .colourBand(tint = color.tint, corner = corner.dp)
            .padding(vertical = (th.value * 0.09f).dp),
        verticalArrangement = Arrangement.spacedBy((ROW_GAP / 2).dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = BAND_PAD.dp),
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
                contentDescription = stringResource(R.string.lock_content_description, colourLabelText(color)),
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
        // Second-cross strip: a thinner cell under each number. Only the
        // most-recent space is tappable; already-doubled spaces show a mark.
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = BAND_PAD.dp),
            horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Spacer(modifier = Modifier.width(w).height(stripH)) // chevron column
            color.numbers.indices.forEach { i ->
                SecondCrossCell(viewModel, color, index = i, row = row, w = w, h = stripH)
            }
            Spacer(modifier = Modifier.width(w * 2 + TILE_GAP.dp).height(stripH)) // lock + score columns
        }
    }
}

/**
 * The "draw a second cross below" cell for one column. Marked when the
 * number was crossed twice; tappable only on the most-recent space. Tapping
 * the single most-recent double un-checks it (LIFO undo). Mirrors
 * `secondCrossCell(_:index:row:w:h:)`.
 */
@Composable
private fun SecondCrossCell(
    viewModel: DoubleViewModel,
    color: GameColor,
    index: Int,
    row: DoubleColorRow,
    w: Dp,
    h: Dp,
) {
    val isDoubled = index in row.doubles
    val isLegal = viewModel.canDoubleColor(color, index)
    val undoable = isDoubled && viewModel.isLastDoubleMark(color, index)
    val active = isDoubled || isLegal
    val s = min(w.value, h.value)
    val baseDescription = stringResource(
        R.string.double_second_cross_content_description,
        colourLabelText(color),
        "${color.numbers[index]}",
    )
    val stateLabel = when {
        isDoubled -> stringResource(R.string.tile_state_crossed)
        isLegal -> stringResource(R.string.tile_state_available)
        else -> stringResource(R.string.tile_state_blocked)
    }
    // Idle slots keep most of their opacity so the dashed outline stays
    // clearly visible — the band's extra height must read as slots, not
    // padding. Mirrors the iOS `.opacity(active ? 1 : 0.8)`.
    val cellAlpha = if (active) 1f else 0.8f
    Box(
        modifier = Modifier
            .size(w, h)
            .alpha(cellAlpha)
            .clip(RoundedCornerShape((s * 0.18f).dp))
            // A doubled cell is the SAME near-opaque white as a crossed
            // number tile (uniform crossed whiteness across the board).
            .background(Color.White.copy(alpha = if (isDoubled) 0.95f else (if (active) 0.85f else 0f)))
            .then(
                if (undoable) {
                    Modifier.border(
                        width = BoardStroke.medium(s).dp,
                        color = color.tint,
                        shape = RoundedCornerShape((s * 0.18f).dp),
                    )
                } else Modifier,
            )
            .clickable(enabled = isDoubled || isLegal) {
                if (undoable) viewModel.undo() else if (isLegal) viewModel.doubleColor(color, index)
            }
            .semantics {
                contentDescription = "$baseDescription $stateLabel"
                if (!(isDoubled || isLegal)) disabled()
            },
        contentAlignment = Alignment.Center,
    ) {
        // Empty slots must clearly read as slots on every band colour (band
        // tints are identical in light and dark mode, so one white works for
        // both) — mirrors the iOS dashed-stroke outline for idle slots.
        if (!isDoubled) {
            Canvas(modifier = Modifier.size(w, h)) {
                drawRoundRect(
                    color = Color.White.copy(alpha = if (active) 0.7f else 0.45f),
                    cornerRadius = CornerRadius(s * 0.18f),
                    style = Stroke(
                        width = BoardStroke.small(s).dp.toPx(),
                        pathEffect = if (undoable) null else {
                            PathEffect.dashPathEffect(floatArrayOf(s * 0.16f, s * 0.12f))
                        },
                    ),
                )
            }
        }
        if (isDoubled) {
            Text(
                text = "✕",
                color = color.tint,
                fontWeight = FontWeight.Black,
                fontSize = (s * 0.7f).sp,
            )
        } else if (isLegal) {
            Text(
                text = "+1×",
                color = Color.White,
                fontWeight = FontWeight.Black,
                fontSize = (s * 0.42f).sp,
                maxLines = 1,
            )
        }
    }
}

/**
 * Controls (undo, redo, reset, finish) on the left, penalties + running total
 * on the right. Mirrors `bottomBar(w:h:)`.
 */
@Composable
private fun BottomBar(
    viewModel: DoubleViewModel,
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
        repeat(DoubleState.MAX_PENALTIES) { i ->
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
 * Tile sizing, mirroring the iOS `BoardMetrics.tile(...)` call in
 * `DoubleBoardView.body`: width fills the full container width; height fills
 * the container but is capped at the width (square is the MAX) and floored
 * at a readable MIN.
 *
 * Row units: 4 colour bands, each `1 + 0.55 + 2*0.09` (number row + strip +
 * band vertical padding) plus the bottom bar's `1.05`, i.e.
 * `4 * 1.73 + 1.05 = 7.97` — matching the iOS `rowUnits` derivation exactly.
 * `rowCount` fixed gaps: 4 stack gaps between the 5 VStack/Column children.
 */
private fun sizing(availWidthDp: Float, availHeightDp: Float): Pair<Float, Float> {
    val bandCount = 4f
    val children = bandCount + 1f // colour bands + bottom bar
    val gaps = maxOf(0f, children - 1f)

    val w = maxOf(14f, (availWidthDp - (COLUMNS - 1) * TILE_GAP - 2 * BAND_PAD) / COLUMNS)

    val units = bandCount * (1f + 0.55f + 2 * 0.09f) + 1.05f
    val fill = (availHeightDp - gaps * ROW_GAP) / units
    val th = maxOf(22f, minOf(fill, w))
    return w to th
}

@Composable
private fun colourLabelText(color: GameColor): String = color.displayName()
