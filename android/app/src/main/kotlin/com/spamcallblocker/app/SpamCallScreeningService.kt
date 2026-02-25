package com.spamcallblocker.app

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
            // No number available, allow through
            respondAllow(callDetails)
            return
        }

        // Check if the caller is in the user's contacts
        if (isContact(phoneNumber)) {
            Log.d(TAG, "Caller is a contact, allowing: $phoneNumber")
            respondAllow(callDetails)
        } else {
            Log.d(TAG, "Unknown caller, blocking: $phoneNumber")
            // Block unknown callers - they didn't pass the challenge
            // In a full implementation, we'd issue a TTS challenge first.
            // For the MVP, unknown non-contact callers are silently rejected
            // (sent to voicemail) so the user isn't disturbed.
            val response = CallResponse.Builder()
                .setDisallowCall(true)
                .setRejectCall(true)
                .setSkipCallLog(false)
                .setSkipNotification(false)
                .build()
            respondToCall(callDetails, response)
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
     * Check if the given phone number matches any contact on the device.
     * Uses ContactsContract.PhoneLookup for normalized matching.
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
