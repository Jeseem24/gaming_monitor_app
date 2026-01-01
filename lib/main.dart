// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'screens/monitoring_gate.dart';
import 'screens/login_screen.dart';
import 'screens/child_selection_screen.dart';
import 'screens/monitoring_screen.dart';
import 'screens/installed_games_screen.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SERVER WARMUP - Handles Render.com cold starts (30-50 seconds)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class ServerWarmup {
  static const String _baseUrl = 'https://gaming-twin-backend.onrender.com';
  static bool _isWarmingUp = false;
  static bool _isReady = false;
  
  /// Check if server is ready
  static bool get isReady => _isReady;
  
  /// Wake up the server - call this as early as possible
  /// Non-blocking, runs in background
  static void wakeUp() {
    if (_isWarmingUp || _isReady) return;
    _isWarmingUp = true;
    
    _warmUpWithRetry().then((_) {
      _isWarmingUp = false;
    });
  }
  
  static Future<void> _warmUpWithRetry() async {
    final stopwatch = Stopwatch()..start();
    debugPrint("🌅 [WARMUP] Waking up server...");
    
    // Try up to 3 times with increasing timeouts
    final timeouts = [30, 45, 60]; // seconds
    
    for (int attempt = 0; attempt < timeouts.length; attempt++) {
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/health'),
        ).timeout(Duration(seconds: timeouts[attempt]));
        
        if (response.statusCode == 200) {
          stopwatch.stop();
          _isReady = true;
          debugPrint("✅ [WARMUP] Server ready! Took ${stopwatch.elapsedMilliseconds}ms");
          return;
        } else {
          debugPrint("⚠️ [WARMUP] Attempt ${attempt + 1}: Status ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("⚠️ [WARMUP] Attempt ${attempt + 1} failed: $e");
        
        // If not last attempt, wait a bit before retry
        if (attempt < timeouts.length - 1) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    
    stopwatch.stop();
    debugPrint("❌ [WARMUP] Server wake-up failed after ${stopwatch.elapsedMilliseconds}ms");
  }
  
  /// Quick health check (for already-warm server)
  static Future<bool> quickPing() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      _isReady = response.statusCode == 200;
      return _isReady;
    } catch (e) {
      return false;
    }
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MAIN ENTRY POINT
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🎨 Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  
  // 🌅 Wake up server IMMEDIATELY (fire-and-forget, non-blocking)
  // This runs in background while user goes through onboarding screens
  ServerWarmup.wakeUp();
      
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