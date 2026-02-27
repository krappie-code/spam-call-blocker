package com.spamcallblocker.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import android.speech.tts.TextToSpeech
import android.telecom.Call
import android.telecom.InCallService
import android.telecom.VideoProfile
import android.util.Log
import java.util.Locale

/**
 * InCallService implementing the "wait-and-connect" spam filter.
 *
 * Flow for unknown callers:
 * 1. Call comes in → check contacts & blocklist
 * 2. Contact → let it ring normally
 * 3. Blocklisted → reject immediately
 * 4. Unknown → answer, play "Please hold while we connect you",
 *    wait 8 seconds. If caller hangs up → spam. If still connected → 
 *    notify the user via Flutter that a screened call is live.
 */
class SpamInCallService : InCallService(), TextToSpeech.OnInitListener {

    companion object {
        private const val TAG = "SpamInCallService"
        private const val HOLD_DURATION_MS = 8000L
        private const val TTS_DELAY_MS = 500L
    }

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val handler = Handler(Looper.getMainLooper())
    private val screenedCalls = mutableMapOf<Call, String>() // call → phoneNumber

    override fun onCreate() {
        super.onCreate()
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.US
            tts?.setSpeechRate(0.9f)
            ttsReady = true
            Log.d(TAG, "TTS initialized")
        } else {
            Log.e(TAG, "TTS init failed: $status")
        }
    }

    override fun onCallAdded(call: Call?) {
        super.onCallAdded(call)
        call ?: return

        val phoneNumber = call.details?.handle?.schemeSpecificPart ?: ""
        val state = call.details?.state ?: Call.STATE_NEW

        if (state != Call.STATE_RINGING) return
        if (phoneNumber.isEmpty()) return

        // Contact → let it ring normally
        if (isContact(phoneNumber)) {
            Log.d(TAG, "Contact: $phoneNumber, allowing")
            CallLogStore.log(this, phoneNumber, "allowed", "contact_allowed")
            notifyFlutter("contact_allowed", phoneNumber)
            return
        }

        // Blocklisted → reject immediately
        if (isBlocklisted(phoneNumber)) {
            Log.d(TAG, "Blocklisted: $phoneNumber, rejecting")
            CallLogStore.log(this, phoneNumber, "blocked", "blocklist_rejected")
            call.reject(false, null)
            notifyFlutter("blocklist_rejected", phoneNumber)
            return
        }

        // Unknown → screen with hold
        Log.d(TAG, "Unknown: $phoneNumber, screening")
        screenedCalls[call] = phoneNumber
        startScreening(call, phoneNumber)
    }

    private fun startScreening(call: Call, phoneNumber: String) {
        call.registerCallback(object : Call.Callback() {
            override fun onStateChanged(call: Call?, newState: Int) {
                when (newState) {
                    Call.STATE_ACTIVE -> {
                        // Call answered by us, play hold message
                        handler.postDelayed({
                            playHoldMessage(call!!, phoneNumber)
                        }, TTS_DELAY_MS)
                    }
                    Call.STATE_DISCONNECTED -> {
                        // Caller hung up during screening → spam
                        val num = screenedCalls.remove(call)
                        if (num != null) {
                            Log.d(TAG, "Caller hung up during hold: $num → spam")
                            CallLogStore.log(this@SpamInCallService, num, "blocked", "spam_detected")
                            notifyFlutter("spam_detected", num)
                        }
                    }
                }
            }
        })

        // Answer the call to begin screening
        call.answer(VideoProfile.STATE_AUDIO_ONLY)
    }

    private fun playHoldMessage(call: Call, phoneNumber: String) {
        if (!ttsReady || tts == null) {
            Log.e(TAG, "TTS not ready, allowing call through")
            screenedCalls.remove(call)
            notifyFlutter("screened_connected", phoneNumber)
            return
        }

        tts?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}

            override fun onDone(utteranceId: String?) {
                // After TTS, wait the remaining hold duration
                handler.postDelayed({
                    // If caller is still connected → they're human
                    if (screenedCalls.containsKey(call)) {
                        screenedCalls.remove(call)
                        Log.d(TAG, "Caller waited through hold: $phoneNumber → human")
                        CallLogStore.log(this@SpamInCallService, phoneNumber, "challengePassed", "screened_connected")
                        notifyFlutter("screened_connected", phoneNumber)
                        // Call stays active — user can now talk to the caller
                    }
                }, HOLD_DURATION_MS)
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                Log.e(TAG, "TTS error")
                screenedCalls.remove(call)
                notifyFlutter("screened_connected", phoneNumber)
            }
        })

        tts?.speak(
            "Please hold while we connect you. This call is being screened.",
            TextToSpeech.QUEUE_FLUSH,
            null,
            "hold_message"
        )
    }

    override fun onCallRemoved(call: Call?) {
        super.onCallRemoved(call)
        call ?: return
        val phoneNumber = screenedCalls.remove(call)
        if (phoneNumber != null) {
            Log.d(TAG, "Call removed during screening: $phoneNumber")
            CallLogStore.log(this, phoneNumber, "blocked", "spam_detected")
            notifyFlutter("spam_detected", phoneNumber)
        }
    }

    /**
     * Check if caller is in device contacts.
     */
    private fun isContact(phoneNumber: String): Boolean {
        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            )
            val cursor = contentResolver.query(
                uri,
                arrayOf(ContactsContract.PhoneLookup._ID),
                null, null, null
            )
            cursor?.use { it.moveToFirst() } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Contact check error", e)
            false
        }
    }

    /**
     * Check if number is in the app's blocklist via SharedPreferences.
     * The Flutter side syncs the blocklist to SharedPreferences for
     * fast native access without needing a DB connection.
     */
    private fun isBlocklisted(phoneNumber: String): Boolean {
        return try {
            val prefs = getSharedPreferences("blocklist", MODE_PRIVATE)
            val blocklist = prefs.getStringSet("numbers", emptySet()) ?: emptySet()
            // Check exact match and last-10-digit match
            val normalized = phoneNumber.replace(Regex("[^\\d]"), "")
            val suffix = if (normalized.length > 10) normalized.takeLast(10) else normalized
            blocklist.any { blocked ->
                val blockedNorm = blocked.replace(Regex("[^\\d]"), "")
                val blockedSuffix = if (blockedNorm.length > 10) blockedNorm.takeLast(10) else blockedNorm
                blockedNorm == normalized || blockedSuffix == suffix
            }
        } catch (e: Exception) {
            Log.e(TAG, "Blocklist check error", e)
            false
        }
    }

    private fun notifyFlutter(action: String, phoneNumber: String) {
        val intent = Intent("com.spamcallblocker.app.CALL_EVENT").apply {
            putExtra("action", action)
            putExtra("phoneNumber", phoneNumber)
            setPackage(packageName)
        }
        sendBroadcast(intent)
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
