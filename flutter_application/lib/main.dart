import 'package:flutter/material.dart';
import 'screens/onboarding_page.dart';
import 'services/food_database_service.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the SQLite database
  final db = await FoodDatabaseService().initDatabase();
  developer.log("Database path: ${db.path}", name: "Database");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fridge Genius',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
      ),
      home: const OnboardingPage(),
    );
  }
}
