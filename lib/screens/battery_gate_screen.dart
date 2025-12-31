// lib/screens/battery_gate_screen.dart
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'monitoring_gate.dart'; // ✅ Point back to the gate

class BatteryGateScreen extends StatefulWidget {
  const BatteryGateScreen({super.key});

  @override
  State<BatteryGateScreen> createState() => _BatteryGateScreenState();
}

class _BatteryGateScreenState extends State<BatteryGateScreen> {
  static const Color _primary = Color(0xFF3D77FF);
  static const Color _textDark = Color(0xFF2D3436);
  static const Color _textLight = Color(0xFF636E72);
  static const Color _background = Color(0xFFF8F9FA);

  Future<void> _handlePermission(bool skip) async {
    if (!skip) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('battery_done', true);

    if (!mounted) return;
    // ✅ Always return to MonitoringGate to let it decide the next screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MonitoringGate()),
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
              const Spacer(flex: 2),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.battery_saver_rounded, size: 52, color: _primary),
              ),
              const SizedBox(height: 28),
              const Text(
                'Unrestricted Monitoring',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'To ensure the app can track gameplay accurately even when the screen is off, please allow it to run without battery restrictions.',
                style: TextStyle(fontSize: 15, height: 1.5, color: _textLight),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => _handlePermission(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('ENABLE UNRESTRICTED MODE', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _handlePermission(true),
                child: const Text('Maybe Later', style: TextStyle(color: _textLight, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}