package dev.bo3.rollnwrite.connected

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
 * The official Qwixx Connected (The Chain, version B, sheet A) rules, ported
 * verbatim from `RollnWrite/Games/QwixxConnected/QwixxConnectedGame.swift`'s
 * `RulesDocument`. Mirrors `dev.bo3.rollnwrite.bonus.BonusRulesDialog`'s shape.
 */
@Composable
fun ConnectedRulesDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.close)) }
        },
        title = {
            Column {
                Text(stringResource(R.string.rules_title_connected), style = MaterialTheme.typography.titleLarge)
                Text(
                    stringResource(R.string.rules_subtitle_connected),
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
                    stringResource(R.string.rules_heading_connected_goal),
                    listOf(stringResource(R.string.rules_body_connected_goal)),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_connected_card),
                    listOf(
                        stringResource(R.string.rules_body_connected_card_1),
                        stringResource(R.string.rules_body_connected_card_2),
                        stringResource(R.string.rules_body_connected_card_3),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_connected_crossing),
                    listOf(stringResource(R.string.rules_body_connected_crossing_1)),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_connected_chains),
                    listOf(
                        stringResource(R.string.rules_body_connected_chains_1),
                        stringResource(R.string.rules_body_connected_chains_2),
                        stringResource(R.string.rules_body_connected_chains_3),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_connected_locking),
                    listOf(
                        stringResource(R.string.rules_body_connected_locking_1),
                        stringResource(R.string.rules_body_connected_locking_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_connected_penalties),
                    listOf(
                        stringResource(R.string.rules_body_connected_penalties_1),
                        stringResource(R.string.rules_body_connected_penalties_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_connected_scoring),
                    listOf(
                        stringResource(R.string.rules_body_connected_scoring_1),
                        stringResource(R.string.rules_body_connected_scoring_2),
                        stringResource(R.string.rules_body_connected_scoring_3),
                    ),
                )
                Text(
                    stringResource(R.string.rules_source_connected),
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
