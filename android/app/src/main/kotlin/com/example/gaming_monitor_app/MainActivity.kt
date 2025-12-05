package com.example.gaming_monitor_app

import android.content.Context
import android.content.Intent
import android.app.AppOpsManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL_USAGE = "usage_access"
    private val CHANNEL_SERVICE = "game_detection"
    private val CHANNEL_EVENTS = "game_events"   // Flutter listens here

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache engine so the background service can call Flutter
        FlutterEngineCache
            .getInstance()
            .put("my_engine", flutterEngine)

        // -------------------------------------------------------
        // 1️⃣ USAGE ACCESS PERMISSIONS CHANNEL
        // -------------------------------------------------------
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_USAGE
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // Open Usage Access settings page
                "open_settings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                // NEW: Check if Usage Access permission is granted
                "check_usage" -> {
                    try {
                        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                        val mode = appOps.checkOpNoThrow(
                            AppOpsManager.OPSTR_GET_USAGE_STATS,
                            android.os.Process.myUid(),
                            packageName
                        )
                        val granted = mode == AppOpsManager.MODE_ALLOWED
                        result.success(granted)

                    } catch (e: Exception) {
                        result.error("ERR", "check_usage failed: ${e.message}", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // -------------------------------------------------------
        // 2️⃣ START BACKGROUND SERVICE FROM FLUTTER
        // -------------------------------------------------------
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_SERVICE
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "start_service" -> {
                    println("🔥 START_SERVICE CALLED FROM FLUTTER")

                    val serviceIntent = Intent(this, GameMonitorService::class.java)

                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }

                    result.success("Service Started")
                }

                "stop_service" -> {
    println("🛑 STOP_SERVICE CALLED FROM FLUTTER")

    val serviceIntent = Intent(this, GameMonitorService::class.java)
    stopService(serviceIntent)

    result.success("Service Stopped")
}


                else -> result.notImplemented()
            }
        }

        // -------------------------------------------------------
        // 3️⃣ GAME EVENTS CHANNEL (KOTLIN → FLUTTER)
        // -------------------------------------------------------
        // No handler needed — Flutter listens only.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_EVENTS
        )
    }
}
