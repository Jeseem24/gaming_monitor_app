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

  static const String baseUrl = "https://gaming-twin-backend.onrender.com";

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  // ============================================================
  //                       LOGIN LOGIC
  // ============================================================
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

      // ------------------------------------------------------------
      //                   REAL BACKEND LOGIN
      // ------------------------------------------------------------
      final response = await http.post(
        Uri.parse("$baseUrl/parent/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": pass,
        }),
      );

      if (response.statusCode != 200) {
        _toast("Invalid login. Check credentials.");
        return;
      }

      final data = jsonDecode(response.body);

      if (data["success"] != true) {
        _toast("Login failed");
        return;
      }

      // ---------------- NORMALIZE DATA ----------------
      final parentId = data["parent_id"].toString();

      final rawChildren =
          (data["children"] is List) ? data["children"] : [];

      final children = rawChildren.map<Map<String, String>>((c) {
        return {
          "child_id": c["child_id"].toString(),
          "name": c["name"]?.toString() ?? "Child",
        };
      }).toList();

      // ---------------- SAVE LOCALLY ----------------
      await prefs.setString("parent_email", email);
      await prefs.setString("parent_id", parentId);
      await prefs.setString(
        "auth_token",
        data["token"]?.toString() ?? "local_token",
      );
      await prefs.setString("child_list", jsonEncode(children));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ChildSelectionScreen(),
        ),
      );
    } catch (e) {
      _toast("Error logging in: $e");
    } finally {
      setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ============================================================
  //                         UI
  // ============================================================
  @override
  Widget build(BuildContext context) {
    const Color primaryBlue = Color(0xFF3D77FF);

    return Scaffold(
      appBar: AppBar(title: const Text("Digital Twin Monitor")),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(26, 10, 26, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 5),

                  const Text(
                    "Login to Continue",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "Use the same credentials as the Parent Dashboard\nYour child’s insights await you.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailCtl,
                          decoration: const InputDecoration(
                            labelText: "Parent Email",
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: _passCtl,
                          obscureText: !_showPassword,
                          decoration: InputDecoration(
                            labelText: "Password",
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(
                                  () => _showPassword = !_showPassword,
                                );
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _busy ? null : _login,
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    "LOGIN",
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
