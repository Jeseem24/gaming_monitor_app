import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'database.dart';
import 'sync_service.dart'; // ⬅️ NEW (Sync engine for backend upload)

// =============================================================
// MAIN APP
// =============================================================
void main() {
  runApp(const GamingMonitorApp());
}

class GamingMonitorApp extends StatelessWidget {
  const GamingMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gaming Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ConsentHandler(),
    );
  }
}

// =============================================================
// CONSENT HANDLER
// =============================================================
class ConsentHandler extends StatefulWidget {
  const ConsentHandler({super.key});

  @override
  State<ConsentHandler> createState() => _ConsentHandlerState();
}

class _ConsentHandlerState extends State<ConsentHandler> {
  bool? _consentGiven = false;

  @override
  void initState() {
    super.initState();
    _loadConsentStatus();
  }

  Future<void> _loadConsentStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool? stored = prefs.getBool("parent_consent");

    setState(() {
      _consentGiven = stored ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_consentGiven == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _consentGiven == true
        ? const MonitoringScreen()
        : ConsentScreen(
            onConsentGiven: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool("parent_consent", true);

              setState(() {
                _consentGiven = true;
              });
            },
          );
  }
}

// =============================================================
// CONSENT SCREEN UI
// =============================================================
class ConsentScreen extends StatelessWidget {
  final VoidCallback onConsentGiven;
  const ConsentScreen({super.key, required this.onConsentGiven});

  void _openUsageAccessSettings() {
    const platform = MethodChannel("usage_access");
    platform.invokeMethod("open_settings");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parental Consent")),
      body: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Parent Consent Required",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 14),

            const Text(
              "This app monitors which games are played and for how long.\n"
              "Only game name + duration are collected. No personal data.",
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 25),

            ElevatedButton(
              onPressed: _openUsageAccessSettings,
              child: const Text("Open Usage Access Settings"),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: () {
                onConsentGiven();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MonitoringScreen()),
                );
              },
              child: const Text("I Give Consent"),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// MONITORING SCREEN — SERVICE + EVENT RECEIVER + SYNC ENGINE
// =============================================================
class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  static const MethodChannel serviceChannel = MethodChannel("game_detection");
  static const MethodChannel eventChannel = MethodChannel("game_events");

  @override
  void initState() {
    super.initState();
    requestNotificationPermission();
    listenForNativeEvents();
  }

  // ⬇️ LISTEN FOR GAME EVENTS FROM KOTLIN
  void listenForNativeEvents() {
    eventChannel.setMethodCallHandler((call) async {
      if (call.method == "log_event") {
        Map data = Map.from(call.arguments);

        await GameDatabase.instance.insertEvent({
          "user_id": "demo_user_1",
          "package_name": data["package_name"],
          "game_name": data["package_name"], // Temporary
          "genre": "unknown", // Temporary
          "start_time": data["start_time"],
          "end_time": data["end_time"],
          "duration": data["duration"],
          "timestamp": data["timestamp"],
          "synced": 0,
        });

        print("🔥 EVENT RECEIVED FROM NATIVE → $data");
      }
    });
  }

  Future<void> requestNotificationPermission() async {
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  Future<void> startBackgroundService() async {
    try {
      await serviceChannel.invokeMethod("start_service");

      // Start API sync loop
      SyncService.instance.startSyncLoop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Background Service Started")),
      );
    } catch (e) {
      print("ERROR STARTING SERVICE: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Monitoring Active")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Monitoring is active…\n"
              "Press the button below to start background tracking.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: startBackgroundService,
              child: const Text("Start Background Service"),
            ),
          ],
        ),
      ),
    );
  }
}
