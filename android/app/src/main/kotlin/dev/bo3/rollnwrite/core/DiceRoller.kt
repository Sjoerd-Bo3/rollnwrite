package dev.bo3.rollnwrite.core

import android.content.Context
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import dev.bo3.rollnwrite.R
import kotlin.math.max
import kotlin.math.min
import kotlinx.coroutines.delay
import kotlin.random.Random

/**
 * Optional, purely informational in-app dice roller (issue #30, ported from
 * iOS `RollnWrite/Core/DiceRoller.swift`).
 *
 * A game that declares its physical dice ([GameDefinition.diceSet] in
 * `GameRegistry.kt`) gets a die toggle in the header ([GameHeader]);
 * switching it on shows [DiceRollerStrip] between the header and the board.
 * Rolling NEVER marks cells and never touches an engine — the app stays a
 * pure scorecard; the strip merely replaces the physical dice on the table
 * for players who left theirs at home. The dice-shown preference persists
 * per game (`SharedPreferences`, see [rememberDiceVisibility]); roll results
 * do not.
 */

/** One physical die of a game, as declared by its [dev.bo3.rollnwrite.catalogue.GameDefinition]. */
data class DieSpec(
    /** English colour name ("White", "Red", …) used for accessibility labels like "Red die: 4". */
    val name: String,
    /** The die's display colour. Qwixx dice are always fixed colours (never player-themed). */
    val color: Color,
    /** Whether the face is light (white/yellow) so pips must render dark. */
    val isLight: Boolean = false,
) {
    companion object {
        /** The standard white die (light face, dark pips). */
        fun white(): DieSpec = DieSpec(
            name = "White",
            color = Color(red = 0.88f, green = 0.89f, blue = 0.92f),
            isLight = true,
        )
    }
}

/**
 * Per-game, per-install persisted visibility of the dice strip — an OPT-IN,
 * default off. Mirrors iOS's `@AppStorage("diceRoller." + title)` in
 * `ScorecardScaffold.swift` exactly, including the key scheme, so the
 * naming convention stays consistent across platforms even though the
 * storage backends differ (`SharedPreferences` vs. `UserDefaults`).
 */
@Composable
fun rememberDiceVisibility(title: String): DiceVisibilityState {
    val context = LocalContext.current
    val prefs = remember(context) {
        context.applicationContext.getSharedPreferences(DICE_PREFS_NAME, Context.MODE_PRIVATE)
    }
    val key = remember(title) { "diceRoller.$title" }
    var shown by remember(key) { mutableStateOf(prefs.getBoolean(key, false)) }
    return remember(key, shown) {
        DiceVisibilityState(
            shown = shown,
            toggle = {
                shown = !shown
                prefs.edit().putBoolean(key, shown).apply()
            },
        )
    }
}

data class DiceVisibilityState(val shown: Boolean, val toggle: () -> Unit)

private const val DICE_PREFS_NAME = "rollnwrite"

// MARK: - Roller strip

/**
 * A compact horizontal strip of rollable dice. Sits between the header and
 * the board (boards are `BoxWithConstraints`-driven and simply adapt to the
 * shorter space, mirroring iOS's `GeometryReader`-driven boards).
 *
 * Interactions (mirrors iOS `DiceRollerStrip` exactly):
 * - "Roll" button — or a tap anywhere on the strip background — rolls every
 *   die that isn't held, with a brief tumble animation (five ~80ms frames of
 *   random faces + wobble, then settle) and a light haptic.
 * - Tapping a single die HOLDS it (dimmed + lock badge): re-rolls keep it.
 * - Long-pressing the strip clears all holds.
 *
 * Roll state is deliberately transient (`remember`, not persisted or handed
 * to a game engine).
 */
@Composable
fun DiceRollerStrip(dice: List<DieSpec>, modifier: Modifier = Modifier) {
    val view = LocalView.current
    var faces by remember(dice) { mutableStateOf(dice.map { Random.nextInt(1, 7) }) }
    var wobble by remember(dice) { mutableStateOf(List(dice.size) { 0f }) }
    var held by remember(dice) { mutableStateOf(setOf<Int>()) }
    var isRolling by remember { mutableStateOf(false) }
    var rollRequest by remember { mutableIntStateOf(0) }

    LaunchedEffect(rollRequest) {
        if (rollRequest == 0) return@LaunchedEffect
        if (held.size >= dice.size) return@LaunchedEffect
        isRolling = true
        repeat(5) {
            faces = faces.mapIndexed { i, f -> if (i in held) f else Random.nextInt(1, 7) }
            wobble = wobble.mapIndexed { i, w -> if (i in held) w else Random.nextInt(-9, 10).toFloat() }
            delay(80)
        }
        faces = faces.mapIndexed { i, f -> if (i in held) f else Random.nextInt(1, 7) }
        wobble = List(dice.size) { 0f }
        isRolling = false
    }

    fun roll() {
        if (isRolling || held.size >= dice.size) return
        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
        rollRequest++
    }

    fun toggleHold(i: Int) {
        held = if (i in held) held - i else held + i
        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    }

    fun clearHolds() {
        if (held.isEmpty()) return
        held = emptySet()
        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    }

    val rollLabel = stringResource(R.string.dice_roll)
    Surface(
        color = MaterialTheme.colorScheme.surfaceVariant,
        modifier = modifier
            .fillMaxWidth()
            .height(DiceStripHeight)
            .pointerInput(dice) {
                detectTapGestures(
                    onTap = { roll() },
                    onLongPress = { clearHolds() },
                )
            },
    ) {
        BoxWithConstraints(modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp)) {
            val side = dieSide(maxWidth, dice.size)
            Row(
                modifier = Modifier.fillMaxSize(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(DiceSpacing),
            ) {
                dice.forEachIndexed { i, die ->
                    DieButton(
                        die = die,
                        face = faces[i],
                        wobbleDegrees = wobble.getOrElse(i) { 0f },
                        isHeld = i in held,
                        side = side,
                        onTap = { toggleHold(i) },
                    )
                }
                Box(modifier = Modifier.weight(1f, fill = true))
                Button(
                    onClick = { roll() },
                    enabled = !isRolling && held.size < dice.size,
                    colors = ButtonDefaults.buttonColors(containerColor = RollDiceRed),
                ) {
                    Icon(Icons.Filled.Casino, contentDescription = null, modifier = Modifier.size(18.dp))
                    Text(text = rollLabel, modifier = Modifier.padding(start = 6.dp))
                }
            }
        }
    }
}

