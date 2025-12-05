// lib/screens/pin_verify_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple PIN verification dialog. Call with:
/// final ok = await showDialog(context: context, builder: (_) => const PinVerifyScreen());
/// returns true if verified else false / null.
class PinVerifyScreen extends StatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  State<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends State<PinVerifyScreen> {
  final TextEditingController _ctrl = TextEditingController();
  bool _obscure = true;
  String? _error;
  bool _checking = false;

  Future<void> _verify() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString('parent_pin') ?? '';
    await Future.delayed(const Duration(milliseconds: 300)); // small UX delay
    if (_ctrl.text.trim() == pin && pin.isNotEmpty) {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = 'Incorrect PIN';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter PIN to Confirm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            obscureText: _obscure,
            maxLength: 4,
            decoration: InputDecoration(
              counterText: '',
              hintText: '4-digit PIN',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _verify(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        ElevatedButton(
          onPressed: _checking ? null : _verify,
          child: _checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('CONFIRM'),
        ),
      ],
    );
  }
}
