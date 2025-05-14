// Defines the main app widget
import 'package:flutter/material.dart';
import 'package:flutter_application/screens/onboarding_page.dart';
import 'screens/onboarding_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Fridge Genious',
      home: OnboardingPage(),
    );
  }
}
