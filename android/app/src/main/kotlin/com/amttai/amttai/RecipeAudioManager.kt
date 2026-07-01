package com.amttai.amttai

import android.content.Context
import android.media.MediaPlayer
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedInputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * RecipeAudioManager
 *
 * Manages the download, disk-caching, and MediaPlayer playback of pre-generated
 * Mongolian step audio from Appwrite Storage.
 *
 * All heavy I/O runs on [Dispatchers.IO] so the main UI thread is never blocked.
 * Call [release] from your Activity/Fragment's onDestroy() to prevent leaks.
 *
 * Appwrite Storage download URL pattern:
 *   {endpoint}/storage/buckets/{bucketId}/files/{fileId}/download?project={projectId}
 */
class RecipeAudioManager(private val context: Context) {

    companion object {
        private const val TAG = "RecipeAudioManager"

        // ─── Appwrite Config ───────────────────────────────────────────────────
        // Keep in sync with your .env / backend configuration.
        private const val APPWRITE_ENDPOINT  = "https://cloud.appwrite.io/v1"
        private const val APPWRITE_PROJECT_ID = "amttai"
        private const val APPWRITE_BUCKET_ID  = "recipe-audio-bucket"

        private const val CONNECT_TIMEOUT_MS = 15_000
        private const val READ_TIMEOUT_MS    = 30_000
        private const val BUFFER_SIZE        = 8_192
    }

    // ─── Internal State ────────────────────────────────────────────────────────
    private var mediaPlayer: MediaPlayer? = null
    private val audioCacheDir = File(context.cacheDir, "recipe_audio").also { it.mkdirs() }

    // ─── Public Callback Interface ─────────────────────────────────────────────

    interface PlaybackListener {
        fun onPlaybackStarted(stepIndex: Int)
        fun onPlaybackCompleted(stepIndex: Int)
        /** Called when the cached file is missing (offline fallback) or on player error. */
        fun onAudioUnavailable(stepIndex: Int, reason: String)
    }

    // ─── Download & Cache ──────────────────────────────────────────────────────

