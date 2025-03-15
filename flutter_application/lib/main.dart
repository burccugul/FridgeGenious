import 'package:flutter/material.dart';
import 'package:logging/logging.dart'; // Logging paketi
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase paketi
import 'package:flutter_application/screens/onboarding_page.dart';
import 'package:flutter_application/services/supabase_helper.dart'; // Supabase helper dosyasını içe aktar

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  var myLogger = Logger('MyLogger');
  myLogger.info("My custom logger initialized.");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Asenkron işlemleri başlatmak için gerekli
  
  await SupabaseHelper.initialize(); // SupabaseHelper başlat (bunu ekledik)

  setupLogging(); // Logging başlat
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fridge Genius',
      theme: ThemeData(
        primarySwatch: Colors.orange,
      ),
      home: const OnboardingPage(),
      debugShowCheckedModeBanner: false, // Debug banner'ı kaldır
    );
  }
}