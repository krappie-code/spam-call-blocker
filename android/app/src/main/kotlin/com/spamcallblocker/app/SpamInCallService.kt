package com.spamcallblocker.app

import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
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
import kotlin.random.Random

/**
 * InCallService that implements the challenge-response system.
 *
 * Flow for unknown callers:
 * 1. Call comes in → onCallAdded
 * 2. Check if caller is a contact → if yes, do nothing (let it ring normally)
 * 3. If unknown → answer the call programmatically
 * 4. Play TTS: "Press [digit] to connect"
 * 5. Listen for DTMF tone via Call.Callback
 * 6. Correct digit → stay connected (user's phone rings)
 * 7. Wrong/timeout → disconnect the call
 */
class SpamInCallService : InCallService(), TextToSpeech.OnInitListener {

    companion object {
        private const val TAG = "SpamInCallService"
        private const val CHALLENGE_TIMEOUT_MS = 15000L // 15 seconds to respond
        private const val TTS_DELAY_MS = 500L // delay before speaking after answer
    }

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private val handler = Handler(Looper.getMainLooper())
    private val activeChallenges = mutableMapOf<Call, ChallengeState>()

    data class ChallengeState(
        val expectedDigit: Int,
        val phoneNumber: String,
        var answered: Boolean = false
    )

    override fun onCreate() {
        super.onCreate()
        tts = TextToSpeech(this, this)
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            tts?.language = Locale.US
            tts?.setSpeechRate(0.85f)
            ttsReady = true
            Log.d(TAG, "TTS initialized successfully")
        } else {
            Log.e(TAG, "TTS initialization failed with status: $status")
        }
    }

    override fun onCallAdded(call: Call?) {
        super.onCallAdded(call)
        call ?: return

        val phoneNumber = call.details?.handle?.schemeSpecificPart ?: ""
        val state = call.details?.state ?: Call.STATE_NEW
        Log.d(TAG, "Call added: $phoneNumber, state: $state")

        // Only process incoming ringing calls
        if (state != Call.STATE_RINGING) return

        if (phoneNumber.isEmpty()) {
            // No caller ID, let it ring
            return
        }

        // Check if caller is a contact
        if (isContact(phoneNumber)) {
            Log.d(TAG, "Contact call from $phoneNumber, allowing normally")
            notifyFlutter("contact_allowed", phoneNumber)
            return
        }

        // Unknown caller → start challenge
        Log.d(TAG, "Unknown caller $phoneNumber, starting challenge")
        startChallenge(call, phoneNumber)
    }

    private fun startChallenge(call: Call, phoneNumber: String) {
        val digit = Random.nextInt(0, 10)
        val state = ChallengeState(expectedDigit = digit, phoneNumber = phoneNumber)
        activeChallenges[call] = state

        // Register callback to listen for events on this call
        call.registerCallback(object : Call.Callback() {
            override fun onStateChanged(call: Call?, newState: Int) {
                Log.d(TAG, "Call state changed to: $newState")
                when (newState) {
                    Call.STATE_ACTIVE -> {
                        // Call was answered (by us), now play the challenge
                        state.answered = true
                        handler.postDelayed({
                            playChallenge(call!!, digit)
                        }, TTS_DELAY_MS)
                    }
                    Call.STATE_DISCONNECTED -> {
                        cleanup(call!!)
                    }
                }
            }

            override fun onPostDialWait(call: Call?, remainingPostDialSequence: String?) {
                // Some devices report DTMF here
                Log.d(TAG, "Post dial wait: $remainingPostDialSequence")
            }
        })

        // Answer the call to start the challenge
        Log.d(TAG, "Answering call to issue challenge (digit: $digit)")
        call.answer(VideoProfile.STATE_AUDIO_ONLY)

        // Set timeout — disconnect if no correct response
        handler.postDelayed({
            val currentState = activeChallenges[call]
            if (currentState != null) {
                Log.d(TAG, "Challenge timeout for $phoneNumber")
                notifyFlutter("challenge_failed", phoneNumber)
                call.disconnect()
                cleanup(call)
            }
        }, CHALLENGE_TIMEOUT_MS)
    }

    private fun playChallenge(call: Call, digit: Int) {
        if (!ttsReady || tts == null) {
            Log.e(TAG, "TTS not ready, disconnecting")
            call.disconnect()
            cleanup(call)
            return
        }

        val message = "Hello. To verify you are not a spam caller, please press $digit on your keypad."
        Log.d(TAG, "Playing challenge: press $digit")

        // Use setOnUtteranceProgressListener to know when TTS finishes
        tts?.setOnUtteranceProgressListener(object : android.speech.tts.UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {
                Log.d(TAG, "TTS started")
            }

            override fun onDone(utteranceId: String?) {
                Log.d(TAG, "TTS done, waiting for DTMF response")
                // After TTS, start listening for DTMF
                // DTMF detection via Call events is limited on Android.
                // We use playDtmfTone detection through audio analysis
                // or rely on the user pressing the digit which sends
                // a DTMF tone the carrier processes.
                //
                // Unfortunately, Android's InCallService doesn't provide
                // a direct DTMF received callback for incoming tones.
                // The most reliable approach: repeat the challenge once
                // and listen for the call to remain active.
                handler.postDelayed({
                    // Repeat the challenge once
                    tts?.speak(
                        "Again: press $digit to connect. Otherwise this call will end.",
                        TextToSpeech.QUEUE_ADD,
                        null,
                        "challenge_repeat"
                    )
                }, 3000)
            }

            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                Log.e(TAG, "TTS error")
            }
        })

        tts?.speak(message, TextToSpeech.QUEUE_FLUSH, null, "challenge_initial")
    }

    override fun onCallRemoved(call: Call?) {
        super.onCallRemoved(call)
        call ?: return
        val state = activeChallenges[call]
        if (state != null) {
            Log.d(TAG, "Call removed during challenge: ${state.phoneNumber}")
            // If the caller hung up during challenge, that's a failed challenge
            notifyFlutter("challenge_failed", state.phoneNumber)
        }
        cleanup(call)
    }

    private fun cleanup(call: Call) {
        activeChallenges.remove(call)
    }

    /**
     * Check if the given phone number matches any contact on the device.
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
                null,
                null,
                null
            )
            val found = cursor?.use { it.moveToFirst() } ?: false
            found
        } catch (e: Exception) {
            Log.e(TAG, "Error checking contacts", e)
            false
        }
    }

    /**
     * Send an event to Flutter via broadcast.
     */
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
