package com.spamcallblocker.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.app.role.RoleManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build

class MainActivity : FlutterActivity() {
    private val SCREENING_CHANNEL = "com.spamcallblocker.app/screening"
    private val INCALL_CHANNEL = "com.spamcallblocker.app/incall"
    private val CALL_EVENTS_CHANNEL = "com.spamcallblocker.app/call_events"
    private val REQUEST_SCREENING_ROLE = 1001

    private var eventSink: EventChannel.EventSink? = null
    private var callEventReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Event channel for call screening events (from native service → Flutter)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CALL_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerCallEventReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterCallEventReceiver()
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestScreeningRole" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val roleManager = getSystemService(RoleManager::class.java)
                            if (roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
                                if (roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) {
                                    result.success(true)
                                } else {
                                    val intent = roleManager.createRequestRoleIntent(
                                        RoleManager.ROLE_CALL_SCREENING
                                    )
                                    startActivityForResult(intent, REQUEST_SCREENING_ROLE)
                                    result.success(true)
                                }
                            } else {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "drainPendingCallLogs" -> {
                        val entries = CallLogStore.drainPending(this@MainActivity)
                        result.success(entries)
                    }
                    "syncBlocklist" -> {
                        val numbers = call.argument<List<String>>("numbers") ?: emptyList()
                        val prefs = getSharedPreferences("blocklist", MODE_PRIVATE)
                        prefs.edit().putStringSet("numbers", numbers.toSet()).apply()
                        result.success(true)
                    }
                    "syncWhitelist" -> {
                        val numbers = call.argument<List<String>>("numbers") ?: emptyList()
                        val prefs = getSharedPreferences("whitelist", MODE_PRIVATE)
                        prefs.edit().putStringSet("numbers", numbers.toSet()).apply()
                        result.success(true)
                    }
                    "hasScreeningRole" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                            val roleManager = getSystemService(RoleManager::class.java)
                            result.success(
                                roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
                            )
                        } else {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INCALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestInCallRole" -> result.success(true)
                    "endCall" -> result.success(null)
                    "answerCall" -> result.success(null)
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerCallEventReceiver() {
        callEventReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val action = intent?.getStringExtra("action") ?: return
                val phoneNumber = intent.getStringExtra("phoneNumber") ?: return
                eventSink?.success(mapOf(
                    "action" to action,
                    "phoneNumber" to phoneNumber
                ))
            }
        }
        val filter = IntentFilter("com.spamcallblocker.app.CALL_EVENT")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(callEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(callEventReceiver, filter)
        }
    }

    private fun unregisterCallEventReceiver() {
        callEventReceiver?.let {
            unregisterReceiver(it)
            callEventReceiver = null
        }
    }

    override fun onDestroy() {
        unregisterCallEventReceiver()
        super.onDestroy()
    }
}
