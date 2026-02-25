package com.spamcallblocker.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.role.RoleManager
import android.content.Intent
import android.os.Build

class MainActivity : FlutterActivity() {
    private val SCREENING_CHANNEL = "com.spamcallblocker.app/screening"
    private val INCALL_CHANNEL = "com.spamcallblocker.app/incall"
    private val REQUEST_SCREENING_ROLE = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
}
