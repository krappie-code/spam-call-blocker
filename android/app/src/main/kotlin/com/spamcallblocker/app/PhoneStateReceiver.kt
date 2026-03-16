package com.spamcallblocker.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.telecom.TelecomManager
import android.telephony.TelephonyManager
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.core.app.NotificationCompat

/**
 * Fallback BroadcastReceiver for PHONE_STATE changes.
 * This fires for ALL incoming calls on all Android devices,
 * regardless of CallScreeningService role status.
 *
 * Used as a safety net when CallScreeningService doesn't fire
 * (e.g., Google Phone app on Pixel overriding the screening role).
 */
class PhoneStateReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "PhoneStateReceiver"
        private const val CHANNEL_ID = "call_screening_debug"
        private const val NOTIFICATION_ID = 9001
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != TelephonyManager.ACTION_PHONE_STATE_CHANGED) return

        val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE) ?: return
        val phoneNumber = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: ""

        Log.d(TAG, "Phone state: $state, number: $phoneNumber")

        if (state != TelephonyManager.EXTRA_STATE_RINGING) return
        if (phoneNumber.isEmpty()) return

        // Check if CallScreeningService already handled this call
        // by looking at the native log store for a recent entry
        val recentlyScreened = wasRecentlyScreened(context, phoneNumber)
        if (recentlyScreened) {
            Log.d(TAG, "Already screened by CallScreeningService: $phoneNumber")
            return
        }

        Log.d(TAG, "CallScreeningService DID NOT fire — using fallback for: $phoneNumber")

        // Check contacts
        if (isContact(context, phoneNumber)) {
            Log.d(TAG, "Contact (fallback): $phoneNumber → allow")
            CallLogStore.log(context, phoneNumber, "allowed", "contact_allowed")
            notifyFlutter(context, "contact_allowed", phoneNumber)
            showDebugNotification(context, "✅ Contact: $phoneNumber")
            return
        }

        // Check whitelist
        if (isInSet(context, phoneNumber, "whitelist", "numbers")) {
            Log.d(TAG, "Whitelisted (fallback): $phoneNumber → allow")
            CallLogStore.log(context, phoneNumber, "allowed", "whitelist_allowed")
            notifyFlutter(context, "whitelist_allowed", phoneNumber)
            showDebugNotification(context, "✅ Whitelisted: $phoneNumber")
            return
        }

        // Check blocklist
        if (isInSet(context, phoneNumber, "blocklist", "numbers")) {
            Log.d(TAG, "Blocklisted (fallback): $phoneNumber → reject")
            CallLogStore.log(context, phoneNumber, "blocked", "blocklist_rejected")
            notifyFlutter(context, "blocklist_rejected", phoneNumber)
            rejectCall(context)
            showDebugNotification(context, "🚫 Blocked: $phoneNumber")
            return
        }

        // Unknown caller → reject
        Log.d(TAG, "Unknown (fallback): $phoneNumber → reject")
        CallLogStore.log(context, phoneNumber, "blocked", "unknown_rejected")
        notifyFlutter(context, "unknown_silenced", phoneNumber)
        rejectCall(context)
        showDebugNotification(context, "🔇 Rejected unknown: $phoneNumber")
    }

    /**
     * Check if this number was recently screened (within last 5 seconds)
     * by the CallScreeningService, to avoid double-processing.
     */
    private fun wasRecentlyScreened(context: Context, phoneNumber: String): Boolean {
        try {
            val prefs = context.getSharedPreferences("call_log_native", Context.MODE_PRIVATE)
            val pending = prefs.getString("pending_entries", "[]") ?: "[]"
            val array = org.json.JSONArray(pending)
            val now = System.currentTimeMillis()
            val normalized = phoneNumber.replace(Regex("[^\\d]"), "")
            val suffix = if (normalized.length > 9) normalized.takeLast(9) else normalized

            for (i in 0 until array.length()) {
                val entry = array.getJSONObject(i)
                val entryTime = entry.getLong("timestamp")
                val entryNumber = entry.getString("phoneNumber").replace(Regex("[^\\d]"), "")
                val entrySuffix = if (entryNumber.length > 9) entryNumber.takeLast(9) else entryNumber

                // If same number logged within last 5 seconds, CSS handled it
                if ((now - entryTime) < 5000 && (entrySuffix == suffix || entryNumber == normalized)) {
                    return true
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error checking recent screens", e)
        }
        return false
    }

    @Suppress("DEPRECATION")
    private fun rejectCall(context: Context) {
        try {
            val telecomManager = context.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                telecomManager.endCall()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reject call", e)
        }
    }

    private fun isContact(context: Context, phoneNumber: String): Boolean {
        return try {
            val uri = Uri.withAppendedPath(
                ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                Uri.encode(phoneNumber)
            )
            val cursor = context.contentResolver.query(
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

    private fun isInSet(context: Context, phoneNumber: String, prefsName: String, key: String): Boolean {
        return try {
            val prefs = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
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

    private fun notifyFlutter(context: Context, action: String, phoneNumber: String) {
        val intent = Intent("com.spamcallblocker.app.CALL_EVENT").apply {
            putExtra("action", action)
            putExtra("phoneNumber", phoneNumber)
            setPackage(context.packageName)
        }
        context.sendBroadcast(intent)
    }

    /**
     * Show a debug notification so the user can see the app is working.
     * This can be removed in production.
     */
    private fun showDebugNotification(context: Context, message: String) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Call Screening Activity",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when calls are screened by the app"
            }
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_call)
            .setContentTitle("Spam Call Blocker")
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setAutoCancel(true)
            .build()

        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
