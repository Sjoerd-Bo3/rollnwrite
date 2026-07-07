package dev.bo3.rollnwrite.qwixxdouble

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
 * The official Qwixx Double (Variant A - "double crosses") rules, ported
 * verbatim from `RollnWrite/Games/QwixxDouble/QwixxDoubleGame.swift`'s
 * `RulesDocument` (same headings/body copy, localised the same way as
 * everything else via `strings_qwixxdouble.xml`). Mirrors
 * `dev.bo3.rollnwrite.qwixx.QwixxRulesDialog`'s structure.
 */
@Composable
fun DoubleRulesDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.close)) }
        },
        title = {
            Column {
                Text(stringResource(R.string.rules_title_double), style = MaterialTheme.typography.titleLarge)
                Text(
                    stringResource(R.string.rules_subtitle_double),
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
                    listOf(stringResource(R.string.rules_body_goal_double)),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_card),
                    listOf(
                        stringResource(R.string.rules_body_card_1_double),
                        stringResource(R.string.rules_body_card_2_double),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_crossing),
                    listOf(
                        stringResource(R.string.rules_body_crossing_1_double),
                        stringResource(R.string.rules_body_crossing_2_double),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_double_crosses),
                    listOf(
                        stringResource(R.string.rules_body_double_crosses_1),
                        stringResource(R.string.rules_body_double_crosses_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_locking),
                    listOf(
                        stringResource(R.string.rules_body_locking_1_double),
                        stringResource(R.string.rules_body_locking_2_double),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_penalties),
                    listOf(
                        stringResource(R.string.rules_body_penalties_1_double),
                        stringResource(R.string.rules_body_penalties_2_double),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_scoring),
                    listOf(
                        stringResource(R.string.rules_body_scoring_1_double),
                        stringResource(R.string.rules_body_scoring_2_double),
                        stringResource(R.string.rules_body_scoring_3_double),
                    ),
                )
                Text(
                    stringResource(R.string.rules_source_double),
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
