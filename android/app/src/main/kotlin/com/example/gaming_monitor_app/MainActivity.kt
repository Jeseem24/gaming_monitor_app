package com.example.gaming_monitor_app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL_USAGE = "usage_access"
    private val CHANNEL_SERVICE = "game_detection"
    // Match Dart: Flutter listens on "game_events"
    private val CHANNEL_EVENTS = "game_events"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Cache engine so service can use MethodChannel
        FlutterEngineCache
            .getInstance()
            .put("my_engine", flutterEngine)

        // -------------------------------------------------------
        // 1. OPEN USAGE ACCESS SETTINGS
        // -------------------------------------------------------
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_USAGE
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "open_settings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }

        // -------------------------------------------------------
        // 2. START BACKGROUND SERVICE
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

                else -> result.notImplemented()
            }
        }

        // -------------------------------------------------------
        // 3. PREPARE CHANNEL FOR GAME EVENTS (KOTLIN → FLUTTER)
        // -------------------------------------------------------
        // Create the MethodChannel instance so Flutter side can listen.
        // No handler is needed here — service will invoke methods on this channel.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_EVENTS
        )
    }
}
