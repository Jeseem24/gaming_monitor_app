// lib/screens/notification_gate_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pin_create_screen.dart';

class NotificationGateScreen extends StatefulWidget {
  const NotificationGateScreen({super.key});

  @override
  State<NotificationGateScreen> createState() => _NotificationGateScreenState();
}

class _NotificationGateScreenState extends State<NotificationGateScreen> {
  bool _checking = true;
  bool _granted = false;

  // 🎨 Consistent theme colors
  static const Color _primary = Color(0xFF3D77FF);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _textDark = Color(0xFF2D3436);
  static const Color _textLight = Color(0xFF636E72);
  static const Color _background = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.notification.status;

    if (!mounted) return;

    setState(() {
      _granted = status.isGranted;
      _checking = false;
    });

    if (_granted) {
      await _saveAndProceed();
    }
  }

  Future<void> _requestPermission() async {
    final status = await Permission.notification.request();

    if (status.isGranted) {
      await _saveAndProceed();
      return;
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Enable Notifications',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Notifications are required. Please enable them from settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('CANCEL', style: TextStyle(color: _textLight)),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('OPEN SETTINGS', style: TextStyle(color: _primary)),
            ),
          ],
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enable notifications to continue"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _saveAndProceed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_done', true);

    debugPrint("✅ SAVED: notif_done = true");

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PinCreateScreen()),
    );
  }

  Widget _statusRow() {
    final Color statusColor = _granted ? _success : _textLight;
    final String statusText = _granted ? 'Notifications Enabled' : 'Permission Required';
    final IconData statusIcon = _granted ? Icons.check_circle_rounded : Icons.notifications_off_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _checking
            ? const Center(child: CircularProgressIndicator(color: _primary))
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  children: [
                    const Spacer(flex: 1),

                    // Icon
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: _primary.withAlpha(25),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.notifications_rounded,
                        size: 52,
                        color: _primary,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Title
                    const Text(
                      'Enable Notifications',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Description
                    const Text(
                      'We need notification permission to deliver important alerts about your child\'s activity.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: _textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Status
                    _statusRow(),

                    const Spacer(flex: 2),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _granted ? null : _requestPermission,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _granted ? _success : _primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _success,
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _granted ? Icons.check_rounded : Icons.notifications_active_rounded,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _granted ? 'ENABLED' : 'ENABLE NOTIFICATIONS',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    
                    const SizedBox(height: 8),
                  ],
                ),
              ),
      ),
    );
  }
}