package com.example.gaming_monitor_app

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import android.app.usage.UsageStatsManager
import android.content.Context
import java.util.*
import kotlin.concurrent.timerTask
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel


class GameMonitorService : Service() {

    private val CHANNEL_ID = "game_monitor_channel"

    private var lastPackage: String? = null
    private var lastStartTime: Long = 0

    override fun onCreate() {
        super.onCreate()
        Log.i("GAME_SERVICE", "SERVICE CREATED")

        createNotificationChannel()
        startForegroundNotification()
        startDetectionLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i("GAME_SERVICE", "SERVICE STARTED SUCCESSFULLY")
        return START_STICKY
    }

    // ---------------------------------------------------------
    // GAME / APP DETECTION LOOP
    // ---------------------------------------------------------
    private fun startDetectionLoop() {
        Timer().scheduleAtFixedRate(timerTask {
            detectForegroundApp()
        }, 0, 4000) // 4 sec interval
    }

    private fun detectForegroundApp() {
        val usageStatsManager =
            getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

        val now = System.currentTimeMillis()
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 20000,
            now
        )

        if (stats.isNullOrEmpty()) return

        val recent = stats.maxByOrNull { it.lastTimeUsed } ?: return
        val currentPackage = recent.packageName

        if (currentPackage != lastPackage) {

            // Close previous app/game
            if (lastPackage != null) {
                val durationSec = ((now - lastStartTime) / 1000)

                val event = hashMapOf(
                    "package_name" to lastPackage!!,
                    "start_time" to lastStartTime,
                    "end_time" to now,
                    "duration" to durationSec,
                    "timestamp" to now
                )

                Log.i("GAME_USAGE", "App closed → $lastPackage | Duration: $durationSec sec")

                // SEND EVENT TO FLUTTER → SQLite
                val engine = FlutterEngineCache.getInstance()["my_engine"]
                if (engine != null) {
                    MethodChannel(engine.dartExecutor.binaryMessenger, "game_events")
                        .invokeMethod("log_event", event)
                }
            }

            // New app started
            if (isGame(currentPackage))
                Log.i("GAME_USAGE", "Game started → $currentPackage")
            else
                Log.i("GAME_USAGE", "App started → $currentPackage")

            lastPackage = currentPackage
            lastStartTime = now
        }
    }

    // Simple game detector (extend later)
    private fun isGame(pkg: String): Boolean {
        return pkg.contains("game") ||
                pkg.contains("pubg") ||
                pkg.contains("freefire") ||
                pkg.contains("coc") ||
                pkg.contains("cod") ||
                pkg.contains("madout", ignoreCase = true)
    }

    // ---------------------------------------------------------
    // FOREGROUND NOTIFICATION
    // ---------------------------------------------------------
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Game Monitor Service",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.enableVibration(false)
            channel.enableLights(false)

            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun startForegroundNotification() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Monitoring Active")
            .setContentText("Tracking game usage in background.")
            .setOngoing(true)
            .build()

        startForeground(1, notification)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
