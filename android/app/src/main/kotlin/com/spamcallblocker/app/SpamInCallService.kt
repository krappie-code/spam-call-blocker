package com.spamcallblocker.app

import android.telecom.Call
import android.telecom.InCallService

/**
 * InCallService fallback for Android 8-9 (API 26-28).
 * Provides basic call control capabilities.
 */
class SpamInCallService : InCallService() {

    override fun onCallAdded(call: Call?) {
        super.onCallAdded(call)
        // In a full implementation, this would communicate with the Flutter engine
        // to perform challenge-response screening.
    }

    override fun onCallRemoved(call: Call?) {
        super.onCallRemoved(call)
    }
}
