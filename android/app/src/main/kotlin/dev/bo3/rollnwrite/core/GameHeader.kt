package dev.bo3.rollnwrite.core

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Casino
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.outlined.Casino
import androidx.compose.material.icons.outlined.People
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.bo3.rollnwrite.R

/**
 * Header sizing shared by every board screen, scaled to mirror iOS's slim
 * ~44pt in-board bar (see `RollnWrite/Core/ScorecardScaffold.swift`) rather
 * than a standard Material app-bar height.
 *
 * [iconGlyphSize] shrinks the visual glyph so the row reads as compact, while
 * [touchTargetSize] keeps every control's actual tappable area at Android's
 * 44dp accessibility minimum — [GameHeaderIconButton] enforces the target via
 * `minimumInteractiveComponentSize`-style `size()`, not padding, so shrinking
 * the glyph never shrinks the hit area.
 */
object GameHeaderMetrics {
    val verticalPadding = 2.dp
    val horizontalPadding = 12.dp
    val spacing = 4.dp
    val iconGlyphSize = 20.dp
    val touchTargetSize = 44.dp
}

/**
 * The compact in-board header row: back, title, an optional per-game
 * [accessory] slot (e.g. Mixx's A/B board switch), an optional dice-strip
 * toggle (shown only when the game has [dev.bo3.rollnwrite.catalogue.GameDefinition.diceSet]
 * — leftmost of the right-side icon group, mirroring iOS's
 * `ScorecardScaffold` header order), a 2-player toggle, and rules info.
 * Every scorecard screen (`QwixxScorecardScreen`, `Connect15ScorecardScreen`,
 * `Lucky15ScorecardScreen`, `ConnectedScorecardScreen`,
 * `DoubleScorecardScreen`, `BonusScorecardScreen`, `XChangeScorecardScreen`,
 * `MixxScorecardScreen`) renders this instead of pasting its own copy —
 * mirrors iOS's shared `ScorecardScaffold` header.
 *
 * NO system app bar — this Row IS the header, positioned by the caller as the
 * first child of the screen's top-level `Column`.
 */
@Composable
fun GameHeader(
    title: String,
    twoPlayer: Boolean,
    onBack: () -> Unit,
    onToggleTwoPlayer: () -> Unit,
    onShowRules: () -> Unit,
    accessory: @Composable (() -> Unit)? = null,
    diceShown: Boolean? = null,
    onToggleDice: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .windowInsetsPadding(WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Top))
            .padding(horizontal = GameHeaderMetrics.horizontalPadding, vertical = GameHeaderMetrics.verticalPadding),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(GameHeaderMetrics.spacing),
    ) {
        GameHeaderIconButton(
            icon = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = stringResource(R.string.back),
            onClick = onBack,
        )
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            maxLines = 1,
            modifier = Modifier.weight(1f),
        )
        accessory?.invoke()
        if (diceShown != null && onToggleDice != null) {
            GameHeaderIconButton(
                icon = if (diceShown) Icons.Filled.Casino else Icons.Outlined.Casino,
                contentDescription = stringResource(if (diceShown) R.string.hide_dice else R.string.show_dice),
                onClick = onToggleDice,
            )
        }
        GameHeaderIconButton(
            icon = if (twoPlayer) Icons.Filled.Person else Icons.Outlined.People,
            contentDescription = stringResource(if (twoPlayer) R.string.single_player else R.string.two_players),
            onClick = onToggleTwoPlayer,
        )
        GameHeaderIconButton(
            icon = Icons.Filled.Info,
            contentDescription = stringResource(R.string.rules),
            onClick = onShowRules,
        )
    }
}

/**
 * A header icon button with a small glyph but a full 44dp tappable area
 * ([GameHeaderMetrics.touchTargetSize]) — the compact-chrome/accessible-target
 * split the header relies on. An explicit `size()` on the button (rather than
 * relying on `IconButton`'s default 48dp minimum) pins the hit area exactly
 * at the 44dp floor so the row's visual height can shrink without shrinking
 * the tappable area below Android's accessibility minimum.
 */
@Composable
private fun GameHeaderIconButton(
    icon: ImageVector,
    contentDescription: String,
    onClick: () -> Unit,
) {
    IconButton(
        onClick = onClick,
        modifier = Modifier.size(GameHeaderMetrics.touchTargetSize),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = contentDescription,
            modifier = Modifier.size(GameHeaderMetrics.iconGlyphSize),
        )
    }
}
