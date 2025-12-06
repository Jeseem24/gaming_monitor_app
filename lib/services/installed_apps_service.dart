// lib/services/installed_apps_service.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InstalledAppsService {
  static const MethodChannel _channel = MethodChannel('installed_apps');

  /// RAM cache (fastest path)
  static List<Map<String, dynamic>>? _memoryCache;

  /// Icon cache in RAM
  static final Map<String, Uint8List?> _iconCache = {};

  /// Avoid multiple parallel fetches
  static bool _isFetching = false;

  // ----------------------------------------------------------------------
  // MAIN FAST API
  // ----------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> listInstalled() async {
    final prefs = await SharedPreferences.getInstance();

    // 1️⃣ RAM cache → fastest
    if (_memoryCache != null) {
      return _applyOverrides(_memoryCache!, prefs);
    }

    // 2️⃣ Load cached list (without icons)
    final cachedJson = prefs.getString("cached_installed_apps");
    if (cachedJson != null) {
      try {
        final List decoded = jsonDecode(cachedJson);
        final list = decoded
            .map<Map<String, dynamic>>(
              (e) => Map<String, dynamic>.from(e as Map),
            )
            .toList();

        // plug icons from RAM cache
        for (var it in list) {
          final pkg = it["package"];
          if (_iconCache.containsKey(pkg)) {
            it["icon"] = _iconCache[pkg];
          }
        }

        _memoryCache = list;
        return _applyOverrides(list, prefs);
      } catch (_) {}
    }

    // 3️⃣ Wait if another fetch in progress
    if (_isFetching) {
      await Future.delayed(const Duration(milliseconds: 200));
      return listInstalled();
    }

    // 4️⃣ Fetch from native (slow only ONCE)
    _isFetching = true;
    try {
      final res = await _channel.invokeMethod('list_installed');

      if (res is! List) {
        _isFetching = false;
        return [];
      }

      final nativeList = <Map<String, dynamic>>[];

      for (final e in res) {
        if (e is! Map) continue;

        final map = Map<String, dynamic>.from(e);

        final pkg = map["package"]?.toString() ?? "";

        // store icon in RAM but NOT in shared prefs
        if (map["icon"] is Uint8List) {
          _iconCache[pkg] = map["icon"];
        }

        nativeList.add(map);
      }

      // Save lightweight version (no icons) to prefs
      final withoutIcons = nativeList.map((m) {
        final c = Map<String, dynamic>.from(m);
        c.remove("icon");
        return c;
      }).toList();

      prefs.setString("cached_installed_apps", jsonEncode(withoutIcons));

      _memoryCache = nativeList;

      _isFetching = false;
      return _applyOverrides(nativeList, prefs);
    } catch (e) {
      _isFetching = false;
      return [];
    }
  }

  // ----------------------------------------------------------------------
  // APPLY OVERRIDES + RESOLVE FINAL isGame
  // ----------------------------------------------------------------------
  static List<Map<String, dynamic>> _applyOverrides(
    List<Map<String, dynamic>> list,
    SharedPreferences prefs,
  ) {
    final overrides = prefs.getStringMap("app_overrides") ?? {};

    return list.map((raw) {
      final pkg = raw["package"].toString();
      final autoIsGame = raw["isGame"] == true;

      final override = overrides[pkg];
      bool finalIsGame = autoIsGame;

      if (override == "game") finalIsGame = true;
      if (override == "app") finalIsGame = false;

      return {
        "package": pkg,
        "label": raw["label"]?.toString() ?? pkg,
        "autoIsGame": autoIsGame,
        "isGame": finalIsGame,
        "override": override,
        "icon": _iconCache[pkg],
      };
    }).toList();
  }

  // ----------------------------------------------------------------------
  // MANUAL REFRESH
  // ----------------------------------------------------------------------
  static Future<bool> refresh() async {
    _memoryCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("cached_installed_apps");
    return true;
  }

  // ----------------------------------------------------------------------
  // OVERRIDE SETTERS
  // ----------------------------------------------------------------------
  static Future<void> setOverride(String packageName, String value) async {
    final prefs = await SharedPreferences.getInstance();
    final map = prefs.getStringMap("app_overrides") ?? {};
    map[packageName] = value;
    await prefs.setStringMap("app_overrides", map);

    if (_memoryCache != null) {
      for (var item in _memoryCache!) {
        if (item["package"] == packageName) {
          item["override"] = value;
        }
      }
    }
  }

  static Future<void> clearOverride(String packageName) async {
    final prefs = await SharedPreferences.getInstance();
    final map = prefs.getStringMap("app_overrides") ?? {};
    map.remove(packageName);
    await prefs.setStringMap("app_overrides", map);

    if (_memoryCache != null) {
      for (var item in _memoryCache!) {
        if (item["package"] == packageName) {
          item["override"] = null;
        }
      }
    }
  }
}

extension _PrefsMap on SharedPreferences {
  Map<String, String>? getStringMap(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    try {
      final Map m = jsonDecode(raw);
      return m.map((k, v) => MapEntry(k.toString(), v.toString()));
    } catch (_) {
      return null;
    }
  }

  Future<bool> setStringMap(String key, Map<String, String> value) {
    return setString(key, jsonEncode(value));
  }
}
