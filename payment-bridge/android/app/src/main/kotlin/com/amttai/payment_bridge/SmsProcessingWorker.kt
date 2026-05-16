package com.amttai.payment_bridge

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class SmsProcessingWorker(
    appContext: Context,
    params: WorkerParameters
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val appContext = applicationContext
        val settingsManager = BridgeSettingsManager.getInstance(appContext)
        val settings = settingsManager.current
        val store = NativeBridgeStore.getInstance(appContext)
        val records = store.nextPending(limit = MAX_BATCH_SIZE)
        if (records.isEmpty()) return Result.success()

        val approver = NativePaymentApprover(settings)
        var processed = 0
        for (record in records) {
            try {
                Log.d(TAG, "--------------------------------------------------")
                Log.d(TAG, "Processing record ID: ${record.id}, Sender: ${record.sender}")
                Log.d(TAG, "Raw Body: [${record.body}]")

                store.markProcessing(record.id)
                if (!settingsManager.isTrustedSender(record.sender)) {
                    Log.w(TAG, "REJECTED: Untrusted sender: ${record.sender}")
                    store.markRejected(record.id, "Untrusted sender: ${record.sender}")
                    continue
                }
                
                Log.d(TAG, "Sender is trusted. Attempting to parse SMS...")
                val parsed = SmsParser.parse(record.sender, record.body, record.receivedAt)
                if (parsed == null) {
                    Log.w(TAG, "REJECTED: No payment SMS pattern matched for body: [${record.body}]")
                    store.markRejected(record.id, "No payment SMS pattern matched")
                    continue
                }
                
                Log.d(TAG, "SUCCESSFULLY PARSED: UserID=${parsed.userId}, Amount=${parsed.amount}, Duration=${parsed.duration}, Date=${parsed.dateText}")
                
                if (!settingsManager.isTargetUserAllowed(parsed.userId)) {
                    Log.w(TAG, "REJECTED: Parsed user '${parsed.userId}' is not in target user list")
                    store.markRejected(record.id, "Parsed user is not in target user list")
                    continue
                }

                if (settings.appwriteApiKey.isBlank()) {
                    Log.d(TAG, "Appwrite API Key is blank. Handing over to Flutter SyncEngine local queue...")
                    // Hand over to Flutter: enqueueForFlutter = true makes it available to getUnprocessedSms
                    store.markParsed(record, parsed, enqueueForFlutter = true)
                    processed++
                    continue
                }

                Log.d(TAG, "Appwrite API Key is present. Bypassing Flutter SyncEngine and sending DIRECTLY to Appwrite Cloud Function...")
                store.markParsed(record, parsed, enqueueForFlutter = false)
                val approval = approver.approve(parsed, record.smsHash, record.sender)
                if (approval.success) {
                    Log.d(TAG, "Appwrite Direct Sync SUCCESS: PaymentId=${approval.paymentId}")
                    store.markSynced(record, parsed, approval.paymentId, approval.userId)
                    processed++
                } else if (approval.retryable && record.attempts + 1 < settings.retryMaxAttempts) {
                    Log.w(TAG, "Appwrite Direct Sync RETRYABLE ERROR: ${approval.error}. Attempt ${record.attempts + 1}")
                    store.markRetry(record.id, record.attempts, settings.retryBaseDelayMs, settings.retryMaxDelayMs, approval.error ?: "Retryable native sync failure")
                } else {
                    Log.e(TAG, "Appwrite Direct Sync PERMANENT FAILURE: ${approval.error}")
                    store.markFailed(record.id, approval.error ?: "Native sync failed")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed processing native SMS queue item ${record.id}", e)
                if (record.attempts + 1 < settings.retryMaxAttempts) {
                    store.markRetry(record.id, record.attempts, settings.retryBaseDelayMs, settings.retryMaxDelayMs, e.message ?: e.javaClass.simpleName)
                } else {
                    store.markFailed(record.id, e.message ?: e.javaClass.simpleName)
                }
            }
        }
        if (store.pendingCount() > 0) scheduleOneTime(appContext)
        Log.d(TAG, "Native SMS processing complete: $processed/${records.size}")
        return Result.success()
    }

    companion object {
        private const val TAG = "SmsProcessingWorker"
        private const val UNIQUE_ONE_TIME_WORK = "native_sms_processing"
        private const val UNIQUE_PERIODIC_WORK = "native_payment_bridge_sync"
        private const val MAX_BATCH_SIZE = 10

        fun scheduleOneTime(context: Context) {
            val request = OneTimeWorkRequestBuilder<SmsProcessingWorker>()
                .setInitialDelay(2, TimeUnit.SECONDS)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .addTag(UNIQUE_ONE_TIME_WORK)
                .build()
            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                UNIQUE_ONE_TIME_WORK,
                ExistingWorkPolicy.KEEP,
                request
            )
        }

        fun schedulePeriodic(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            val request = PeriodicWorkRequestBuilder<SmsProcessingWorker>(15, TimeUnit.MINUTES)
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .addTag(UNIQUE_PERIODIC_WORK)
                .build()
            WorkManager.getInstance(context.applicationContext).enqueueUniquePeriodicWork(
                UNIQUE_PERIODIC_WORK,
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }
    }
}
