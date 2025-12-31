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
    private var lastStartTime: Long = 0
    private var lastHeartbeatTime: Long = 0 
    private var detectionTimer: Timer? = null

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
        val restartIntent = Intent(applicationContext, GameMonitorService::class.java).also { it.setPackage(packageName) }
        val pendingIntent = PendingIntent.getService(this, 1, restartIntent, if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        (getSystemService(Context.ALARM_SERVICE) as AlarmManager).set(AlarmManager.RTC, System.currentTimeMillis() + 1000, pendingIntent)
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
            val chan = NotificationChannel(CHANNEL_ID, "Game Monitor Service", NotificationManager.IMPORTANCE_LOW)
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
            val prefs = getSharedPreferences("installed_overrides", MODE_PRIVATE)
            val override = prefs.getString("override_pkg_$pkg", null)
            if (override != null) return override == "game"
            val info = packageManager.getApplicationInfo(pkg, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && info.category == ApplicationInfo.CATEGORY_GAME) return true
            val label = packageManager.getApplicationLabel(info).toString().lowercase()
            val keywords = listOf("game", "battle", "fight", "arena", "clash", "royale", "pubg", "bgmi", "snake")
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
            val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, now - 20000, now)

            if (stats.isNullOrEmpty()) return
            val recent = stats.maxByOrNull { it.lastTimeUsed } ?: return
            val currentPackage = recent.packageName ?: return

            if (currentPackage.contains("launcher") || currentPackage.contains("systemui")) return

            val currentIsGame = isGameApp(currentPackage)

            if (currentPackage != lastPackage) {
                if (lastPackage != null && isGameApp(lastPackage!!)) {
                    val appName = resolveAppName(lastPackage!!)
                    processEvent(lastPackage!!, appName, "STOP", 0, now)
                }

                if (currentIsGame) {
                    val appName = resolveAppName(currentPackage)
                    processEvent(currentPackage, appName, "START", 0, now)
                    lastHeartbeatTime = now
                    updateNotification(appName)
                } else {
                    updateNotification(null)
                }

                lastPackage = currentPackage
                lastStartTime = now
            } 
            else if (currentIsGame) {
                if (now - lastHeartbeatTime >= 60000) {
                    val appName = resolveAppName(currentPackage)
                    processEvent(currentPackage, appName, "HEARTBEAT", 1, now)
                    lastHeartbeatTime = now
                }
            }
        } catch (e: Exception) { log("Detection error: ${e.message}") }
    }

    private fun processEvent(pkg: String, name: String, status: String, duration: Long, timestamp: Long) {
        // Run network and DB tasks on background thread
        Thread {
            val prefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            val childId = prefs.getString("flutter.selected_child_id", "child_101")?.replace("\"", "") ?: "child_101"
            
            // 1. Prepare JSON
            val json = JSONObject()
            json.put("user_id", childId)
            json.put("childdeviceid", "android_$childId")
            json.put("status", status)
            json.put("package_name", pkg)
            json.put("game_name", name)
            json.put("duration", duration)
            json.put("start_time", timestamp)
            json.put("end_time", timestamp)
            json.put("timestamp", timestamp)

            // 2. Try to sync to backend
            val success = sendHttpRequest(json.toString())

            // 3. Save to Database (mark as synced if HTTP succeeded)
            insertEventToDatabase(childId, pkg, name, status, duration, timestamp, if (success) 1 else 0)

            // 4. If internet is back, try to clear out any old unsynced packets
            if (success) syncPendingOldRecords(childId)

            // 5. Tell Flutter to refresh UI (if it's awake)
            sendEventToFlutter(pkg, name, status, duration, timestamp)
            
            log("NATIVE SYNC ($status): Success=$success")
        }.start()
    }

    private fun sendHttpRequest(jsonBody: String): Boolean {
        return try {
            val url = URL("https://gaming-twin-backend.onrender.com/events")
            val conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("X-API-KEY", "secret")
            conn.connectTimeout = 8000
            conn.doOutput = true
            conn.outputStream.write(jsonBody.toByteArray())
            val code = conn.responseCode
            conn.disconnect()
            code == 200 || code == 201
        } catch (e: Exception) { false }
    }

    private fun syncPendingOldRecords(childId: String) {
        var db: android.database.sqlite.SQLiteDatabase? = null
        try {
            db = openOrCreateDatabase("gaming_monitor.db", MODE_PRIVATE, null)
            val cursor = db.rawQuery("SELECT * FROM game_events WHERE synced = 0 LIMIT 20", null)
            if (cursor.moveToFirst()) {
                do {
                    val id = cursor.getInt(cursor.getColumnIndex("id"))
                    val json = JSONObject()
                    json.put("user_id", childId)
                    json.put("childdeviceid", "android_$childId")
                    json.put("status", cursor.getString(cursor.getColumnIndex("status")))
                    json.put("package_name", cursor.getString(cursor.getColumnIndex("package_name")))
                    json.put("game_name", cursor.getString(cursor.getColumnIndex("game_name")))
                    json.put("duration", cursor.getInt(cursor.getColumnIndex("duration")))
                    val ts = cursor.getString(cursor.getColumnIndex("timestamp")).toLong()
                    json.put("start_time", ts)
                    json.put("end_time", ts)
                    json.put("timestamp", ts)

                    if (sendHttpRequest(json.toString())) {
                        db.execSQL("UPDATE game_events SET synced = 1 WHERE id = $id")
                        log("RESTORED: Synced old offline event ID $id")
                    }
                } while (cursor.moveToNext())
            }
            cursor.close()
        } catch (_: Exception) {} finally { db?.close() }
    }

    private fun insertEventToDatabase(userId: String, pkg: String, gameName: String, status: String, duration: Long, timestamp: Long, synced: Int) {
        var db: android.database.sqlite.SQLiteDatabase? = null
        try {
            db = openOrCreateDatabase("gaming_monitor.db", MODE_PRIVATE, null)
            db.execSQL("CREATE TABLE IF NOT EXISTS game_events (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id TEXT, package_name TEXT NOT NULL, game_name TEXT, genre TEXT, start_time TEXT, end_time TEXT, duration INTEGER NOT NULL, timestamp TEXT NOT NULL, status TEXT, synced INTEGER NOT NULL DEFAULT 0)")
            
            db.execSQL("INSERT INTO game_events (user_id, package_name, game_name, duration, timestamp, status, synced) VALUES (?, ?, ?, ?, ?, ?, ?)",
                arrayOf(userId, pkg, gameName, duration, timestamp.toString(), status, synced))
        } catch (e: Exception) { log("DB Error: ${e.message}") } 
        finally { db?.close() }
    }

    private fun sendEventToFlutter(pkg: String, gameName: String, status: String, duration: Long, timestamp: Long) {
        try {
            val engine = FlutterEngineCache.getInstance()["preloaded_engine"] ?: return
            Handler(Looper.getMainLooper()).post {
                MethodChannel(engine.dartExecutor.binaryMessenger, "game_detection")
                    .invokeMethod("log_event", mapOf("package_name" to pkg, "game_name" to gameName, "status" to status, "duration" to duration, "timestamp" to timestamp))
            }
        } catch (_: Exception) {}
    }

    private fun log(msg: String) { Log.i(LOG_TAG, "[$LOG_TAG] $msg") }
    override fun onBind(intent: Intent?): IBinder? = null
}