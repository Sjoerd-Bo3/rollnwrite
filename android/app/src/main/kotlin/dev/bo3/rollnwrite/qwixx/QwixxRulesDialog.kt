package dev.bo3.rollnwrite.qwixx

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import dev.bo3.rollnwrite.R

/**
 * The official Qwixx rules for both flavours, ported verbatim from
 * `RollnWrite/Games/Qwixx/QwixxBigPointsGame.swift` / `QwixxClassicGame.swift`'s
 * `RulesDocument`s (same headings/body copy, localised the same way as
 * everything else via `strings.xml`). [variant] picks Big Points (with its
 * bonus-row section) or classic (no bonus rows, cap 12) — same dialog shell.
 */
@Composable
fun QwixxRulesDialog(variant: QwixxRulesVariant, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.close)) }
        },
        title = {
            Column {
                Text(
                    stringResource(
                        if (variant == QwixxRulesVariant.BIG_POINTS) {
                            R.string.rules_title_big_points
                        } else {
                            R.string.rules_title_classic
                        },
                    ),
                    style = MaterialTheme.typography.titleLarge,
                )
                Text(
                    stringResource(
                        if (variant == QwixxRulesVariant.BIG_POINTS) {
                            R.string.rules_subtitle_big_points
                        } else {
                            R.string.rules_subtitle_classic
                        },
                    ),
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        },
        text = {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                RulesSection(
                    stringResource(R.string.rules_heading_goal),
                    listOf(
                        stringResource(
                            if (variant == QwixxRulesVariant.BIG_POINTS) {
                                R.string.rules_body_goal
                            } else {
                                R.string.rules_body_goal_classic
                            },
                        ),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_card),
                    if (variant == QwixxRulesVariant.BIG_POINTS) {
                        listOf(
                            stringResource(R.string.rules_body_card_1),
                            stringResource(R.string.rules_body_card_2),
                        )
                    } else {
                        listOf(
                            stringResource(R.string.rules_body_card_1),
                            stringResource(R.string.rules_body_card_classic_2),
                        )
                    },
                )
                RulesSection(
                    stringResource(R.string.rules_heading_crossing),
                    listOf(
                        stringResource(R.string.rules_body_crossing_1),
                        stringResource(R.string.rules_body_crossing_2),
                    ),
                )
                if (variant == QwixxRulesVariant.BIG_POINTS) {
                    RulesSection(
                        stringResource(R.string.rules_heading_bonus),
                        listOf(
                            stringResource(R.string.rules_body_bonus_1),
                            stringResource(R.string.rules_body_bonus_2),
                            stringResource(R.string.rules_body_bonus_3),
                            stringResource(R.string.rules_body_bonus_4),
                            stringResource(R.string.rules_body_bonus_5),
                        ),
                    )
                }
                RulesSection(
                    stringResource(R.string.rules_heading_locking),
                    listOf(
                        stringResource(R.string.rules_body_locking_1),
                        stringResource(R.string.rules_body_locking_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_penalties),
                    listOf(
                        stringResource(R.string.rules_body_penalties_1),
                        stringResource(R.string.rules_body_penalties_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_scoring),
                    if (variant == QwixxRulesVariant.BIG_POINTS) {
                        listOf(
                            stringResource(R.string.rules_body_scoring_1),
                            stringResource(R.string.rules_body_scoring_2),
                        )
                    } else {
                        listOf(
                            stringResource(R.string.rules_body_scoring_classic_1),
                            stringResource(R.string.rules_body_scoring_2),
                        )
                    },
                )
                Text(
                    stringResource(
                        if (variant == QwixxRulesVariant.BIG_POINTS) {
                            R.string.rules_source_big_points
                        } else {
                            R.string.rules_source_classic
                        },
                    ),
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        },
    )
}

@Composable
private fun RulesSection(heading: String, body: List<String>) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(heading, style = MaterialTheme.typography.titleMedium)
        body.forEach { paragraph ->
            Text(paragraph, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.padding(top = 2.dp))
        }
    }
}
