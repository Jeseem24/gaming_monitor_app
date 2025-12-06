// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// FIXED: All imports converted to safe relative imports
import 'screens/installed_games_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/notification_gate_screen.dart';
import 'screens/pin_create_screen.dart';
import 'screens/monitoring_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D77FF)),
        scaffoldBackgroundColor: Colors.white,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
        ),
      ),
      home: const RootRouter(),

      // FIXED: route defined without package import
      routes: {'/installed_games': (_) => const InstalledGamesScreen()},
    );
  }
}

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

    if (!_notifDone) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        if (result.isGranted) {
          await prefs.setBool('notif_done', true);
          _notifDone = true;
        }
      } else {
        await prefs.setBool('notif_done', true);
        _notifDone = true;
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_consentDone) return const ConsentScreen();
    if (!_notifDone) return const NotificationGateScreen();
    if (!_pinSet) return const PinCreateScreen();

    return const MonitoringScreen();
  }
}
