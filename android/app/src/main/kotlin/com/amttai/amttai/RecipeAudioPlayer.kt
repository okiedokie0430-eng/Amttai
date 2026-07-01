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

class RecipeAudioPlayer(private val context: Context) {

    private var mediaPlayer: MediaPlayer? = null
    private val audioCacheDir = File(context.cacheDir, "recipe_audio_cache")

    init {
        // Ensure cache directory exists for Khödöö offline usage
        if (!audioCacheDir.exists()) {
            audioCacheDir.mkdirs()
        }
    }

    interface AudioPlaybackListener {
        fun onPlaybackStarted(stepIndex: Int)
        fun onPlaybackCompleted(stepIndex: Int)
        fun onError(stepIndex: Int, message: String)
    }

    /**
     * Pre-downloads all MP3 step URLs to the app's internal cache directory.
     * Prevents UI blocking by running completely on the IO dispatcher.
     */
    suspend fun downloadAndCacheAudioSteps(
        recipeId: String,
        audioUrls: List<String>,
        listener: AudioPlaybackListener? = null
    ) = withContext(Dispatchers.IO) {
        for ((index, urlString) in audioUrls.withIndex()) {
            val fileName = "${recipeId}_step_${index}.mp3"
            val targetFile = File(audioCacheDir, fileName)

            if (targetFile.exists() && targetFile.length() > 0) {
                Log.d("RecipeAudioPlayer", "Audio step $index is already cached. Skipping.")
                continue
            }

            if (!isNetworkAvailable()) {
                Log.e("RecipeAudioPlayer", "No network available to download step $index audio.")
                withContext(Dispatchers.Main) {
                    listener?.onError(index, "No internet. Failed to cache offline audio.")
                }
                continue
            }

            var connection: HttpURLConnection? = null
            var inputStream: BufferedInputStream? = null
            var outputStream: FileOutputStream? = null

            try {
                val url = URL(urlString)
                connection = url.openConnection() as HttpURLConnection
                connection.connectTimeout = 15000
                connection.readTimeout = 15000
                connection.connect()

                if (connection.responseCode != HttpURLConnection.HTTP_OK) {
                    throw Exception("Server responded with HTTP ${connection.responseCode}")
                }

                inputStream = BufferedInputStream(url.openStream(), 8192)
                outputStream = FileOutputStream(targetFile)

                val data = ByteArray(1024)
                var count: Int
                while (inputStream.read(data).also { count = it } != -1) {
                    outputStream.write(data, 0, count)
                }

                Log.d("RecipeAudioPlayer", "Successfully cached audio for step $index.")

            } catch (e: Exception) {
                Log.e("RecipeAudioPlayer", "Error caching audio step $index", e)
                if (targetFile.exists()) {
                    targetFile.delete() // Cleanup corrupted download
                }
                withContext(Dispatchers.Main) {
                    listener?.onError(index, "Download failed: ${e.localizedMessage}")
                }
            } finally {
                // Prevent memory leaks
                try {
                    outputStream?.flush()
                    outputStream?.close()
                    inputStream?.close()
                    connection?.disconnect()
                } catch (e: Exception) {
                    Log.e("RecipeAudioPlayer", "Error closing streams", e)
                }
            }
        }
    }

    /**
     * Plays the audio associated with the given step index strictly from the local cache.
     * Provides instantaneous zero-latency playback.
     */
    fun playStepAudio(recipeId: String, stepIndex: Int, listener: AudioPlaybackListener? = null) {
        val fileName = "${recipeId}_step_${stepIndex}.mp3"
        val audioFile = File(audioCacheDir, fileName)

        if (!audioFile.exists() || audioFile.length() == 0L) {
            listener?.onError(stepIndex, "Оффлайн аудио олдсонгүй. Интернеттэй үедээ татаж авна уу.")
            return
        }

        try {
            stopAudio() // Safely stop and reset prior playback to avoid state overlap

            mediaPlayer = MediaPlayer().apply {
                setDataSource(audioFile.absolutePath)
                setOnPreparedListener { mp ->
                    mp.start()
                    listener?.onPlaybackStarted(stepIndex)
                }
                setOnCompletionListener {
                    listener?.onPlaybackCompleted(stepIndex)
                    releaseAudio() // Clean up hardware resources immediately upon finish
                }
                setOnErrorListener { _, what, extra ->
                    listener?.onError(stepIndex, "MediaPlayer хөдөлгүүрийн алдаа: $what, $extra")
                    releaseAudio()
                    true
                }
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e("RecipeAudioPlayer", "Critical error playing audio for step $stepIndex", e)
            listener?.onError(stepIndex, "Аудио тоглуулахад алдаа гарлаа: ${e.localizedMessage}")
            releaseAudio()
        }
    }

    /**
     * Pauses and fully resets the media player state.
     */
    fun stopAudio() {
        mediaPlayer?.let {
            if (it.isPlaying) {
                it.stop()
            }
            it.reset()
        }
    }

    /**
     * Crucial to call this during Activity/Fragment onDestroy() to prevent battery/memory leaks.
     */
    fun releaseAudio() {
        mediaPlayer?.release()
        mediaPlayer = null
    }

    /**
     * Fallback verification helper to ensure network logic functions smoothly
     */
    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = connectivityManager.activeNetwork ?: return false
        val activeNetwork = connectivityManager.getNetworkCapabilities(network) ?: return false

        return when {
            activeNetwork.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> true
            activeNetwork.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> true
            else -> false
        }
    }
}
