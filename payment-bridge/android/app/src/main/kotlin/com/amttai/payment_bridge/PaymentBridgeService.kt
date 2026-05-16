package com.amttai.payment_bridge

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps the Payment Bridge alive.
 *
 * This service displays a persistent notification and ensures the app process
 * is not killed by Android's background restrictions. It uses START_STICKY
 * to automatically restart if the system kills it.
 *
 * Native SMS queue processing runs through WorkManager; this service keeps
 * process priority high enough for reliable low-memory background operation.
 */
class PaymentBridgeService : Service() {

    companion object {
        private const val TAG = "PaymentBridgeService"
        private const val CHANNEL_ID = "payment_bridge_channel"
        private const val NOTIFICATION_ID = 1001

        fun start(context: Context) {
            val appContext = context.applicationContext
            val intent = Intent(appContext, PaymentBridgeService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    appContext.startForegroundService(intent)
                } else {
                    appContext.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start foreground service", e)
            }
        }

        fun stop(context: Context) {
            context.applicationContext.stopService(Intent(context.applicationContext, PaymentBridgeService::class.java))
        }

        fun isRunning(context: Context): Boolean {
            return try {
                val manager = context.applicationContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                @Suppress("DEPRECATION")
                manager.getRunningServices(Int.MAX_VALUE).any { it.service.className == PaymentBridgeService::class.java.name }
            } catch (_: Exception) {
                false
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification("Payment Bridge active"))
        Log.d(TAG, "Foreground service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started with flags=$flags, startId=$startId")
        SmsProcessingWorker.schedulePeriodic(applicationContext)
        SmsProcessingWorker.scheduleOneTime(applicationContext)
        return START_STICKY // Restart if killed
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Foreground service destroyed")
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Payment Bridge Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the SMS payment bridge running"
                setShowBadge(false)
            }

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Amttai Payment Bridge")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_send)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    fun updateNotification(text: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(NOTIFICATION_ID, buildNotification(text))
    }
}
