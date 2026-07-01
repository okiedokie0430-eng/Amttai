package com.amttai.amttai.recommendation

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.io.IOException

/**
 * Background synchronization worker for the Adaptive Home Screen Recommendation Algorithm.
 * Safe extraction of local weights and a raw REST payload to bypass the Appwrite 1.6.0 SDK bug.
 */
class PreferenceSyncWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        // 1. Verify network connectivity for Offline-Resilient handling
        if (!isNetworkAvailable(context)) {
            return@withContext Result.retry()
        }

        // 2. Safely extract WorkManager input parameters
        val userId = inputData.getString("USER_ID") ?: return@withContext Result.failure()
        val endpoint = inputData.getString("APPWRITE_ENDPOINT") ?: return@withContext Result.failure()
        val projectId = inputData.getString("APPWRITE_PROJECT_ID") ?: return@withContext Result.failure()
        val databaseId = inputData.getString("APPWRITE_DATABASE_ID") ?: return@withContext Result.failure()
        val collectionId = inputData.getString("APPWRITE_COLLECTION_ID") ?: return@withContext Result.failure()
        val documentId = inputData.getString("APPWRITE_DOCUMENT_ID") ?: return@withContext Result.failure()
        val sessionToken = inputData.getString("APPWRITE_SESSION")
        
        // 3. Extract the local weights via Engine
        val engine = PreferenceLearningEngine(context, userId)
        val rawWeights = engine.getRawWeightsJson()

        // 4. Prepare raw JSON payload wrapped in 'data' object per Appwrite REST specs
        val jsonBody = JSONObject().apply {
            put("data", JSONObject().apply {
                put("tagWeights", rawWeights)
                put("lastSyncedTimestamp", System.currentTimeMillis())
            })
        }

        val mediaType = "application/json".toMediaType()
        val requestBody = jsonBody.toString().toRequestBody(mediaType)

        // 5. Build raw REST PATCH to bypass Appwrite 1.6.0 SDK updateDocument stripping bug
        val url = "$endpoint/databases/$databaseId/collections/$collectionId/documents/$documentId"

        val requestBuilder = Request.Builder()
            .url(url)
            .patch(requestBody)
            .addHeader("Content-Type", "application/json")
            .addHeader("X-Appwrite-Project", projectId)
        
        // Use active Appwrite session for authentication context (fallback cookie strategy)
        if (sessionToken != null) {
            requestBuilder.addHeader("X-Fallback-Cookies", sessionToken)
        }

        val client = OkHttpClient()

        try {
            // 6. Execute network call
            val response = client.newCall(requestBuilder.build()).execute()
            
            if (response.isSuccessful) {
                return@withContext Result.success()
            } else {
                val code = response.code
                // Retry if we hit a rate limit (429) or remote server errors (500-599)
                if (code == 429 || code in 500..599) {
                    return@withContext Result.retry()
                }
                // Terminal failure for auth errors or bad requests
                return@withContext Result.failure()
            }
        } catch (e: IOException) {
            e.printStackTrace()
            // Physical network exceptions trigger worker retry
            return@withContext Result.retry()
        } catch (e: Exception) {
            e.printStackTrace()
            return@withContext Result.failure()
        }
    }

    private fun isNetworkAvailable(context: Context): Boolean {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return false
        val activeNetwork = connectivityManager.getNetworkCapabilities(network) ?: return false
        return when {
            activeNetwork.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> true
            activeNetwork.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> true
            activeNetwork.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> true
            else -> false
        }
    }
}
