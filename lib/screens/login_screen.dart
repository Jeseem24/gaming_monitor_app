// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'child_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _busy = false;
  bool _showPassword = false;

  // 🎨 Consistent theme colors
  static const Color _primary = Color(0xFF3D77FF);
  static const Color _textDark = Color(0xFF2D3436);
  static const Color _textLight = Color(0xFF636E72);
  static const Color _background = Color(0xFFF8F9FA);

  static const String baseUrl = "https://gaming-twin-backend.onrender.com";

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

    Future<void> _login() async {
    final email = _emailCtl.text.trim();
    final pass = _passCtl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _toast("Enter email and password");
      return;
    }

    setState(() => _busy = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // (Keep Mock Accounts code here...)
      if (email == "zero@test.com" && pass == "1111") { /* ... */ }
      // ... (rest of mock accounts)

      // ==================== REAL BACKEND ====================
      debugPrint("🌐 Sending Login to: $baseUrl/parent/login");
      debugPrint("📤 Payload: email: $email");

      final response = await http.post(
        Uri.parse("$baseUrl/parent/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": email, "password": pass}),
      );

      // ✅ ADD THESE TWO LINES TO SEE THE ERROR:
      debugPrint("📥 Status Code: ${response.statusCode}");
      debugPrint("📥 Response Body: ${response.body}");

      if (response.statusCode != 200) {
        _toast("Server Error (${response.statusCode}). Check logs."); // Updated message
        setState(() => _busy = false);
        return;
      }

      final data = jsonDecode(response.body);
      if (data["success"] != true) {
        _toast("Login failed: ${data["message"] ?? "Invalid credentials"}");
        setState(() => _busy = false);
        return;
      }

      final parentId = data["parent_id"].toString();
      final children = (data["children"] is List) ? data["children"] : [];

      await prefs.setString("parent_email", email);
      await prefs.setString("parent_id", parentId);
      await prefs.setString("auth_token", data["token"]?.toString() ?? "local_token");
      await prefs.setString("child_list", jsonEncode(children));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChildSelectionScreen()),
      );
    } catch (e) {
      debugPrint("🚨 Exception during login: $e");
      _toast("Connection error. Check internet.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 42,
                    color: _primary,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  "Parent Login",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  "Use the same credentials as the Parent Dashboard",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: _textLight,
                  ),
                ),
                const SizedBox(height: 32),

                // Form Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Email Field
                      TextField(
                        controller: _emailCtl,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Email",
                          hintText: "Enter your email",
                          prefixIcon: const Icon(Icons.email_outlined, color: _textLight),
                          filled: true,
                          fillColor: _background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      TextField(
                        controller: _passCtl,
                        obscureText: !_showPassword,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Password",
                          hintText: "Enter your password",
                          prefixIcon: const Icon(Icons.lock_outline, color: _textLight),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                              color: _textLight,
                            ),
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                          ),
                          filled: true,
                          fillColor: _background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: _primary.withAlpha(150),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "LOGIN",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Footer
                Text(
                  "Digital Twin Monitor",
                  style: TextStyle(
                    fontSize: 12,
                    color: _textLight.withAlpha(150),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}