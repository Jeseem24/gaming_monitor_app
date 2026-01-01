package com.example.gaming_monitor_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            
            Log.i(TAG, "📱 Device booted - checking if monitoring should start")
            
            // Check if monitoring was enabled before reboot
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val monitoringEnabled = prefs.getBoolean("flutter.monitoring_enabled", false)
            val childId = prefs.getString("flutter.selected_child_id", null)
            
            if (monitoringEnabled && !childId.isNullOrEmpty()) {
                Log.i(TAG, "🚀 Starting GameMonitorService after boot")
                
                try {
                    val serviceIntent = Intent(context, GameMonitorService::class.java)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                    
                    Log.i(TAG, "✅ Service started successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to start service: ${e.message}")
                }
            } else {
                Log.i(TAG, "⏭️ Monitoring not enabled, skipping service start")
            }
        }
    }
}