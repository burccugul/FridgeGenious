import 'package:flutter/material.dart';
import 'package:flutter_application/screens/onboarding_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:logging/logging.dart';
import 'package:provider/provider.dart' as app_provider;
import 'services/theme_service.dart';
import 'providers/theme_notifier.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/forgot_password_page.dart';  // FORGOT PASSWORD IMPORT
// update_password_page.dart import'unu kaldırdık - artık gerekli değil
import 'package:flutter_application/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:developer';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Supabase client ve kullanıcı ID
final _supabase = sb.Supabase.instance.client;
String? effectiveUserID;

Future<void> getEffectiveUserID() async {
  try {
    final currentUserID = _supabase.auth.currentUser?.id;
    if (currentUserID == null) {
      log('No current user logged in');
      effectiveUserID = null;
      return;
    }

    final userIDArray = '["$currentUserID"]';

    final familyPackagesResponse = await _supabase
        .from('family_packages')
        .select()
        .or('owner_user_id.eq.$currentUserID,member_user_ids.cs.$userIDArray');

    if (familyPackagesResponse != null && familyPackagesResponse.isNotEmpty) {
      final familyPackage = familyPackagesResponse[0];
      effectiveUserID = familyPackage['owner_user_id'];
      log('User is part of family package: ${familyPackage['family_name']}');
      log('Using family owner ID: $effectiveUserID');
    } else {
      effectiveUserID = currentUserID;
      log('User is not part of any family package, using personal ID: $effectiveUserID');
    }
  } catch (e) {
    log('Error getting effective user ID: $e');
    effectiveUserID = _supabase.auth.currentUser?.id;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final location = tz.getLocation('Europe/Istanbul');
  tz.setLocalLocation(location);

  final notificationService = NotificationService();
  await notificationService.initialize();

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
  late final NotificationService notificationService;

  @override
  void initState() {
    super.initState();
    supabase = sb.Supabase.instance.client;
    notificationService = NotificationService();

    // Auth event listener
    sb.Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      debugPrint("**** onAuthStateChange: $event");

      if (event == sb.AuthChangeEvent.signedIn) {
        await getEffectiveUserID();

        // Kullanıcının envanter verisini çek ve bildirimleri planla
        try {
          final response = await supabase
              .from('inventory')
              .select()
              .eq('uuid_userid', effectiveUserID);

          final items = response as List;

          for (var item in items) {
            final String foodName = item['food_name'];
            final DateTime expiryDate = DateTime.parse(item['expiration_date']);

            await notificationService.sendExpirationReminderAtSpecificTime(
              foodName: foodName,
              expiryDate: expiryDate,
              hour: 20,
              minute: 30,
            );
          }
        } catch (e) {
          log("Error fetching inventory or scheduling notifications: $e");
        }

        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/home', (route) => false);
      } else if (event == sb.AuthChangeEvent.signedOut) {
        effectiveUserID = null;
        navigatorKey.currentState
            ?.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = app_provider.Provider.of<ThemeNotifier>(context);
    final textSizeNotifier =
        app_provider.Provider.of<TextSizeNotifier>(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Fridge Genius',
      theme: ThemeService().getLightTheme(textSizeNotifier.textSizeString),
      darkTheme: ThemeService().getDarkTheme(textSizeNotifier.textSizeString),
      themeMode: themeNotifier.themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) {
          final currentUser = sb.Supabase.instance.client.auth.currentUser;
          if (currentUser != null) {
            return const HomePage();
          } else {
            return OnboardingPage();
          }
        },
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        // '/update-password' route'unu kaldırdık - artık gerekli değil
      },
    );
  }
}