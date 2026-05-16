package com.amttai.payment_bridge

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

class NativePaymentApprover(private val settings: BridgeNativeSettings) {
    suspend fun approve(parsed: ParsedSms, smsHash: String, sender: String): NativeApprovalResult = withContext(Dispatchers.IO) {
        if (settings.appwriteApiKey.isBlank()) {
            return@withContext NativeApprovalResult(success = false, error = "Native Appwrite API key is not configured", retryable = false)
        }
        try {
            val timestamp = System.currentTimeMillis()
            val nonce = UUID.randomUUID().toString()
            val signature = sign(settings.deviceId, parsed.transactionCode, parsed.amount, timestamp, nonce, settings.hmacSecret)
            val payload = JSONObject().apply {
                put("device_id", settings.deviceId)
                put("transaction_code", parsed.transactionCode)
                put("direct_user_id", parsed.userId)
                put("amount", parsed.amount)
                put("plan", parsed.plan ?: JSONObject.NULL)
                put("sms_hash", smsHash)
                put("sender", sender)
                put("received_at", parsed.receivedAtMillis)
                put("timestamp", timestamp)
                put("nonce", nonce)
                put("signature", signature)
            }
            val response = postJson("${settings.appwriteEndpoint.trimEnd('/')}/functions/process-sms-payment/executions", settings.appwriteProjectId, settings.appwriteApiKey, JSONObject().apply {
                put("body", payload.toString())
                put("async", false)
            })
            if (response.code in 200..299) {
                val outer = JSONObject(response.body.ifBlank { "{}" })
                val body = outer.optString("responseBody", outer.optString("body", ""))
                val inner = if (body.isNotBlank()) runCatching { JSONObject(body) }.getOrNull() else outer
                val success = inner?.optBoolean("success", false) ?: false
                if (success) {
                    NativeApprovalResult(
                        success = true,
                        paymentId = inner?.optString("payment_id")?.takeIf { it.isNotBlank() },
                        userId = inner?.optString("user_id")?.takeIf { it.isNotBlank() } ?: parsed.userId,
                        plan = inner?.optString("plan")?.takeIf { it.isNotBlank() } ?: parsed.plan
                    )
                } else {
                    val errMsg = inner?.optString("error")?.takeIf { it.isNotBlank() }
                        ?: outer.optString("errors")?.takeIf { it.isNotBlank() }
                        ?: "Full Appwrite Response: ${response.body.take(500)}"
                    NativeApprovalResult(success = false, error = errMsg, retryable = false)
                }
            } else {
                NativeApprovalResult(success = false, error = "HTTP ${response.code}: ${response.body.take(300)}", retryable = response.code == 429 || response.code >= 500)
            }
        } catch (e: Exception) {
            NativeApprovalResult(success = false, error = e.message ?: e.javaClass.simpleName, retryable = true)
        }
    }

    private fun postJson(endpoint: String, projectId: String, apiKey: String, body: JSONObject): HttpResponse {
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 30_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("X-Appwrite-Project", projectId)
            setRequestProperty("X-Appwrite-Key", apiKey)
        }
        val bytes = body.toString().toByteArray(Charsets.UTF_8)
        connection.outputStream.use { it.write(bytes) }
        val code = connection.responseCode
        val stream = if (code in 200..299) connection.inputStream else connection.errorStream
        val response = stream?.bufferedReader()?.use { it.readText() }.orEmpty()
        connection.disconnect()
        return HttpResponse(code, response)
    }

    private fun sign(deviceId: String, transactionCode: String, amount: Int, timestamp: Long, nonce: String, secret: String): String {
        val message = "$deviceId|$transactionCode|$amount|$timestamp|$nonce"
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256"))
        return mac.doFinal(message.toByteArray(Charsets.UTF_8)).joinToString("") { "%02x".format(it) }
    }

    private data class HttpResponse(val code: Int, val body: String)
}

data class NativeApprovalResult(
    val success: Boolean,
    val error: String? = null,
    val paymentId: String? = null,
    val userId: String? = null,
    val plan: String? = null,
    val retryable: Boolean = false
)
