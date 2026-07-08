package dev.bo3.rollnwrite.core

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.LockOpen
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.disabled
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.bo3.rollnwrite.R
import kotlin.math.min

/**
 * Shared stroke weights for board decorations, relative to the tile size
 * (`min(w, h)`), so rings/outlines keep one consistent visual scale on every
 * board and screen size. Mirrors `RollnWrite/Core/BoardComponents.swift`
 * (`BoardStroke`).
 */
object BoardStroke {
    /** Thin outline weight: tile borders, dashes. */
    fun small(tile: Float): Float = maxOf(1.5f, tile * 0.05f)

    /** Emphasis weight: the tap-to-undo ring around the most-recent mark. */
    fun medium(tile: Float): Float = maxOf(2.5f, tile * 0.09f)
}

/**
 * A markable number tile: light rounded cell, coloured number, crossed when
 * marked. Tapping calls [onTap] — the ENGINE (via the caller's `can*`/`isLast*`
 * checks) decides whether that means mark or undo; this composable enforces
 * nothing itself.
 *
 * Mirrors `NumberTile` in `RollnWrite/Core/BoardComponents.swift`.
 */
@Composable
fun NumberTile(
    text: String,
    tint: Color,
    marked: Boolean,
    legal: Boolean,
    undoable: Boolean = false,
    forfeited: Boolean = false,
    w: Dp,
    h: Dp,
    onTap: () -> Unit,
) {
    val s = min(w.value, h.value)
    val interactive = legal || undoable
    val stateDescription = when {
        marked -> stringResource(R.string.tile_state_crossed)
        legal -> stringResource(R.string.tile_state_available)
        forfeited -> stringResource(R.string.tile_state_forfeited)
        else -> stringResource(R.string.tile_state_blocked)
    }
    // A forfeited (skipped-forever) cell wears a translucent wash of the row's
    // tint over the tile — mirrors iOS's `NumberTile`, where the whole button
    // (light base included) dims to 0.4 opacity over the colour band beneath
    // it, so a forfeited tile reads as a coloured wash, not just a faded number.
    val forfeitedWashAlpha = 0.4f
    Box(
        modifier = Modifier
            .size(w, h)
            .clip(RoundedCornerShape((s * 0.18f).dp))
            .background(Color.White.copy(alpha = 0.95f))
            .then(
                if (forfeited && !marked) {
                    Modifier.background(tint.copy(alpha = forfeitedWashAlpha))
                } else Modifier
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
            .clickable(enabled = interactive) { onTap() }
            .semantics {
                contentDescription = stateDescription
                if (!interactive) disabled()
            },
        contentAlignment = Alignment.Center,
    ) {
        val alpha = if (marked || legal) 1f else 0.4f
        Text(
            text = text,
            color = tint.copy(alpha = alpha),
            fontWeight = FontWeight.Black,
            fontSize = (s * 0.5f).sp,
            maxLines = 1,
        )
        if (forfeited && !marked) {
            // Subtle diagonal slash for a skipped-forever cell.
            Canvas(modifier = Modifier.size(w, h)) {
                val inset = size.minDimension * 0.22f
                drawLine(
                    color = tint.copy(alpha = 0.5f),
                    start = Offset(inset, size.height - inset),
                    end = Offset(size.width - inset, inset),
                    strokeWidth = BoardStroke.small(s).dp.toPx(),
                )
            }
        }
        if (marked) {
            // Matches iOS's `s * 0.74` weight/size for the crossed-out mark
            // (bolder and larger relative to the tile than the plain number).
            Text(
                text = "✕",
                color = tint.copy(alpha = alpha),
                fontWeight = FontWeight.Black,
                fontSize = (s * 0.74f).sp,
            )
        }
    }
}

/** A row's running score, shown as a dark inline tile at the band's edge. */
@Composable
fun ScoreTile(value: Int, w: Dp, h: Dp) {
    val s = min(w.value, h.value)
    Box(
        modifier = Modifier
            .size(w, h)
            .clip(RoundedCornerShape((s * 0.18f).dp))
            .background(Color.Black.copy(alpha = 0.2f)),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "$value",
            color = Color.White,
            fontWeight = FontWeight.Bold,
            fontSize = (s * 0.46f).sp,
            maxLines = 1,
        )
    }
}

