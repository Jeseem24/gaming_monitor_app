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
import java.io.File

class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
    return FlutterEngineCache.getInstance().get("preloaded_engine")
}

override fun getCachedEngineId(): String? {
    return "preloaded_engine"
}


    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL_INSTALLED = "installed_apps"
        val iconCache: MutableMap<String, ByteArray?> = mutableMapOf()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ---------------- INSTALLED APPS ----------------
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_INSTALLED
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                "list_installed" -> {
                    GlobalScope.launch(Dispatchers.IO) {
                        val apps = fetchInstalledApps()
                        withContext(Dispatchers.Main) {
                            result.success(apps)
                        }
                    }
                }

                "refresh_installed" -> {
                    GlobalScope.launch(Dispatchers.IO) {
                        iconCache.clear()
                        clearDiskCache()
                        withContext(Dispatchers.Main) {
                            result.success(true)
                        }
                    }
                }

                "set_override" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val value = call.argument<String>("value") ?: ""
                    GlobalScope.launch(Dispatchers.IO) {
                        val ok = setOverride(pkg, value)
                        withContext(Dispatchers.Main) {
                            result.success(ok)
                        }
                    }
                }

                "clear_override" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    GlobalScope.launch(Dispatchers.IO) {
                        val ok = clearOverride(pkg)
                        withContext(Dispatchers.Main) {
                            result.success(ok)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ---------------- GAME MONITOR SERVICE ----------------
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "game_detection"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start_service" -> {
                    try {
                        startForegroundService(
                            Intent(this, GameMonitorService::class.java)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERR", "Failed to start service: $e", null)
                    }
                }

                "stop_service" -> {
                    try {
                        stopService(
                            Intent(this, GameMonitorService::class.java)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERR", "Failed to stop service: $e", null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ---------------- USAGE ACCESS ----------------
        // ---------------- USAGE ACCESS ----------------
MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "usage_access"
).setMethodCallHandler { call, result ->
    when (call.method) {
        "check_usage" -> {
            try {
                val appOps =
                    getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

                val mode = appOps.checkOpNoThrow(
                    AppOpsManager.OPSTR_GET_USAGE_STATS,
                    android.os.Process.myUid(),
                    packageName
                )

                result.success(mode == AppOpsManager.MODE_ALLOWED)
            } catch (e: Exception) {
                result.error("ERR", "check_usage failed: $e", null)
            }
        }

        "open_settings" -> {
            try {
                val intent =
                    Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                result.success(true)
            } catch (e: Exception) {
                result.error("ERR", "open_settings failed: $e", null)
            }
        }

        else -> result.notImplemented()
    }
}


        // ---------------- NOTIFICATION PERMISSION ----------------
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "notification_permission"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "check" -> {
                    val enabled =
                        NotificationManagerCompat.from(this).areNotificationsEnabled()
                    result.success(enabled)
                }

                "request" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        requestPermissions(
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            9911
                        )
                        result.success(true)
                        return@setMethodCallHandler
                    }

                    try {
                        val manager = NotificationManagerCompat.from(this)
                        val channelId = "perm_test_channel"

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val channel = android.app.NotificationChannel(
                                channelId,
                                "Permission Test",
                                android.app.NotificationManager.IMPORTANCE_HIGH
                            )
                            getSystemService(android.app.NotificationManager::class.java)
                                ?.createNotificationChannel(channel)
                        }

                        val notification =
                            NotificationCompat.Builder(this, channelId)
                                .setSmallIcon(android.R.drawable.ic_dialog_info)
                                .setContentTitle("Permission Needed")
                                .setContentText(
                                    "Enable notifications for monitoring to work."
                                )
                                .setAutoCancel(true)
                                .build()

                        manager.notify(9912, notification)
                    } catch (e: Exception) {
                        Log.e(TAG, "Notification request failed: $e")
                    }

                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    // ---------------- HELPER METHODS (UNCHANGED) ----------------

    private fun fetchInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val installed = pm.getInstalledApplications(0)
        val prefs =
            getSharedPreferences("installed_overrides", Context.MODE_PRIVATE)
        val out = mutableListOf<Map<String, Any?>>()

        for (info in installed) {
            try {
                val pkg = info.packageName ?: continue

                if ((info.flags and ApplicationInfo.FLAG_SYSTEM) != 0) {
                    if (
                        pkg.contains("android") ||
                        pkg.contains("google") ||
                        pkg.contains("com.android")
                    ) continue
                }

                val label =
                    pm.getApplicationLabel(info)?.toString() ?: pkg

                val autoIsGame = detectGameHeuristic(pm, info, label, pkg)
                val overrideValue =
                    prefs.getString("override_pkg_$pkg", null)

                val effectiveIsGame = when (overrideValue) {
                    "game" -> true
                    "app" -> false
                    else -> autoIsGame
                }

                val iconBytes = iconCache[pkg] ?: run {
                    val drawable = pm.getApplicationIcon(info)
                    val bytes = convertDrawableToPNGBytes(drawable)
                    iconCache[pkg] = bytes
                    saveIconToDisk(pkg, bytes)
                    bytes
                }

                out.add(
                    mapOf(
                        "package" to pkg,
                        "label" to label,
                        "isGame" to effectiveIsGame,
                        "autoIsGame" to autoIsGame,
                        "override" to overrideValue,
                        "icon" to iconBytes
                    )
                )

            } catch (_: Exception) {
            }
        }

        out.sortBy { (it["label"] as? String)?.lowercase() ?: "" }
        return out
    }

    private fun detectGameHeuristic(
        pm: android.content.pm.PackageManager,
        info: ApplicationInfo,
        label: String,
        pkg: String
    ): Boolean {
        try {
            if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                info.category == ApplicationInfo.CATEGORY_GAME
            ) return true

            val lowerLabel = label.lowercase()
            if (
                listOf("game", "fight", "battle", "clash", "racing", "arena")
                    .any { lowerLabel.contains(it) }
            ) return true

            val lowerPkg = pkg.lowercase()
            if (
                listOf("game", "pubg", "bgmi", "clash", "minecraft", "roblox")
                    .any { lowerPkg.contains(it) }
            ) return true

        } catch (_: Exception) {
        }

        return false
    }

    private fun convertDrawableToPNGBytes(drawable: Drawable): ByteArray? {
        return try {
            val bitmap = when (drawable) {
                is BitmapDrawable -> drawable.bitmap
                else -> {
                    val w =
                        if (drawable.intrinsicWidth > 0)
                            drawable.intrinsicWidth else 64
                    val h =
                        if (drawable.intrinsicHeight > 0)
                            drawable.intrinsicHeight else 64
                    val bmp =
                        Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    drawable.setBounds(0, 0, canvas.width, canvas.height)
                    drawable.draw(canvas)
                    bmp
                }
            }

            val baos = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, baos)
            baos.toByteArray()

        } catch (e: Exception) {
            Log.e(TAG, "convertDrawableToPNGBytes error: $e")
            null
        }
    }

    private fun getIconCacheFile(pkg: String): File {
        val dir = File(cacheDir, "icons")
        if (!dir.exists()) dir.mkdirs()
        return File(dir, "$pkg.png")
    }

    private fun saveIconToDisk(pkg: String, bytes: ByteArray?) {
        if (bytes == null) return
        getIconCacheFile(pkg).writeBytes(bytes)
    }

    private fun clearDiskCache() {
        val dir = File(cacheDir, "icons")
        if (dir.exists()) dir.deleteRecursively()
    }

    private fun setOverride(pkg: String, value: String): Boolean {
        return try {
            getSharedPreferences("installed_overrides", Context.MODE_PRIVATE)
                .edit()
                .putString("override_pkg_$pkg", value)
                .apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "setOverride error: $e")
            false
        }
    }

    private fun clearOverride(pkg: String): Boolean {
        return try {
            getSharedPreferences("installed_overrides", Context.MODE_PRIVATE)
                .edit()
                .remove("override_pkg_$pkg")
                .apply()
            true
        } catch (e: Exception) {
            Log.e(TAG, "clearOverride error: $e")
            false
        }
    }
}
