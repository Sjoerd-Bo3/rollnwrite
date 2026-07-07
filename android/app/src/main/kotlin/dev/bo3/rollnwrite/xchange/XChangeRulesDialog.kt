package dev.bo3.rollnwrite.xchange

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
 * The official Qwixx X-Change rules, ported verbatim from
 * `RollnWrite/Games/QwixxXChange/QwixxXChangeGame.swift`'s `RulesDocument`
 * (same headings/body copy, localised via `strings_xchange.xml`). Mirrors
 * `dev.bo3.rollnwrite.qwixx.QwixxRulesDialog`'s structure.
 */
@Composable
fun XChangeRulesDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.close)) }
        },
        title = {
            Column {
                Text(stringResource(R.string.rules_title_xchange), style = MaterialTheme.typography.titleLarge)
                Text(
                    stringResource(R.string.rules_subtitle_xchange),
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
                    listOf(stringResource(R.string.rules_body_goal_xchange)),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_card),
                    listOf(
                        stringResource(R.string.rules_body_card_1_xchange),
                        stringResource(R.string.rules_body_card_2_xchange),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_crossing),
                    listOf(
                        stringResource(R.string.rules_body_crossing_1_xchange),
                        stringResource(R.string.rules_body_crossing_2_xchange),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_xchange_row),
                    listOf(
                        stringResource(R.string.rules_body_xchange_row_1),
                        stringResource(R.string.rules_body_xchange_row_2),
                        stringResource(R.string.rules_body_xchange_row_3),
                        stringResource(R.string.rules_body_xchange_row_4),
                        stringResource(R.string.rules_body_xchange_row_5),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_locking),
                    listOf(
                        stringResource(R.string.rules_body_locking_1_xchange),
                        stringResource(R.string.rules_body_locking_2_xchange),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_penalties),
                    listOf(
                        stringResource(R.string.rules_body_penalties_1_xchange),
                        stringResource(R.string.rules_body_penalties_2_xchange),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_scoring),
                    listOf(
                        stringResource(R.string.rules_body_scoring_1_xchange),
                        stringResource(R.string.rules_body_scoring_2_xchange),
                        stringResource(R.string.rules_body_scoring_3_xchange),
                    ),
                )
                Text(
                    stringResource(R.string.rules_source_xchange),
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
