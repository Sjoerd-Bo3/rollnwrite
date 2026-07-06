package dev.bo3.rollnwrite.catalogue

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Email
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import dev.bo3.rollnwrite.BuildConfig
import dev.bo3.rollnwrite.R

/**
 * Minimal settings sheet — the Android twin of iOS `SettingsView`, scoped
 * down to what this platform currently has: app name/version, and a "Send
 * feedback" row that opens a `mailto:` intent (mirrors iOS's Feedback.swift
 * mailto approach, without the full composer — no Clever/dice settings exist
 * on Android yet).
 */
@Composable
fun SettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current

    Scaffold(
        contentWindowInsets = WindowInsets.safeDrawing,
        topBar = {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.back))
                }
                Text(
                    text = stringResource(R.string.settings),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        },
    ) { innerPadding ->
        Column(modifier = Modifier.padding(innerPadding).padding(vertical = 8.dp)) {
            Text(
                text = stringResource(R.string.settings_app_section).uppercase(),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
            )

            SettingsRow(
                title = stringResource(R.string.app_name),
                subtitle = stringResource(R.string.settings_version, BuildConfig.VERSION_NAME),
            )
            HorizontalDivider(modifier = Modifier.padding(horizontal = 20.dp))
            SettingsRow(
                title = stringResource(R.string.settings_send_feedback),
                subtitle = stringResource(R.string.settings_send_feedback_subtitle),
                icon = Icons.Filled.Email,
                onClick = { sendFeedback(context) },
            )
        }
    }
}

@Composable
private fun SettingsRow(
    title: String,
    subtitle: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector? = null,
    onClick: (() -> Unit)? = null,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 20.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        if (icon != null) {
            Icon(imageVector = icon, contentDescription = null, tint = RollnWriteRed)
        }
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(text = title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Medium)
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

/**
 * Opens a `mailto:` intent with subject/body pre-filled — the Android twin
 * of iOS `FeedbackMailURL`, minus the composer UI (no bug/feature picker or
 * device-info block yet on this platform).
 */
private fun sendFeedback(context: android.content.Context) {
    val subject = context.getString(R.string.settings_feedback_subject)
    val body = context.getString(R.string.settings_feedback_body)
    val intent = Intent(Intent.ACTION_SENDTO).apply {
        data = Uri.parse("mailto:")
        putExtra(Intent.EXTRA_EMAIL, arrayOf(FEEDBACK_RECIPIENT))
        putExtra(Intent.EXTRA_SUBJECT, subject)
        putExtra(Intent.EXTRA_TEXT, body)
    }
    context.startActivity(Intent.createChooser(intent, context.getString(R.string.settings_send_feedback)))
}

/** Mirrors iOS `FeedbackMailURL.recipient`. */
private const val FEEDBACK_RECIPIENT = "sjoerd.bozon@gmail.com"