/** The inline lock indicator at a row's lockable end. */
@Composable
fun LockTile(
    tint: Color,
    locked: Boolean,
    undoable: Boolean = false,
    w: Dp,
    h: Dp,
    contentDescription: String,
    onTap: (() -> Unit)? = null,
) {
    val s = min(w.value, h.value)
    Box(
        modifier = Modifier
            .size(w, h)
            .clip(RoundedCornerShape((s * 0.18f).dp))
            .background(Color.White.copy(alpha = if (locked) 0.95f else 0.42f))
            .then(
                if (undoable) {
                    Modifier.border(
                        width = BoardStroke.medium(s).dp,
                        color = tint,
                        shape = RoundedCornerShape((s * 0.18f).dp),
                    )
                } else Modifier
            )
            .then(if (onTap != null) Modifier.clickable { onTap() } else Modifier)
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = if (locked) Icons.Filled.Lock else Icons.Filled.LockOpen,
            contentDescription = null,
            tint = tint,
            modifier = Modifier.size((s * 0.5f).dp),
        )
    }
}

/**
 * A two-colour bonus space (diagonal split fill), e.g. Big Points bonus rows.
 * Mirrors `BonusTile` in `RollnWrite/Core/BoardComponents.swift`.
 */
@Composable
fun BonusTile(
    text: String,
    tintA: Color,
    tintB: Color,
    marked: Boolean,
    legal: Boolean,
    aActive: Boolean = false,
    bActive: Boolean = false,
    undoable: Boolean = false,
    w: Dp,
    h: Dp,
    onTap: () -> Unit,
) {
    val s = min(w.value, h.value)
    val aOpacity = if (marked || aActive) 1f else 0.16f
    val bOpacity = if (marked || bActive) 1f else 0.16f
    val litForWhiteText = marked || (aActive && bActive)
    val interactive = (legal && !marked) || undoable
    val bonusDescription = stringResource(R.string.bonus_content_description, text)
    Box(
        modifier = Modifier
            .size(w, h)
            .clickable(enabled = interactive) { onTap() }
            .semantics {
                contentDescription = bonusDescription
                if (!interactive) disabled()
            },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val d = min(size.width, size.height)
            val topLeft = Offset((size.width - d) / 2f, (size.height - d) / 2f)
            val circleSize = Size(d, d)

            // Light base.
            drawArcCircle(Color.White.copy(alpha = 0.95f), topLeft, circleSize)

            // Upper-left half = colour A.
            clipDiagonalHalf(upperLeft = true, topLeft = topLeft, circleSize = circleSize) {
                drawArcCircle(tintA.copy(alpha = aOpacity), topLeft, circleSize)
            }
            // Lower-right half = colour B.
            clipDiagonalHalf(upperLeft = false, topLeft = topLeft, circleSize = circleSize) {
                drawArcCircle(tintB.copy(alpha = bOpacity), topLeft, circleSize)
            }

            drawOval(
                color = Color.Black.copy(alpha = 0.18f),
                topLeft = topLeft,
                size = circleSize,
                style = Stroke(width = BoardStroke.small(s).dp.toPx()),
            )
            if (undoable) {
                drawOval(
                    color = Color.White,
                    topLeft = topLeft,
                    size = circleSize,
                    style = Stroke(width = BoardStroke.medium(s).dp.toPx()),
                )
            }
        }
        Text(
            text = text,
            color = if (litForWhiteText) Color.White else Color.Black.copy(alpha = 0.55f),
            fontWeight = FontWeight.Bold,
            fontSize = (s * 0.46f).sp,
            maxLines = 1,
        )
        if (marked) {
            Text(
                text = "✕",
                color = Color.White,
                fontWeight = FontWeight.Black,
                fontSize = (s * 0.5f).sp,
            )
        }
    }
}

private fun DrawScope.drawArcCircle(
    color: Color,
    topLeft: Offset,
    size: Size,
) {
    drawOval(color = color, topLeft = topLeft, size = size)
}

/** Clips drawing to the upper-left or lower-right diagonal half of a circle's bounding box. */
private inline fun DrawScope.clipDiagonalHalf(
    upperLeft: Boolean,
    topLeft: Offset,
    circleSize: Size,
    block: DrawScope.() -> Unit,
) {
    val path = Path().apply {
        if (upperLeft) {
            moveTo(topLeft.x, topLeft.y)
            lineTo(topLeft.x + circleSize.width, topLeft.y)
            lineTo(topLeft.x, topLeft.y + circleSize.height)
        } else {
            moveTo(topLeft.x + circleSize.width, topLeft.y)
            lineTo(topLeft.x + circleSize.width, topLeft.y + circleSize.height)
            lineTo(topLeft.x, topLeft.y + circleSize.height)
        }
        close()
    }
    clipPath(path) { block() }
}

