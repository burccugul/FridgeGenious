import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class FoodDatabaseService {
  static final FoodDatabaseService _instance = FoodDatabaseService._internal();
  factory FoodDatabaseService() => _instance;

  static Database? _database;

  FoodDatabaseService._internal();

  // Method to initialize the database
  Future<Database> initDatabase() async {
    if (_database != null) {
      return _database!;
    }

    // Get the directory to store the database
    final directory = await getApplicationDocumentsDirectory();
    String path = join(directory.path, 'food_database.db'); // Custom path

    print("Database path: $path");

    // Open or create the database
    _database = await openDatabase(path, version: 1, onCreate: (db, version) {
      // Create the food table
      return db.execute('''
        CREATE TABLE food(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT
        )
      ''');
    });

    return _database!;
  }

  // Method to insert a food item
  Future<void> insertFood(String foodName) async {
    final db = await initDatabase();
    await db.insert(
      'food',
      {'name': foodName},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Method to fetch all food items
  Future<List<String>> getAllFood() async {
    final db = await initDatabase();
    final List<Map<String, dynamic>> maps = await db.query('food');

    return List.generate(maps.length, (i) {
      return maps[i]['name'] as String;
    });
  }
}
