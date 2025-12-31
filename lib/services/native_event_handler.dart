// lib/services/native_event_handler.dart

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database.dart';
import '../screens/monitoring_screen.dart'; // ✅ Added
import 'sync_service.dart';

class NativeEventHandler {
  NativeEventHandler._private();
  static final NativeEventHandler instance = NativeEventHandler._private();

  final MethodChannel _channel = const MethodChannel('game_detection');

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _channel.setMethodCallHandler(_handleCall);
    _started = true;
    print("🎧 NativeEventHandler listening on game_detection");
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    if (call.method != 'log_event') return null;

    try {
      final status = call.arguments['status']?.toString() ?? 'HEARTBEAT';
      print("📥 [SIGNAL] Received $status from Kotlin");

      // 1. Wake up the Sync Service to upload to backend immediately
      SyncService.instance.syncPendingEvents(); 

      // 2. ✅ NEW: Tell the Monitoring Screen to refresh its UI NOW
      if (MonitoringScreenState.instance != null) {
          MonitoringScreenState.instance!.refreshLocalSummary();
      }

      return {'status': 'ok'};
    } catch (e) {
      print("❌ NativeEventHandler error: $e");
      return {'status': 'error'};
    }
  }
}