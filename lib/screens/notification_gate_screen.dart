// lib/screens/notification_gate_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pin_create_screen.dart';
import 'monitoring_screen.dart';

class NotificationGateScreen extends StatefulWidget {
  const NotificationGateScreen({super.key});

  @override
  State<NotificationGateScreen> createState() => _NotificationGateScreenState();
}

class _NotificationGateScreenState extends State<NotificationGateScreen> {
  bool _checking = true;
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      _granted = status.isGranted;
      _checking = false;
    });
    if (_granted) _routeNext();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      _granted = status.isGranted;
    });

    final prefs = await SharedPreferences.getInstance();
    if (status.isGranted) {
      await prefs.setBool('notif_done', true);
      _routeNext();
    } else if (status.isPermanentlyDenied) {
      // ask user to open app settings
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Enable Notifications'),
          content: const Text(
            'Notifications are required for important alerts. Open app settings to enable notifications.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('OPEN SETTINGS'),
            ),
          ],
        ),
      );
    } else {
      // denied but not permanent — stay on gate and prompt user again
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable notifications to continue.'),
        ),
      );
    }
  }

  Future<void> _routeNext() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('parent_pin');
    if (pin == null || pin.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PinCreateScreen()),
      );
    } else {
      if (!mounted) return;
      await prefs.setBool('notif_done', true);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MonitoringScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF3D77FF);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Permission'),
        backgroundColor: primary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _checking
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Notifications permission',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'We need notification permission to deliver important alerts to parents. Please enable notifications to continue.',
                      style: TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _granted ? null : _requestPermission,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _granted ? 'ENABLED' : 'ENABLE NOTIFICATIONS',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 8),
                    const Text(
                      'Notifications are required. Please enable to proceed.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
