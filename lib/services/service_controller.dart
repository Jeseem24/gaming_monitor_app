// lib/services/service_controller.dart

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'sync_service.dart';

class ServiceController {
  static final MethodChannel _serviceChannel = const MethodChannel('game_detection');

  /// Start the monitoring service
  static Future<bool> startMonitoringService() async {
    try {
      // Start Android foreground service
      final result = await _serviceChannel.invokeMethod('start_service');
      print("🚀 Android monitoring service started: $result");
      
      // Start sync loop
      SyncService.instance.startSyncLoop();
      print("🔄 Sync loop started");
      
      // Save state for boot receiver
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('monitoring_enabled', true);
      
      return true;
    } catch (e) {
      print("⚠️ Error starting monitoring: $e");
      return false;
    }
  }

  /// Stop the monitoring service
  static Future<void> stopMonitoringService() async {
    try {
      // Stop sync loop first
      SyncService.instance.stopSyncLoop();
      print("⏹ Sync loop stopped");

      // Stop Android foreground service
      await _serviceChannel.invokeMethod('stop_service');
      print("🛑 Android monitoring service stopped");
      
      // Save state for boot receiver
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('monitoring_enabled', false);
    } catch (e) {
      print("⚠️ Error stopping monitoring: $e");
    }
  }

  /// Check if service is running
  static Future<bool> isServiceRunning() async {
    try {
      final result = await _serviceChannel.invokeMethod('is_service_running');
      return result == true;
    } catch (e) {
      print("⚠️ Error checking service status: $e");
      return false;
    }
  }
  
  /// Ensure service is running (call on app resume)
  static Future<void> ensureServiceRunning() async {
    final prefs = await SharedPreferences.getInstance();
    final shouldBeRunning = prefs.getBool('monitoring_enabled') ?? false;
    
    if (shouldBeRunning) {
      final isRunning = await isServiceRunning();
      if (!isRunning) {
        print("🔄 Service should be running but isn't - restarting...");
        await startMonitoringService();
      }
    }
  }
}