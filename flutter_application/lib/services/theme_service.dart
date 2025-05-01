// File: lib/services/theme_service.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  // Constants for shared preferences keys
  static const String _darkModeKey = 'dark_mode_enabled';
  static const String _textSizeKey = 'text_size';

  // Default text size
  static const String _defaultTextSize = 'medium';

  // Get the current theme mode
  Future<ThemeMode> getThemeMode() async {
    final isDarkMode = await isDarkModeEnabled();
    return isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // Check if dark mode is enabled
  Future<bool> isDarkModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  // Toggle dark mode
  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, enabled);
  }

  // Get the current text size
  Future<String> getTextSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_textSizeKey) ?? _defaultTextSize;
  }

  // Set the text size
  Future<void> setTextSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_textSizeKey, size);
  }

  // Get text style based on selected size
  TextStyle _getTextStyleForSize(String size, TextStyle baseStyle) {
    switch (size) {
      case 'small':
        return baseStyle.copyWith(fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! * 0.8 : 12);
      case 'large':
        return baseStyle.copyWith(fontSize: baseStyle.fontSize != null ? baseStyle.fontSize! * 1.2 : 18);
      case 'medium':
      default:
        return baseStyle;
    }
  }

  // Get app theme data for light mode
  ThemeData getLightTheme(String textSize) { // Şimdi String argüman alıyor
    const baseTextStyle = TextStyle(fontFamily: 'Roboto');
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.green,
      primaryColor: Colors.green,
      colorScheme: ColorScheme.light(
        primary: Colors.green,
        secondary: Colors.lightGreen,
        surface: Colors.white,
        background: Colors.grey[50]!,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 16)),
        bodyMedium: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 14)),
        bodySmall: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 12)),
        titleLarge: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
        titleMedium: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
        titleSmall: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
        // Diğer text stillerini de buraya ekleyebilirsiniz
      ),
    );
  }

  // Get app theme data for dark mode
  ThemeData getDarkTheme(String textSize) { // Şimdi String argüman alıyor
    const baseTextStyle = TextStyle(fontFamily: 'Roboto');
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.green,
      primaryColor: Colors.green,
      colorScheme: ColorScheme.dark(
        primary: Colors.green,
        secondary: Colors.lightGreen,
        surface: Colors.grey[900]!,
        background: Colors.grey[850]!,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.grey[900],
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        color: Colors.grey[800],
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 16)),
        bodyMedium: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 14)),
        bodySmall: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 12)),
        titleLarge: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
        titleMedium: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
        titleSmall: _getTextStyleForSize(textSize, baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
        // Diğer text stillerini de buraya ekleyebilirsiniz
      ),
    );
  }
}