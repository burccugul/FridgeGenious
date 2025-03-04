import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // If database is not initialized, initialize it
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Here, specify the path to the existing database (identifier.sqlite).
    String path = join('/Users/iremgungor/FridgeGenious', 'identifier.sqlite');
    return await openDatabase(path, version: 1);
  }

  // Fetch inventory items from the database
  Future<List<Map<String, dynamic>>> getInventory() async {
    final db = await database;
    return await db.query('inventory');
  }

  // Insert an item into the inventory (optional)
  Future<void> insertInventory(Map<String, dynamic> item) async {
    final db = await database;
    await db.insert('inventory', item, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
