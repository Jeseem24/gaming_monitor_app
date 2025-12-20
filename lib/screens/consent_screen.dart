import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 🔒 KEEP IMPORTS (even if unused now)
import 'pin_create_screen.dart';
import 'monitoring_screen.dart';
import 'notification_gate_screen.dart';

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

  // ============================================================
  // ✅ APP LIFECYCLE SAFE POLLING
  // ============================================================
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

  // ============================================================
  // USAGE ACCESS CHECK
  // ============================================================
  Future<void> _checkUsageAccess() async {
  if (!mounted || _consentCompleted) return;

  try {
    final bool allowed =
        await _usageChannel.invokeMethod('check_usage');

    if (!mounted || _consentCompleted) return;
    setState(() => _usageGranted = allowed);
  } on MissingPluginException {
    // ✅ Engine temporarily detached — safe to ignore
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

  // ============================================================
  // CONTINUE FLOW
  // ============================================================
Future<void> _onIHaveEnabled() async {
  _stopPolling(); // ⛔ stop polling first

  await _checkUsageAccess(); // ✅ allow one final check

  if (_usageGranted == true) {
    _consentCompleted = true; // ✅ mark complete ONLY after success

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('consent_done', true);

    final notifStatus = await Permission.notification.request();
    await prefs.setBool('notif_done', notifStatus.isGranted);

    if (!mounted) return;

    if (notifStatus.isGranted) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const NotificationGateScreen(),
        ),
      );
    }
  } else {
    // ❌ consent not completed → polling can resume if needed
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Usage Access still not enabled. Please enable it and try again.',
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }
}



  // ============================================================
  // STATUS ROW (UNCHANGED)
  // ============================================================
  Widget _statusRow() {
    Color dotColor;
    String label;

    if (_usageGranted == null) {
      dotColor = Colors.grey;
      label = 'Checking usage access…';
    } else if (_usageGranted == true) {
      dotColor = const Color(0xFF2ECC71);
      label = 'Usage Access: ENABLED';
    } else {
      dotColor = const Color(0xFFE74C3C);
      label = 'Usage Access: NOT ENABLED';
    }

    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: dotColor.withOpacity(0.25),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INSTRUCTION SHEET (UNCHANGED)
  // ============================================================
  void _showHowToSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final height = MediaQuery.of(context).size.height * 0.5;
        return SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 60,
                  height: 6,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Text(
                  'How to enable Usage Access',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. Tap "Open Usage Access Settings".\n'
                  '2. Find "Digital Twin Monitor" and enable "Permit usage access".\n'
                  '3. Return here and press "I HAVE ENABLED ACCESS".',
                  style: TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                _statusRow(),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _openUsageSettings();
                      Navigator.pop(context);
                    },
                    child: const Text('OPEN USAGE ACCESS SETTINGS'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _onIHaveEnabled();
                    },
                    child: const Text('I HAVE ENABLED ACCESS'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // MAIN UI (UNCHANGED)
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF3D77FF);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Icon(Icons.shield_rounded, size: 64, color: primary),
                ),
              ),
              const SizedBox(height: 26),
              const Text(
                'Parental Consent Required',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'This app monitors which apps (games) are used and for how long. '
                'Only app name and duration are collected — no personal data.',
                style: TextStyle(fontSize: 15, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _statusRow(),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _showHowToSheet,
                child: const Text('GIVE CONSENT TO START MONITORING'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _onIHaveEnabled,
                child: const Text('I HAVE ENABLED ACCESS'),
              ),
              const Spacer(),
              const Text(
                'By continuing you confirm you are the parent/guardian and grant permission for background monitoring.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
