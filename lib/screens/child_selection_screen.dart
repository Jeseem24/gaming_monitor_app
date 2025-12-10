// lib/screens/child_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'monitoring_screen.dart';
import 'login_screen.dart';

class ChildSelectionScreen extends StatefulWidget {
  const ChildSelectionScreen({super.key});

  @override
  State<ChildSelectionScreen> createState() => _ChildSelectionScreenState();
}

class _ChildSelectionScreenState extends State<ChildSelectionScreen> {
  bool _loading = true;
  List<Map<String, String>> _children = [];

  @override
  void initState() {
    super.initState();
    _loadChildrenFromLocal();
  }

  Future<void> _loadChildrenFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("child_list");

    if (raw == null || raw.isEmpty) {
      setState(() {
        _children = [];
        _loading = false;
      });
      return;
    }

    final decoded = jsonDecode(raw);

    if (decoded is! List || decoded.isEmpty) {
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

    setState(() {
      _children = parsed;
      _loading = false;
    });
  }

  Future<void> _selectChild(Map<String, String> child) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("selected_child_id", child["id"]!);
    await prefs.setString("selected_child_name", child["name"]!);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MonitoringScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF3D77FF);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Digital Twin Monitor"),
          backgroundColor: primaryBlue,
          elevation: 0,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _children.isEmpty
                ? _buildEmptyMessage()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // ⭐ MAIN TITLE
                      const Text(
                        "Select the child profile",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // ⭐ SUBTITLE
                      const Text(
                        "Choose a linked child account to start monitoring.",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 22),

                      Expanded(child: _buildChildList()),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // EMPTY STATE UI
  // ===============================================================
  Widget _buildEmptyMessage() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(28),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 14,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 42, color: Colors.orange),
            SizedBox(height: 14),
            Text(
              "No child profiles found.",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Please add children using the Parent Dashboard.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // CHILD CARDS LIST (MODERN UI)
  // ===============================================================
  Widget _buildChildList() {
    const primaryBlue = Color(0xFF3D77FF);

    return ListView.builder(
      itemCount: _children.length,
      itemBuilder: (context, i) {
        final child = _children[i];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
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
          child: Row(
            children: [
              // ⭐ CIRCLE AVATAR (UPGRADED)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_circle_rounded,
                  color: primaryBlue,
                  size: 34,
                ),
              ),

              const SizedBox(width: 16),

              // NAME + ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child["name"]!,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "ID: ${child["id"]}",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // SELECT BUTTON
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _selectChild(child),
                child: const Text(
                  "SELECT",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
