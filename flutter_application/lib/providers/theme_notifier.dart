import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeNotifier extends ChangeNotifier {
  final ThemeService _themeService = ThemeService();
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  ThemeNotifier() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDarkMode = await _themeService.isDarkModeEnabled();
    _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> setThemeMode(bool isDark) async {
    await _themeService.setDarkMode(isDark);
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}

class TextSizeNotifier extends ChangeNotifier {
  final ThemeService _themeService = ThemeService();
  String _textSize = 'medium';

  String get textSizeString => _textSize;

  TextSizeNotifier() {
    _loadTextSize();
  }

  Future<void> _loadTextSize() async {
    _textSize = await _themeService.getTextSize();
    notifyListeners();
  }

  Future<void> setTextSize(String size) async {
    await _themeService.setTextSize(size);
    _textSize = size;
    notifyListeners();
  }
}