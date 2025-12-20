// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Screens
import 'screens/consent_screen.dart';
import 'screens/notification_gate_screen.dart';
import 'screens/pin_create_screen.dart';
import 'screens/login_screen.dart';
import 'screens/child_selection_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/installed_games_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear(); // 🔥 HARD RESET
  runApp(const GamingMonitorApp());
}

class GamingMonitorApp extends StatelessWidget {
  const GamingMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  debugShowCheckedModeBanner: false,

  home: const RootRouter(),

  // 🚫 disable Android route restoration
  restorationScopeId: null,

  routes: {
    '/login': (_) => const LoginScreen(),
    '/child-selection': (_) => const ChildSelectionScreen(),
    '/monitoring': (_) => const MonitoringScreen(),
    '/installed_games': (_) => const InstalledGamesScreen(),
  },
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
  bool _loginDone = false;
  bool _childSelected = false;

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

    _loginDone = (prefs.getString("parent_id") ?? "").isNotEmpty;
    _childSelected =
        (prefs.getString("selected_child_id") ?? "").isNotEmpty;

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ✅ FINAL, GUARANTEED FLOW
    if (!_consentDone) return const ConsentScreen();
    if (!_notifDone) return const NotificationGateScreen();
    if (!_pinSet) return const PinCreateScreen();
    if (!_loginDone) return const LoginScreen();
    if (!_childSelected) return const ChildSelectionScreen();

    return const MonitoringScreen();
  }
}
