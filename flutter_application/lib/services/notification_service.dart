// File: lib/services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:fixnum/fixnum.dart';
import 'dart:typed_data';
import 'package:flutter_application/main.dart'; // navigatorKey erişimi için

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _expiringItemsNotificationKey =
      'expiring_items_notification';
  static const String _recipeNotificationKey = 'recipe_notification';
  static const String _lowStockNotificationKey = 'low_stock_notification';

  NotificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('NotificationService: initializing...');

    // Time zone ayarları
    tz_data.initializeTimeZones();
    final String timeZoneName = tz.local.name;
    debugPrint(
        'NotificationService: time zones initialized with local timezone: $timeZoneName');

    // Notification ayarları
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Plugin'i başlat
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // iOS için özel izinleri talep et
    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final bool? result = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('iOS notification permission result: $result');
    }

    // Android için notification kanallarını oluştur
    await _createNotificationChannels();

    _isInitialized = true;
    debugPrint('NotificationService initialized successfully');
    debugPrint('Bildirim servisi başarıyla başlatıldı!');
  }

  Future<void> checkAndRequestPermissions() async {
    await _ensureInitialized();

    // Platform-specific permission check
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final bool? granted = await androidPlugin.areNotificationsEnabled();
      debugPrint('Android notifications enabled: $granted');

      if (granted != true) {
        // Request permissions again
        final bool? result = await androidPlugin.requestPermission();
        debugPrint('Android permission request result: $result');
      }
    }
  }

  // Request notification permissions explicitly
  Future<bool> _requestNotificationPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android permission request
    if (androidPlugin != null) {
      final bool? result = await androidPlugin.requestPermission();
      debugPrint('Android notification permission result: $result');
      return result ?? false;
    }

    // iOS permission request
    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    if (iosPlugin != null) {
      final bool? result = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('iOS notification permission result: $result');
      return result ?? false;
    }

    return true;
  }

  // Create notification channels for Android 8.0+
  Future<void> _createNotificationChannels() async {
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Main channel for all notifications
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'fridgegenious_channel',
          'FridgeGenious Notifications',
          description: 'Notifications from FridgeGenious app',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );

      // Expiring items channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'expiry_channel',
          'Expiration Notifications',
          description: 'Notifications about expiring food items',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      // Recipe suggestions channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'recipe_channel',
          'Recipe Suggestions',
          description: 'Notifications with recipe ideas',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      // Low inventory channel
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'inventory_channel',
          'Inventory Alerts',
          description: 'Notifications about low inventory items',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      debugPrint('Android notification channels created successfully');
    }
  }

  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // Handle iOS foreground notification
    debugPrint(
        'Received iOS local notification: id=$id, title=$title, body=$body, payload=$payload');
  }

  void _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    debugPrint('Notification Tapped: $payload');

    // Navigator ile yönlendir
    if (navigatorKey.currentState != null) {
      // Mevcut route stack'i temizleyerek home'a yönlendir
      navigatorKey.currentState!
          .pushNamedAndRemoveUntil('/home', (route) => false);
    } else {
      debugPrint('NavigatorKey.currentState null. Navigasyon yapılamadı!');
    }
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    await _ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  // Enable or disable notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
  }

  // Check if expiring items notifications are enabled
  Future<bool> areExpiringItemsNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_expiringItemsNotificationKey) ?? true;
  }

  // Enable or disable expiring items notifications
  Future<void> setExpiringItemsNotification(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expiringItemsNotificationKey, enabled);
  }

  // Check if recipe notifications are enabled
  Future<bool> areRecipeNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_recipeNotificationKey) ?? true;
  }

  // Enable or disable recipe notifications
  Future<void> setRecipeNotification(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_recipeNotificationKey, enabled);
  }

  // Check if low stock notifications are enabled
  Future<bool> areLowStockNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_lowStockNotificationKey) ?? true;
  }

  // Enable or disable low stock notifications
  Future<void> setLowStockNotification(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lowStockNotificationKey, enabled);
  }

  // Make sure the service is initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  // Show immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'fridgegenious_channel',
  }) async {
    if (!await areNotificationsEnabled()) {
      debugPrint('Notifications are disabled. Not showing notification.');
      return;
    }

    await _ensureInitialized();

    String channelName = 'FridgeGenious Notifications';
    if (channelId == 'expiry_channel') {
      channelName = 'Expiration Notifications';
    } else if (channelId == 'recipe_channel') {
      channelName = 'Recipe Suggestions';
    } else if (channelId == 'inventory_channel') {
      channelName = 'Inventory Alerts';
    }
    final vibrationPattern = [Int64(0), Int64(1000), Int64(500), Int64(1000)];

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications from FridgeGenious app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
      ticker: 'ticker',
      visibility: NotificationVisibility.public,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.active,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin.show(
        id,
        title,
        body,
        platformChannelSpecifics,
        payload: payload,
      );
      debugPrint('Notification sent successfully: $title - $body');
    } catch (error) {
      debugPrint('Failed to send notification: $error');
    }
  }

  // Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String channelId = 'fridgegenious_channel',
  }) async {
    if (!await areNotificationsEnabled()) {
      debugPrint('Notifications are disabled. Not scheduling notification.');
      return;
    }

    await _ensureInitialized();

    String channelName = 'FridgeGenious Notifications';
    if (channelId == 'expiry_channel') {
      channelName = 'Expiration Notifications';
    } else if (channelId == 'recipe_channel') {
      channelName = 'Recipe Suggestions';
    } else if (channelId == 'inventory_channel') {
      channelName = 'Inventory Alerts';
    }

    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: 'Notifications from FridgeGenious app',
      importance: Importance.max,
      priority: Priority.high,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 255, 0, 0),
      ledOnMs: 1000,
      ledOffMs: 500,
      visibility: NotificationVisibility.public,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    );

    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.active,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint(
          'Scheduled notification for ${scheduledDate.toString()}: $title - $body');
    } catch (error) {
      debugPrint('Failed to schedule notification: $error');
    }
  }

  // DENEME AMAÇLI ÖNEMLİ KALSIN
  // Schedule a notification for 2 minutes from now
  Future<void> scheduleNotificationInTwoMinutes({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'fridgegenious_channel',
  }) async {
    final scheduledDate = DateTime.now().add(const Duration(minutes: 2));
    await scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
      channelId: channelId,
    );
  }

