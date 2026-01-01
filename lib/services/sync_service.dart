// lib/services/sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database.dart';

class SyncService {
  static final SyncService instance = SyncService._private();
  Timer? _timer;
  bool _isSyncing = false; 

  SyncService._private();

  static const String _baseUrl = 'https://gaming-twin-backend.onrender.com';
  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'X-API-KEY': 'secret',
  };

  Future<String?> _getActiveChildId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString("selected_child_id");
    if (id == null || id.trim().isEmpty) return null;
    return id;
  }

  void startSyncLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => syncPendingEvents());
    print("🔄 SYNC LOOP ACTIVE (every 15 sec)");
  }

  void stopSyncLoop() {
    _timer?.cancel();
    _timer = null;
    print("⏹ Sync loop stopped");
  }

  Future<void> syncPendingEvents() async {
    if (_isSyncing) return; 
    final childId = await _getActiveChildId();
    if (childId == null) return;

    final pending = await GameDatabase.instance.getPendingEvents();
    if (pending.isEmpty) return;

    _isSyncing = true;
    try {
      for (final event in pending) {
        final ok = await _uploadSingleEvent(event, childId);
        if (ok) await GameDatabase.instance.markEventSynced(event['id']);
        else break; 
      }
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> _uploadSingleEvent(Map<String, dynamic> event, String childId) async {
  try {
    final url = '$_baseUrl/events';
    final status = event['status']?.toString() ?? "HEARTBEAT";
    final packageName = event['package_name']?.toString();
    final gameName = event['game_name']?.toString() ?? packageName ?? "Unknown";
    if (packageName == null) return true;

    int parseMs(dynamic v) => (v is num) ? v.toInt() : (int.tryParse(v?.toString() ?? '') ?? DateTime.now().millisecondsSinceEpoch);

    final timestamp = parseMs(event['timestamp']);
    final startTime = parseMs(event['start_time'] ?? timestamp);
    final endTime = parseMs(event['end_time'] ?? timestamp);

    // ✅ FIX: Duration is stored in SECONDS from Kotlin
    int durationSeconds = (event['duration'] is num) ? (event['duration'] as num).toInt() : 0;
    
    int durationInMinutes;
    switch (status) {
      case "START":
        durationInMinutes = 0;
        break;
      case "HEARTBEAT":
        durationInMinutes = 1;
        break;
      case "STOP":
        durationInMinutes = (durationSeconds / 60).ceil().clamp(1, 999);  // ✅ At least 1 minute
        break;
      default:
        durationInMinutes = 0;
    }

    final payload = {
      "user_id": childId,
      "childdeviceid": "android_$childId",
      "status": status,
      "package_name": packageName,
      "game_name": gameName,
      "duration": durationInMinutes,
      "start_time": startTime,
      "end_time": endTime,
      "timestamp": timestamp,
    };

    final res = await http.post(
      Uri.parse(url), 
      headers: _defaultHeaders, 
      body: jsonEncode(payload)
    ).timeout(const Duration(seconds: 10));
    
    if (res.statusCode == 200 || res.statusCode == 201) return true;
    if (res.statusCode == 422 || res.statusCode == 400) return true;
    return false;
  } catch (e) { 
    return false; 
  }
}
}