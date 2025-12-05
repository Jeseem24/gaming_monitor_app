// lib/screens/pin_create_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'monitoring_screen.dart';

class PinCreateScreen extends StatefulWidget {
  const PinCreateScreen({super.key});

  @override
  State<PinCreateScreen> createState() => _PinCreateScreenState();
}

class _PinCreateScreenState extends State<PinCreateScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _saving = false;

  Future<void> _savePin() async {
    final text = _ctrl.text.trim();
    if (text.length != 4 || int.tryParse(text) == null) {
      setState(() => _error = 'Enter a 4-digit PIN (numbers only)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_pin', text);
    await prefs.setBool('pin_set', true);
    await prefs.setBool('consent_done', true); // ensure consent persisted

    final notifStatus = await Permission.notification.status;
    if (notifStatus.isGranted) {
      await prefs.setBool('notif_done', true);
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MonitoringScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF3D77FF);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Parent PIN'),
        backgroundColor: primary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a 4-digit PIN',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'This PIN will be required to STOP monitoring. Do not share it with the child.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _ctrl,
                keyboardType: TextInputType.number,
                obscureText: _obscure,
                maxLength: 4,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Enter 4-digit PIN',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _savePin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('SAVE PIN'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