// DENEME AMAÇLI ÖNEMLİ KALSIN
  Future<void> scheduleNotificationAtSpecificTime({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    String? payload,
    String channelId = 'fridgegenious_channel',
  }) async {
    final now = DateTime.now();
    DateTime scheduledDate =
        DateTime(now.year, now.month, now.day, hour, minute);

    // Eğer belirtilen saat geçtiyse, ertesi gün planla
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint("Bildirim şu tarihte planlandı: $scheduledDate");

    await scheduleNotification(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
      channelId: channelId,
    );
  }

  // Send expiration reminder based on days until expiry
  // buradaki hour ve minutes önemli değil
  Future<void> sendExpirationReminderAtSpecificTime({
    required String foodName,
    required DateTime expiryDate,
    int thresholdDays = 1,
    int hour = 19,
    int minute = 59,
  }) async {
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;

    if (difference <= thresholdDays) {
      String body;
      if (difference < 0) {
        body = '$foodName expired ${-difference} day(s) ago!';
      } else if (difference == 0) {
        body = '$foodName will expire today!';
      } else if (difference == 1) {
        body = '$foodName will expire tomorrow!';
      } else {
        body = '$foodName will expire in $difference days.';
      }

      // Bildirimi planla: aynı gün saat 19:22’de
      DateTime scheduledDate =
          DateTime(now.year, now.month, now.day, hour, minute);

      // Eğer o saat geçtiyse ertesi gün gönder
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      debugPrint(
          "[$foodName] için bildirim şu tarihte planlandı: $scheduledDate");

      await scheduleNotification(
        id: foodName.hashCode,
        title: 'Food Expiration Alert',
        body: body,
        scheduledDate: scheduledDate,
        payload: 'expiration_$foodName',
        channelId: 'expiry_channel',
      );
    }
  }

  // Send recipe suggestion
  Future<void> sendRecipeSuggestion(
      String recipeName, List<String> ingredients) async {
    if (!await areRecipeNotificationsEnabled()) return;

    final ingredientList = ingredients.take(3).join(", ");
    final body =
        'Try making $recipeName with $ingredientList and more ingredients you have!';

    await showNotification(
      id: recipeName.hashCode,
      title: 'Recipe Suggestion',
      body: body,
      payload: 'recipe_$recipeName',
      channelId: 'recipe_channel',
    );
  }

  // Send low inventory reminder
  Future<void> sendLowInventoryReminder(String foodName) async {
    if (!await areLowStockNotificationsEnabled()) return;

    await showNotification(
      id: (foodName + '_low').hashCode,
      title: 'Low Inventory Alert',
      body: 'You\'re running low on $foodName. Add it to your shopping list?',
      payload: 'low_inventory_$foodName',
      channelId: 'inventory_channel',
    );
  }

  // Test notification system
  Future<void> sendTestNotification() async {
    await showNotification(
      id: 9999,
      title: 'Test Notification',
      body: 'This is a test notification from FridgeGenius.',
      payload: 'test_notification',
    );
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _ensureInitialized();
    await _notificationsPlugin.cancelAll();
  }

  // Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _ensureInitialized();
    await _notificationsPlugin.cancel(id);
  }
}
