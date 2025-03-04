import 'package:flutter/material.dart';
import 'package:flutter_application/screens/fridge.page.dart';
import 'package:logging/logging.dart'; // Import logging package

void setupLogging() {
  // Enable hierarchical logging (necessary for modifying non-root loggers)
  Logger.root.level = Level.ALL; // Set the level for root logger
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Example of setting up a non-root logger if needed
  var myLogger = Logger('MyLogger');
  myLogger.info("My custom logger initialized.");
}

void main() {
  setupLogging();  // Initialize logging when the app starts
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fridge App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FridgePage(),
    );
  }
}
