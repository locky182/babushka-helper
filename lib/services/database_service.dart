import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/pressure_record.dart';
import '../models/user_profile.dart';

class DatabaseService {
  DatabaseService._internal();
  static final DatabaseService instance = DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'pressure_app_v3.db');

    return openDatabase(
      path,
      version: 4,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            systolic INTEGER NOT NULL,
            diastolic INTEGER NOT NULL,
            pulse INTEGER NOT NULL,
            dateTime TEXT NOT NULL,
            pillName TEXT,
            pillDose TEXT,
            userId INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            age INTEGER NOT NULL DEFAULT 0,
            iconKey TEXT NOT NULL,
            colorValue INTEGER NOT NULL
          )
        ''');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE records ADD COLUMN pillName TEXT');
          await db.execute('ALTER TABLE records ADD COLUMN pillDose TEXT');
        }
        if (oldVersion < 3) {
          // Проверяем и создаем таблицу users если её нет
          final tables = await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table' AND name='users'");
          if (tables.isEmpty) {
            await db.execute('''
              CREATE TABLE users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT,
                iconKey TEXT,
                colorValue INTEGER
              )
            ''');
          }

          // Проверяем и добавляем колонку userId если её нет
          final columns = await db.rawQuery("PRAGMA table_info(records)");
          final hasUserId = columns.any((c) => c['name'] == 'userId');
          if (!hasUserId) {
            await db.execute('ALTER TABLE records ADD COLUMN userId INTEGER');
            await db.execute('UPDATE records SET userId = 1');
          }
        }
        if (oldVersion < 4) {
          final columns = await db.rawQuery("PRAGMA table_info(users)");
          final hasAge = columns.any((c) => c['name'] == 'age');
          if (!hasAge) {
            await db.execute(
                'ALTER TABLE users ADD COLUMN age INTEGER NOT NULL DEFAULT 0');
          }
        }
      },
    );
  }

  Future<int> insertRecord(PressureRecord record) async {
    final db = await database;
    if (record.userId == null) {
      throw ArgumentError('Record must have userId');
    }
    return db.insert('records', record.toMap());
  }

  Future<List<PressureRecord>> getRecords({required int userId}) async {
    final db = await database;
    final rows = await db.query(
      'records',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'dateTime DESC',
    );
    return rows.map(PressureRecord.fromMap).toList();
  }

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return db.query('users');
  }

  Future<int> insertUser(Map<String, dynamic> user) async {
    final db = await database;
    return db.insert('users', user);
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return db.delete(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUser(int id) async {
    final db = await database;
    await db.delete(
      'records',
      where: 'userId = ?',
      whereArgs: [id],
    );
    await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateUser(UserProfile user) async {
    final db = await database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }
}
