// lib/screens/monitoring_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'child_id_screen.dart';

import '../services/sync_service.dart';
import '../services/native_event_handler.dart';
import '../database.dart';
import 'pin_verify_screen.dart';
import 'installed_games_screen.dart';
import '../services/twin_service.dart';

bool _busyMonitor = false; // start/stop monitoring
bool _busyReport = false; // backend report loading

const MethodChannel _serviceChannel = MethodChannel('game_detection');

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  int _backendToday = 0;
  int _backendWeekly = 0;
  int _backendNight = 0;
  int _backendSessions = 0;
  String _backendState = "Unknown";

  bool _serviceRunning = false;
  int _todayMinutes = 0;

  final Color _primary = const Color(0xFF3D77FF);

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _loadServiceState();
    _refreshSummary();
    _loadTwinReport(); // auto-load backend on start
  }

  Future<void> _loadServiceState() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool('service_running') ?? false;
    setState(() => _serviceRunning = stored);

    if (_serviceRunning) {
      await NativeEventHandler.instance.start();
      SyncService.instance.startSyncLoop();
    }
  }

  Future<void> _saveServiceState(bool running) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('service_running', running);
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  // -------------------------------------------------------------
  // START SERVICE
  // -------------------------------------------------------------
  Future<void> _startService() async {
    if (_busyMonitor) return;
    setState(() => _busyMonitor = true);

    try {
      await NativeEventHandler.instance.start();
      await _serviceChannel.invokeMethod('start_service');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background service started')),
      );

      setState(() => _serviceRunning = true);
      await _saveServiceState(true);
      SyncService.instance.startSyncLoop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start: $e')));
    } finally {
      setState(() => _busyMonitor = false);
    }
  }

  // -------------------------------------------------------------
  // STOP SERVICE
  // -------------------------------------------------------------
  Future<void> _stopService() async {
    if (_busyMonitor) return;
    setState(() => _busyMonitor = true);

    final ok = await showDialog(
      context: context,
      builder: (_) => const PinVerifyScreen(),
    );

    if (ok != true) {
      setState(() => _busyMonitor = false);
      return;
    }

    SyncService.instance.stopSyncLoop();
    setState(() => _serviceRunning = false);
    await _saveServiceState(false);

    try {
      await _serviceChannel.invokeMethod('stop_service');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {}

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Monitoring stopped')));

    setState(() => _busyMonitor = false);
  }

  Future<void> _toggleService() async {
    _serviceRunning ? await _stopService() : await _startService();
  }

  // -------------------------------------------------------------
  // REFRESH SUMMARY
  // -------------------------------------------------------------
  Future<void> _refreshSummary() async {
    try {
      final db = await GameDatabase.instance.database;
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;

      final res = await db.rawQuery(
        'SELECT SUM(duration) as total FROM game_events WHERE timestamp >= ?',
        [startOfDay],
      );

      final totalSec = (res.first['total'] as int?) ?? 0;
      setState(() => _todayMinutes = totalSec ~/ 60);
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // REFRESH BACKEND REPORT (separate loading)
  // -------------------------------------------------------------
  Future<void> _loadTwinReport() async {
    setState(() => _busyReport = true);

    try {
      final userId = await SyncService.instance.getChildId();

      final report = await TwinService.getReport(userId);
      final twin = await TwinService.getTwin(userId);

      if (report == null || twin == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to fetch backend data")),
        );
        return;
      }

      setState(() {
        _backendToday = report["today_minutes"] ?? 0;
        _backendWeekly = report["weekly_minutes"] ?? 0;
        _backendNight = report["night_minutes"] ?? 0;
        _backendSessions = report["sessions_per_day"] ?? 0;
        _backendState = twin["state"] ?? "Unknown";
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Report updated")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading: $e")));
    } finally {
      setState(() => _busyReport = false);
    }
  }

  // -------------------------------------------------------------
  // BUILD UI WIDGETS
  // -------------------------------------------------------------
  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.schedule, color: _primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Today's total usage",
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_todayMinutes min',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_serviceRunning ? Colors.green : Colors.grey).withOpacity(
                0.12,
              ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _serviceRunning ? "ACTIVE" : "INACTIVE",
              style: TextStyle(
                color: _serviceRunning ? Colors.green : Colors.grey,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton() {
    final label = _serviceRunning ? 'STOP MONITORING' : 'START MONITORING';
    final background = _serviceRunning ? Colors.red : _primary;

    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _busyMonitor ? null : _toggleService,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        child: _busyMonitor
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _installedAppsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.apps),
        label: const Text("VIEW INSTALLED APPS"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InstalledGamesScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: _primary, width: 1.6),
        ),
      ),
    );
  }

  Widget _childIdButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.qr_code),
        label: const Text("SHOW CHILD DEVICE ID"),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChildIdScreen()),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.black54, width: 1.4),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // MAIN BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Digital Twin Monitor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () async {
              await _refreshSummary();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Summary refreshed')),
              );
            },
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Monitoring is ready. Use the button below to start background tracking.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                _summaryCard(),
                const SizedBox(height: 22),

                _buildPillButton(),
                const SizedBox(height: 20),

                _installedAppsButton(),
                const SizedBox(height: 12),

                _childIdButton(),
                const SizedBox(height: 20),

                // BACKEND REPORT CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Backend Report",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text("Today: $_backendToday min"),
                      Text("Weekly: $_backendWeekly min"),
                      Text("Night: $_backendNight min"),
                      Text("Sessions/Day: $_backendSessions"),
                      Text("State: $_backendState"),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busyReport ? null : _loadTwinReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _busyReport
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "REFRESH BACKEND REPORT",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                const Text(
                  'Background detection will continue even when the app is closed.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
