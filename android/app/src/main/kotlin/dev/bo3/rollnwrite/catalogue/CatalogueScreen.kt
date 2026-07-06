package dev.bo3.rollnwrite.catalogue

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.bo3.rollnwrite.R

/**
 * The game catalogue, styled to mirror iOS `RootView`: a large title, a
 * settings gear (red-tinted, top-right), and a grouped inset list — one
 * section per family ("QWIXX", …) — of rows with a 44dp accent-gradient
 * icon tile, bold title, secondary subtitle and a trailing chevron.
 *
 * Driven entirely by [GameRegistry.families]; adding a game means adding a
 * registry entry, never editing this composable (Open/Closed).
 */
@Composable
fun CatalogueScreen(onOpenGame: (String) -> Unit, onOpenSettings: () -> Unit) {
    Scaffold(
        contentWindowInsets = WindowInsets.safeDrawing,
        // Grouped-list background (iOS systemGroupedBackground twin) so the
        // white/surface family Card reads as an inset card, not a page with a
        // divider — matching the iOS reference (VERIFIED-catalogue.jpg).
        containerColor = RollnWriteGroupedBackground,
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 12.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Text(
                    text = stringResource(R.string.catalogue_title),
                    style = MaterialTheme.typography.headlineLarge,
                    fontWeight = FontWeight.Bold,
                )
                IconButton(onClick = onOpenSettings) {
                    Icon(
                        imageVector = Icons.Filled.Settings,
                        contentDescription = stringResource(R.string.settings),
                        tint = RollnWriteRed,
                    )
                }
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                items(GameRegistry.families()) { (family, games) ->
                    FamilySection(family = family, games = games, onOpenGame = onOpenGame)
                }
            }
        }
    }
}

@Composable
private fun FamilySection(family: String, games: List<GameDefinition>, onOpenGame: (String) -> Unit) {
    Column {
        Text(
            text = family.uppercase(),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 20.dp, bottom = 6.dp),
        )
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(14.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
            elevation = CardDefaults.cardElevation(defaultElevation = 0.dp),
        ) {
            games.forEachIndexed { index, game ->
                GameRow(game = game, onClick = { onOpenGame(game.id) })
                if (index != games.lastIndex) {
                    HorizontalDivider(modifier = Modifier.padding(start = 74.dp))
                }
            }
        }
    }
}

@Composable
private fun GameRow(game: GameDefinition, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier
                .size(44.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(
                    Brush.verticalGradient(
                        listOf(game.accent, game.accent.darken(0.18f)),
                    ),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(imageVector = game.icon, contentDescription = null, tint = Color.White)
        }

        Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(text = game.title(), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(
                text = game.subtitle(),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Icon(
            imageVector = Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/** Darkens a colour by [amount] (0..1) toward black — used for the icon tile's gradient, mirroring iOS's `.gradient`. */
private fun Color.darken(amount: Float): Color = Color(
    red = red * (1 - amount),
    green = green * (1 - amount),
    blue = blue * (1 - amount),
    alpha = alpha,
)

/**
 * Shared red accent (catalogue settings gear, Settings feedback icon,
 * per-game tile accents) — the single source of truth so the three sites
 * that used to duplicate this literal stay in sync.
 */
val RollnWriteRed: Color = Color(red = 0.86f, green = 0.18f, blue = 0.18f)

/** iOS `systemGroupedBackground` twin — a light grey the family Card (surface/white) sits on. */
val RollnWriteGroupedBackground: Color = Color(0xFFF2F2F7)
