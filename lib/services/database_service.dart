import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/pressure_record.dart';

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
    final path = p.join(dbPath, 'pressure_diary.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY,
            systolic INTEGER,
            diastolic INTEGER,
            pulse INTEGER,
            dateTime TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertRecord(PressureRecord record) async {
    final db = await database;
    return db.insert('records', {
      'systolic': record.systolic,
      'diastolic': record.diastolic,
      'pulse': record.pulse,
      'dateTime': record.dateTime.toIso8601String(),
    });
  }

  Future<List<PressureRecord>> getRecords() async {
    final db = await database;
    final rows = await db.query(
      'records',
      orderBy: 'dateTime DESC',
    );
    return rows.map(PressureRecord.fromMap).toList();
  }

  Future<int> deleteRecord(int id) async {
    final db = await database;
    return db.delete(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
