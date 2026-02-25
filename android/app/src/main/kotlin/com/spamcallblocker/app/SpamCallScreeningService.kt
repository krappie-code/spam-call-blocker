package com.spamcallblocker.app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi

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

        // Check if the caller is in the user's contacts
        if (isContact(phoneNumber)) {
            Log.d(TAG, "Caller is a contact, allowing: $phoneNumber")
            respondAllow(callDetails)
            // Notify Flutter to log this call
            notifyFlutter("contact_allowed", phoneNumber)
        } else {
            Log.d(TAG, "Unknown caller, allowing through for challenge: $phoneNumber")
            // IMPORTANT: We allow ALL calls through. The challenge happens
            // AFTER the call is answered, via the InCallService / Flutter.
            // The CallScreeningService can't play audio or wait for input.
            respondAllow(callDetails)
            // Notify Flutter that an unknown caller needs to be challenged
            notifyFlutter("challenge_needed", phoneNumber)
        }
    }

    private fun respondAllow(callDetails: Call.Details) {
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()
        respondToCall(callDetails, response)
    }

    /**
     * Send an event to Flutter via a broadcast that MainActivity listens for.
     */
    private fun notifyFlutter(action: String, phoneNumber: String) {
        val intent = Intent("com.spamcallblocker.app.CALL_EVENT").apply {
            putExtra("action", action)
            putExtra("phoneNumber", phoneNumber)
            setPackage(packageName)
        }
        sendBroadcast(intent)
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
}
