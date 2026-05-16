package com.amttai.payment_bridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receives BOOT_COMPLETED broadcast to restart the Payment Bridge
 * foreground service and reschedule WorkManager tasks after device reboot.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON"
        ) {
            Log.d(TAG, "Boot completed — restarting Payment Bridge service")
            PaymentBridgeService.start(context.applicationContext)
            SmsProcessingWorker.schedulePeriodic(context.applicationContext)
            SmsProcessingWorker.scheduleOneTime(context.applicationContext)
        }
    }
}