/** One of the four penalty boxes in a board's bottom bar. */
@Composable
fun PenaltyBox(
    filled: Boolean,
    isNext: Boolean,
    undoable: Boolean,
    size: Dp,
    contentDescription: String,
    onTap: () -> Unit,
) {
    val h = size.value
    val interactive = isNext || undoable
    Box(
        modifier = Modifier
            .size(size)
            .clip(RoundedCornerShape((h * 0.2f).dp))
            .background(if (filled) Color(0xFFDC2626).copy(alpha = 0.85f) else Color.Gray.copy(alpha = 0.28f))
            .border(
                width = (if (undoable) BoardStroke.medium(h) else BoardStroke.small(h)).dp,
                color = if (undoable) Color.White else Color(0xFFDC2626).copy(alpha = 0.7f),
                shape = RoundedCornerShape((h * 0.2f).dp),
            )
            .clickable(enabled = interactive) { onTap() }
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        val boxAlpha = if (filled || isNext) 1f else 0.62f
        if (filled) {
            Text(
                text = "✕",
                color = Color.White.copy(alpha = boxAlpha),
                fontWeight = FontWeight.Black,
                fontSize = (h * 0.5f).sp,
            )
        } else {
            Text(
                text = "−5",
                color = Color(0xFFDC2626).copy(alpha = boxAlpha),
                fontWeight = FontWeight.Bold,
                fontSize = (h * 0.32f).sp,
            )
        }
    }
}

/** A small dark control button (undo, redo, new game, finish) for a board's bottom bar. */
@Composable
fun BoardControlButton(
    icon: ImageVector,
    size: Dp,
    contentDescription: String,
    enabled: Boolean = true,
    action: () -> Unit,
) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(RoundedCornerShape((size.value * 0.2f).dp))
            .background(Color.Gray.copy(alpha = 0.25f))
            .clickable(enabled = enabled) { action() }
            .semantics { this.contentDescription = contentDescription },
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = if (enabled) 1f else 0.4f),
            modifier = Modifier.size((size.value * 0.42f).dp),
        )
    }
}

/**
 * A right-pointing direction chevron at a band's leading edge: a SOLID
 * play-style triangle in a darker shade of the band colour, matching iOS's
 * `arrowtriangle.right.fill` (`BandChevron` in BoardComponents.swift) rather
 * than a thin arrow glyph.
 */
@Composable
fun BandChevron(w: Dp, h: Dp) {
    val s = min(w.value, h.value)
    val triangleColor = Color.Black.copy(alpha = 0.5f)
    Box(modifier = Modifier.size(w, h), contentAlignment = Alignment.Center) {
        val glyphSize = s * 0.5f
        Canvas(modifier = Modifier.size(glyphSize.dp)) {
            val path = Path().apply {
                moveTo(0f, 0f)
                lineTo(size.width, size.height / 2f)
                lineTo(0f, size.height)
                close()
            }
            drawPath(path, color = triangleColor)
        }
    }
}

/**
 * The coloured-band background modifier for a band's tile row (a `Row` using
 * this modifier IS the band — clip + fill + border), matching
 * `colourBand(tint:hPad:vPad:corner:)`. Horizontal/vertical padding on the
 * `Row`'s own `Modifier.padding` is applied by the caller BEFORE this, so the
 * background still spans the full band and the tiles sit inset within it.
 */
fun Modifier.colourBand(tint: Color, corner: Dp): Modifier = this
    .clip(RoundedCornerShape(corner))
    .background(tint)
    .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(corner))

/**
 * A horizontally **segmented** band background: one colour per column slot,
 * in band order (chevron, the number cells, lock, score). Lets a row whose
 * cells span several colours — e.g. Qwixx Mixx Variant A — show those colour
 * segments on the *bar itself*, not just on the number tiles. Mirrors
 * `segmentedColourBand(columns:columnWidth:gap:hPad:vPad:corner:)` in
 * `RollnWrite/Core/BoardComponents.swift`.
 *
 * [columnWidth]/[gap] must match the band's foreground `Row` (same slot width
 * per column, same spacing). Each interior segment spans its slot plus half
 * the gap on each side, so a colour boundary falls in the middle of the gap
 * between two differently-coloured tiles (not hard against one tile), and
 * runs of the same colour still read as one continuous segment. The first and
 * last segments absorb [hPad] so the strip reaches the band edges. With a
 * uniform `columns` list this renders identically to [colourBand].
 */
fun Modifier.segmentedColourBand(
    columns: List<Color>,
    columnWidth: Dp,
    gap: Dp,
    hPad: Dp,
    corner: Dp,
): Modifier = this
    .clip(RoundedCornerShape(corner))
    .drawBehind {
        val wPx = columnWidth.toPx()
        val gapPx = gap.toPx()
        val hPadPx = hPad.toPx()
        var x = 0f
        columns.forEachIndexed { idx, color ->
            val segWidth = when (idx) {
                0 -> hPadPx + wPx + gapPx / 2f
                columns.lastIndex -> gapPx / 2f + wPx + hPadPx
                else -> wPx + gapPx
            }
            drawRect(color = color, topLeft = Offset(x, 0f), size = Size(segWidth, size.height))
            x += segWidth
        }
    }
    .border(1.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(corner))
