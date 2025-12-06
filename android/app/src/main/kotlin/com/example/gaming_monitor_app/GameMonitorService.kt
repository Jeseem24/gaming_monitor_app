package com.example.gaming_monitor_app

import android.app.*
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.text.SimpleDateFormat
import java.util.*
import kotlin.concurrent.timerTask

class GameMonitorService : Service() {

    private val CHANNEL_ID = "game_monitor_channel"
    private val LOG_TAG = "GAME_SERVICE"

    // session tracking
    private var lastPackage: String? = null
    private var lastStartTime: Long = 0
    private var detectionTimer: Timer? = null

    private val tsFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())

    override fun onCreate() {
        super.onCreate()
        log("SERVICE CREATED")
        createNotificationChannel()
        startForegroundNotification()
        startDetectionLoop()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        log("SERVICE STARTED")
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)

        val restartIntent = Intent(applicationContext, GameMonitorService::class.java)
        startService(restartIntent)

        log("TASK REMOVED → SERVICE RESTARTED")
    }

    override fun onDestroy() {
        super.onDestroy()
        log("SERVICE DESTROYED")

        detectionTimer?.cancel()
        detectionTimer = null

        try { stopForeground(true) } catch (_: Exception) {}
    }

    // -----------------------------------------------------------------------
    // Create notification channel
    // -----------------------------------------------------------------------
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                CHANNEL_ID,
                "Game Monitor",
                NotificationManager.IMPORTANCE_LOW
            )
            chan.enableLights(false)
            chan.enableVibration(false)

            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(chan)
        }
    }

    private fun startForegroundNotification() {
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Monitoring Active")
            .setContentText("Tracking gameplay in background...")
            .setOngoing(true)
            .build()

        startForeground(1, notification)
        log("FOREGROUND NOTIFICATION ACTIVE")
    }

    // -----------------------------------------------------------------------
    // Parent override
    // -----------------------------------------------------------------------
    private fun readParentOverride(pkg: String): String? {
        return try {
            val prefs = getSharedPreferences("installed_overrides", MODE_PRIVATE)
            prefs.getString("override_pkg_$pkg", null)
        } catch (e: Exception) {
            log("Override read error: ${e.message}")
            null
        }
    }

    // -----------------------------------------------------------------------
    // Is Game ?
    // -----------------------------------------------------------------------
    private fun isGameApp(pkg: String): Boolean {
        // Parent override wins
        val override = readParentOverride(pkg)
        if (override != null) return override == "game"

        return try {
            val info = packageManager.getApplicationInfo(pkg, 0)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                if (info.category == ApplicationInfo.CATEGORY_GAME) return true
            }

            val label = packageManager.getApplicationLabel(info).toString().lowercase()
            val keywords = listOf("game", "battle", "fight", "arena", "clash", "royale")
            if (keywords.any { label.contains(it) }) return true

            val pk = pkg.lowercase()
            val pkgKeys = listOf("ff", "bgmi", "pubg", "clash", "arena")
            if (pkgKeys.any { pk.contains(it) }) return true

            false
        } catch (_: Exception) {
            false
        }
    }

    // -----------------------------------------------------------------------
    // Detection loop
    // -----------------------------------------------------------------------
    private fun startDetectionLoop() {
        detectionTimer?.cancel()
        detectionTimer = Timer()

        detectionTimer!!.scheduleAtFixedRate(
            timerTask { detectApp() },
            0,
            4000
        )

        log("DETECTION LOOP STARTED (every 4s)")
    }

    private fun detectApp() {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()

            val stats = usm.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                now - 20000, now
            )

            if (stats.isNullOrEmpty()) return

            val recent = stats.maxByOrNull { it.lastTimeUsed } ?: return
            val currentPackage = recent.packageName ?: return

            if (currentPackage.contains("launcher") || currentPackage.contains("systemui"))
                return

            if (currentPackage != lastPackage) {
                val nowTs = now

                if (lastPackage != null) {
                    val duration = (nowTs - lastStartTime) / 1000
                    val isGame = isGameApp(lastPackage!!)

                    if (isGame) {
                        insertEventToDatabase(lastPackage!!, lastStartTime, nowTs, duration)
                        sendEventToFlutter(lastPackage!!, lastStartTime, nowTs, duration)
                        log("GAME CLOSED → ${lastPackage} | ${duration}s")
                    }
                }

                lastPackage = currentPackage
                lastStartTime = nowTs

                log("APP STARTED → $currentPackage")
            }

        } catch (e: Exception) {
            log("Detection error: ${e.message}")
        }
    }

    // -----------------------------------------------------------------------
    // DIRECT DATABASE INSERT for RELIABLE STORAGE
    // -----------------------------------------------------------------------
    private fun insertEventToDatabase(pkg: String, start: Long, end: Long, duration: Long) {
        try {
            val db = openOrCreateDatabase("gaming_monitor.db", MODE_PRIVATE, null)

            db.execSQL("""
                CREATE TABLE IF NOT EXISTS game_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT,
                    package_name TEXT NOT NULL,
                    game_name TEXT,
                    genre TEXT,
                    start_time TEXT NOT NULL,
                    end_time TEXT NOT NULL,
                    duration INTEGER NOT NULL,
                    timestamp TEXT NOT NULL,
                    synced INTEGER NOT NULL DEFAULT 0
                )
            """)

            db.execSQL("""
                INSERT INTO game_events (
                    user_id, package_name, start_time, end_time, duration, timestamp
                ) VALUES (?, ?, ?, ?, ?, ?)
            """, arrayOf(
                "demo_user_1",
                pkg,
                start.toString(),
                end.toString(),
                duration,
                end.toString()
            ))

            log("DB EVENT SAVED → $pkg | ${duration}s")

        } catch (e: Exception) {
            log("DB INSERT ERROR: ${e.message}")
        }
    }

    // -----------------------------------------------------------------------
    // Send event to Flutter (optional)
    // -----------------------------------------------------------------------
    private fun sendEventToFlutter(pkg: String, start: Long, end: Long, duration: Long) {
        try {
            val engine = FlutterEngineCache.getInstance()["my_engine"]
            if (engine == null) {
                log("Flutter engine missing → event saved but not forwarded")
                return
            }

            Handler(Looper.getMainLooper()).post {
                MethodChannel(engine.dartExecutor.binaryMessenger, "game_events")
                    .invokeMethod(
                        "log_event",
                        mapOf(
                            "package_name" to pkg,
                            "start_time" to start,
                            "end_time" to end,
                            "duration" to duration,
                            "timestamp" to end
                        )
                    )
            }

        } catch (e: Exception) {
            log("sendEventToFlutter error: ${e.message}")
        }
    }

    // -----------------------------------------------------------------------
    // Logging
    // -----------------------------------------------------------------------
    private fun log(msg: String) {
        Log.i(LOG_TAG, "[$LOG_TAG] $msg")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
