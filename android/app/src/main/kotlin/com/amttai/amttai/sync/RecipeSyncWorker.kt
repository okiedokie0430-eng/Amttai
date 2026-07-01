package com.amttai.amttai.sync

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.IOException

/**
 * Background worker to fetch recipes from Appwrite and download associated audio files.
 * Provides granular progress updates to the UI.
 */
class RecipeSyncWorker(
    private val context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    // Assumed injected/available clients (mocked for architectural completeness)
    private val httpClient = OkHttpClient()
    
    // In a real implementation, these would be injected via Hilt/Dagger or passed via a ServiceLocator
    private val endpoint = inputData.getString("APPWRITE_ENDPOINT") ?: "https://cloud.appwrite.io/v1"
    private val projectId = inputData.getString("APPWRITE_PROJECT_ID") ?: ""
    private val databaseId = inputData.getString("APPWRITE_DATABASE_ID") ?: ""
    private val collectionId = inputData.getString("APPWRITE_COLLECTION_ID") ?: ""
    private val storageBucketId = inputData.getString("APPWRITE_BUCKET_ID") ?: ""

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            // 1. Fetch the master list of recipes from Appwrite
            val url = "$endpoint/databases/$databaseId/collections/$collectionId/documents"
            val request = Request.Builder()
                .url(url)
                .addHeader("X-Appwrite-Project", projectId)
                .build()

            val response = httpClient.newCall(request).execute()
            if (!response.isSuccessful) {
                return@withContext Result.retry()
            }

            val responseBody = response.body?.string() ?: return@withContext Result.failure()
            val jsonObject = JSONObject(responseBody)
            val documents = jsonObject.getJSONArray("documents")
            val totalRecipes = documents.length()

            if (totalRecipes == 0) {
                return@withContext Result.success()
            }

            // Report initial progress
            setProgress(workDataOf("PROGRESS" to 0, "MAX" to totalRecipes))

            // 2 & 3. Iterate, save to Room, and download MP3s
            for (i in 0 until totalRecipes) {
                try {
                    val doc = documents.getJSONObject(i)
                    val recipeId = doc.getString("\$id")
                    val audioFileId = doc.optString("audioFileId", "")

                    // TODO: Replace with actual Room DAO insert
                    // recipeDao.insertOrUpdate(RecipeEntity.fromJson(doc))
                    saveRecipeToLocalDatabase(doc)

                    // 4. Download associated .mp3 file if it exists and isn't cached
                    if (audioFileId.isNotEmpty()) {
                        downloadAudioFile(audioFileId)
                    }

                } catch (e: Exception) {
                    // Log failure for this specific item but CONTINUE the loop
                    e.printStackTrace()
                }

                // Emit progress
                setProgress(workDataOf("PROGRESS" to (i + 1), "MAX" to totalRecipes))
            }

            return@withContext Result.success()
            
        } catch (e: IOException) {
            e.printStackTrace()
            return@withContext Result.retry()
        } catch (e: Exception) {
            e.printStackTrace()
            return@withContext Result.failure()
        }
    }

    private fun saveRecipeToLocalDatabase(recipeJson: JSONObject) {
        // Stub for Room DAO logic.
        // Assumes: AppDatabase.getInstance(context).recipeDao().insert(recipe)
    }

    private suspend fun downloadAudioFile(fileId: String) = withContext(Dispatchers.IO) {
        val audioDir = File(context.cacheDir, "recipe_audio")
        if (!audioDir.exists()) {
            audioDir.mkdirs()
        }

        val targetFile = File(audioDir, "$fileId.mp3")
        if (targetFile.exists() && targetFile.length() > 0) {
            // Already downloaded
            return@withContext
        }

        val url = "$endpoint/storage/buckets/$storageBucketId/files/$fileId/download"
        val request = Request.Builder()
            .url(url)
            .addHeader("X-Appwrite-Project", projectId)
            .build()

        val response = httpClient.newCall(request).execute()
        if (response.isSuccessful) {
            val body = response.body ?: throw IOException("Empty body")
            FileOutputStream(targetFile).use { fos ->
                body.byteStream().use { input ->
                    input.copyTo(fos)
                }
            }
        } else {
            throw IOException("Failed to download audio file: $fileId")
        }
    }
}
