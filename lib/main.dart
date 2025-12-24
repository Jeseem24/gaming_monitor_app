// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'screens/monitoring_gate.dart';
import 'screens/login_screen.dart';
import 'screens/child_selection_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/installed_games_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🎨 Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
http.get(Uri.parse('https://gaming-twin-backend.onrender.com/health'))
      .then((_) => debugPrint("🚀 Server pinged successfully"))
      .catchError((e) {
        debugPrint("⚠️ Server ping failed (expected if cold): $e");
        return http.Response('Error', 500); // Return dummy response
      });

  runApp(const GamingMonitorApp());
}

class GamingMonitorApp extends StatelessWidget {
  const GamingMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Digital Twin Monitor',
      
      // 🔒 LOCK UI STYLE
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF3D77FF),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF3D77FF),
          secondary: const Color(0xFF3D77FF),
          error: const Color(0xFFE74C3C),
        ),
      ),
      
      initialRoute: '/',
      routes: {
        '/': (_) => const MonitoringGate(),
        '/login': (_) => const LoginScreen(),
        '/child-selection': (_) => const ChildSelectionScreen(),
        '/monitoring': (_) => const MonitoringScreen(),
        '/installed_games': (_) => const InstalledGamesScreen(),
      },
    );
  }
}