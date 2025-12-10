// lib/screens/pin_create_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class PinCreateScreen extends StatefulWidget {
  const PinCreateScreen({super.key});

  @override
  State<PinCreateScreen> createState() => _PinCreateScreenState();
}

class _PinCreateScreenState extends State<PinCreateScreen> {
  String _pin = "";
  bool _saving = false;
  String? _error;

  // ⭐ NEW: reveal last typed digit temporarily
  int _visiblePinIndex = -1;

  Future<void> _savePin() async {
    if (_pin.length != 4) {
      setState(() => _error = "Enter a 4-digit PIN");
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("parent_pin", _pin);
    await prefs.setBool("pin_set", true);
    await prefs.setBool("consent_done", true);

    final notif = await Permission.notification.status;
    if (notif.isGranted) {
      await prefs.setBool("notif_done", true);
    }

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  // -----------------------------------------------------
  // Number Pad Input Handler + reveal last digit
  // -----------------------------------------------------
  void _onKeyPress(String key) {
    if (key == "back") {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _visiblePinIndex = -1;
        });
      }
      return;
    }

    // Prevent overflow
    if (_pin.length >= 4) return;

    setState(() {
      _pin += key;
      _visiblePinIndex = _pin.length - 1; // show last digit typed
      _error = null;
    });

    // hide last digit after 500ms
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _visiblePinIndex = -1);
    });
  }

  // -----------------------------------------------------
  // Dot indicators with digit reveal
  // -----------------------------------------------------
  Widget _buildPinDots() {
    const primaryBlue = Color(0xFF3D77FF);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        bool filled = i < _pin.length;
        bool showDigit = i == _visiblePinIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          height: 28,
          width: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: filled ? primaryBlue : Colors.grey.shade400,
              width: 2,
            ),
            color: filled
                ? (showDigit ? primaryBlue.withOpacity(0.15) : primaryBlue)
                : Colors.transparent,
          ),
          child: showDigit
              ? Text(
                  _pin[i],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryBlue,
                  ),
                )
              : null,
        );
      }),
    );
  }

  // -----------------------------------------------------
  // Number button
  // -----------------------------------------------------
  Widget _keyButton(String text) {
    const primaryBlue = Color(0xFF3D77FF);

    return GestureDetector(
      onTap: () => _onKeyPress(text),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400, width: 1.8),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: primaryBlue,
          ),
        ),
      ),
    );
  }

  // -----------------------------------------------------
  // Backspace button
  // -----------------------------------------------------
  Widget _backspaceButton() {
    const primaryBlue = Color(0xFF3D77FF);

    return GestureDetector(
      onTap: () => _onKeyPress("back"),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        child: Icon(Icons.backspace_outlined, size: 30, color: primaryBlue),
      ),
    );
  }

  // -----------------------------------------------------
  // UI BUILD
  // -----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF3D77FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create PIN"),
        backgroundColor: primaryBlue,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 26),
          child: Column(
            children: [
              const SizedBox(height: 10),

              const Text(
                "Set Parent PIN",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),

              const SizedBox(height: 12),

              const Text(
                "This PIN is required to stop monitoring.\nKeep it confidential.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 40),

              // PIN DOTS
              _buildPinDots(),

              const SizedBox(height: 10),

              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 40),

              // NUMERIC KEYPAD
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _keyButton("1"),
                        _keyButton("2"),
                        _keyButton("3"),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _keyButton("4"),
                        _keyButton("5"),
                        _keyButton("6"),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _keyButton("7"),
                        _keyButton("8"),
                        _keyButton("9"),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 70),
                        _keyButton("0"),
                        _backspaceButton(),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _savePin,
                  child: _saving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "SAVE PIN",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
