package com.example.gaming_monitor_app

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {

    // Fast launch using preloaded engine
    override fun provideFlutterEngine(context: Context): FlutterEngine {
        return FlutterEngineCache.getInstance()["preloaded_engine"]!!
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL_INSTALLED = "installed_apps"

        // MEMORY CACHE ONLY → FIXES ICON ISSUE
        val iconCache: MutableMap<String, ByteArray?> = mutableMapOf()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Allow background service to use this engine
        FlutterEngineCache.getInstance().put("my_engine", flutterEngine)

        // ============================================================
        // INSTALLED APPS CHANNEL
        // ============================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_INSTALLED)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "list_installed" -> {
                        GlobalScope.launch(Dispatchers.IO) {
                            val apps = fetchInstalledApps()
                            withContext(Dispatchers.Main) { result.success(apps) }
                        }
                    }

                    "refresh_installed" -> {
                        GlobalScope.launch(Dispatchers.IO) {
                            iconCache.clear()   // no disk cache anymore
                            withContext(Dispatchers.Main) { result.success(true) }
                        }
                    }

                    "set_override" -> {
                        val pkg = call.argument<String>("package")!!
                        val value = call.argument<String>("value")!!
                        GlobalScope.launch(Dispatchers.IO) {
                            val ok = setOverride(pkg, value)
                            withContext(Dispatchers.Main) { result.success(ok) }
                        }
                    }

                    "clear_override" -> {
                        val pkg = call.argument<String>("package")!!
                        GlobalScope.launch(Dispatchers.IO) {
                            val ok = clearOverride(pkg)
                            withContext(Dispatchers.Main) { result.success(ok) }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ============================================================
        // START / STOP SERVICE
        // ============================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "game_detection")
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "start_service" -> {
                        try {
                            startForegroundService(Intent(this, GameMonitorService::class.java))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERR", "$e", null)
                        }
                    }

                    "stop_service" -> {
                        try {
                            stopService(Intent(this, GameMonitorService::class.java))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERR", "$e", null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // ============================================================
        // USAGE ACCESS PERMISSION
        // ============================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "usage_access")
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "check_usage" -> {
                        try {
                            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
                            val mode = appOps.checkOpNoThrow(
                                "android:get_usage_stats",
                                android.os.Process.myUid(),
                                packageName
                            )
                            result.success(mode == AppOpsManager.MODE_ALLOWED)
                        } catch (e: Exception) {
                            result.error("ERR", "$e", null)
                        }
                    }

                    "open_settings" -> {
                        val intent = Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        startActivity(intent)
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }

        // ============================================================
        // NOTIFICATION PERMISSION POPUP
        // ============================================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "notification_permission")
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "check" ->
                        result.success(NotificationManagerCompat.from(this).areNotificationsEnabled())

                    "request" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            requestPermissions(
                                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                                9911
                            )
                        } else {
                            showNotificationPermissionPopup()
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    // ============================================================
    // INSTALLED APPS LIST (NO DISK CACHE)
    // ============================================================
    private fun fetchInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val prefs = getSharedPreferences("installed_overrides", MODE_PRIVATE)
        val list = mutableListOf<Map<String, Any?>>()

        for (info in pm.getInstalledApplications(0)) {
            try {
                val pkg = info.packageName
                if (pkg.contains("android") || pkg.contains("google")) continue

                val label = pm.getApplicationLabel(info).toString()
                val autoIsGame = detectGame(info, label)
                val override = prefs.getString("override_pkg_$pkg", null)

                val effectiveIsGame = when (override) {
                    "game" -> true
                    "app" -> false
                    else -> autoIsGame
                }

                // FIXED: ALWAYS LOAD ICON PROPERLY
                val iconBytes = iconCache[pkg] ?: run {
                    val drawable = pm.getApplicationIcon(info)
                    val bytes = convertDrawable(drawable)
                    iconCache[pkg] = bytes
                    bytes
                }

                list.add(
                    mapOf(
                        "package" to pkg,
                        "label" to label,
                        "isGame" to effectiveIsGame,
                        "autoIsGame" to autoIsGame,
                        "override" to override,
                        "icon" to iconBytes
                    )
                )

            } catch (_: Exception) {}
        }

        list.sortBy { (it["label"] as String).lowercase() }
        return list
    }

    private fun detectGame(info: ApplicationInfo, label: String): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            info.category == ApplicationInfo.CATEGORY_GAME
        ) return true

        val l = label.lowercase()
        return listOf("game", "battle", "arena", "clash", "fight").any { l.contains(it) }
    }

    private fun convertDrawable(drawable: Drawable): ByteArray? {
        return try {
            val bitmap = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val b = Bitmap.createBitmap(
                        drawable.intrinsicWidth.coerceAtLeast(64),
                        drawable.intrinsicHeight.coerceAtLeast(64),
                        Bitmap.Config.ARGB_8888
                    )
                    val canvas = Canvas(b)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    b
                }
            }

            ByteArrayOutputStream().apply {
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, this)
            }.toByteArray()
        } catch (e: Exception) {
            Log.e(TAG, "Icon convert failed: $e")
            null
        }
    }

    private fun setOverride(pkg: String, value: String): Boolean {
        return try {
            getSharedPreferences("installed_overrides", MODE_PRIVATE)
                .edit()
                .putString("override_pkg_$pkg", value)
                .apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Override save failed: $e")
            false
        }
    }

    private fun clearOverride(pkg: String): Boolean {
        return try {
            getSharedPreferences("installed_overrides", MODE_PRIVATE)
                .edit()
                .remove("override_pkg_$pkg")
                .apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Override clear failed: $e")
            false
        }
    }

    private fun showNotificationPermissionPopup() {
        try {
            val manager = NotificationManagerCompat.from(this)
            val channelId = "perm_test"

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = android.app.NotificationChannel(
                    channelId,
                    "Permission Test",
                    android.app.NotificationManager.IMPORTANCE_HIGH
                )
                getSystemService(android.app.NotificationManager::class.java)
                    ?.createNotificationChannel(channel)
            }

            val notif = NotificationCompat.Builder(this, channelId)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("Permission Needed")
                .setContentText("Please enable notifications.")
                .setAutoCancel(true)
                .build()

            manager.notify(9999, notif)

        } catch (e: Exception) {
            Log.e(TAG, "Notification request failed: $e")
        }
    }
}
