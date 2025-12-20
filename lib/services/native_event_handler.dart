// lib/services/native_event_handler.dart

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database.dart';

class NativeEventHandler {
  NativeEventHandler._private();
  static final NativeEventHandler instance = NativeEventHandler._private();

  // ✅ FIXED CHANNEL NAME
  final MethodChannel _channel = const MethodChannel('game_detection');

  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _channel.setMethodCallHandler(_handleCall);
    _started = true;
    print("🎧 NativeEventHandler listening on game_detection");
  }

  Future<String?> _getActiveChildId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString("selected_child_id");

    if (id == null || id.isEmpty) {
      print("⚠️ No child selected — dropping event");
      return null;
    }
    return id;
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    if (call.method != 'log_event') return null;

    try {
      final childId = await _getActiveChildId();
      if (childId == null) {
        return {'status': 'skipped_no_child'};
      }

      final raw = call.arguments;
      final data = (raw is Map) ? Map<String, dynamic>.from(raw) : {};

      final packageName = data['package_name']?.toString() ?? 'unknown';
      final gameName = data['game_name']?.toString() ?? packageName;

      final startTime = (data['start_time'] is num)
          ? (data['start_time'] as num).toInt()
          : 0;

      final endTime = (data['end_time'] is num)
          ? (data['end_time'] as num).toInt()
          : 0;

      final duration = (data['duration'] is num)
          ? (data['duration'] as num).toInt()
          : 0;

      int now = DateTime.now().millisecondsSinceEpoch;
      int timestamp = (data['timestamp'] is num)
          ? (data['timestamp'] as num).toInt()
          : (endTime != 0 ? endTime : now);

      if (timestamp > now) timestamp = now;

      final event = {
        'user_id': childId,
        'package_name': packageName,
        'game_name': gameName,
        'genre': 'unknown',
        'start_time': startTime,
        'end_time': endTime,
        'duration': duration,
        'timestamp': timestamp,
        'synced': 0,
      };

      await GameDatabase.instance.insertEvent(event);
      print("📥 Event inserted → $gameName ($duration sec)");

      return {'status': 'ok'};
    } catch (e) {
      print("❌ NativeEventHandler error: $e");
      return {'status': 'error'};
    }
  }
}
