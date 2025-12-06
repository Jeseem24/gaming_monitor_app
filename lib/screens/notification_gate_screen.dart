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

    if (status.isGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_done', true);
      _routeNext();
      return;
    }

    if (status.isPermanentlyDenied) {
      // ONLY here we ask to open settings
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Enable Notifications'),
          content: const Text(
            'Notifications are required. Please enable them from settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('OPEN SETTINGS'),
            ),
          ],
        ),
      );
    } else {
      // Not granted → keep trying without opening settings
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enable notifications to continue"),
        ),
      );
    }
  }

  Future<void> _routeNext() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('parent_pin');

    if (pin == null || pin.isEmpty) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PinCreateScreen()),
      );
      return;
    }

    await prefs.setBool('notif_done', true);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MonitoringScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF3D77FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notification Permission"),
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
                      'We need notification permission to deliver important alerts. Please enable notifications.',
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity, // make the button wide
                      child: ElevatedButton(
                        onPressed: _granted ? null : _requestPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _granted ? "ENABLED" : "ENABLE NOTIFICATIONS",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
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
