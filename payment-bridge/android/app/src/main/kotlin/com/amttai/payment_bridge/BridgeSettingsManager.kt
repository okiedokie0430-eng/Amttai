package com.amttai.payment_bridge

import android.content.Context
import org.json.JSONArray
import java.util.Locale
import java.util.UUID

class BridgeSettingsManager private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val prefs = appContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)

    val current: BridgeNativeSettings
        get() = BridgeNativeSettings(
            trustedSenders = getStringList(KEY_TRUSTED_SENDERS, DEFAULT_TRUSTED_SENDERS),
            targetUserIds = getStringList(KEY_TARGET_USER_IDS, emptyList()),
            amountTolerance = prefs.getInt(KEY_AMOUNT_TOLERANCE, DEFAULT_AMOUNT_TOLERANCE),
            retryBaseDelayMs = prefs.getInt(KEY_RETRY_BASE_DELAY_MS, DEFAULT_RETRY_BASE_DELAY_MS),
            retryMaxDelayMs = prefs.getInt(KEY_RETRY_MAX_DELAY_MS, DEFAULT_RETRY_MAX_DELAY_MS),
            retryMaxAttempts = prefs.getInt(KEY_RETRY_MAX_ATTEMPTS, DEFAULT_RETRY_MAX_ATTEMPTS),
            foregroundServiceEnabled = prefs.getBoolean(KEY_FOREGROUND_SERVICE_ENABLED, true),
            fallbackParsingEnabled = prefs.getBoolean(KEY_FALLBACK_PARSING_ENABLED, true),
            strictMode = prefs.getBoolean(KEY_STRICT_MODE, false),
            appwriteEndpoint = prefs.getString(KEY_APPWRITE_ENDPOINT, DEFAULT_APPWRITE_ENDPOINT) ?: DEFAULT_APPWRITE_ENDPOINT,
            appwriteProjectId = prefs.getString(KEY_APPWRITE_PROJECT_ID, DEFAULT_APPWRITE_PROJECT_ID) ?: DEFAULT_APPWRITE_PROJECT_ID,
            appwriteApiKey = prefs.getString(KEY_APPWRITE_API_KEY, "standard_b6f4a1858f9e74d8225fa0d7f0b47dcfb8dc5a9ccc4aebbc1538d7bf0f845d12fcd482541f9b29b1b87d948950b8327f83f298a6407aaf37ec1a46788c3ab6947f838fd4b644ca12f80105d0ffefd814d6e841ac411b8837b1c6781f19d99a339a8d7025f9ca79c5051167b384fba61788b6e3e413efaba4a1fd8bd5898012db") ?: "standard_b6f4a1858f9e74d8225fa0d7f0b47dcfb8dc5a9ccc4aebbc1538d7bf0f845d12fcd482541f9b29b1b87d948950b8327f83f298a6407aaf37ec1a46788c3ab6947f838fd4b644ca12f80105d0ffefd814d6e841ac411b8837b1c6781f19d99a339a8d7025f9ca79c5051167b384fba61788b6e3e413efaba4a1fd8bd5898012db",
            databaseId = prefs.getString(KEY_DATABASE_ID, DEFAULT_DATABASE_ID) ?: DEFAULT_DATABASE_ID,
            paymentsCollection = prefs.getString(KEY_PAYMENTS_COLLECTION, DEFAULT_PAYMENTS_COLLECTION) ?: DEFAULT_PAYMENTS_COLLECTION,
            usersCollection = prefs.getString(KEY_USERS_COLLECTION, DEFAULT_USERS_COLLECTION) ?: DEFAULT_USERS_COLLECTION,
            smsTransactionsCollection = prefs.getString(KEY_SMS_TRANSACTIONS_COLLECTION, DEFAULT_SMS_TRANSACTIONS_COLLECTION) ?: DEFAULT_SMS_TRANSACTIONS_COLLECTION,
            hmacSecret = prefs.getString(KEY_HMAC_SECRET, DEFAULT_HMAC_SECRET) ?: DEFAULT_HMAC_SECRET,
            deviceId = getOrCreateDeviceId()
        )

    fun updateFromMap(map: Map<*, *>) {
        val editor = prefs.edit()
        map[KEY_TRUSTED_SENDERS]?.let { editor.putString(KEY_TRUSTED_SENDERS, encodeList(asStringList(it))) }
        map[KEY_TARGET_USER_IDS]?.let { editor.putString(KEY_TARGET_USER_IDS, encodeList(asStringList(it))) }
        map[KEY_AMOUNT_TOLERANCE]?.let { editor.putInt(KEY_AMOUNT_TOLERANCE, asInt(it, DEFAULT_AMOUNT_TOLERANCE)) }
        map[KEY_RETRY_BASE_DELAY_MS]?.let { editor.putInt(KEY_RETRY_BASE_DELAY_MS, asInt(it, DEFAULT_RETRY_BASE_DELAY_MS)) }
        map[KEY_RETRY_MAX_DELAY_MS]?.let { editor.putInt(KEY_RETRY_MAX_DELAY_MS, asInt(it, DEFAULT_RETRY_MAX_DELAY_MS)) }
        map[KEY_RETRY_MAX_ATTEMPTS]?.let { editor.putInt(KEY_RETRY_MAX_ATTEMPTS, asInt(it, DEFAULT_RETRY_MAX_ATTEMPTS)) }
        map[KEY_FOREGROUND_SERVICE_ENABLED]?.let { editor.putBoolean(KEY_FOREGROUND_SERVICE_ENABLED, asBoolean(it, true)) }
        map[KEY_FALLBACK_PARSING_ENABLED]?.let { editor.putBoolean(KEY_FALLBACK_PARSING_ENABLED, asBoolean(it, true)) }
        map[KEY_STRICT_MODE]?.let { editor.putBoolean(KEY_STRICT_MODE, asBoolean(it, false)) }
        map[KEY_APPWRITE_ENDPOINT]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_APPWRITE_ENDPOINT, it) }
        map[KEY_APPWRITE_PROJECT_ID]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_APPWRITE_PROJECT_ID, it) }
        map[KEY_APPWRITE_API_KEY]?.toString()?.trim()?.let { editor.putString(KEY_APPWRITE_API_KEY, it) }
        map[KEY_DATABASE_ID]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_DATABASE_ID, it) }
        map[KEY_PAYMENTS_COLLECTION]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_PAYMENTS_COLLECTION, it) }
        map[KEY_USERS_COLLECTION]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_USERS_COLLECTION, it) }
        map[KEY_SMS_TRANSACTIONS_COLLECTION]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_SMS_TRANSACTIONS_COLLECTION, it) }
        map[KEY_HMAC_SECRET]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_HMAC_SECRET, it) }
        map[KEY_DEVICE_ID]?.toString()?.trim()?.takeIf { it.isNotEmpty() }?.let { editor.putString(KEY_DEVICE_ID, it) }
        editor.apply()
    }

    fun setAppwriteApiKey(apiKey: String) {
        prefs.edit().putString(KEY_APPWRITE_API_KEY, apiKey.trim()).apply()
    }

    fun setHmacSecret(secret: String) {
        if (secret.isNotBlank()) prefs.edit().putString(KEY_HMAC_SECRET, secret.trim()).apply()
    }

    fun setDeviceId(deviceId: String) {
        if (deviceId.isNotBlank()) prefs.edit().putString(KEY_DEVICE_ID, deviceId.trim()).apply()
    }

    fun getTargetUserIds(): List<String> = getStringList(KEY_TARGET_USER_IDS, emptyList())

    fun setTargetUserIds(userIds: List<String>) {
        prefs.edit().putString(KEY_TARGET_USER_IDS, encodeList(normalizeList(userIds))).apply()
    }

    fun addTargetUserId(userId: String) {
        val normalized = userId.trim()
        if (normalized.isEmpty()) return
        val next = getTargetUserIds().toMutableList()
        if (next.none { it.equals(normalized, ignoreCase = true) }) next.add(normalized)
        setTargetUserIds(next)
    }

    fun removeTargetUserId(userId: String) {
        val normalized = userId.trim()
        setTargetUserIds(getTargetUserIds().filterNot { it.equals(normalized, ignoreCase = true) })
    }

    fun clearTargetUserIds() {
        prefs.edit().putString(KEY_TARGET_USER_IDS, "[]").apply()
    }

    fun isTrustedSender(sender: String): Boolean {
        val normalized = normalizeSender(sender)
        if (normalized.isEmpty()) return false
        return current.trustedSenders.any {
            val trusted = normalizeSender(it)
            trusted.isNotEmpty() && (normalized.contains(trusted) || trusted.contains(normalized))
        }
    }

    fun isTargetUserAllowed(userId: String?): Boolean {
        val targets = getTargetUserIds()
        if (targets.isEmpty()) return true
        val normalized = userId?.trim() ?: return false
        return targets.any { it == normalized || it.equals(normalized, ignoreCase = true) }
    }

    fun toMap(): Map<String, Any> {
        val settings = current
        return mapOf(
            KEY_TRUSTED_SENDERS to settings.trustedSenders,
            KEY_TARGET_USER_IDS to settings.targetUserIds,
            KEY_AMOUNT_TOLERANCE to settings.amountTolerance,
            KEY_RETRY_BASE_DELAY_MS to settings.retryBaseDelayMs,
            KEY_RETRY_MAX_DELAY_MS to settings.retryMaxDelayMs,
            KEY_RETRY_MAX_ATTEMPTS to settings.retryMaxAttempts,
            KEY_FOREGROUND_SERVICE_ENABLED to settings.foregroundServiceEnabled,
            KEY_FALLBACK_PARSING_ENABLED to settings.fallbackParsingEnabled,
            KEY_STRICT_MODE to settings.strictMode,
            KEY_APPWRITE_ENDPOINT to settings.appwriteEndpoint,
            KEY_APPWRITE_PROJECT_ID to settings.appwriteProjectId,
            KEY_DATABASE_ID to settings.databaseId,
            KEY_PAYMENTS_COLLECTION to settings.paymentsCollection,
            KEY_USERS_COLLECTION to settings.usersCollection,
            KEY_SMS_TRANSACTIONS_COLLECTION to settings.smsTransactionsCollection,
            KEY_DEVICE_ID to settings.deviceId,
            "hasAppwriteApiKey" to settings.appwriteApiKey.isNotBlank()
        )
    }

    private fun getOrCreateDeviceId(): String {
        val existing = prefs.getString(KEY_DEVICE_ID, null)
        if (!existing.isNullOrBlank()) return existing
        val generated = UUID.randomUUID().toString()
        prefs.edit().putString(KEY_DEVICE_ID, generated).apply()
        return generated
    }

    private fun getStringList(key: String, fallback: List<String>): List<String> {
        val encoded = prefs.getString(key, null) ?: return fallback
        return try {
            val array = JSONArray(encoded)
            buildList {
                for (i in 0 until array.length()) {
                    val value = array.optString(i).trim()
                    if (value.isNotEmpty()) add(value)
                }
            }
        } catch (_: Exception) {
            fallback
        }
    }

    private fun asStringList(value: Any): List<String> = when (value) {
        is List<*> -> value.mapNotNull { it?.toString()?.trim()?.takeIf(String::isNotEmpty) }
        is Array<*> -> value.mapNotNull { it?.toString()?.trim()?.takeIf(String::isNotEmpty) }
        is String -> value.split('\n', ',').mapNotNull { it.trim().takeIf(String::isNotEmpty) }
        else -> emptyList()
    }

    private fun normalizeList(values: List<String>): List<String> = values.mapNotNull { it.trim().takeIf(String::isNotEmpty) }.distinct()

    private fun encodeList(values: List<String>): String = JSONArray(normalizeList(values)).toString()

    private fun asInt(value: Any, fallback: Int): Int = when (value) {
        is Number -> value.toInt()
        is String -> value.trim().toIntOrNull() ?: fallback
        else -> fallback
    }

    private fun asBoolean(value: Any, fallback: Boolean): Boolean = when (value) {
        is Boolean -> value
        is String -> when (value.trim().lowercase(Locale.ROOT)) {
            "true", "1", "yes", "on" -> true
            "false", "0", "no", "off" -> false
            else -> fallback
        }
        is Number -> value.toInt() != 0
        else -> fallback
    }

    private fun normalizeSender(sender: String): String = sender.lowercase(Locale.ROOT).replace(Regex("[\\s\\-+]+"), "")

    companion object {
        private const val PREF_NAME = "native_payment_bridge_settings"
        const val KEY_TRUSTED_SENDERS = "trustedSenders"
        const val KEY_TARGET_USER_IDS = "targetUserIds"
        const val KEY_AMOUNT_TOLERANCE = "amountTolerance"
        const val KEY_RETRY_BASE_DELAY_MS = "retryBaseDelayMs"
        const val KEY_RETRY_MAX_DELAY_MS = "retryMaxDelayMs"
        const val KEY_RETRY_MAX_ATTEMPTS = "retryMaxAttempts"
        const val KEY_FOREGROUND_SERVICE_ENABLED = "foregroundServiceEnabled"
        const val KEY_FALLBACK_PARSING_ENABLED = "fallbackParsingEnabled"
        const val KEY_STRICT_MODE = "strictMode"
        const val KEY_APPWRITE_ENDPOINT = "appwriteEndpoint"
        const val KEY_APPWRITE_PROJECT_ID = "appwriteProjectId"
        const val KEY_APPWRITE_API_KEY = "appwriteApiKey"
        const val KEY_DATABASE_ID = "databaseId"
        const val KEY_PAYMENTS_COLLECTION = "paymentsCollection"
        const val KEY_USERS_COLLECTION = "usersCollection"
        const val KEY_SMS_TRANSACTIONS_COLLECTION = "smsTransactionsCollection"
        const val KEY_HMAC_SECRET = "hmacSecret"
        const val KEY_DEVICE_ID = "deviceId"

        private const val DEFAULT_AMOUNT_TOLERANCE = 500
        private const val DEFAULT_RETRY_BASE_DELAY_MS = 30_000
        private const val DEFAULT_RETRY_MAX_DELAY_MS = 1_800_000
        private const val DEFAULT_RETRY_MAX_ATTEMPTS = 10
        private const val DEFAULT_APPWRITE_ENDPOINT = "https://fra.cloud.appwrite.io/v1"
        private const val DEFAULT_APPWRITE_PROJECT_ID = "amttai"
        private const val DEFAULT_DATABASE_ID = "amttai_db"
        private const val DEFAULT_PAYMENTS_COLLECTION = "payments"
        private const val DEFAULT_USERS_COLLECTION = "users"
        private const val DEFAULT_SMS_TRANSACTIONS_COLLECTION = "sms_transactions"
        private const val DEFAULT_HMAC_SECRET = "amttai_hmac_9f8e4d2a1b3c6f7e8d9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7"
        private val DEFAULT_TRUSTED_SENDERS = listOf("Golomt", "GOLOMT", "golomtbank", "1800", "7766", "77660101", "KhanBank", "KHANBANK", "StateBank", "TDB", "tdbm", "900", "1900", "966631826", "96631826", "132525")

        @Volatile
        private var instance: BridgeSettingsManager? = null

        fun getInstance(context: Context): BridgeSettingsManager = instance ?: synchronized(this) {
            instance ?: BridgeSettingsManager(context.applicationContext).also { instance = it }
        }
    }
}

data class BridgeNativeSettings(
    val trustedSenders: List<String>,
    val targetUserIds: List<String>,
    val amountTolerance: Int,
    val retryBaseDelayMs: Int,
    val retryMaxDelayMs: Int,
    val retryMaxAttempts: Int,
    val foregroundServiceEnabled: Boolean,
    val fallbackParsingEnabled: Boolean,
    val strictMode: Boolean,
    val appwriteEndpoint: String,
    val appwriteProjectId: String,
    val appwriteApiKey: String,
    val databaseId: String,
    val paymentsCollection: String,
    val usersCollection: String,
    val smsTransactionsCollection: String,
    val hmacSecret: String,
    val deviceId: String
)
