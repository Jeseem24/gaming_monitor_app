// lib/screens/monitoring_gate.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'consent_screen.dart';
import 'notification_gate_screen.dart';
import 'pin_create_screen.dart';
import 'login_screen.dart';
import 'child_selection_screen.dart';
import 'monitoring_screen.dart';

class MonitoringGate extends StatefulWidget {
  const MonitoringGate({super.key});

  @override
  State<MonitoringGate> createState() => _MonitoringGateState();
}

class _MonitoringGateState extends State<MonitoringGate> {
  bool _loading = true;
  Widget? _targetScreen;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final consent = prefs.getBool('consent_done') ?? false;
    final notif = prefs.getBool('notif_done') ?? false;
    final pin = prefs.getBool('pin_set') ?? false;
    final parentId = prefs.getString("parent_id") ?? "";
    final childId = prefs.getString("selected_child_id") ?? "";

    final login = parentId.isNotEmpty;
    final child = childId.isNotEmpty;

    debugPrint("═══════════════════════════════════════");
    debugPrint("🔍 MonitoringGate Check:");
    debugPrint("   consent_done: $consent");
    debugPrint("   notif_done: $notif");
    debugPrint("   pin_set: $pin");
    debugPrint("   parent_id: '$parentId'");
    debugPrint("   selected_child_id: '$childId'");
    debugPrint("═══════════════════════════════════════");

    Widget screen;

    if (!consent) {
      debugPrint("➡️ Going to ConsentScreen");
      screen = const ConsentScreen();
    } else if (!notif) {
      debugPrint("➡️ Going to NotificationGateScreen");
      screen = const NotificationGateScreen();
    } else if (!pin) {
      debugPrint("➡️ Going to PinCreateScreen");
      screen = const PinCreateScreen();
    } else if (!login) {
      debugPrint("➡️ Going to LoginScreen");
      screen = const LoginScreen();
    } else if (!child) {
      debugPrint("➡️ Going to ChildSelectionScreen");
      screen = const ChildSelectionScreen();
    } else {
      debugPrint("✅ All complete → MonitoringScreen");
      screen = const MonitoringScreen();
    }

    if (!mounted) return;

    setState(() {
      _targetScreen = screen;
      _loading = false;
    });
  } catch (e) {
    debugPrint("❌ MonitoringGate error: $e");
    if (!mounted) return;
    setState(() {
      _targetScreen = const ConsentScreen();
      _loading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    if (_loading || _targetScreen == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _targetScreen!;
  }
}
