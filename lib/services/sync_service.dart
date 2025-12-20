// lib/services/sync_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../database.dart';

class SyncService {
  static final SyncService instance = SyncService._private();
  Timer? _timer;

  SyncService._private();

  static const String _baseUrl = 'https://gaming-twin-backend.onrender.com';
  static const Map<String, String> _defaultHeaders = {
    'Content-Type': 'application/json',
    'X-API-KEY': 'secret',
  };

  // --------------------------------------------------------------
  //  SAFE CHILD ID FETCH
  // --------------------------------------------------------------
  Future<String?> _getActiveChildId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString("selected_child_id");

    if (id == null || id.trim().isEmpty) {
      print("⚠️ No child selected → Sync paused");
      return null;
    }

    return id;
  }

  // For UI screens:
  Future<String?> getChildId() async => _getActiveChildId();

  // --------------------------------------------------------------
  //  ENSURE SYNC LOOP ALWAYS RUNS ON APP STARTUP
  // --------------------------------------------------------------
  bool _syncStarted = false;

  void ensureStarted() {
    if (_syncStarted) return;
    _syncStarted = true;
    startSyncLoop();
  }

  // --------------------------------------------------------------
  //  SYNC LOOP
  // --------------------------------------------------------------
  void startSyncLoop() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => syncPendingEvents(),
    );

    print("🔄 SYNC LOOP ACTIVE (every 30 sec)");
  }

  void stopSyncLoop() {
    _timer?.cancel();
    _timer = null;
    _syncStarted = false;
    print("⏹ Sync loop stopped");
  }

  // --------------------------------------------------------------
  //  SYNC PENDING EVENTS
  // --------------------------------------------------------------
  Future<void> syncPendingEvents() async {
    print("🔎 Checking for pending events…");

    final childId = await _getActiveChildId();
    if (childId == null) {
      print("⛔ No child selected → Skipping sync");
      return;
    }

    final pending = await GameDatabase.instance.getPendingEvents();

    if (pending.isEmpty) {
      print("✅ No events to sync");
      return;
    }

    print("📦 Found ${pending.length} events to sync");

    for (final event in pending) {
      final ok = await _uploadSingleEvent(event, childId);

      if (ok) {
        await GameDatabase.instance.markEventSynced(event['id']);
        print("✔ Synced event ID ${event['id']}");
      } else {
        print("❗ Event upload failed → Will retry later");
      }
    }
  }

  // --------------------------------------------------------------
  //  UPLOAD 1 EVENT
  // --------------------------------------------------------------
Future<bool> _uploadSingleEvent(
  Map<String, dynamic> event,
  String childId,
) async {
  try {
    final url = '$_baseUrl/events';

    // ----------------------------
    // Duration: seconds → minutes
    // ----------------------------
    int durationSeconds =
        (event['duration'] is num) ? event['duration'] as int : 0;

    // If milliseconds slipped in, convert
    if (durationSeconds > 30000) {
      durationSeconds ~/= 1000;
    }

    if (durationSeconds <= 0) {
      print("❌ Invalid duration → skip event");
      return true;
    }

    int durationMinutes = (durationSeconds / 60).ceil();
    if (durationMinutes < 1) durationMinutes = 1;

    // ----------------------------
    // Required fields
    // ----------------------------
    final packageName = event['package_name']?.toString();
    final gameName =
        event['game_name']?.toString() ?? packageName ?? "Unknown";

    if (packageName == null) {
      print("❌ Missing package_name → skip event");
      return true;
    }

    // ----------------------------
    // Time fields → MUST be epoch ms (INT)
    // ----------------------------
    int parseMs(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return DateTime.now().millisecondsSinceEpoch;
    }

    final startTime = parseMs(event['start_time']);
    final endTime = parseMs(event['end_time']);
    final timestamp = parseMs(event['timestamp'] ?? event['end_time']);

    // ----------------------------
    // FINAL PAYLOAD (MATCHES POSTMAN ✔)
    // ----------------------------
    final payload = {
      "user_id": childId,
      "childdeviceid": "android_$childId",
      "package_name": packageName,
      "game_name": gameName,
      "duration": durationMinutes, // ✅ MINUTES
      "start_time": startTime,      // ✅ INT
      "end_time": endTime,          // ✅ INT
      "timestamp": timestamp,       // ✅ INT
    };

    print("🌐 Uploading event → ${jsonEncode(payload)}");

    final res = await http.post(
      Uri.parse(url),
      headers: _defaultHeaders,
      body: jsonEncode(payload),
    );

    if (res.statusCode == 200 || res.statusCode == 201) {
      print("✅ Backend accepted event → ${res.body}");
      return true;
    }

    if (res.statusCode == 400 || res.statusCode == 422) {
      print("⚠️ Invalid payload → skipping event permanently");
      return true;
    }

    print("⚠️ Server error ${res.statusCode}: ${res.body}");
    return false;
  } catch (e) {
    print("🚨 Upload exception: $e");
    return false;
  }
}



}
