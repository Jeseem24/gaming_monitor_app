// lib/screens/monitoring_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync_service.dart';
import '../services/native_event_handler.dart';
import '../database.dart';
import 'pin_verify_screen.dart';

const MethodChannel _serviceChannel = MethodChannel('game_detection');

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  bool _serviceRunning = false;
  bool _busy = false;
  int _todayMinutes = 0;
  final Color _primary = const Color(0xFF3D77FF);

  @override
  void initState() {
    super.initState();
    // Safe: will not show system dialog again if already asked
    _requestNotificationPermission();
    _loadServiceState();
    _refreshSummary();
  }

  Future<void> _loadServiceState() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool('service_running') ?? false;
    setState(() => _serviceRunning = stored);
    // If serviceRunning true on startup, start sync loop and ensure native listener is running
    if (_serviceRunning) {
      // start native listener so service events are handled
      await NativeEventHandler.instance.start();
      SyncService.instance.startSyncLoop();
    }
  }

  Future<void> _saveServiceState(bool running) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('service_running', running);
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (!status.isGranted) await Permission.notification.request();
  }

  // start native service + sync loop
  Future<void> _startService() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      // Ensure the Dart-side native event handler is active BEFORE asking native to start.
      // This prevents a race where native immediately sends events while Flutter isn't listening.
      await NativeEventHandler.instance.start();

      // Now call native to start foreground service
      await _serviceChannel.invokeMethod('start_service');

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Background service started')),
      );

      // local state + sync
      setState(() {
        _serviceRunning = true;
      });
      await _saveServiceState(true);

      // start sync loop after service started (so DB events from service will be picked up)
      SyncService.instance.startSyncLoop();
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start service: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // stop sync loop and try to stop native service (if native supports it)
  Future<void> _stopService() async {
    if (_busy) return;
    setState(() => _busy = true);

    // require PIN verification before stopping
    final ok = await showDialog(
      context: context,
      builder: (_) => const PinVerifyScreen(),
    );

    if (ok != true) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    // stop sync & local state immediately
    SyncService.instance.stopSyncLoop();
    setState(() {
      _serviceRunning = false;
    });
    await _saveServiceState(false);

    // attempt to notify native to stop foreground service (native may not implement stop; that's ok)
    try {
      await _serviceChannel.invokeMethod('stop_service');
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (e) {
      // ignore if platform doesn't implement stop_service
    }

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Monitoring stopped locally')));

    if (mounted) setState(() => _busy = false);
  }

  // toggle wrapper
  Future<void> _toggleService() async {
    if (_serviceRunning) {
      await _stopService();
    } else {
      await _startService();
    }
  }

  Widget _stateBadge({required bool active}) {
    final color = active ? Colors.green.shade600 : Colors.grey.shade400;
    final text = active ? 'ACTIVE' : 'INACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillButton() {
    final label = _serviceRunning ? 'STOP MONITORING' : 'START MONITORING';
    final background = _serviceRunning ? Colors.red.shade600 : _primary;
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: _busy ? null : _toggleService,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_busy) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
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
                  'Today\'s total usage',
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
          _stateBadge(active: _serviceRunning),
        ],
      ),
    );
  }

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
      final totalSec = res.isNotEmpty ? (res.first['total'] as int?) ?? 0 : 0;
      final totalMin = (totalSec ~/ 60);
      if (mounted) setState(() => _todayMinutes = totalMin);
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring'),
        backgroundColor: _primary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await _refreshSummary();
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Summary refreshed')),
                );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Monitoring is ready. Use the button below to start background tracking.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _summaryCard(),
              const SizedBox(height: 22),
              _buildPillButton(),
              const SizedBox(height: 14),
              const Text(
                'Background detection will continue even when the app is closed.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (_) => Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Quick actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Start/Stop monitoring\n• View logs (dev)\n• Settings (future)',
                  ),
                ],
              ),
            ),
          );
        },
        backgroundColor: _primary,
        child: const Icon(Icons.settings),
      ),
    );
  }
}
