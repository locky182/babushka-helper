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
      version: 2, // Поднимаем версию до 2
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE records (
            id INTEGER PRIMARY KEY,
            systolic INTEGER,
            diastolic INTEGER,
            pulse INTEGER,
            dateTime TEXT,
            pillName TEXT,
            pillDose TEXT
          )
        ''');
      },
      // Этот блок добавит колонки в уже существующую базу у мамы на телефоне
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE records ADD COLUMN pillName TEXT');
          await db.execute('ALTER TABLE records ADD COLUMN pillDose TEXT');
        }
      },
    );
  }

  Future<int> insertRecord(PressureRecord record) async {
    final db = await database;
    // Используем метод toMap() из модели, он уже умеет работать с pillName/pillDose
    return db.insert('records', record.toMap());
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
