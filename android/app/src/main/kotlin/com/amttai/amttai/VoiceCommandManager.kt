package com.amttai.amttai

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat

/**
 * VoiceCommandManager
 *
 * Wraps Android's native [SpeechRecognizer] to provide hands-free, continuous voice
 * command detection during a cooking session — designed for the "No-Touch Guidance"
 * (Khödöö mode) use-case.
 *
 * Supported Mongolian commands:
 *   → "дараах" / "цааш"    → triggers [CommandListener.onNextStep]
 *   → "буцах"  / "өмнөх"  → triggers [CommandListener.onPreviousStep]
 *
 * Usage:
 *   val voiceManager = VoiceCommandManager(context, listener)
 *   voiceManager.startListening()   // begin cooking session
 *   voiceManager.stopListening()    // pause (e.g. Activity paused)
 *   voiceManager.release()          // mandatory in onDestroy()
 *
 * Permissions:
 *   Declare <uses-permission android:name="android.permission.RECORD_AUDIO" /> in
 *   AndroidManifest.xml and request the permission at runtime before calling startListening().
 *   Use [isAudioPermissionGranted] to guard the call site.
 */
class VoiceCommandManager(
    private val context: Context,
    private val commandListener: CommandListener
) {

    companion object {
        private const val TAG = "VoiceCommandManager"
        private const val LANGUAGE = "mn-MN"

        // Mongolian keywords for step navigation
        private val NEXT_KEYWORDS     = listOf("дараах", "цааш")
        private val PREVIOUS_KEYWORDS = listOf("буцах", "өмнөх")
    }

    // ─── Public Callback Interface ─────────────────────────────────────────────

    interface CommandListener {
        /** User said "дараах" or "цааш" — advance to the next step. */
        fun onNextStep()
        /** User said "буцах" or "өмнөх" — go back to the previous step. */
        fun onPreviousStep()
        /** Voice recognition became active and is listening for speech. */
        fun onListeningStarted()
        /**
         * Fired when the recognizer encounters a non-recoverable error.
         * Normal transient errors (no-match, silence timeout, network) are
         * handled internally with an automatic restart — this only fires for
         * errors that require user intervention (e.g. recognizer not available).
         */
        fun onRecognizerError(errorCode: Int, message: String)
    }

    // ─── Internal State ────────────────────────────────────────────────────────

    private var speechRecognizer: SpeechRecognizer? = null
    /** True while we want continuous listening (between startListening/stopListening). */
    private var isActive = false
    /** Guards against restarting during an already-scheduled restart. */
    private var isRestarting = false

    // ─── Lifecycle ─────────────────────────────────────────────────────────────

    /**
     * Starts the continuous voice recognition loop.
     * Safe to call multiple times — it is idempotent when already active.
     *
     * @throws IllegalStateException if RECORD_AUDIO permission is not granted.
     */
    fun startListening() {
        check(isAudioPermissionGranted()) {
            "RECORD_AUDIO permission is not granted. Request it before calling startListening()."
        }
        if (isActive) return

        isActive = true
        buildRecognizer()
        beginRecognition()
    }

    /**
     * Pauses recognition. The recognizer is stopped gracefully and will not
     * auto-restart until [startListening] is called again.
     */
    fun stopListening() {
        isActive = false
        isRestarting = false
        speechRecognizer?.stopListening()
    }

    /**
     * Permanently tears down the [SpeechRecognizer].
     * **Must be called in Activity.onDestroy() / Fragment.onDestroyView().**
     */
    fun release() {
        isActive = false
        isRestarting = false
        speechRecognizer?.destroy()
        speechRecognizer = null
        Log.d(TAG, "SpeechRecognizer released.")
    }

    // ─── Permission Helper ─────────────────────────────────────────────────────

    /** Returns true if the RECORD_AUDIO permission has been granted by the user. */
    fun isAudioPermissionGranted(): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    // ─── Private Implementation ────────────────────────────────────────────────

    private fun buildRecognizer() {
        speechRecognizer?.destroy()

        if (!SpeechRecognizer.isRecognitionAvailable(context)) {
            commandListener.onRecognizerError(
                SpeechRecognizer.ERROR_CLIENT,
                "Таны төхөөрөмж яриа таних боломжгүй байна."
            )
            isActive = false
            return
        }

        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(context).apply {
            setRecognitionListener(mongolianRecognitionListener)
        }
        Log.d(TAG, "SpeechRecognizer created.")
    }

    private fun beginRecognition() {
        if (!isActive || speechRecognizer == null) return
        isRestarting = false

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, LANGUAGE)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, LANGUAGE)
            putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, false)
            // Keep listening even if the device language differs
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, false)
            // We want partial results so we can react before speech fully ends (optional)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
            // Minimum speech input length — avoids false positives on background noise
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 300L)
        }

        try {
            speechRecognizer?.startListening(intent)
            commandListener.onListeningStarted()
            Log.d(TAG, "Listening started (mn-MN).")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start recognition", e)
            scheduleRestart(delayMs = 1_500)
        }
    }

    /**
     * Schedules a recognition restart after [delayMs] milliseconds.
     * Uses android.os.Handler to stay on the Main thread (SpeechRecognizer requirement).
     */
    private fun scheduleRestart(delayMs: Long = 800L) {
        if (!isActive || isRestarting) return
        isRestarting = true
        android.os.Handler(context.mainLooper).postDelayed({
            if (isActive) {
                Log.d(TAG, "Auto-restarting recognition loop.")
                beginRecognition()
            }
        }, delayMs)
    }

    // ─── Recognition Listener ──────────────────────────────────────────────────

    private val mongolianRecognitionListener = object : RecognitionListener {

        override fun onReadyForSpeech(params: Bundle?) {
            Log.d(TAG, "onReadyForSpeech")
        }

        override fun onBeginningOfSpeech() {
            Log.d(TAG, "onBeginningOfSpeech")
        }

        override fun onRmsChanged(rmsdB: Float) {
            // Intentionally unused — would be used to animate a mic level indicator
        }

        override fun onBufferReceived(buffer: ByteArray?) {
            // Raw audio buffer — not needed for command detection
        }

        override fun onEndOfSpeech() {
            Log.d(TAG, "onEndOfSpeech — waiting for results.")
            // Do not restart here; wait for onResults / onError to avoid double-start
        }

        override fun onResults(results: Bundle?) {
            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            if (matches.isNullOrEmpty()) {
                Log.d(TAG, "onResults — no matches returned.")
                scheduleRestart()
                return
            }

            // Combine all candidate strings into one lower-cased blob for matching
            val combinedText = matches.joinToString(" ").lowercase()
            Log.d(TAG, "onResults — heard: \"$combinedText\"")

            when {
                NEXT_KEYWORDS.any     { combinedText.contains(it) } -> {
                    Log.i(TAG, "→ NEXT STEP command recognised")
                    commandListener.onNextStep()
                }
                PREVIOUS_KEYWORDS.any { combinedText.contains(it) } -> {
                    Log.i(TAG, "← PREVIOUS STEP command recognised")
                    commandListener.onPreviousStep()
                }
                else -> Log.d(TAG, "No navigational command detected.")
            }

            // Always re-arm the listener after processing results
            scheduleRestart(delayMs = 300L)
        }

        override fun onPartialResults(partialResults: Bundle?) {
            // Partial results not used — full results are sufficient for command matching
        }

        override fun onError(error: Int) {
            val errorMsg = speechErrorToString(error)
            Log.w(TAG, "onError — $errorMsg (code $error)")

            when (error) {
                // ── Transient / recoverable errors — silently restart ──────────
                SpeechRecognizer.ERROR_NO_MATCH,        // Heard nothing recognisable
                SpeechRecognizer.ERROR_SPEECH_TIMEOUT,  // Silence for too long
                SpeechRecognizer.ERROR_AUDIO,           // Transient audio hiccup
                SpeechRecognizer.ERROR_NETWORK,         // Temporary network glitch
                SpeechRecognizer.ERROR_NETWORK_TIMEOUT  // Network timed out
                -> scheduleRestart(delayMs = 1_000L)

                // ── Recogniser service crashed — rebuild and restart ───────────
                SpeechRecognizer.ERROR_SERVER
                -> {
                    buildRecognizer()
                    scheduleRestart(delayMs = 2_000L)
                }

                // ── Fatal errors — inform the caller ──────────────────────────
                SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS,
                SpeechRecognizer.ERROR_CLIENT,
                SpeechRecognizer.ERROR_RECOGNIZER_BUSY
                -> {
                    isActive = false
                    commandListener.onRecognizerError(error, errorMsg)
                }

                else -> scheduleRestart(delayMs = 1_500L)
            }
        }

        override fun onEvent(eventType: Int, params: Bundle?) {
            // Reserved for future SpeechRecognizer events
        }
    }

    // ─── Error Code Translation ────────────────────────────────────────────────

    private fun speechErrorToString(errorCode: Int): String = when (errorCode) {
        SpeechRecognizer.ERROR_AUDIO                   -> "Аудио тохиргооны алдаа"
        SpeechRecognizer.ERROR_CLIENT                  -> "Клиент алдаа"
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Яриа таних эрх олгогдоогүй"
        SpeechRecognizer.ERROR_NETWORK                 -> "Сүлжээний алдаа"
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT         -> "Сүлжээний хугацаа дууссан"
        SpeechRecognizer.ERROR_NO_MATCH                -> "Тохирох үг олдсонгүй"
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY         -> "Таних систем завгүй байна"
        SpeechRecognizer.ERROR_SERVER                  -> "Серверийн алдаа"
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT          -> "Яриа цацгүй байна"
        else                                           -> "Тодорхойгүй алдаа ($errorCode)"
    }
}
