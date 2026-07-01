package com.amttai.amttai.sync

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.livedata.observeAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.work.WorkInfo
import java.util.UUID

/**
 * Jetpack Compose Settings Screen for monitoring and triggering offline bulk downloads.
 */
@Composable
fun SettingsSyncScreen(
    syncManager: SyncManager = SyncManager(LocalContext.current)
) {
    // State to track the currently running manual sync WorkRequest ID
    var activeWorkId by remember { mutableStateOf<UUID?>(null) }

    // Observe the WorkInfo from WorkManager using the active Work ID
    val workInfoState = activeWorkId?.let { syncManager.observeWorkInfo(it).observeAsState() }
    val workInfo = workInfoState?.value

    // Determine current status
    val isRunning = workInfo?.state == WorkInfo.State.RUNNING || workInfo?.state == WorkInfo.State.ENQUEUED
    val progress = workInfo?.progress?.getInt("PROGRESS", 0) ?: 0
    val max = workInfo?.progress?.getInt("MAX", 0) ?: 0

    // Calculate progress ratio for the LinearProgressIndicator
    val progressRatio = if (max > 0) progress.toFloat() / max.toFloat() else 0f

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.Top,
        horizontalAlignment = Alignment.Start
    ) {
        Text(
            text = "Оффлайн тохиргоо (Offline Settings)",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(bottom = 8.dp)
        )
        
        Text(
            text = "Интернэтгүй үед ашиглахын тулд бүх жор болон аудио файлуудыг татаж авна уу.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(bottom = 24.dp)
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 2.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Text(
                    text = "Бүх контентыг татах (Download All Offline Content)",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold
                )

                Spacer(modifier = Modifier.height(16.dp))

                if (isRunning) {
                    LinearProgressIndicator(
                        progress = progressRatio,
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(8.dp)
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Татаж байна... $progress/$max",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Medium,
                        color = MaterialTheme.colorScheme.primary
                    )
                } else {
                    if (workInfo?.state == WorkInfo.State.SUCCEEDED) {
                        Text(
                            text = "Амжилттай татагдлаа! (Download Complete!)",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )
                    } else if (workInfo?.state == WorkInfo.State.FAILED) {
                        Text(
                            text = "Татахад алдаа гарлаа. (Download Failed)",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.error,
                            modifier = Modifier.padding(bottom = 8.dp)
                        )
                    }

                    Button(
                        onClick = {
                            activeWorkId = syncManager.triggerManualBulkDownload()
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("Одоо татах (Download Now)")
                    }
                }
            }
        }
    }
}
