// lib/screens/consent_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'monitoring_gate.dart';

const MethodChannel _usageChannel = MethodChannel('usage_access');

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen>
    with WidgetsBindingObserver {
  bool? _usageGranted;
  Timer? _pollTimer;
  bool _consentCompleted = false;
  bool _isProcessing = false;

  // 🎨 Theme colors - use throughout the app
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkUsageAccess();
      _startPolling();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkUsageAccess();
      _startPolling();
    } else {
      _stopPolling();
    }
  }

  void _startPolling() {
    if (_consentCompleted) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkUsageAccess(),
    );
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _checkUsageAccess() async {
    if (!mounted || _consentCompleted) return;

    try {
      final bool allowed = await _usageChannel.invokeMethod('check_usage');
      if (!mounted || _consentCompleted) return;
      setState(() => _usageGranted = allowed);
    } on MissingPluginException {
      // Engine temporarily detached — safe to ignore
    } catch (e) {
      debugPrint('check_usage error (safe ignore): $e');
    }
  }

  Future<void> _openUsageSettings() async {
    try {
      await _usageChannel.invokeMethod('open_settings');
    } catch (e) {
      debugPrint('open_settings error: $e');
    }
  }

  Future<void> _onIHaveEnabled({bool fromBottomSheet = false}) async {
    if (_isProcessing || _consentCompleted) return;

    setState(() => _isProcessing = true);
    _stopPolling();

    if (fromBottomSheet && mounted) {
      Navigator.of(context).pop();
    }

    await _checkUsageAccess();

    if (_usageGranted == true) {
      _consentCompleted = true;

      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('consent_done', true);
      debugPrint("✅ SAVED: consent_done = true");

      final notifStatus = await Permission.notification.request();
      await prefs.setBool('notif_done', notifStatus.isGranted);
      debugPrint("✅ SAVED: notif_done = ${notifStatus.isGranted}");

      await prefs.reload();

      debugPrint("✅ VERIFY: consent_done = ${prefs.getBool('consent_done')}");
      debugPrint("✅ VERIFY: notif_done = ${prefs.getBool('notif_done')}");

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 100));

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MonitoringGate()),
        (route) => false,
      );
    } else {
      if (!mounted) return;

      setState(() => _isProcessing = false);
      _startPolling();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Usage Access still not enabled. Please enable it and try again.',
          ),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _statusRow() {
    Color dotColor;
    String label;
    IconData icon;

    if (_usageGranted == null) {
      dotColor = Colors.grey;
      label = 'Checking usage access…';
      icon = Icons.hourglass_empty_rounded;
    } else if (_usageGranted == true) {
      dotColor = _success;
      label = 'Usage Access: ENABLED';
      icon = Icons.check_circle_rounded;
    } else {
      dotColor = _error;
      label = 'Usage Access: NOT ENABLED';
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: dotColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dotColor.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(icon, color: dotColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: dotColor,
              ),
            ),
          ),
          if (_usageGranted == null)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: dotColor,
              ),
            ),
        ],
      ),
    );
  }

  void _showHowToSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(sheetContext).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              const Text(
                'How to Enable Usage Access',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 20),

              // Steps
              _buildStep('1', 'Tap "Open Settings" below'),
              _buildStep('2', 'Find "Digital Twin Monitor"'),
              _buildStep('3', 'Enable "Permit usage access"'),
              _buildStep('4', 'Return here and confirm'),

              const SizedBox(height: 20),

              // Status
              _statusRow(),

              const SizedBox(height: 24),

              // Buttons
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _openUsageSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OPEN SETTINGS',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => _onIHaveEnabled(fromBottomSheet: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primary,
                    side: const BorderSide(color: _primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'I HAVE ENABLED ACCESS',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: _textDark,
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
        child: Padding(
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
                  Icons.shield_rounded,
                  size: 52,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 28),

              // Title
              const Text(
                'Parental Consent Required',
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
                'This app monitors which apps (games) are used and for how long. Only app name and duration are collected — no personal data.',
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

              // Primary Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _showHowToSheet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withAlpha(150),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'GIVE CONSENT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // Secondary Button
              TextButton(
                onPressed: _isProcessing ? null : () => _onIHaveEnabled(),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                ),
                child: const Text(
                  'I have already enabled access',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Footer
              Text(
                'By continuing you confirm you are the parent/guardian and grant permission for background monitoring.',
                style: TextStyle(
                  fontSize: 12,
                  color: _textLight.withAlpha(180),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}