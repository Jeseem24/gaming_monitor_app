// lib/screens/monitoring_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'monitoring_gate.dart';
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

class _MonitoringScreenState extends State<MonitoringScreen>
    with WidgetsBindingObserver {
  bool _serviceRunning = false;
  bool _busyMonitor = false;
  int _todayMinutes = 0;
  bool _isInitialized = false;

  Timer? _refreshTimer;

  // 🎨 Consistent theme colors
  static const Color _primary = Color(0xFF3D77FF);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _error = Color(0xFFE74C3C);
  static const Color _textDark = Color(0xFF2D3436);
  static const Color _textLight = Color(0xFF636E72);
  static const Color _background = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRefreshTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLocalSummary();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      _stopRefreshTimer();
    }
  }

  Future<void> _initialize() async {
    await _requestNotificationPermission();
    await _checkChildSelected();
    _startRefreshTimer();
  }

  void _startRefreshTimer() {
    _stopRefreshTimer();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) {
        if (mounted) {
          _refreshLocalSummary();
        }
      },
    );
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> _checkChildSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString("selected_child_id");

    if (!mounted) return;

    if (id == null || id.isEmpty) {
      _showNoChildSelectedDialog();
    } else {
      await _loadServiceState();
      await _refreshLocalSummary();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  void _showNoChildSelectedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "No Child Selected",
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text("Please select a child profile before monitoring."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
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

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
  }

  Future<void> _loadServiceState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final running = prefs.getBool('service_running') ?? false;

      if (!mounted) return;
      setState(() => _serviceRunning = running);

      if (running) {
        await _serviceChannel.invokeMethod('start_service'); 

        await NativeEventHandler.instance.start();
        SyncService.instance.startSyncLoop();
      }
    } catch (e) {
      debugPrint('Load service state error: $e');
    }
  }

  Future<void> _saveServiceState(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('service_running', value);
    } catch (e) {
      debugPrint('Save service state error: $e');
    }
  }

  Future<void> _startMonitoring() async {
    if (_busyMonitor) return;

    if (!mounted) return;
    setState(() => _busyMonitor = true);

    try {
      await NativeEventHandler.instance.start();
      await _serviceChannel.invokeMethod('start_service');

      SyncService.instance.startSyncLoop();
      await _saveServiceState(true);

      if (!mounted) return;
      setState(() => _serviceRunning = true);

      _showSnackBar("Monitoring started", isSuccess: true);
    } catch (e) {
      _showSnackBar("Failed: $e", isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _busyMonitor = false);
      }
    }
  }

  Future<void> _stopMonitoring() async {
    if (_busyMonitor) return;

    if (!mounted) return;
    setState(() => _busyMonitor = true);

    try {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PinVerifyScreen(),
      );

      if (ok != true) {
        if (mounted) setState(() => _busyMonitor = false);
        return;
      }

      SyncService.instance.stopSyncLoop();
      await _serviceChannel.invokeMethod('stop_service');
      await _saveServiceState(false);

      if (!mounted) return;
      setState(() => _serviceRunning = false);

      _showSnackBar("Monitoring stopped", isSuccess: true);
    } catch (e) {
      debugPrint('Stop monitoring error: $e');
      _showSnackBar("Failed to stop monitoring", isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _busyMonitor = false);
      }
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_serviceRunning) {
      await _stopMonitoring();
    } else {
      await _startMonitoring();
    }
  }

  void _showSnackBar(String message, {bool isSuccess = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
        backgroundColor: isSuccess ? _success : _error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _refreshLocalSummary() async {
    if (!mounted) return;

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

      if (!mounted) return;

      final total = res.first['total'];
      final sec = (total is int) ? total : (total as num?)?.toInt() ?? 0;

      setState(() => _todayMinutes = sec ~/ 60);
    } catch (e) {
      debugPrint('Refresh summary error: $e');
    }
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _primary.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bar_chart_rounded, size: 28, color: _primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Usage",
                  style: TextStyle(
                    fontSize: 14,
                    color: _textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$_todayMinutes min",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: (_serviceRunning ? _success : _error).withAlpha(20),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (_serviceRunning ? _success : _error).withAlpha(50),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _serviceRunning ? _success : _error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _serviceRunning ? "ACTIVE" : "INACTIVE",
                  style: TextStyle(
                    color: _serviceRunning ? _success : _error,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigCircleButton() {
    final running = _serviceRunning;

    return GestureDetector(
      onTap: _busyMonitor ? null : _toggleMonitoring,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 180,
        height: 180,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: running
                ? [_error.withAlpha(220), _error]
                : [_primary.withAlpha(220), _primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (running ? _error : _primary).withAlpha(80),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: _busyMonitor
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      running ? "STOP" : "START",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  ButtonStyle _modernButtonStyle() {
    return OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),
      side: BorderSide(color: _primary.withAlpha(100), width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      foregroundColor: _primary,
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: _primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Digital Twin Monitor",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
                          ),
                          Text(
                            "Child activity monitoring",
                            style: TextStyle(
                              fontSize: 13,
                              color: _textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Summary Card
                _summaryCard(),

                const SizedBox(height: 36),

                // Start/Stop Button
                _bigCircleButton(),

                const SizedBox(height: 12),

                // Hint text
                Text(
                  _serviceRunning
                      ? "Tap to stop monitoring"
                      : "Tap to start monitoring",
                  style: TextStyle(
                    fontSize: 13,
                    color: _textLight,
                  ),
                ),

                const SizedBox(height: 36),

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    style: _modernButtonStyle(),
                    icon: const Icon(Icons.apps_rounded, size: 20),
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
                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    style: _modernButtonStyle(),
                    icon: const Icon(Icons.child_care_rounded, size: 20),
                    label: const Text("CHILD PROFILE"),
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

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}