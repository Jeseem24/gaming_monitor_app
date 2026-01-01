// lib/services/native_event_handler.dart

import 'package:flutter/services.dart';
import '../screens/monitoring_screen.dart';
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

      // ✅ FIX 1: Await sync completion
      await SyncService.instance.syncPendingEvents(); 

      // ✅ FIX 2: Small delay to ensure backend processed
      await Future.delayed(const Duration(milliseconds: 500));

      // ✅ FIX 3: Refresh UI after sync
      if (MonitoringScreenState.instance != null) {
        await MonitoringScreenState.instance!.refreshLocalSummary();
      }

      return {'status': 'ok'};
    } catch (e) {
      print("❌ NativeEventHandler error: $e");
      return {'status': 'error'};
    }
  }
  
  void stop() {
    _channel.setMethodCallHandler(null);
    _started = false;
    print("🛑 NativeEventHandler stopped");
  }
}