private val DiceStripHeight = 58.dp
private val DiceSpacing = 8.dp
/** Space reserved for the Roll button + paddings when sizing dice (mirrors iOS's `reservedWidth`). */
private val ReservedWidth = 130.dp

private fun dieSide(available: Dp, count: Int): Dp {
    val n = max(1, count)
    val free = available - ReservedWidth - DiceSpacing * (n - 1)
    val perDie = free / n
    return perDie.coerceIn(26.dp, 44.dp)
}

private val RollDiceRed = Color(red = 0.86f, green = 0.18f, blue = 0.18f)

@Composable
private fun DieButton(
    die: DieSpec,
    face: Int,
    wobbleDegrees: Float,
    isHeld: Boolean,
    side: Dp,
    onTap: () -> Unit,
) {
    val pip = if (die.isLight) Color.Black else Color.White
    val heldLabel = stringResource(R.string.dice_held)
    val holdHint = stringResource(R.string.dice_holds_hint)
    val releaseHint = stringResource(R.string.dice_releases_hint)
    val dieLabel = stringResource(R.string.dice_die_value, die.name, face)
    Box(
        modifier = Modifier
            .size(side)
            .rotate(wobbleDegrees)
            .pointerInput(Unit) { detectTapGestures(onTap = { onTap() }) }
            .semantics {
                contentDescription = dieLabel
                stateDescription = if (isHeld) "$heldLabel — $releaseHint" else holdHint
            },
        contentAlignment = Alignment.Center,
    ) {
        DieFace(
            value = face,
            fill = die.color,
            pip = pip,
            modifier = Modifier.fillMaxSize(),
            dimmed = isHeld,
        )
        if (isHeld) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .size(side * 0.28f)
                    .clip(RoundedCornerShape(50))
                    .background(Color.Black.copy(alpha = 0.65f)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.Lock,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(side * 0.16f),
                )
            }
        }
    }
}

/**
 * A rounded die face with the classic pip arrangements (never numerals).
 * Mirrors iOS's `DieFace`.
 */
@Composable
fun DieFace(
    value: Int,
    fill: Color,
    pip: Color,
    modifier: Modifier = Modifier,
    dimmed: Boolean = false,
) {
    val alpha = if (dimmed) 0.45f else 1f
    Canvas(modifier = modifier) {
        val s = min(size.width, size.height)
        val corner = s * 0.22f
        drawRoundRect(
            color = fill.copy(alpha = alpha),
            size = size,
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(corner, corner),
        )
        drawRoundRect(
            color = Color.Black.copy(alpha = 0.18f * alpha),
            size = size,
            cornerRadius = androidx.compose.ui.geometry.CornerRadius(corner, corner),
            style = Stroke(width = 1.dp.toPx()),
        )
        val pipRadius = s * 0.085f
        for ((px, py) in pipsFor(value)) {
            drawCircle(
                color = pip.copy(alpha = alpha),
                radius = pipRadius,
                center = Offset(
                    x = (0.5f + px * 0.27f) * size.width,
                    y = (0.5f + py * 0.27f) * size.height,
                ),
            )
        }
    }
}

/** Classic western pip layouts on a −1…1 grid, matching iOS's `DieFace.pips(for:)`. */
private fun pipsFor(value: Int): List<Pair<Float, Float>> = when (value) {
    1 -> listOf(0f to 0f)
    2 -> listOf(1f to -1f, -1f to 1f)
    3 -> listOf(1f to -1f, 0f to 0f, -1f to 1f)
    4 -> listOf(-1f to -1f, 1f to -1f, -1f to 1f, 1f to 1f)
    5 -> listOf(-1f to -1f, 1f to -1f, 0f to 0f, -1f to 1f, 1f to 1f)
    else -> listOf(-1f to -1f, 1f to -1f, -1f to 0f, 1f to 0f, -1f to 1f, 1f to 1f)
}
