// lib/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';

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

  // =============================================================
  //  CHILD DEVICE ID — ALWAYS USED AS user_id
  // =============================================================
  static const String _childIdKey = "child_device_id";

  /// Internal: returns existing ID or generates a new one
  Future<String> _getOrCreateChildId() async {
    final prefs = await SharedPreferences.getInstance();

    final saved = prefs.getString(_childIdKey);
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }

    // Generate new ID
    final random = Random();
    final id = "child_${random.nextInt(99999999).toString().padLeft(8, '0')}";

    await prefs.setString(_childIdKey, id);
    print("🆔 NEW CHILD DEVICE ID GENERATED → $id");

    return id;
  }

  /// Public method used by UI
  Future<String> getChildId() async => _getOrCreateChildId();

  // =============================================================
  //  REGENERATE CHILD ID (When parent wants to monitor new child)
  // =============================================================
  Future<String> regenerateChildId() async {
    final prefs = await SharedPreferences.getInstance();

    final random = Random();
    final newId =
        "child_${random.nextInt(99999999).toString().padLeft(8, '0')}";

    await prefs.setString(_childIdKey, newId);

    print("🆕 CHILD ID REGENERATED → $newId");

    return newId;
  }

  // =============================================================
  //  SYNC LOOP
  // =============================================================
  void startSyncLoop() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => syncPendingEvents(),
    );
    print("🔄 SYNC LOOP STARTED (every 30 seconds)");
  }

  void stopSyncLoop() {
    _timer?.cancel();
    _timer = null;
    print("⏹ SYNC LOOP STOPPED");
  }

  Future<void> syncPendingEvents() async {
    print("📡 Checking for unsynced events...");
    final pendingEvents = await GameDatabase.instance.getPendingEvents();

    if (pendingEvents.isEmpty) {
      print("✅ No pending events");
      return;
    }

    print("📥 Found ${pendingEvents.length} events to sync");

    for (var event in pendingEvents) {
      final success = await _uploadSingleEvent(event);
      if (success) {
        await GameDatabase.instance.markEventSynced(event['id']);
        print("✔ EVENT SYNCED (ID = ${event['id']})");
      } else {
        print("❌ Upload failed, will retry later");
      }
    }
  }

  // =============================================================
  //  UPLOAD EVENT
  // =============================================================
  Future<bool> _uploadSingleEvent(Map<String, dynamic> event) async {
    try {
      final url = '$_baseUrl/events';

      // ALWAYS use child ID
      final childId = await _getOrCreateChildId();

      final durationSec = (event['duration'] is num)
          ? (event['duration'] as num).toInt()
          : 0;

      int durationMin = (durationSec / 60).ceil();
      if (durationMin <= 0) durationMin = 1;

      final gameName = event['game_name'] ?? event['package_name'];

      final payloadMap = {
        'user_id': childId,
        'game_name': gameName,
        'duration': durationMin,
      };

      final payload = jsonEncode(payloadMap);

      print("🌐 Sending event → $payload");

      final response = await http.post(
        Uri.parse(url),
        headers: _defaultHeaders,
        body: payload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Backend accepted event → ${response.body}");
        return true;
      }

      print("⚠️ Server ${response.statusCode}: ${response.body}");
      return false;
    } catch (e) {
      print("🚨 Upload error: $e");
      return false;
    }
  }
}
