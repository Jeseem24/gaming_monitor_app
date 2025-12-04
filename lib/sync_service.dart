import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database.dart';

class SyncService {
  static final SyncService instance = SyncService._private();
  Timer? _timer;

  SyncService._private();

  // ------------------------------------------------------------
  // START SYNC LOOP (runs every 30 seconds)
  // ------------------------------------------------------------
  void startSyncLoop() {
    _timer?.cancel(); // stop old timer if exists

    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      syncPendingEvents();
    });

    print("🔄 SYNC LOOP STARTED (every 30 seconds)");
  }

  // ------------------------------------------------------------
  // SYNC UNSENT EVENTS TO BACKEND
  // ------------------------------------------------------------
  Future<void> syncPendingEvents() async {
    print("📡 Checking for unsynced events...");

    final pendingEvents = await GameDatabase.instance.getPendingEvents();

    if (pendingEvents.isEmpty) {
      print("✅ No pending events");
      return;
    }

    print("📥 Found ${pendingEvents.length} events to sync");

    for (var event in pendingEvents) {
      bool success = await _uploadSingleEvent(event);

      if (success) {
        await GameDatabase.instance.markEventSynced(event["id"]);
        print("✔ EVENT SYNCED (ID = ${event['id']})");
      } else {
        print("❌ Upload failed, will retry later");
      }
    }
  }

  // ------------------------------------------------------------
  // UPLOAD EVENT TO BACKEND (API CALL)
  // ------------------------------------------------------------
  Future<bool> _uploadSingleEvent(Map<String, dynamic> event) async {
    try {
      // TODO: replace when Member 2 gives API
      const url = "https://your_backend.com/events";

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(event),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      print("⚠️ Server responded with ${response.statusCode}");
      return false;
    } catch (e) {
      print("🚨 Upload error: $e");
      return false;
    }
  }
}
