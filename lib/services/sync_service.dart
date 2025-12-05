// lib/services/sync_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  Future<bool> _uploadSingleEvent(Map<String, dynamic> event) async {
    try {
      final url = '$_baseUrl/events';
      // backend expects duration in minutes
      final durationSec = (event['duration'] is num)
          ? (event['duration'] as num).toInt()
          : 0;
      final durationMin = (durationSec ~/ 60);
      final payload = jsonEncode({
        'user_id': event['user_id'] ?? 'demo_user_1',
        'game_name': event['game_name'] ?? event['package_name'],
        'duration': durationMin,
      });

      final response = await http.post(
        Uri.parse(url),
        headers: _defaultHeaders,
        body: payload,
      );
      if (response.statusCode == 200 || response.statusCode == 201) return true;
      print(
        "⚠️ Server responded with ${response.statusCode}: ${response.body}",
      );
      return false;
    } catch (e) {
      print("🚨 Upload error: $e");
      return false;
    }
  }
}
