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

  // 🎨 Consistent theme colors
  static const Color _primary = Color(0xFF3D77FF);
  static const Color _error = Color(0xFFE74C3C);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _textDark = Color(0xFF2D3436);
  static const Color _textLight = Color(0xFF636E72);
  static const Color _background = Color(0xFFF8F9FA);

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

  // 🔥 FIXED LOGOUT FLOW
  Future<void> _handleLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PinVerifyScreen(),
    );

    if (ok != true) return;

    final prefs = await SharedPreferences.getInstance();
    
    // 1. Stop the service first
    final running = prefs.getBool("service_running") ?? false;
    if (running) {
      await ServiceController.stopMonitoringService();
    }

    // 2. ✅ SELECTIVE CLEAR (Don't use prefs.clear())
    // We keep: consent_done, notif_done, pin_set, parent_pin, app_overrides
    // We remove: user session data
    final keysToRemove = [
      "parent_id",
      "parent_email",
      "auth_token",
      "child_list",
      "selected_child_id",
      "selected_child_name",
      "service_running"
    ];

    for (String key in keysToRemove) {
      await prefs.remove(key);
    }
    
    debugPrint("🚪 Logout: Session data cleared, Onboarding data preserved.");

    if (!mounted) return;

    // 3. Go back to Login (MonitoringGate will now handle this correctly)
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  void _copyId() async {
    await Clipboard.setData(ClipboardData(text: _childId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text("Child ID copied to clipboard"),
          ],
        ),
        backgroundColor: _success,
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
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _textDark,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    "Child Profile",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _primary.withAlpha(30),
                            _primary.withAlpha(15),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: _childName.isNotEmpty
                            ? Text(
                                _childName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                ),
                              )
                            : const Icon(
                                Icons.child_care_rounded,
                                size: 44,
                                color: _primary,
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Name
                    if (_childName.isNotEmpty) ...[
                      Text(
                        _childName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: _textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Subtitle
                    const Text(
                      "Linked to this device",
                      style: TextStyle(
                        fontSize: 14,
                        color: _textLight,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        children: [
                          _infoRow(
                            icon: Icons.fingerprint_rounded,
                            label: "Child ID",
                            value: _childId,
                            showCopy: _childId != "No child selected",
                            onCopy: _copyId,
                          ),

                          if (_childName.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Divider(height: 1),
                            ),
                            _infoRow(
                              icon: Icons.person_rounded,
                              label: "Name",
                              value: _childName,
                            ),
                          ],

                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Divider(height: 1),
                          ),

                          _infoRow(
                            icon: Icons.link_rounded,
                            label: "Status",
                            value: _childId != "No child selected" ? "Connected" : "Not Connected",
                            valueColor: _childId != "No child selected" ? _success : _error,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_childId != "No child selected")
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_rounded, size: 20),
                          label: const Text(
                            "COPY CHILD ID",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _primary,
                            side: BorderSide(color: _primary.withAlpha(100), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _copyId,
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Logout Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.logout_rounded, size: 22),
                  label: const Text(
                    "LOGOUT",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _handleLogout,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool showCopy = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primary.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: _primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: _textLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? _textDark,
                ),
              ),
            ],
          ),
        ),
        if (showCopy && onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.copy_rounded,
                size: 18,
                color: _textLight,
              ),
            ),
          ),
      ],
    );
  }
}