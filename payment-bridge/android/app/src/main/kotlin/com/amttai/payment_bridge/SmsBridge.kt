package com.amttai.payment_bridge

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Platform channel bridge between Android native SMS layer and Flutter.
 *
 * Provides:
 * - MethodChannel for request/response operations (get pending SMS, start service, etc.)
 * - EventChannel for streaming new SMS events to Flutter in real-time
 */
class SmsBridge {

    companion object {
        private const val TAG = "SmsBridge"
        private const val METHOD_CHANNEL = "com.amttai.bridge/sms"
        private const val EVENT_CHANNEL = "com.amttai.bridge/sms_events"

        private var eventSink: EventChannel.EventSink? = null

        fun registerWith(flutterEngine: FlutterEngine, context: Context) {
            val appContext = context.applicationContext
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                METHOD_CHANNEL
            ).setMethodCallHandler { call, result ->
                handleMethodCall(call, result, appContext)
            }

            EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                EVENT_CHANNEL
            ).setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    Log.d(TAG, "SMS event stream started")
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    Log.d(TAG, "SMS event stream cancelled")
                }
            })
        }

        /**
         * Called by SmsReceiver when a new SMS arrives.
         * Sends the SMS data to Flutter via the EventChannel if available.
         */
        fun notifyNewSms(smsJson: String) {
            try {
                eventSink?.success(smsJson)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify Flutter of new SMS", e)
            }
        }

        private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result, context: Context) {
            when (call.method) {
                "getUnprocessedSms" -> {
                    try {
                        result.success("[]")
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get pending SMS", e.message)
                    }
                }

                "markSmsProcessed" -> {
                    try {
                        val timestamp = call.argument<Long>("timestamp")
                        if (timestamp == null) {
                            result.error("INVALID_ARGS", "timestamp required", null)
                            return
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to mark SMS processed", e.message)
                    }
                }

                "clearProcessedSms" -> {
                    try {
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to clear processed SMS", e.message)
                    }
                }

                "startForegroundService" -> {
                    try {
                        PaymentBridgeService.start(context)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to start service", e.message)
                    }
                }

                "stopForegroundService" -> {
                    try {
                        PaymentBridgeService.stop(context)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to stop service", e.message)
                    }
                }

                "isServiceRunning" -> {
                    try {
                        result.success(PaymentBridgeService.isRunning(context))
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "requestBatteryOptimizationExemption" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(context.packageName)) {
                                val intent = Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:${context.packageName}")
                                )
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                context.startActivity(intent)
                                result.success(false) // Will be true after user grants
                            } else {
                                result.success(true) // Already exempted
                            }
                        } else {
                            result.success(true) // Not needed on older Android
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to request battery exemption", e.message)
                    }
                }

                "isBatteryOptimizationExempted" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(context.packageName))
                        } else {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }

                "getNativeSettings" -> {
                    try {
                        result.success(BridgeSettingsManager.getInstance(context).toMap())
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get native settings", e.message)
                    }
                }

                "updateNativeSettings" -> {
                    try {
                        val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        BridgeSettingsManager.getInstance(context).updateFromMap(args)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to update native settings", e.message)
                    }
                }

                "syncNativeCredentials" -> {
                    try {
                        val manager = BridgeSettingsManager.getInstance(context)
                        call.argument<String>("apiKey")?.let { manager.setAppwriteApiKey(it) }
                        call.argument<String>("hmacSecret")?.let { manager.setHmacSecret(it) }
                        call.argument<String>("deviceId")?.let { manager.setDeviceId(it) }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to sync native credentials", e.message)
                    }
                }

                "getNativeTargetUserIds" -> {
                    try {
                        result.success(BridgeSettingsManager.getInstance(context).getTargetUserIds())
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get target user IDs", e.message)
                    }
                }

                "setNativeTargetUserIds" -> {
                    try {
                        val ids = (call.argument<List<*>>("userIds") ?: emptyList<Any>())
                            .mapNotNull { it?.toString() }
                        BridgeSettingsManager.getInstance(context).setTargetUserIds(ids)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to set target user IDs", e.message)
                    }
                }

                "addNativeTargetUserId" -> {
                    try {
                        val userId = call.argument<String>("userId") ?: ""
                        BridgeSettingsManager.getInstance(context).addTargetUserId(userId)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to add target user ID", e.message)
                    }
                }

                "removeNativeTargetUserId" -> {
                    try {
                        val userId = call.argument<String>("userId") ?: ""
                        BridgeSettingsManager.getInstance(context).removeTargetUserId(userId)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to remove target user ID", e.message)
                    }
                }

                "clearNativeTargetUserIds" -> {
                    try {
                        BridgeSettingsManager.getInstance(context).clearTargetUserIds()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to clear target user IDs", e.message)
                    }
                }

                "testSmsParsing" -> {
                    try {
                        val rawSms = call.argument<String>("rawSms") ?: ""
                        result.success(SmsParsingTestUtil.test(rawSms))
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to test SMS parsing", e.message)
                    }
                }

                "testSmsParsingBatch" -> {
                    try {
                        val messages = (call.argument<List<*>>("messages") ?: emptyList<Any>())
                            .mapNotNull { it?.toString() }
                        result.success(SmsParsingTestUtil.testBatch(messages))
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to test SMS parsing batch", e.message)
                    }
                }

                "getNativeQueueStatus" -> {
                    try {
                        val store = NativeBridgeStore.getInstance(context)
                        result.success(mapOf("pendingCount" to store.pendingCount()))
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get native queue status", e.message)
                    }
                }

                "getRecentNativeSms" -> {
                    try {
                        val limit = call.argument<Int>("limit") ?: 50
                        result.success(NativeBridgeStore.getInstance(context).recent(limit))
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get recent native SMS", e.message)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
