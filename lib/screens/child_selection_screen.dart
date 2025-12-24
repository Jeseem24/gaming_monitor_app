// lib/screens/child_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'monitoring_gate.dart';
import 'login_screen.dart';

class ChildSelectionScreen extends StatefulWidget {
  const ChildSelectionScreen({super.key});

  @override
  State<ChildSelectionScreen> createState() => _ChildSelectionScreenState();
}

class _ChildSelectionScreenState extends State<ChildSelectionScreen> {
  bool _loading = true;
  List<Map<String, String>> _children = [];
  bool _isSelecting = false;

  // 🎨 Consistent theme colors
  static const Color _primary = Color(0xFF3D77FF);
  static const Color _warning = Color(0xFFF39C12);
  static const Color _textDark = Color(0xFF2D3436);
  static const Color _textLight = Color(0xFF636E72);
  static const Color _background = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _loadChildrenFromLocal();
  }

  Future<void> _loadChildrenFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final raw = prefs.getString("child_list");

    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() {
        _children = [];
        _loading = false;
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List || decoded.isEmpty) {
        if (!mounted) return;
        setState(() {
          _children = [];
          _loading = false;
        });
        return;
      }

      final parsed = decoded.map<Map<String, String>>((c) {
        final id = c["child_id"]?.toString() ?? "UNKNOWN_ID";
        final name = c["name"]?.toString() ?? id;
        return {"id": id, "name": name};
      }).toList();

      if (!mounted) return;
      setState(() {
        _children = parsed;
        _loading = false;
      });
    } catch (e) {
      debugPrint("Error parsing children: $e");
      if (!mounted) return;
      setState(() {
        _children = [];
        _loading = false;
      });
    }
  }

  Future<void> _selectChild(Map<String, String> child) async {
    if (_isSelecting) return;
    setState(() => _isSelecting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString("selected_child_id", child["id"]!);
      await prefs.setString("selected_child_name", child["name"]!);

      debugPrint("✅ SAVED: selected_child_id = ${child["id"]}");
      debugPrint("✅ SAVED: selected_child_name = ${child["name"]}");

      await prefs.reload();

      final verifyId = prefs.getString("selected_child_id");
      final verifyName = prefs.getString("selected_child_name");
      debugPrint("✅ VERIFY: selected_child_id = $verifyId");
      debugPrint("✅ VERIFY: selected_child_name = $verifyName");

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 100));

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MonitoringGate()),
        (route) => false,
      );
    } catch (e) {
      debugPrint("❌ Error saving child: $e");
      if (!mounted) return;
      setState(() => _isSelecting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        }
      },
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _primary))
              : _children.isEmpty
                  ? _buildEmptyState()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header Section
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Back button row
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _textDark,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.child_care_rounded,
                  size: 38,
                  color: _primary,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                "Select Child Profile",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                "Choose which child to monitor on this device",
                style: TextStyle(
                  fontSize: 14,
                  color: _textLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // Child List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            itemCount: _children.length,
            itemBuilder: (context, i) => _buildChildCard(_children[i]),
          ),
        ),

        // Footer
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "${_children.length} child profile${_children.length > 1 ? 's' : ''} available",
            style: TextStyle(
              fontSize: 12,
              color: _textLight.withAlpha(150),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChildCard(Map<String, String> child) {
    return GestureDetector(
      onTap: _isSelecting ? null : () => _selectChild(child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _primary.withAlpha(40),
                    _primary.withAlpha(20),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  child["name"]!.isNotEmpty ? child["name"]![0].toUpperCase() : "?",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child["name"]!,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    "ID: ${child["id"]}",
                    style: TextStyle(
                      fontSize: 13,
                      color: _textLight,
                    ),
                  ),
                ],
              ),
            ),

            // Arrow or Loading
            _isSelecting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        // Header with back button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: _textDark,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Empty state content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _warning.withAlpha(25),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.person_off_rounded,
                    size: 50,
                    color: _warning,
                  ),
                ),
                const SizedBox(height: 24),

                // Title
                const Text(
                  "No Child Profiles",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                const SizedBox(height: 10),

                // Description
                Text(
                  "You haven't added any children yet.\nPlease add a child profile using the Parent Dashboard.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: _textLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Back to login button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text(
                      "BACK TO LOGIN",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: _primary, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}