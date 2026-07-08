package dev.bo3.rollnwrite.connect15

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
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Redo
import androidx.compose.material.icons.automirrored.filled.Undo
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Link
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
import androidx.compose.ui.draw.clip
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
import dev.bo3.rollnwrite.engine.connect15.Connect15Layout
import dev.bo3.rollnwrite.engine.connect15.Connect15State
import dev.bo3.rollnwrite.engine.qwixx.GameColor
import dev.bo3.rollnwrite.qwixx.QwixxGameOverOverlay
import dev.bo3.rollnwrite.qwixx.displayName
import dev.bo3.rollnwrite.qwixx.tint
import kotlin.math.min

/**
 * The pure banded board for one Connect15 player — no navigation chrome,
 * mirroring `Connect15BoardView` in
 * `RollnWrite/Games/QwixxConnect15/Connect15ScorecardView.swift`. Fills all
 * available space edge-to-edge with no scrolling; rule enforcement lives
 * entirely in [Connect15ViewModel]/the engine — this file only asks
 * `can*`/`isLast*` and renders.
 *
 * Four classic colour bands, each with three connection-field squares
 * OVERLAID on the gaps between the number tiles at the positions printed on
 * the official sheet ([Connect15Layout]) — exactly like iOS's
 * `numberStrip(_:w:th:)` overlay — plus the bottom bar. Row units match the
 * iOS `rowUnits = 4 + 0.95` / `rowCount = 5` derivation.
 */
private const val TILE_GAP = 4
private const val ROW_GAP = 4
private const val OUTER_PAD = 4 // gap to the container edge
private const val BAND_PAD = 4 // coloured border inside each band
private const val COLUMNS = 14f // chevron + 11 numbers + lock + score