    /**
     * Pre-fetches all MP3 step files for a recipe and saves them to the device's
     * internal cache directory so they are available for instant offline playback.
     *
     * Already-cached and valid files are skipped automatically (idempotent).
     *
     * @param recipeId    Appwrite Document ID of the recipe (used as the cache key).
     * @param fileIds     Ordered list of Appwrite Storage File IDs from `audio_step_urls`.
     * @param listener    Optional listener to receive per-step error callbacks.
     */
    suspend fun prefetchAudio(
        recipeId: String,
        fileIds: List<String>,
        listener: PlaybackListener? = null
    ) = withContext(Dispatchers.IO) {
        fileIds.forEachIndexed { index, fileId ->
            val cacheFile = cacheFileFor(recipeId, index)

            if (cacheFile.exists() && cacheFile.length() > 0L) {
                Log.d(TAG, "Step $index already cached — skipping download.")
                return@forEachIndexed
            }

            if (!isNetworkAvailable()) {
                Log.w(TAG, "No network — cannot download step $index.")
                withContext(Dispatchers.Main) {
                    listener?.onAudioUnavailable(index, "Интернет холболт байхгүй байна.")
                }
                return@forEachIndexed
            }

            val downloadUrl = buildDownloadUrl(fileId)
            Log.d(TAG, "Downloading step $index from $downloadUrl")

            var connection: HttpURLConnection? = null
            var input: BufferedInputStream? = null
            var output: FileOutputStream? = null

            try {
                val url = URL(downloadUrl)
                connection = (url.openConnection() as HttpURLConnection).apply {
                    connectTimeout = CONNECT_TIMEOUT_MS
                    readTimeout    = READ_TIMEOUT_MS
                    requestMethod  = "GET"
                    // Appwrite requires the project ID header for authenticated buckets.
                    setRequestProperty("X-Appwrite-Project", APPWRITE_PROJECT_ID)
                    connect()
                }

                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    throw Exception("HTTP ${connection.responseCode} from Appwrite Storage")
                }

                input  = BufferedInputStream(connection.inputStream, BUFFER_SIZE)
                output = FileOutputStream(cacheFile)

                val buffer = ByteArray(BUFFER_SIZE)
                var bytesRead: Int
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                }
                output.flush()

                Log.d(TAG, "Step $index cached successfully (${cacheFile.length()} bytes).")

            } catch (e: Exception) {
                Log.e(TAG, "Failed to download step $index (fileId=$fileId)", e)
                cacheFile.takeIf { it.exists() }?.delete() // Remove partial / corrupt file
                withContext(Dispatchers.Main) {
                    listener?.onAudioUnavailable(index, "Татаж авахад алдаа гарлаа: ${e.localizedMessage}")
                }
            } finally {
                runCatching { output?.close() }
                runCatching { input?.close()  }
                runCatching { connection?.disconnect() }
            }
        }
    }

    // ─── Playback ──────────────────────────────────────────────────────────────

    /**
     * Plays the cached MP3 for the given [stepIndex].
     *
     * If the file is absent from cache, [listener.onAudioUnavailable] is invoked
     * immediately so the caller can fall back to live TTS or display a UI notice.
     *
     * Must be called from the **Main thread** (MediaPlayer requirement).
     */
    fun playStep(recipeId: String, stepIndex: Int, listener: PlaybackListener? = null) {
        val cacheFile = cacheFileFor(recipeId, stepIndex)

        if (!cacheFile.exists() || cacheFile.length() == 0L) {
            listener?.onAudioUnavailable(
                stepIndex,
                "Оффлайн аудио олдсонгүй. Интернеттэй үедээ татаж авна уу."
            )
            return
        }

        try {
            stopAndReset()

            mediaPlayer = MediaPlayer().apply {
                setDataSource(cacheFile.absolutePath)
                setOnPreparedListener { mp ->
                    mp.start()
                    listener?.onPlaybackStarted(stepIndex)
                    Log.d(TAG, "Playback started — step $stepIndex")
                }
                setOnCompletionListener {
                    listener?.onPlaybackCompleted(stepIndex)
                    release()
                    mediaPlayer = null
                }
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what extra=$extra")
                    listener?.onAudioUnavailable(stepIndex, "Тоглуулахад алдаа гарлаа ($what / $extra).")
                    release()
                    mediaPlayer = null
                    true
                }
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception initialising MediaPlayer for step $stepIndex", e)
            listener?.onAudioUnavailable(stepIndex, "Аудио тоглуулахад алдаа: ${e.localizedMessage}")
            release()
        }
    }

    /** Stops active playback without releasing the player permanently. */
    fun stopAndReset() {
        mediaPlayer?.let {
            runCatching { if (it.isPlaying) it.stop() }
            runCatching { it.reset() }
        }
    }

    /**
     * Releases all MediaPlayer hardware resources.
     * **Call this from Activity.onDestroy() / Fragment.onDestroyView() to prevent leaks.**
     */
    fun release() {
        mediaPlayer?.release()
        mediaPlayer = null
    }

    // ─── Cache Helpers ─────────────────────────────────────────────────────────

    /** Returns true if all steps for the given recipe are already on disk. */
    fun isFullyCached(recipeId: String, totalSteps: Int): Boolean =
        (0 until totalSteps).all { i ->
            cacheFileFor(recipeId, i).let { it.exists() && it.length() > 0L }
        }

    /** Deletes all cached audio files for a recipe (e.g. when recipe is removed). */
    fun evictCache(recipeId: String) {
        audioCacheDir.listFiles { f -> f.name.startsWith("recipe_${recipeId}_step_") }
            ?.forEach { it.delete() }
        Log.d(TAG, "Evicted cache for recipe $recipeId")
    }

    // ─── Private Utilities ─────────────────────────────────────────────────────

    private fun cacheFileFor(recipeId: String, stepIndex: Int): File =
        File(audioCacheDir, "recipe_${recipeId}_step_$stepIndex.mp3")

    private fun buildDownloadUrl(fileId: String): String =
        "$APPWRITE_ENDPOINT/storage/buckets/$APPWRITE_BUCKET_ID/files/$fileId/download" +
        "?project=$APPWRITE_PROJECT_ID"

    private fun isNetworkAvailable(): Boolean {
        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
            || caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
            || caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET)
    }
}
