// lib/screens/monitoring_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/sync_service.dart';
import '../services/native_event_handler.dart';
import '../database.dart';
import 'pin_verify_screen.dart';
import 'installed_games_screen.dart';
import 'child_id_screen.dart';
import 'child_selection_screen.dart';

const MethodChannel _serviceChannel = MethodChannel('game_detection');

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _serviceRunning = false;
  bool _busyMonitor = false;
  int _todayMinutes = 0;

  final Color _primary = const Color(0xFF3D77FF);

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _checkChildSelected();
    _autoRefreshLoop();
  }

  // AUTO REFRESH EVERY 10 SECONDS
  Future<void> _autoRefreshLoop() async {
    while (mounted) {
      await _refreshLocalSummary();
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  // CHILD CHECK
  Future<void> _checkChildSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString("selected_child_id");

    if (id == null || id.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNoChildSelectedDialog();
      });
    } else {
      await _loadServiceState();
      await _refreshLocalSummary();
    }
  }

  void _showNoChildSelectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("No Child Selected"),
        content: const Text("Please select a child profile before monitoring."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ChildSelectionScreen()),
              );
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // NOTIFICATIONS
  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  // LOAD SERVICE STATE
  Future<void> _loadServiceState() async {
    final prefs = await SharedPreferences.getInstance();
    final running = prefs.getBool('service_running') ?? false;

    setState(() => _serviceRunning = running);

    if (running) {
      await NativeEventHandler.instance.start();
      SyncService.instance.startSyncLoop();
    }
  }

  Future<void> _saveServiceState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('service_running', value);
  }

  // START MONITORING
  Future<void> _startMonitoring() async {
    if (_busyMonitor) return;
    setState(() => _busyMonitor = true);

    try {
      await NativeEventHandler.instance.start();
      await _serviceChannel.invokeMethod('start_service');

      SyncService.instance.startSyncLoop();
      await _saveServiceState(true);

      setState(() => _serviceRunning = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Monitoring started")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed: $e")));
    }

    setState(() => _busyMonitor = false);
  }

  // STOP MONITORING
  Future<void> _stopMonitoring() async {
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

    try {
      SyncService.instance.stopSyncLoop();
      await _serviceChannel.invokeMethod('stop_service');
      await _saveServiceState(false);

      setState(() => _serviceRunning = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Monitoring stopped")));
    } catch (_) {}

    setState(() => _busyMonitor = false);
  }

  Future<void> _toggleMonitoring() async {
    _serviceRunning ? await _stopMonitoring() : await _startMonitoring();
  }

  // LOCAL SUMMARY
  Future<void> _refreshLocalSummary() async {
    try {
      final db = await GameDatabase.instance.database;
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).millisecondsSinceEpoch;

      final res = await db.rawQuery(
  '''
  SELECT SUM(duration) as total 
  FROM game_events 
  WHERE CAST(timestamp AS INTEGER) >= ?
  ''',
  [startOfDay],
);


      final sec = (res.first['total'] as int?) ?? 0;
      setState(() => _todayMinutes = sec ~/ 60);
    } catch (_) {}
  }

  // MODERN SUMMARY CARD
  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bar_chart, size: 30, color: Colors.blue),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's usage",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 6),
              Text(
                "$_todayMinutes min",
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: (_serviceRunning ? Colors.green : Colors.red).withOpacity(
                0.15,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _serviceRunning ? "ACTIVE" : "INACTIVE",
              style: TextStyle(
                color: _serviceRunning ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // BIG MODERN RING BUTTON
  Widget _bigCircleButton() {
    final running = _serviceRunning;

    return GestureDetector(
      onTap: _busyMonitor ? null : _toggleMonitoring,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: running
                ? [Colors.red.shade400, Colors.red.shade700]
                : [_primary.withOpacity(0.8), _primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (running ? Colors.red : _primary).withOpacity(0.45),
              blurRadius: 36,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: _busyMonitor
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              : Text(
                  running ? "STOP" : "START",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  // ❗ MODERN OUTLINED BUTTON STYLE (BIGGER)
  ButtonStyle _modernButtonStyle() {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      side: BorderSide(color: _primary, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      foregroundColor: _primary,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  // MAIN UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Digital Twin Monitor",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: _primary,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          // FIXED YELLOW OVERFLOW
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  const Text(
                    "Tap the button below to start or stop\nbackground monitoring.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15),
                  ),

                  const SizedBox(height: 28),

                  _summaryCard(),
                  const SizedBox(height: 40),

                  _bigCircleButton(),
                  const SizedBox(height: 40),

                  // BIG MODERN BUTTON 1
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      style: _modernButtonStyle(),
                      icon: const Icon(Icons.apps, size: 22),
                      label: const Text("VIEW INSTALLED APPS"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const InstalledGamesScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 14),

                  // BIG MODERN BUTTON 2
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      style: _modernButtonStyle(),
                      icon: const Icon(Icons.qr_code, size: 22),
                      label: const Text("SHOW CHILD PROFILE"),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChildIdScreen(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
