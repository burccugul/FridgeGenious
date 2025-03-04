import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'foods.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE foods (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
      },
    );
  }

  // Yiyecek ekleme fonksiyonu
  Future<void> insertFood(String name) async {
    final db = await database;
    await db.insert(
      'foods',
      {'name': name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Tüm yiyecekleri getir
  Future<List<String>> getFoods() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('foods');

    return List.generate(maps.length, (i) {
      return maps[i]['name'] as String;
    });
  }
}
