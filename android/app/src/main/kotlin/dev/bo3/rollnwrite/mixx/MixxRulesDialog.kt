package dev.bo3.rollnwrite.mixx

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
 * The official Qwixx "gemixxt" (Mixx) rules, ported verbatim from
 * `RollnWrite/Games/QwixxMixx/QwixxMixxGame.swift`'s `RulesDocument` (same
 * headings/body copy, localised via `strings_mixx.xml`).
 */
@Composable
fun MixxRulesDialog(onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.close)) }
        },
        title = {
            Column {
                Text(stringResource(R.string.mixx_rules_title), style = MaterialTheme.typography.titleLarge)
                Text(stringResource(R.string.mixx_rules_subtitle), style = MaterialTheme.typography.bodyMedium)
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
                    listOf(stringResource(R.string.mixx_rules_body_goal)),
                )
                RulesSection(
                    stringResource(R.string.mixx_rules_heading_variant_a),
                    listOf(
                        stringResource(R.string.mixx_rules_body_variant_a_1),
                        stringResource(R.string.mixx_rules_body_variant_a_2),
                        stringResource(R.string.mixx_rules_body_variant_a_3),
                    ),
                )
                RulesSection(
                    stringResource(R.string.mixx_rules_heading_variant_b),
                    listOf(
                        stringResource(R.string.mixx_rules_body_variant_b_1),
                        stringResource(R.string.mixx_rules_body_variant_b_2),
                        stringResource(R.string.mixx_rules_body_variant_b_3),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_crossing),
                    listOf(
                        stringResource(R.string.mixx_rules_body_crossing_1),
                        stringResource(R.string.mixx_rules_body_crossing_2),
                    ),
                )
                RulesSection(
                    stringResource(R.string.rules_heading_locking),
                    listOf(
                        stringResource(R.string.mixx_rules_body_locking_1),
                        stringResource(R.string.mixx_rules_body_locking_2),
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
                    listOf(
                        stringResource(R.string.mixx_rules_body_scoring_1),
                        stringResource(R.string.mixx_rules_body_scoring_2),
                    ),
                )
                Text(stringResource(R.string.mixx_rules_source), style = MaterialTheme.typography.labelSmall)
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
