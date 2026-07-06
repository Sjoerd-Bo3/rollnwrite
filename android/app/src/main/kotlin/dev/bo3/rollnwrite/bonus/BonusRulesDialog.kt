package dev.bo3.rollnwrite.bonus

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
 * The official Qwixx Bonus (version A) rules, ported verbatim from
 * `RollnWrite/Games/QwixxBonus/QwixxBonusGame.swift`'s `RulesDocument`.
 * Mirrors `dev.bo3.rollnwrite.qwixx.QwixxRulesDialog`'s shape.
 */
@Composable
fun BonusRulesDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.close)) }
        },
        title = {
            Column {
                Text(stringResource(R.string.rules_title_bonus), style = MaterialTheme.typography.titleLarge)
                Text(
                    stringResource(R.string.rules_subtitle_bonus),
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
                    stringResource(R.string.rules_heading_bonus_goal),
                    listOf(stringResource(R.string.rules_body_bonus_goal)),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_bonus_card),
                    listOf(
                        stringResource(R.string.rules_body_bonus_card_1),
                        stringResource(R.string.rules_body_bonus_card_2),
                        stringResource(R.string.rules_body_bonus_card_3),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_bonus_crossing),
                    listOf(
                        stringResource(R.string.rules_body_bonus_crossing_1),
                        stringResource(R.string.rules_body_bonus_crossing_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_bonus_bar),
                    listOf(
                        stringResource(R.string.rules_body_bonus_bar_1),
                        stringResource(R.string.rules_body_bonus_bar_2),
                        stringResource(R.string.rules_body_bonus_bar_3),
                        stringResource(R.string.rules_body_bonus_bar_4),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_bonus_forfeit),
                    listOf(
                        stringResource(R.string.rules_body_bonus_forfeit_1),
                        stringResource(R.string.rules_body_bonus_forfeit_2),
                        stringResource(R.string.rules_body_bonus_forfeit_3),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_bonus_locking),
                    listOf(
                        stringResource(R.string.rules_body_bonus_locking_1),
                        stringResource(R.string.rules_body_bonus_locking_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_bonus_penalties),
                    listOf(
                        stringResource(R.string.rules_body_bonus_penalties_1),
                        stringResource(R.string.rules_body_bonus_penalties_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_bonus_scoring),
                    listOf(
                        stringResource(R.string.rules_body_bonus_scoring_1),
                        stringResource(R.string.rules_body_bonus_scoring_2),
                        stringResource(R.string.rules_body_bonus_scoring_3),
                    ),
                )
                Text(
                    stringResource(R.string.rules_source_bonus),
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
