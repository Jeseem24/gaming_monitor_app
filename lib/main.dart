// lib/main.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

// Screens
import 'screens/installed_games_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/notification_gate_screen.dart';
import 'screens/pin_create_screen.dart';
import 'screens/login_screen.dart';
import 'screens/child_selection_screen.dart';
import 'screens/monitoring_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GamingMonitorApp());
}

class GamingMonitorApp extends StatelessWidget {
  const GamingMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF3D77FF);

    return MaterialApp(
      title: 'Gaming Monitor',
      debugShowCheckedModeBanner: false,

      // ============================================================
      //                      GLOBAL THEME
      // ============================================================
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
          secondary: primaryBlue,
        ),

        scaffoldBackgroundColor: Colors.white,

        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: primaryBlue, width: 2),
          ),
          labelStyle: TextStyle(color: Colors.black87),
        ),
      ),

      // Router
      home: const RootRouter(),

      // ⭐⭐⭐ ALL REQUIRED ROUTES ADDED HERE ⭐⭐⭐
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

    // Read states
    _consentDone = prefs.getBool('consent_done') ?? false;
    _notifDone = prefs.getBool('notif_done') ?? false;
    _pinSet = prefs.getBool('pin_set') ?? false;

    // Login check
    final parentId = prefs.getString("parent_id");
    _loginDone = parentId != null && parentId.isNotEmpty;

    // Selected child check
    final childId = prefs.getString("selected_child_id");
    _childSelected = childId != null && childId.isNotEmpty;

    // Notification permission logic
    if (!_notifDone) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        if (result.isGranted) {
          await prefs.setBool("notif_done", true);
          _notifDone = true;
        }
      } else {
        await prefs.setBool("notif_done", true);
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

    // App step-by-step flow
    if (!_consentDone) return const ConsentScreen();
    if (!_notifDone) return const NotificationGateScreen();
    if (!_pinSet) return const PinCreateScreen();

    if (!_loginDone) return const LoginScreen();
    if (!_childSelected) return const ChildSelectionScreen();

    return const MonitoringScreen();
  }
}
