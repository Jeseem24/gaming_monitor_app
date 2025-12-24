// lib/screens/pin_create_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'login_screen.dart';

class PinCreateScreen extends StatefulWidget {
  const PinCreateScreen({super.key});

  @override
  State<PinCreateScreen> createState() => _PinCreateScreenState();
}

class _PinCreateScreenState extends State<PinCreateScreen> {
  String _pin = "";
  bool _saving = false;
  String? _errorText;
  int _visiblePinIndex = -1;

  // 🎨 Consistent theme colors
  static const Color _primary = Color(0xFF3D77FF);
  static const Color _errorColor = Color(0xFFE74C3C);
  static const Color _textDark = Color(0xFF2D3436);
  static const Color _textLight = Color(0xFF636E72);
  static const Color _background = Color(0xFFF8F9FA);

  Future<void> _savePin() async {
    if (_pin.length != 4) {
      setState(() => _errorText = "Enter a 4-digit PIN");
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("parent_pin", _pin);
    await prefs.setBool("pin_set", true);

    debugPrint("✅ SAVED: pin_set = true");

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _onKeyPress(String key) {
    if (key == "back") {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _visiblePinIndex = -1;
          _errorText = null;
        });
      }
      return;
    }

    if (_pin.length >= 4) return;

    setState(() {
      _pin += key;
      _visiblePinIndex = _pin.length - 1;
      _errorText = null;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() => _visiblePinIndex = -1);
    });
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        bool filled = i < _pin.length;
        bool showDigit = i == _visiblePinIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          height: 52,
          width: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: filled
                ? (showDigit ? _primary.withAlpha(30) : _primary)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: filled ? _primary : Colors.grey.shade300,
              width: 2,
            ),
          ),
          child: showDigit
              ? Text(
                  _pin[i],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                )
              : filled
                  ? Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
        );
      }),
    );
  }

  Widget _keyButton(String text) {
    return GestureDetector(
      onTap: () => _onKeyPress(text),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade200, width: 1.5),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
      ),
    );
  }

  Widget _backspaceButton() {
    return GestureDetector(
      onTap: () => _onKeyPress("back"),
      child: Container(
        width: 68,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.backspace_outlined,
          size: 24,
          color: _textLight,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // Icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 36,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        const Text(
                          "Create Parent PIN",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _textDark,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Subtitle
                        const Text(
                          "This PIN is required to stop monitoring.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: _textLight,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // PIN Dots
                        _buildPinDots(),

                        // Error
                        SizedBox(
                          height: 32,
                          child: Center(
                            child: _errorText != null
                                ? Text(
                                    _errorText!,
                                    style: const TextStyle(
                                      color: _errorColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  )
                                : null,
                          ),
                        ),

                        const Spacer(),

                        // Keypad
                        Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _keyButton("1"),
                                _keyButton("2"),
                                _keyButton("3"),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _keyButton("4"),
                                _keyButton("5"),
                                _keyButton("6"),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _keyButton("7"),
                                _keyButton("8"),
                                _keyButton("9"),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const SizedBox(width: 68),
                                _keyButton("0"),
                                _backspaceButton(),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: (_saving || _pin.length != 4) ? null : _savePin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: _primary.withAlpha(100),
                              disabledForegroundColor: Colors.white70,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "SAVE PIN",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}