// lib/services/service_controller.dart

import 'package:flutter/services.dart';
import 'sync_service.dart';

class ServiceController {
  static final MethodChannel _serviceChannel = const MethodChannel(
    'game_detection',
  );

  /// Completely stop monitoring service + sync loop
  static Future<void> stopMonitoringService() async {
    try {
      // Stop sync loop first
      SyncService.instance.stopSyncLoop();
      print("⏹ Sync loop stopped");

      // Stop Android foreground service
      await _serviceChannel.invokeMethod('stop_service');
      print("🛑 Android monitoring service stopped");
    } catch (e) {
      print("⚠️ Error stopping monitoring: $e");
    }
  }
}
