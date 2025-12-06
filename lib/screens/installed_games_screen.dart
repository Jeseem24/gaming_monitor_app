// lib/screens/installed_games_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/installed_apps_service.dart';
import 'pin_verify_screen.dart';

class InstalledGamesScreen extends StatefulWidget {
  const InstalledGamesScreen({super.key});

  @override
  State<InstalledGamesScreen> createState() => _InstalledGamesScreenState();
}

class _InstalledGamesScreenState extends State<InstalledGamesScreen> {
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  String _filter = '';
  bool _onlyGames = false;

  static const _pinSessionMs = 5 * 60 * 1000; // 5 minutes

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  // --------------------------
  // UTF-16 safe sanitizer
  // --------------------------
  String _sanitize(String? text) {
    if (text == null) return '';
    try {
      final buffer = StringBuffer();
      for (final r in text.runes) {
        if (r == 0) continue;
        buffer.writeCharCode(r);
      }
      return buffer.toString();
    } catch (_) {
      return text.replaceAll(RegExp(r'[^\x00-\x7F]'), '?');
    }
  }

  String _getSafeInitial(String? text) {
    final s = _sanitize(text);
    if (s.isEmpty) return '?';
    try {
      final rune = s.runes.first;
      return String.fromCharCode(rune).toUpperCase();
    } catch (_) {
      return '?';
    }
  }

  // --------------------------
  // PIN Session Checker
  // --------------------------
  Future<bool> _checkPinSessionOrAuthenticate() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('override_verified_at') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - last < _pinSessionMs) return true;

    final ok = await showDialog(
      context: context,
      builder: (_) => const PinVerifyScreen(),
    );

    if (ok == true) {
      await prefs.setInt('override_verified_at', now);
      return true;
    }
    return false;
  }

  // --------------------------
  // Load list ONCE
  // --------------------------
  Future<void> _loadApps() async {
    setState(() => _loading = true);

    final list = await InstalledAppsService.listInstalled();

    if (!mounted) return;

    setState(() {
      _apps = list;
      _loading = false;
    });
  }

  // --------------------------
  // Only update the specific app → FAST
  // --------------------------
  void _updateLocalOverride(String pkg, String? override) {
    setState(() {
      for (var app in _apps) {
        if (app['package'] == pkg) {
          if (override == null) {
            app.remove('override');
            app['isGame'] = app['autoIsGame'] == true;
          } else {
            app['override'] = override;
            app['isGame'] = override == 'game';
          }
        }
      }
    });
  }

  Future<void> _applyOverride(String pkg, String value) async {
    await InstalledAppsService.setOverride(pkg, value);
    _updateLocalOverride(pkg, value);

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Override saved → $pkg → ${value.toUpperCase()}")),
    );
  }

  Future<void> _clearOverride(String pkg) async {
    await InstalledAppsService.clearOverride(pkg);
    _updateLocalOverride(pkg, null);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Override cleared")));
  }

  // --------------------------
  // Filtering for search + toggle
  // --------------------------
  List<Map<String, dynamic>> get _visibleApps {
    return _apps.where((a) {
      final label = _sanitize(a['label']);
      final pkg = _sanitize(a['package']);

      if (_onlyGames && a['isGame'] != true) return false;

      if (_filter.isEmpty) return true;

      final f = _filter.toLowerCase();
      return label.toLowerCase().contains(f) || pkg.toLowerCase().contains(f);
    }).toList();
  }

  // --------------------------
  // Single Tile Widget
  // --------------------------
  Widget _tile(Map<String, dynamic> app) {
    final label = _sanitize(app['label']);
    final pkg = _sanitize(app['package']);
    final override = app['override'] as String?;
    final isGame = app['isGame'] == true;
    final auto = app['autoIsGame'] == true;
    final Uint8List? icon = app['icon'];

    final showMarkAsApp = isGame;
    final showMarkAsGame = !isGame;

    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: icon != null && icon.isNotEmpty
              ? Image.memory(
                  icon,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade300,
                    child: Center(
                      child: Text(
                        _getSafeInitial(label),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
              : Container(
                  color: Colors.grey.shade300,
                  child: Center(
                    child: Text(
                      _getSafeInitial(label),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
        ),
      ),

      title: Row(
        children: [
          Expanded(child: Text(label)),
          if (override != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "OVERRIDE: ${override.toUpperCase()}",
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),

      subtitle: Text(pkg, style: const TextStyle(fontSize: 12)),

      trailing: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isGame
              ? Colors.green.withOpacity(0.15)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isGame ? "GAME" : "APP",
          style: TextStyle(
            color: isGame ? Colors.green.shade800 : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),

      onTap: () {
        showModalBottomSheet(
          context: context,
          builder: (_) => Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (_, setSheet) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(pkg, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 10),
                  Text(
                    auto ? "Auto-detected as GAME." : "Auto-detected as APP.",
                  ),
                  if (override != null)
                    Text("Override: ${override.toUpperCase()}"),
                  const SizedBox(height: 20),

                  // MARK AS APP
                  if (showMarkAsApp)
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (await _checkPinSessionOrAuthenticate()) {
                          await _applyOverride(pkg, 'app');
                        }
                      },
                      child: const Text("MARK AS APP (PIN)"),
                    ),

                  // MARK AS GAME
                  if (showMarkAsGame)
                    OutlinedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (await _checkPinSessionOrAuthenticate()) {
                          await _applyOverride(pkg, 'game');
                        }
                      },
                      child: const Text("MARK AS GAME (PIN)"),
                    ),

                  // CLEAR OVERRIDE
                  if (override != null)
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        if (await _checkPinSessionOrAuthenticate()) {
                          await _clearOverride(pkg);
                        }
                      },
                      child: const Text("CLEAR OVERRIDE (PIN)"),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --------------------------
  // UI BUILD
  // --------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Installed Apps",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: const Color(0xFF3D77FF),
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _filter = v),
                          decoration: const InputDecoration(
                            hintText: "Search apps or package name",
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        children: [
                          const Text("Only games"),
                          Switch(
                            value: _onlyGames,
                            onChanged: (v) => setState(() => _onlyGames = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _visibleApps.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => _tile(_visibleApps[i]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    "Detected ${_apps.length} apps — showing ${_visibleApps.length}",
                  ),
                ),
              ],
            ),
    );
  }
}
