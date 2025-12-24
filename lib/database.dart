// lib/database.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
// ✅ Add this at the top for debugPrint

class GameDatabase {
  GameDatabase._private();
  static final GameDatabase instance = GameDatabase._private();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    String path = join(dbPath, "gaming_monitor.db");
    return await openDatabase(path, version: 1, onCreate: _createTables);
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE game_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        package_name TEXT NOT NULL,
        game_name TEXT,
        genre TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // ✅ FIX: Changed TEXT to INTEGER for time columns
  }

  Future<int> insertEvent(Map<String, dynamic> event) async {
    final db = await database;
    debugPrint("🔥 [DB] INSERT EVENT → $event");
    return db.insert("game_events", event);
  }

  Future<List<Map<String, dynamic>>> getPendingEvents() async {
    final db = await database;
    return await db.query("game_events", where: "synced = ?", whereArgs: [0]);
  }

  Future<void> markEventSynced(int id) async {
    final db = await database;
    await db.update(
      "game_events",
      {"synced": 1},
      where: "id = ?",
      whereArgs: [id],
    );
  }

  // ✅ FIX: Corrected SQL query for epoch milliseconds
  Future<void> deleteOlderThan(int days) async {
    final db = await database;
    final cutoffMs = DateTime.now()
        .subtract(Duration(days: days))
        .millisecondsSinceEpoch;

    await db.delete(
      "game_events",
      where: "timestamp < ?",
      whereArgs: [cutoffMs],
    );
    debugPrint("🧹 [DB] Deleted events older than $days days");
  }

  Future<void> clearAllEvents() async {
    final db = await database;
    debugPrint("🧹 [DB] CLEARING ALL LOCAL EVENTS...");
    await db.delete("game_events");
  }
}