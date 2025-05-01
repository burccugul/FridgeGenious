import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:logging/logging.dart';
import 'package:provider/provider.dart' as app_provider;
import 'services/theme_service.dart';
import 'providers/theme_notifier.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';

// Global navigator key for navigation outside of the context tree
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  await sb.Supabase.initialize(
    url: "https://pzelhqrawaevvuqbpjnc.supabase.co",
    anonKey:
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6ZWxocXJhd2FldnZ1cWJwam5jIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxNTc5NjMsImV4cCI6MjA2MDczMzk2M30.LzbdN2MZl-XIxyKQGhmaMCdUf-r41oOkSWCZfwTaSSE",
  );
  
  runApp(
    app_provider.MultiProvider(
      providers: [
        app_provider.ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        app_provider.ChangeNotifierProvider(create: (_) => TextSizeNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final sb.SupabaseClient supabase;
  late Widget initialScreen;
  
  @override
  void initState() {
    super.initState();
    supabase = sb.Supabase.instance.client;
    initialScreen = supabase.auth.currentUser != null ? const HomePage() : const LoginPage();
    
    // Auth event listener
    sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      debugPrint("**** onAuthStateChange: $event");
      
      // Use navigator key for navigation outside of build context
      if (event == sb.AuthChangeEvent.signedOut) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
      } else if (event == sb.AuthChangeEvent.signedIn) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final themeNotifier = app_provider.Provider.of<ThemeNotifier>(context);
    final textSizeNotifier = app_provider.Provider.of<TextSizeNotifier>(context);
    
    return MaterialApp(
      navigatorKey: navigatorKey, // Add the navigator key here
      title: 'Fridge Genius',
      theme: ThemeService().getLightTheme(textSizeNotifier.textSizeString),
      darkTheme: ThemeService().getDarkTheme(textSizeNotifier.textSizeString),
      themeMode: themeNotifier.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => initialScreen, // başlangıç ekranı: login veya home
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        // Diğer route'ları da eklersin: '/settings': (context) => const SettingsPage(),
      },
    );
  }
}