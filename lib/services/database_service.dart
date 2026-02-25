import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/call_log.dart';
import '../models/block_list.dart';
import '../models/settings.dart';

class DatabaseService {
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<void> init() async {
    _db = await _initDb();
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'spam_blocker.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE call_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            result TEXT NOT NULL,
            marked_as_spam INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE block_list (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT NOT NULL UNIQUE,
            label TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE whitelist (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT NOT NULL UNIQUE,
            label TEXT,
            source TEXT NOT NULL DEFAULT 'manual'
          )
        ''');
        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        // Insert default settings
        final defaults = AppSettings();
        for (final entry in defaults.toMap().entries) {
          await db.insert('settings', {
            'key': entry.key,
            'value': entry.value.toString(),
          });
        }
      },
    );
  }

  // Call log operations
  Future<int> insertCallLog(CallLogEntry entry) async {
    final db = await database;
    return db.insert('call_log', entry.toMap());
  }

  Future<List<CallLogEntry>> getCallLogs({int limit = 100}) async {
    final db = await database;
    final maps = await db.query('call_log',
        orderBy: 'timestamp DESC', limit: limit);
    return maps.map(CallLogEntry.fromMap).toList();
  }

  Future<void> updateCallLogSpamStatus(int id, bool isSpam) async {
    final db = await database;
    await db.update('call_log', {'marked_as_spam': isSpam ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // Block list operations
  Future<int> addToBlockList(BlockListEntry entry) async {
    final db = await database;
    return db.insert('block_list', entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<List<BlockListEntry>> getBlockList() async {
    final db = await database;
    final maps =
        await db.query('block_list', orderBy: 'created_at DESC');
    return maps.map(BlockListEntry.fromMap).toList();
  }

  Future<bool> isBlocked(String phoneNumber) async {
    final db = await database;
    final result = await db.query('block_list',
        where: 'phone_number = ?', whereArgs: [phoneNumber]);
    return result.isNotEmpty;
  }

  Future<void> removeFromBlockList(int id) async {
    final db = await database;
    await db.delete('block_list', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearBlockList() async {
    final db = await database;
    await db.delete('block_list');
  }

  // Whitelist operations
  Future<void> addToWhitelist(String phoneNumber,
      {String? label, String source = 'manual'}) async {
    final db = await database;
    await db.insert(
      'whitelist',
      {
        'phone_number': phoneNumber,
        'label': label,
        'source': source,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<bool> isWhitelisted(String phoneNumber) async {
    final db = await database;
    final result = await db.query('whitelist',
        where: 'phone_number = ?', whereArgs: [phoneNumber]);
    return result.isNotEmpty;
  }

  Future<void> syncContactsToWhitelist(
      List<Map<String, String>> contacts) async {
    final db = await database;
    final batch = db.batch();
    for (final contact in contacts) {
      batch.insert(
        'whitelist',
        {
          'phone_number': contact['phone']!,
          'label': contact['name'],
          'source': 'contacts',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  // Settings operations
  Future<AppSettings> getSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    final map = <String, dynamic>{};
    for (final row in rows) {
      final key = row['key'] as String;
      final value = row['value'] as String;
      map[key] = int.tryParse(value) ?? value;
    }
    return AppSettings.fromMap(map);
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final db = await database;
    await db.update('settings', {'value': value.toString()},
        where: 'key = ?', whereArgs: [key]);
  }
}
