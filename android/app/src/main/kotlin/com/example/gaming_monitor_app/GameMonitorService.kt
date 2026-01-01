package com.example.gaming_monitor_app

import android.app.*
import android.content.Intent
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.*
import kotlin.concurrent.timerTask
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

class GameMonitorService : Service() {

    private val CHANNEL_ID = "game_monitor_channel"
    private val LOG_TAG = "GAME_SERVICE"

    private var lastPackage: String? = null
    private var lastGamePackage: String? = null  // ✅ NEW: Track last GAME specifically
    private var lastStartTime: Long = 0
    private var lastHeartbeatTime: Long = 0 
    private var detectionTimer: Timer? = null
    
    // ✅ NEW: Debounce mechanism to prevent false STOP events
    private var pendingStopPackage: String? = null
    private var pendingStopTime: Long = 0
    private val STOP_DEBOUNCE_MS = 8000L  // Wait 8 seconds before confirming STOP

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
        val restartIntent = Intent(applicationContext, GameMonitorService::class.java).also { 
            it.setPackage(packageName) 
        }
        val pendingIntent = PendingIntent.getService(
            this, 1, restartIntent, 
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        )
        (getSystemService(Context.ALARM_SERVICE) as AlarmManager).set(
            AlarmManager.RTC, 
            System.currentTimeMillis() + 1000, 
            pendingIntent
        )
        log("TASK REMOVED → PERSISTENCE ALARM SET")
    }

    override fun onDestroy() {
        log("SERVICE DESTROYED")
        detectionTimer?.cancel()
        detectionTimer = null
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val chan = NotificationChannel(
                CHANNEL_ID, 
                "Game Monitor Service", 
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(chan)
        }
    }

    private fun startForegroundNotification() {
        updateNotification(null)
    }

    private fun updateNotification(gameName: String?) {
        val content = if (gameName != null) "Monitoring: $gameName" else "Tracking gameplay in background..."
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Monitoring Active")
            .setContentText(content)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
        startForeground(1, notification)
    }

    private fun isGameApp(pkg: String): Boolean {
        return try {
            // Skip system packages that cause false detections
            if (pkg.contains("launcher") || 
                pkg.contains("systemui") || 
                pkg.contains("nexuslauncher") ||
                pkg.contains("home") ||
                pkg == packageName) {  // Skip our own app
                return false
            }
            
            val prefs = getSharedPreferences("installed_overrides", MODE_PRIVATE)
            val override = prefs.getString("override_pkg_$pkg", null)
            if (override != null) return override == "game"
            
            val info = packageManager.getApplicationInfo(pkg, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && 
                info.category == ApplicationInfo.CATEGORY_GAME) return true
            
            val label = packageManager.getApplicationLabel(info).toString().lowercase()
            val keywords = listOf(
                "game", "battle", "fight", "arena", "clash", "royale", 
                "pubg", "bgmi", "snake", "chess", "puzzle", "racing",
                "shooter", "rpg", "mmorpg", "casino", "slots", "poker"
            )
            keywords.any { label.contains(it) || pkg.lowercase().contains(it) }
        } catch (_: Exception) { false }
    }

    private fun resolveAppName(pkg: String): String {
        return try {
            val info = packageManager.getApplicationInfo(pkg, 0)
            packageManager.getApplicationLabel(info).toString()
        } catch (e: Exception) { pkg }
    }

    private fun startDetectionLoop() {
        detectionTimer?.cancel()
        detectionTimer = Timer()
        detectionTimer!!.scheduleAtFixedRate(timerTask { detectApp() }, 0, 4000)
        log("DETECTION LOOP STARTED")
    }

    private fun detectApp() {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 10000, now)

            if (stats.isNullOrEmpty()) {
                log("No usage stats available")
                return
            }
            
            val recent = stats.maxByOrNull { it.lastTimeUsed } ?: return
            val currentPackage = recent.packageName ?: return

            // ✅ Skip system packages entirely
            if (currentPackage.contains("launcher") || 
                currentPackage.contains("systemui") ||
                currentPackage.contains("inputmethod") ||
                currentPackage.contains("keyboard")) {
                return
            }

            val currentIsGame = isGameApp(currentPackage)
            
            // ✅ NEW: Handle pending STOP with debounce
            if (pendingStopPackage != null) {
                if (currentPackage == pendingStopPackage || 
                    (currentIsGame && currentPackage == lastGamePackage)) {
                    // User went back to the game - cancel pending stop
                    log("DEBOUNCE: User returned to game, cancelling STOP")
                    pendingStopPackage = null
                    pendingStopTime = 0
                } else if (now - pendingStopTime >= STOP_DEBOUNCE_MS) {
                    // Debounce time passed - confirm STOP
                    val stoppedPackage = pendingStopPackage!!
                    val appName = resolveAppName(stoppedPackage)
                    val sessionDurationSeconds = if (lastStartTime > 0) {
                        ((pendingStopTime - lastStartTime) / 1000).coerceAtLeast(0)
                    } else { 0L }
                    
                    log("DEBOUNCE: Confirmed STOP for $appName after ${sessionDurationSeconds}s")
                    
                    processEvent(
                        pkg = stoppedPackage,
                        name = appName,
                        status = "STOP",
                        durationSeconds = sessionDurationSeconds,
                        startTime = lastStartTime,
                        endTime = pendingStopTime
                    )
                    
                    lastGamePackage = null
                    lastStartTime = 0
                    pendingStopPackage = null
                    pendingStopTime = 0
                    updateNotification(null)
                }
            }

            // ✅ Detect package change
            if (currentPackage != lastPackage) {
                log("Package changed: $lastPackage → $currentPackage (isGame: $currentIsGame)")
                
                // If we were playing a game and switched to something else
                if (lastGamePackage != null && !currentIsGame && currentPackage != lastGamePackage) {
                    // Don't send STOP immediately - set pending with debounce
                    if (pendingStopPackage == null) {
                        pendingStopPackage = lastGamePackage
                        pendingStopTime = now
                        log("DEBOUNCE: Pending STOP for $lastGamePackage (waiting ${STOP_DEBOUNCE_MS}ms)")
                    }
                }

                // If current app is a game and it's NEW (not the pending stop)
                if (currentIsGame && currentPackage != pendingStopPackage) {
                    // If there was a pending stop for a different game, process it immediately
                    if (pendingStopPackage != null && pendingStopPackage != currentPackage) {
                        val stoppedPkg = pendingStopPackage!!
                        val stoppedName = resolveAppName(stoppedPkg)
                        val sessionDuration = if (lastStartTime > 0) {
                            ((now - lastStartTime) / 1000).coerceAtLeast(0)
                        } else { 0L }
                        
                        processEvent(
                            pkg = stoppedPkg,
                            name = stoppedName,
                            status = "STOP",
                            durationSeconds = sessionDuration,
                            startTime = lastStartTime,
                            endTime = now
                        )
                        pendingStopPackage = null
                        pendingStopTime = 0
                    }
                    
                    // Start tracking new game
                    val appName = resolveAppName(currentPackage)
                    lastGamePackage = currentPackage
                    lastStartTime = now
                    lastHeartbeatTime = now
                    
                    processEvent(
                        pkg = currentPackage,
                        name = appName,
                        status = "START",
                        durationSeconds = 0,
                        startTime = now,
                        endTime = now
                    )
                    updateNotification(appName)
                    log("GAME STARTED: $appName")
                }

                lastPackage = currentPackage
            } 
            // ✅ Same game still running - send heartbeat
            else if (currentIsGame && currentPackage == lastGamePackage) {
                // Cancel any pending stop since game is still active
                if (pendingStopPackage == currentPackage) {
                    pendingStopPackage = null
                    pendingStopTime = 0
                }
                
                // Send heartbeat every 60 seconds
                if (now - lastHeartbeatTime >= 60000) {
                    val appName = resolveAppName(currentPackage)
                    val heartbeatDurationSeconds = ((now - lastHeartbeatTime) / 1000).coerceAtLeast(60)
                    
                    processEvent(
                        pkg = currentPackage,
                        name = appName,
                        status = "HEARTBEAT",
                        durationSeconds = heartbeatDurationSeconds,
                        startTime = lastStartTime,
                        endTime = now
                    )
                    lastHeartbeatTime = now
                    log("HEARTBEAT: $appName (${heartbeatDurationSeconds}s)")
                }
            }
        } catch (e: Exception) { 
            log("Detection error: ${e.message}") 
        }
    }

    private fun processEvent(
        pkg: String, 
        name: String, 
        status: String, 
        durationSeconds: Long, 
        startTime: Long, 
        endTime: Long
    ) {
        Thread {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val childId = prefs.getString("flutter.selected_child_id", "child_101")
                ?.replace("\"", "") ?: "child_101"
            
            // Convert to minutes for backend
            val durationMinutes = when (status) {
                "START" -> 0
                "HEARTBEAT" -> 1
                "STOP" -> (durationSeconds / 60).coerceAtLeast(1).toInt()
                else -> 0
            }
            
            val json = JSONObject()
            json.put("user_id", childId)
            json.put("childdeviceid", "android_$childId")
            json.put("status", status)
            json.put("package_name", pkg)
            json.put("game_name", name)
            json.put("duration", durationMinutes)
            json.put("start_time", startTime)
            json.put("end_time", endTime)
            json.put("timestamp", endTime)

            val success = sendHttpRequest(json.toString())
            
            insertEventToDatabase(
                childId, pkg, name, status, durationSeconds, 
                startTime, endTime, if (success) 1 else 0
            )

            if (success) syncPendingOldRecords(childId)
            sendEventToFlutter(pkg, name, status, durationSeconds, endTime)
            
            log("SYNC ($status): $name, Duration=${durationMinutes}min, Success=$success")
        }.start()
    }

    private fun sendHttpRequest(jsonBody: String): Boolean {
        return try {
            val url = URL("https://gaming-twin-backend.onrender.com/events")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("X-API-KEY", "secret")
            conn.connectTimeout = 10000
            conn.readTimeout = 10000
            conn.doOutput = true
            conn.outputStream.write(jsonBody.toByteArray())
            val code = conn.responseCode
            conn.disconnect()
            code == 200 || code == 201
        } catch (e: Exception) { 
            log("HTTP Error: ${e.message}")
            false 
        }
    }

    private fun syncPendingOldRecords(childId: String) {
        var db: android.database.sqlite.SQLiteDatabase? = null
        try {
            db = openOrCreateDatabase("gaming_monitor.db", MODE_PRIVATE, null)
            val cursor = db.rawQuery("SELECT * FROM game_events WHERE synced = 0 LIMIT 20", null)
            
            if (cursor.moveToFirst()) {
                do {
                    val id = cursor.getInt(cursor.getColumnIndexOrThrow("id"))
                    val status = cursor.getString(cursor.getColumnIndexOrThrow("status")) ?: "HEARTBEAT"
                    val durationSeconds = cursor.getLong(cursor.getColumnIndexOrThrow("duration"))
                    
                    val durationMinutes = when (status) {
                        "START" -> 0
                        "HEARTBEAT" -> 1
                        "STOP" -> (durationSeconds / 60).coerceAtLeast(1)
                        else -> 0
                    }
                    
                    val startTime = try {
                        cursor.getLong(cursor.getColumnIndexOrThrow("start_time"))
                    } catch (e: Exception) {
                        cursor.getLong(cursor.getColumnIndexOrThrow("timestamp"))
                    }
                    
                    val endTime = try {
                        cursor.getLong(cursor.getColumnIndexOrThrow("end_time"))
                    } catch (e: Exception) {
                        cursor.getLong(cursor.getColumnIndexOrThrow("timestamp"))
                    }

                    val json = JSONObject()
                    json.put("user_id", childId)
                    json.put("childdeviceid", "android_$childId")
                    json.put("status", status)
                    json.put("package_name", cursor.getString(cursor.getColumnIndexOrThrow("package_name")))
                    json.put("game_name", cursor.getString(cursor.getColumnIndexOrThrow("game_name")))
                    json.put("duration", durationMinutes)
                    json.put("start_time", startTime)
                    json.put("end_time", endTime)
                    json.put("timestamp", endTime)

                    if (sendHttpRequest(json.toString())) {
                        db.execSQL("UPDATE game_events SET synced = 1 WHERE id = $id")
                        log("RESTORED: Synced offline event ID $id")
                    }
                } while (cursor.moveToNext())
            }
            cursor.close()
        } catch (e: Exception) {
            log("Sync pending error: ${e.message}")
        } finally { 
            db?.close() 
        }
    }

    private fun insertEventToDatabase(
        userId: String, 
        pkg: String, 
        gameName: String, 
        status: String, 
        durationSeconds: Long,
        startTime: Long,
        endTime: Long,
        synced: Int
    ) {
        var db: android.database.sqlite.SQLiteDatabase? = null
        try {
            db = openOrCreateDatabase("gaming_monitor.db", MODE_PRIVATE, null)
            db.execSQL("""
                CREATE TABLE IF NOT EXISTS game_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT, 
                    user_id TEXT, 
                    package_name TEXT NOT NULL, 
                    game_name TEXT, 
                    genre TEXT, 
                    start_time INTEGER,
                    end_time INTEGER,
                    duration INTEGER NOT NULL, 
                    timestamp INTEGER NOT NULL,
                    status TEXT, 
                    synced INTEGER NOT NULL DEFAULT 0
                )
            """)
            
            db.execSQL(
                """INSERT INTO game_events 
                   (user_id, package_name, game_name, duration, start_time, end_time, timestamp, status, synced) 
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                arrayOf(userId, pkg, gameName, durationSeconds, startTime, endTime, endTime, status, synced)
            )
        } catch (e: Exception) { 
            log("DB Error: ${e.message}") 
        } finally { 
            db?.close() 
        }
    }

    private fun sendEventToFlutter(pkg: String, gameName: String, status: String, duration: Long, timestamp: Long) {
        try {
            val engine = FlutterEngineCache.getInstance()["preloaded_engine"] ?: return
            Handler(Looper.getMainLooper()).post {
                MethodChannel(engine.dartExecutor.binaryMessenger, "game_detection")
                    .invokeMethod("log_event", mapOf(
                        "package_name" to pkg, 
                        "game_name" to gameName, 
                        "status" to status, 
                        "duration" to duration, 
                        "timestamp" to timestamp
                    ))
            }
        } catch (_: Exception) {}
    }

    private fun log(msg: String) { 
        Log.i(LOG_TAG, "[$LOG_TAG] $msg") 
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
}