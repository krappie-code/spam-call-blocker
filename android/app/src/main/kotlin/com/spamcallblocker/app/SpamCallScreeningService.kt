package com.spamcallblocker.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi

/**
 * CallScreeningService (Android 10+) — the primary screening mechanism.
 *
 * Flow:
 * 1. Contact → allow through, log as allowed
 * 2. Whitelisted (user approved previously) → allow through
 * 3. Blocklisted → reject, don't ring, log as blocked
 * 4. Unknown → silence the call (no ring, appears as missed call),
 *    log for user review. User can then whitelist or block from the app.
 *
 * Note: CallScreeningService must respond quickly — no TTS or waiting.
 * The "screening" happens by silencing unknown calls and letting the
 * user decide after the fact.
 */
@RequiresApi(Build.VERSION_CODES.Q)
class SpamCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "SpamCallScreening"
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart ?: ""
        Log.d(TAG, "Screening call from: $phoneNumber")

        if (phoneNumber.isEmpty()) {
            respondAllow(callDetails)
            return
        }

        // 1. Contact → allow
        if (isContact(phoneNumber)) {
            Log.d(TAG, "Contact: $phoneNumber → allow")
            CallLogStore.log(this, phoneNumber, "allowed", "contact_allowed")
            notifyFlutter("contact_allowed", phoneNumber)
            respondAllow(callDetails)
            return
        }

        // 2. Whitelisted (previously approved by user) → allow
        if (isWhitelisted(phoneNumber)) {
            Log.d(TAG, "Whitelisted: $phoneNumber → allow")
            CallLogStore.log(this, phoneNumber, "allowed", "whitelist_allowed")
            notifyFlutter("whitelist_allowed", phoneNumber)
            respondAllow(callDetails)
            return
        }

        // 3. Blocklisted → reject completely
        if (isBlocklisted(phoneNumber)) {
            Log.d(TAG, "Blocklisted: $phoneNumber → reject")
            CallLogStore.log(this, phoneNumber, "blocked", "blocklist_rejected")
            notifyFlutter("blocklist_rejected", phoneNumber)
            respondReject(callDetails)
            return
        }

        // 4. Unknown → silence (no ring, shows as missed call)
        Log.d(TAG, "Unknown: $phoneNumber → silence")
        CallLogStore.log(this, phoneNumber, "blocked", "unknown_silenced")
        notifyFlutter("unknown_silenced", phoneNumber)
        respondSilence(callDetails)
    }

    private fun respondAllow(callDetails: Call.Details) {
        respondToCall(callDetails, CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build())
    }

    private fun respondReject(callDetails: Call.Details) {
        respondToCall(callDetails, CallResponse.Builder()
            .setDisallowCall(true)
            .setRejectCall(true)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build())
    }

    private fun respondSilence(callDetails: Call.Details) {
        // Silence the ringer but still show in call log as missed call.
        // The call will go to voicemail if configured.
        respondToCall(callDetails, CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSilenceCall(true)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build())
    }

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

    private fun isBlocklisted(phoneNumber: String): Boolean {
        return checkNumberInSet(phoneNumber, "blocklist", "numbers")
    }

    private fun isWhitelisted(phoneNumber: String): Boolean {
        return checkNumberInSet(phoneNumber, "whitelist", "numbers")
    }

    /**
     * Check if a phone number exists in a SharedPreferences string set,
     * using last-9-digit matching to handle country code variations.
     */
    private fun checkNumberInSet(phoneNumber: String, prefsName: String, key: String): Boolean {
        return try {
            val prefs = getSharedPreferences(prefsName, MODE_PRIVATE)
            val numbers = prefs.getStringSet(key, emptySet()) ?: emptySet()
            val normalized = phoneNumber.replace(Regex("[^\\d]"), "")
            val suffix = if (normalized.length > 9) normalized.takeLast(9) else normalized
            numbers.any { stored ->
                val storedNorm = stored.replace(Regex("[^\\d]"), "")
                val storedSuffix = if (storedNorm.length > 9) storedNorm.takeLast(9) else storedNorm
                storedNorm == normalized || storedSuffix == suffix
            }
        } catch (e: Exception) {
            Log.e(TAG, "Number set check error", e)
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
}
