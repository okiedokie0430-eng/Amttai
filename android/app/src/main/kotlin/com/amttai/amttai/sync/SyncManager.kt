package com.amttai.amttai.sync

import android.content.Context
import androidx.lifecycle.LiveData
import androidx.work.*
import java.util.UUID
import java.util.concurrent.TimeUnit

/**
 * Controller class to enqueue and manage WorkManager requests for syncing offline content.
 */
class SyncManager(private val context: Context) {

    private val workManager = WorkManager.getInstance(context)

    /**
     * Schedules a periodic background sync (e.g., every 24 hours).
     * Protected by strict network and battery constraints to save user data plans.
     */
    fun schedulePeriodicSync() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.UNMETERED) // Wi-Fi only
            .setRequiresBatteryNotLow(true)
            .build()

        val periodicRequest = PeriodicWorkRequestBuilder<RecipeSyncWorker>(24, TimeUnit.HOURS)
            .setConstraints(constraints)
            // Add default input data (in a real app, inject via Hilt or pull from encrypted prefs)
            .setInputData(workDataOf(
                "APPWRITE_PROJECT_ID" to "YOUR_PROJECT_ID",
                "APPWRITE_DATABASE_ID" to "YOUR_DB_ID",
                "APPWRITE_COLLECTION_ID" to "YOUR_COL_ID",
                "APPWRITE_BUCKET_ID" to "YOUR_BUCKET_ID"
            ))
            .build()

        workManager.enqueueUniquePeriodicWork(
            "PeriodicRecipeSync",
            ExistingPeriodicWorkPolicy.KEEP, // Keep existing if already scheduled
            periodicRequest
        )
    }

    /**
     * Triggers an immediate one-time sync.
     * Used by the Settings screen for manual bulk downloads.
     * @return The UUID of the WorkRequest to allow the UI to observe its progress.
     */
    fun triggerManualBulkDownload(): UUID {
        // Manual downloads don't require UNMETERED, but we still ensure a network is present
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val oneTimeRequest = OneTimeWorkRequestBuilder<RecipeSyncWorker>()
            .setConstraints(constraints)
            .setInputData(workDataOf(
                "APPWRITE_PROJECT_ID" to "YOUR_PROJECT_ID",
                "APPWRITE_DATABASE_ID" to "YOUR_DB_ID",
                "APPWRITE_COLLECTION_ID" to "YOUR_COL_ID",
                "APPWRITE_BUCKET_ID" to "YOUR_BUCKET_ID"
            ))
            .build()

        workManager.enqueueUniqueWork(
            "ManualBulkSync",
            ExistingWorkPolicy.REPLACE, // Replace any currently running manual sync
            oneTimeRequest
        )

        return oneTimeRequest.id
    }

    /**
     * Exposes the WorkInfo LiveData so Jetpack Compose can observe the state and progress.
     */
    fun observeWorkInfo(workId: UUID): LiveData<WorkInfo> {
        return workManager.getWorkInfoByIdLiveData(workId)
    }
}
