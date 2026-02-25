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
 * CallScreeningService (Android 10+).
 * 
 * This service makes a quick decision on incoming calls:
 * - Known contacts → allow through immediately
 * - Unknown callers → allow through (so InCallService can handle the challenge)
 * 
 * The actual challenge-response logic lives in SpamInCallService.
 */
@RequiresApi(Build.VERSION_CODES.Q)
class SpamCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "SpamCallScreening"
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart ?: ""
        Log.d(TAG, "Screening call from: $phoneNumber")

        // Always allow calls through — InCallService handles the challenge
        // for unknown numbers. We just log contacts here for the dashboard.
        if (phoneNumber.isNotEmpty() && isContact(phoneNumber)) {
            Log.d(TAG, "Contact detected: $phoneNumber")
            notifyFlutter("contact_allowed", phoneNumber)
        }

        // Allow all calls through to ring / be handled by InCallService
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()
        respondToCall(callDetails, response)
    }

    private fun notifyFlutter(action: String, phoneNumber: String) {
        val intent = Intent("com.spamcallblocker.app.CALL_EVENT").apply {
            putExtra("action", action)
            putExtra("phoneNumber", phoneNumber)
            setPackage(packageName)
        }
        sendBroadcast(intent)
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
}
