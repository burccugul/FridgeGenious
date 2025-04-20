// main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:flutter_application/screens/onboarding_page.dart';
// Import other necessary screens

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set up logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final logger = Logger('Main');

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: "https://pzelhqrawaevvuqbpjnc.supabase.co",
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6ZWxocXJhd2FldnZ1cWJwam5jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxNTc5NjMsImV4cCI6MjA2MDczMzk2M30.LzbdN2MZl-XIxyKQGhmaMCdUf-r41oOkSWCZfwTaSSE",
    );
    logger.info("✅ Supabase successfully initialized!");
  } catch (e) {
    logger.severe("Failed to initialize Supabase: $e");
  }

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
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const OnboardingPage(),
    );
  }
}
