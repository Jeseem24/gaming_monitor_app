// lib/database.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
    
    // Incrementing version to 2 to trigger onCreate/onUpgrade if needed
    // However, for a clean test, it is best to uninstall the app first.
    return await openDatabase(
      path, 
      version: 1, 
      onCreate: _createTables
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE game_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        package_name TEXT NOT NULL,
        game_name TEXT,
        genre TEXT,
        start_time INTEGER,
        end_time INTEGER,
        duration INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT, -- ✅ ADDED: START, HEARTBEAT, or STOP
        synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
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

  // ✅ ADDED: Optimization to keep the database small
  Future<void> cleanUpSyncedEvents() async {
    final db = await database;
    // Delete events that are ALREADY synced and older than 1 day
    final oneDayAgo = DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    int count = await db.delete(
      "game_events", 
      where: "synced = 1 AND timestamp < ?", 
      whereArgs: [oneDayAgo]
    );
    debugPrint("🧹 [DB] Cleanup: Removed $count old synced records");
  }

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

  // ✅ ADDED: Prevent memory leaks
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      debugPrint("🔒 [DB] Database connection closed");
    }
  }
}