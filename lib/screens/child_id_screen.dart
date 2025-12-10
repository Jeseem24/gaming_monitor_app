// lib/screens/child_id_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/service_controller.dart';
import 'pin_verify_screen.dart';

class ChildIdScreen extends StatefulWidget {
  const ChildIdScreen({super.key});

  @override
  State<ChildIdScreen> createState() => _ChildIdScreenState();
}

class _ChildIdScreenState extends State<ChildIdScreen> {
  String _childId = "";
  String _childName = "";

  @override
  void initState() {
    super.initState();
    _loadSelectedChild();
  }

  Future<void> _loadSelectedChild() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString("selected_child_id");
    final name = prefs.getString("selected_child_name");

    setState(() {
      if (id == null || id.trim().isEmpty) {
        _childId = "No child selected";
        _childName = "";
      } else {
        _childId = id;
        _childName = name ?? "";
      }
    });
  }

  // 🔥 LOGOUT FLOW
  Future<void> _handleLogout() async {
    final ok = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PinVerifyScreen(),
    );

    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    final running = prefs.getBool("service_running") ?? false;

    if (running) {
      await ServiceController.stopMonitoringService();
    }

    await prefs.clear();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF3D77FF);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Child Profile"),
        backgroundColor: primaryBlue,
        elevation: 0,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 20, 26, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // ⭐ Top Icon
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  size: 42,
                  color: primaryBlue,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                "Linked Child Profile",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                "Details of the child connected to this device.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 30),

              // ⭐ CARD
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (_childName.isNotEmpty) ...[
                      const Text(
                        "CHILD NAME",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _childName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    const Text(
                      "CHILD DEVICE ID",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.7,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 12),

                    SelectableText(
                      _childId,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              if (_childId != "No child selected")
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text(
                    "COPY ID",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 26,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _childId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Child ID copied")),
                    );
                  },
                ),

              const SizedBox(height: 120), // space before bottom button
            ],
          ),
        ),
      ),

      // ⭐ BIG FIXED BOTTOM LOGOUT BUTTON
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.logout_rounded, size: 24),
            label: const Text(
              "LOGOUT",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _handleLogout,
          ),
        ),
      ),
    );
  }
}
