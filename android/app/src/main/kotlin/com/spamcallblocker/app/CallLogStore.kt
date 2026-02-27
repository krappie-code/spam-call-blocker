package com.spamcallblocker.app

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Lightweight native call log that persists events to SharedPreferences.
 * This ensures calls are logged even when Flutter/MainActivity is not active.
 * Flutter syncs these entries to SQLite on next app open.
 */
object CallLogStore {
    private const val TAG = "CallLogStore"
    private const val PREFS_NAME = "call_log_native"
    private const val KEY_PENDING = "pending_entries"

    data class Entry(
        val phoneNumber: String,
        val timestamp: Long,
        val result: String, // "allowed", "blocked", "challengePassed", "challengeFailed"
        val action: String  // original action for Flutter event channel
    )

    private fun getPrefs(context: Context): SharedPreferences {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    /**
     * Log a call event. Safe to call from any service, even when Flutter is dead.
     */
    fun log(context: Context, phoneNumber: String, result: String, action: String) {
        try {
            val prefs = getPrefs(context)
            val existing = prefs.getString(KEY_PENDING, "[]") ?: "[]"
            val array = JSONArray(existing)

            val entry = JSONObject().apply {
                put("phoneNumber", phoneNumber)
                put("timestamp", System.currentTimeMillis())
                put("result", result)
                put("action", action)
            }
            array.put(entry)

            prefs.edit().putString(KEY_PENDING, array.toString()).apply()
            Log.d(TAG, "Logged call: $phoneNumber → $result (${array.length()} pending)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to log call", e)
        }
    }

    /**
     * Get all pending entries and clear them.
     * Called by Flutter on app open to sync to SQLite.
     */
    fun drainPending(context: Context): List<Map<String, Any>> {
        try {
            val prefs = getPrefs(context)
            val existing = prefs.getString(KEY_PENDING, "[]") ?: "[]"
            val array = JSONArray(existing)

            if (array.length() == 0) return emptyList()

            val entries = mutableListOf<Map<String, Any>>()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                entries.add(mapOf(
                    "phoneNumber" to obj.getString("phoneNumber"),
                    "timestamp" to obj.getLong("timestamp"),
                    "result" to obj.getString("result"),
                    "action" to obj.getString("action")
                ))
            }

            // Clear pending
            prefs.edit().putString(KEY_PENDING, "[]").apply()
            Log.d(TAG, "Drained ${entries.size} pending entries")
            return entries
        } catch (e: Exception) {
            Log.e(TAG, "Failed to drain pending", e)
            return emptyList()
        }
    }
}
