// File: lib/services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _expiringItemsNotificationKey = 'expiring_items_notification';
  static const String _recipeNotificationKey = 'recipe_notification';
  static const String _lowStockNotificationKey = 'low_stock_notification';

  NotificationService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      onDidReceiveLocalNotification: _onDidReceiveLocalNotification,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _isInitialized = true;
  }

  void _onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) async {
    // Handle iOS foreground notification
  }

  void _onNotificationTapped(NotificationResponse response) async {
    // Handle notification tap
    final String? payload = response.payload;
    if (payload != null) {
      debugPrint('Notification payload: $payload');
      // You can navigate to a specific screen based on payload
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
  }) async {
    if (!await areNotificationsEnabled()) return;
    
    await _ensureInitialized();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'fridgegenious_channel',
      'FridgeGenious Notifications',
      channelDescription: 'Notifications from FridgeGenious app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );
        
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  // Schedule a notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (!await areNotificationsEnabled()) return;
    
    await _ensureInitialized();

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'fridgegenious_channel',
      'FridgeGenious Notifications',
      channelDescription: 'Notifications from FridgeGenious app',
      importance: Importance.max,
      priority: Priority.high,
    );
    
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

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
  }

  // Send expiration reminder
  Future<void> sendExpirationReminder(String foodName, DateTime expiryDate) async {
    if (!await areExpiringItemsNotificationsEnabled()) return;
    
    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    
    String body;
    if (difference <= 0) {
      body = '$foodName has expired today! Please check it.';
    } else if (difference == 1) {
      body = '$foodName will expire tomorrow! Plan to use it soon.';
    } else {
      body = '$foodName will expire in $difference days. Plan your meals accordingly.';
    }
    
    await showNotification(
      id: foodName.hashCode,
      title: 'Food Expiration Alert',
      body: body,
      payload: 'expiration_$foodName',
    );
  }

  // Send recipe suggestion
  Future<void> sendRecipeSuggestion(String recipeName, List<String> ingredients) async {
    if (!await areRecipeNotificationsEnabled()) return;
    
    final ingredientList = ingredients.take(3).join(", ");
    final body = 'Try making $recipeName with $ingredientList and more ingredients you have!';
    
    await showNotification(
      id: recipeName.hashCode,
      title: 'Recipe Suggestion',
      body: body,
      payload: 'recipe_$recipeName',
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