@Composable
fun Connect15BoardView(viewModel: Connect15ViewModel) {
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
            val bottomH = th.dp * 1.05f
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
        }

        if (showResults) {
            val lines = buildList {
                GameColor.entries.forEach { color ->
                    add(Triple(color.displayName(), viewModel.points(color), color.tint))
                }
                if (viewModel.penaltyPoints > 0) {
                    add(Triple(stringResource(R.string.penalties), -viewModel.penaltyPoints, androidx.compose.ui.graphics.Color(0xFFDC2626)))
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
 * (with the row's three connection-field squares overlaid on the gaps at
 * their printed positions), the lock, and that colour's running score.
 * Mirrors iOS `band(_:w:tile:)` + `numberStrip(_:w:th:)`.
 */
@Composable
private fun ColourBandRow(
    viewModel: Connect15ViewModel,
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
        NumberStrip(viewModel, color, w, th)
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
 * The eleven number tiles with the row's three connection squares overlaid
 * on the gaps at their printed positions. Within the strip, the gap after
 * number column `i` is centred at `i*(w+gap) + w + gap/2`. The square is
 * kept small (0.42x min) and nudged toward the band's LOWER edge so the
 * two-digit numbers keep a clear zone — mirrors iOS `numberStrip`.
 */
@Composable
private fun NumberStrip(viewModel: Connect15ViewModel, color: GameColor, w: Dp, th: Dp) {
    val columns = Connect15Layout.columns(color)
    val s = (min(w.value, th.value) * 0.42f).dp
    // Push the square down so its bottom edge sits just above the tile's:
    // centre offset from the strip's vertical centre.
    val yOff = (th - s) / 2 + th * 0.06f

    Box {
        Row(horizontalArrangement = Arrangement.spacedBy(TILE_GAP.dp)) {
            for (i in 0 until 11) {
                NumberTileCell(viewModel, color, i, w, th)
            }
        }
        columns.forEachIndexed { field, column ->
            val gapCenter = column * (w.value + TILE_GAP) + w.value + TILE_GAP / 2f
            ConnectionTile(
                viewModel = viewModel,
                color = color,
                field = field,
                size = s,
                modifier = Modifier.offset(x = (gapCenter).dp - s / 2, y = yOff),
            )
        }
    }
}

@Composable
private fun NumberTileCell(viewModel: Connect15ViewModel, color: GameColor, i: Int, w: Dp, th: Dp) {
    val row = viewModel.row(color)
    val marked = i in row.marks
    val undoable = marked && viewModel.isLastColorMark(color, i)
    // Skipped-forever: this number's interleaved position is left of the
    // row's front (numbers + connection fields), or the row is locked.
    val forfeited = !marked &&
        (Connect15Layout.numberPosition(i) < viewModel.maxMarkedPosition(color) || row.locked)
    NumberTile(
        text = "${color.numbers[i]}",
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

/**
 * One Connect15 "connection" square: a small dashed-edged light square that
 * straddles the boundary between two number tiles, carrying a link glyph
 * (uncrossed) or an X (crossed) — matching the printed sheet. Mirrors iOS
 * `ConnectionTile`.
 */
@Composable
private fun ConnectionTile(
    viewModel: Connect15ViewModel,
    color: GameColor,
    field: Int,
    size: Dp,
    modifier: Modifier = Modifier,
) {
    val marked = field in viewModel.connections(color).marks
    val legal = viewModel.canMarkConnection(color, field)
    val undoable = marked && viewModel.isLastConnectionMark(color, field)
    val interactive = legal || undoable
    val dimmed = !marked && !legal
    val s = size.value
    val tint = color.tint
    val description = stringResource(R.string.connect15_connection_content_description, color.displayName(), field + 1)

    Box(
        modifier = modifier
            .size(size)
            .clip(RoundedCornerShape((s * 0.18f).dp))
            .background(androidx.compose.ui.graphics.Color.White.copy(alpha = if (marked || legal) 0.95f else 0.95f * 0.35f))
            .border(
                width = BoardStroke.small(s).dp,
                color = tint.copy(alpha = if (dimmed) 0.35f else 1f),
                shape = RoundedCornerShape((s * 0.18f).dp),
            )
            .then(
                if (undoable) {
                    Modifier.border(
                        width = BoardStroke.medium(s).dp,
                        color = tint,
                        shape = RoundedCornerShape((s * 0.18f).dp),
                    )
                } else Modifier
            )
            .clickable(enabled = interactive) {
                if (undoable) viewModel.undo() else if (legal) viewModel.markConnection(color, field)
            }
            .semantics {
                contentDescription = description
                if (!interactive) disabled()
            },
        contentAlignment = Alignment.Center,
    ) {
        val alpha = if (dimmed) 0.35f else 1f
        if (marked) {
            Text(
                text = "✕",
                color = tint.copy(alpha = alpha),
                fontWeight = FontWeight.Black,
                fontSize = (s * 0.5f).sp,
            )
        } else {
            Icon(
                imageVector = Icons.Filled.Link,
                contentDescription = null,
                tint = tint.copy(alpha = alpha),
                modifier = Modifier.size((s * 0.46f).dp),
            )
        }
    }
}

/**
 * Controls (undo, redo, reset, finish) on the left, penalties + running total
 * on the right. Identical to `Lucky15BoardView.BottomBar` (no fifth-band
 * offset, since Connect15 folds its bonus mechanic into the colour bands).
 */
@Composable
private fun BottomBar(
    viewModel: Connect15ViewModel,
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
        repeat(Connect15State.MAX_PENALTIES) { i ->
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
 * Tile sizing, mirroring the iOS derivation: width fills the full container
 * width; height fills the container but is capped at the width (square is
 * the MAX) and floored at a readable MIN.
 *
 * iOS expresses this via the shared `BoardMetrics.tile(rowUnits: 4 + 0.95,
 * rowCount: 5)` helper, whose convention counts a plain colour band as
 * weight 1.0 because SwiftUI's `.colourBand` padding there doesn't inflate
 * the row past the `GeometryReader`-fitted frame. This Android `sizing()`
 * (like every other Compose board's — `QwixxBoardView`, `Lucky15BoardView`,
 * `ConnectedBoardView`, `XChangeBoardView`, `MixxBoardView`) instead sizes
 * each `Column` child directly from these units, and a colour band's actual
 * on-screen height is `th + 2*(th*0.09) = 1.18*th` (see `ColourBandRow`'s
 * `vertical = th*0.09` padding) — so it must use the Android-idiom
 * `bandCount * 1.18f`, not the raw Swift `bandCount * 1.0f`, or the solved
 * `th` comes out too large, overflows the available height, and Compose
 * squeezes the whole board (most visibly crushing the bottom bar and its
 * "Total" text). Bottom bar stays 1.05*th (fixed frame, no padding).
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
