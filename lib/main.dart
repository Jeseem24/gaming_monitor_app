// lib/main.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/consent_screen.dart';
import 'screens/monitoring_screen.dart';
import 'services/native_event_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start native event listener early so background service can send events
  await NativeEventHandler.instance.start();

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

/// Simple root router that reads consent and navigates accordingly
class RootRouter extends StatefulWidget {
  const RootRouter({super.key});

  @override
  State<RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<RootRouter> {
  bool? _consentGiven;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool('parent_consent') ?? false;
    setState(() => _consentGiven = stored);
  }

  @override
  Widget build(BuildContext context) {
    if (_consentGiven == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _consentGiven == true
        ? const MonitoringScreen()
        : const ConsentScreen();
  }
}
