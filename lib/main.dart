// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/consent_screen.dart';
import 'screens/notification_gate_screen.dart';
import 'screens/pin_create_screen.dart';
import 'screens/monitoring_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // NOTE: We intentionally DO NOT start NativeEventHandler here.
  // The native background service must only be allowed to send events
  // after the user has completed onboarding and started monitoring.
  runApp(const GamingMonitorApp());
}

class GamingMonitorApp extends StatelessWidget {
  const GamingMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gaming Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D77FF)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const RootRouter(),
    );
  }
}

/// Root router checks onboarding flags and routes to the correct screen.
/// Flow (first install only):
/// 1) request notification system popup (Option A)
/// 2) Consent screen (usage access)
/// 3) Notification gate (if still not granted)
/// 4) PIN create (one-time)
/// 5) Monitoring
class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  bool _loading = true;
  bool _consentDone = false;
  bool _notifDone = false;
  bool _pinSet = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();

    _consentDone = prefs.getBool('consent_done') ?? false;
    _notifDone = prefs.getBool('notif_done') ?? false;
    _pinSet = prefs.getBool('pin_set') ?? false;

    // OPTION A: Show system notification permission popup immediately on first app launch
    // We only request if notif_done is false.
    if (!_notifDone) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        if (result.isGranted) {
          // mark notif done immediately
          await prefs.setBool('notif_done', true);
          _notifDone = true;
        }
      } else {
        // already granted earlier
        await prefs.setBool('notif_done', true);
        _notifDone = true;
      }
    }

    // After requesting system popup, update loading and allow build to route to next step
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Now route based on flags; each screen will itself update flags once completed.
    if (!_consentDone) {
      return const ConsentScreen();
    }

    if (!_notifDone) {
      // If notification was still not granted after the initial popup, show the gate (no skip).
      return const NotificationGateScreen();
    }

    if (!_pinSet) {
      return const PinCreateScreen();
    }

    return const MonitoringScreen();
  }
}
