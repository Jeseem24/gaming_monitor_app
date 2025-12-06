// lib/services/native_event_handler.dart
import 'package:flutter/services.dart';
import '../database.dart';

class NativeEventHandler {
  NativeEventHandler._private();
  static final NativeEventHandler instance = NativeEventHandler._private();

  final MethodChannel _channel = const MethodChannel('game_events');
  bool _started = false;

  /// Call once at app startup (we call it in main)
  Future<void> start() async {
    if (_started) return;
    _channel.setMethodCallHandler(_handleCall);
    _started = true;
  }

  Future<dynamic> _handleCall(MethodCall call) async {
    if (call.method == 'log_event') {
      try {
        final raw = call.arguments;
        Map data;
        if (raw is Map) {
          data = Map<String, dynamic>.from(raw);
        } else {
          data = {};
        }

        final packageName = data['package_name']?.toString() ?? 'unknown';
        final gameName = data['game_name']?.toString() ?? packageName;
        final startTime = (data['start_time'] is num)
            ? (data['start_time'] as num).toInt()
            : int.tryParse(data['start_time']?.toString() ?? '') ?? 0;
        final endTime = (data['end_time'] is num)
            ? (data['end_time'] as num).toInt()
            : int.tryParse(data['end_time']?.toString() ?? '') ?? 0;
        final duration = (data['duration'] is num)
            ? (data['duration'] as num).toInt()
            : int.tryParse(data['duration']?.toString() ?? '') ?? 0;
        final timestamp = (data['timestamp'] is num)
            ? (data['timestamp'] as num).toInt()
            : (endTime != 0 ? endTime : DateTime.now().millisecondsSinceEpoch);

        final event = <String, dynamic>{
          'user_id': 'demo_user_1',
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
        return {'status': 'ok'};
      } catch (e) {
        print('NativeEventHandler error: $e');
        return {'status': 'error', 'message': e.toString()};
      }
    }

    return null;
  }
}
