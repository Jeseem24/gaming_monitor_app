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

  // 🎨 Consistent theme colors
  static const Color _primary = Color(0xFF3D77FF);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _textDark = Color(0xFF2D3436);
  static const Color _textLight = Color(0xFF636E72);
  static const Color _background = Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

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

  Future<void> _loadApps() async {
    setState(() => _loading = true);

    final list = await InstalledAppsService.listInstalled();

    if (!mounted) return;

    setState(() {
      _apps = list;
      _loading = false;
    });
  }

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
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text("Marked as ${value.toUpperCase()}"),
          ],
        ),
        backgroundColor: _success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _clearOverride(String pkg) async {
    await InstalledAppsService.clearOverride(pkg);
    _updateLocalOverride(pkg, null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text("Override cleared"),
          ],
        ),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

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

  void _showAppDetails(Map<String, dynamic> app) {
    final label = _sanitize(app['label']);
    final pkg = _sanitize(app['package']);
    final override = app['override'] as String?;
    final isGame = app['isGame'] == true;
    final auto = app['autoIsGame'] == true;
    final Uint8List? icon = app['icon'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // App Icon & Name
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: icon != null && icon.isNotEmpty
                              ? Image.memory(icon, fit: BoxFit.cover)
                              : Container(
                                  color: _primary.withAlpha(20),
                                  child: Center(
                                    child: Text(
                                      _getSafeInitial(label),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: _primary,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pkg,
                              style: TextStyle(
                                fontSize: 12,
                                color: _textLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Status Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _detailRow(
                          "Auto-detected",
                          auto ? "Game" : "App",
                          auto ? Icons.games_rounded : Icons.apps_rounded,
                        ),
                        if (override != null) ...[
                          const SizedBox(height: 12),
                          _detailRow(
                            "Override",
                            override.toUpperCase(),
                            Icons.edit_rounded,
                            valueColor: _primary,
                          ),
                        ],
                        const SizedBox(height: 12),
                        _detailRow(
                          "Current Status",
                          isGame ? "GAME" : "APP",
                          isGame ? Icons.sports_esports_rounded : Icons.phone_android_rounded,
                          valueColor: isGame ? _success : _textLight,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  if (isGame)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.phone_android_rounded, size: 20),
                        label: const Text("MARK AS APP"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _primary,
                          side: BorderSide(color: _primary.withAlpha(100)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          if (await _checkPinSessionOrAuthenticate()) {
                            await _applyOverride(pkg, 'app');
                          }
                        },
                      ),
                    ),

                  if (!isGame)
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.games_rounded, size: 20),
                        label: const Text("MARK AS GAME"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _success,
                          side: BorderSide(color: _success.withAlpha(100)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          if (await _checkPinSessionOrAuthenticate()) {
                            await _applyOverride(pkg, 'game');
                          }
                        },
                      ),
                    ),

                  if (override != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: TextButton.icon(
                        icon: Icon(Icons.refresh_rounded, size: 20, color: _textLight),
                        label: Text(
                          "RESET TO AUTO",
                          style: TextStyle(color: _textLight),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          if (await _checkPinSessionOrAuthenticate()) {
                            await _clearOverride(pkg);
                          }
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _textLight),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: _textLight),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? _textDark,
          ),
        ),
      ],
    );
  }

  Widget _appTile(Map<String, dynamic> app) {
    final label = _sanitize(app['label']);
    final pkg = _sanitize(app['package']);
    final override = app['override'] as String?;
    final isGame = app['isGame'] == true;
    final Uint8List? icon = app['icon'];

    return GestureDetector(
      onTap: () => _showAppDetails(app),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            // Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 48,
                height: 48,
                child: icon != null && icon.isNotEmpty
                    ? Image.memory(
                        icon,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholderIcon(label),
                      )
                    : _placeholderIcon(label),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _textDark,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (override != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "OVERRIDE",
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    pkg,
                    style: TextStyle(fontSize: 12, color: _textLight),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isGame ? _success.withAlpha(20) : Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isGame ? "GAME" : "APP",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isGame ? _success : _textLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon(String label) {
    return Container(
      color: _primary.withAlpha(15),
      child: Center(
        child: Text(
          _getSafeInitial(label),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _primary,
          ),
        ),
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
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              color: _background,
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
                    "Installed Apps",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _textDark,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${_visibleApps.length}",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _textLight,
                    ),
                  ),
                ],
              ),
            ),

            // Search & Filter
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              color: _background,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _filter = v),
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Search apps...",
                          hintStyle: TextStyle(color: _textLight.withAlpha(150)),
                          prefixIcon: Icon(Icons.search_rounded, color: _textLight, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _onlyGames = !_onlyGames),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: _onlyGames ? _success.withAlpha(20) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _onlyGames ? _success : Colors.grey.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.games_rounded,
                            size: 18,
                            color: _onlyGames ? _success : _textLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Games",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _onlyGames ? _success : _textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _primary))
                  : _visibleApps.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: _textLight.withAlpha(100)),
                              const SizedBox(height: 12),
                              Text(
                                "No apps found",
                                style: TextStyle(color: _textLight),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _visibleApps.length,
                          itemBuilder: (_, i) => _appTile(_visibleApps[i]),
                        ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Text(
                "${_apps.length} apps detected • ${_visibleApps.length} shown",
                style: TextStyle(fontSize: 12, color: _textLight),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}