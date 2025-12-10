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

      // Duration correction (detect ms vs sec)
      int raw = (event['duration'] is num) ? event['duration'] as int : 0;

      // If value looks like milliseconds, convert to seconds
      if (raw > 30000) raw ~/= 1000;

      int minutes = (raw / 60).ceil();
      if (minutes < 1) minutes = 1;

      final gameName =
          event['game_name']?.toString() ?? event['package_name']?.toString();

      final payload = {
        "user_id": childId,
        "game_name": gameName,
        "duration": minutes,
      };

      print("🌐 Uploading event → ${jsonEncode(payload)}");

      final res = await http.post(
        Uri.parse(url),
        headers: _defaultHeaders,
        body: jsonEncode(payload),
      );

      // Accepted by backend
      if (res.statusCode == 200 || res.statusCode == 201) {
        print("✅ Backend response → ${res.body}");
        return true;
      }

      // If backend says INVALID DATA → skip retry permanently
      if (res.statusCode == 400 || res.statusCode == 422) {
        print("⚠️ Invalid event → marking as synced to avoid infinite retry");
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
