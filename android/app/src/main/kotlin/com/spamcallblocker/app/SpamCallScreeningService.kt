package com.spamcallblocker.app

import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.Q)
class SpamCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        val phoneNumber = callDetails.handle?.schemeSpecificPart ?: ""

        // For the MVP, we respond via the Flutter engine through platform channels.
        // In a production app, this service would communicate with the Flutter isolate
        // or use shared preferences / database directly.
        
        // Default: allow all calls and let Flutter-side logic handle screening
        // via the MethodChannel when the app is in the foreground.
        val response = CallResponse.Builder()
            .setDisallowCall(false)
            .setRejectCall(false)
            .setSkipCallLog(false)
            .setSkipNotification(false)
            .build()

        respondToCall(callDetails, response)
    }
}
