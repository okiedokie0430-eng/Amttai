package com.amttai.payment_bridge

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log
import org.json.JSONObject

/**
 * Lightweight BroadcastReceiver for incoming SMS.
 *
 * This receiver is triggered by the system whenever an SMS arrives.
 * It extracts sender + body, stores a compact native queue record, and
 * schedules native background processing without depending on a live Flutter
 * engine.
 */
class SmsReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "SmsReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        try {
            val appContext = context.applicationContext
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) return

            val grouped = mutableMapOf<String, StringBuilder>()
            for (msg in messages) {
                val sender = msg.displayOriginatingAddress ?: msg.originatingAddress ?: "unknown"
                grouped.getOrPut(sender) { StringBuilder() }.append(msg.messageBody ?: "")
            }

            val store = NativeBridgeStore.getInstance(appContext)

            for ((sender, bodyBuilder) in grouped) {
                val body = bodyBuilder.toString()
                val timestamp = System.currentTimeMillis()
                val insertedId = store.insertRawSms(sender, body, timestamp)
                if (insertedId != -1L) {
                    Log.d(TAG, "Native SMS queued from $sender (${body.length} chars)")
                    SmsBridge.notifyNewSms(
                        JSONObject()
                            .put("sender", sender)
                            .put("body", body)
                            .put("timestamp", timestamp)
                            .put("processed", false)
                            .toString()
                    )
                } else {
                    Log.d(TAG, "Duplicate SMS ignored from $sender")
                }
            }

            PaymentBridgeService.start(appContext)
            SmsProcessingWorker.scheduleOneTime(appContext)

        } catch (e: Exception) {
            Log.e(TAG, "Error processing incoming SMS", e)
        }
    }
}
