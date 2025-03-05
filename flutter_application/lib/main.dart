import 'package:flutter/material.dart';
import 'screens/onboarding_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fridge Genious',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const FridgePage(),
    );
  }
}
