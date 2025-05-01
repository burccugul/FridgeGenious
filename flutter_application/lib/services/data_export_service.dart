import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application/database/supabase_helper.dart';
import 'package:flutter_application/services/auth_service.dart';
import 'package:permission_handler/permission_handler.dart';

class DataExportService {
  final SupabaseClient _supabase = SupabaseHelper().client;
  final AuthService _authService = AuthService();

  // Export user data to a JSON file
  Future<String> exportUserData() async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    
    // Check storage permission
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Storage permission not granted');
      }
    }
    
    // Fetch user profile
    final profileResponse = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    
    // Fetch inventory items
    final inventoryResponse = await _supabase
        .from('inventory')
        .select()
        .eq('user_id', userId);
    
    // Fetch shopping lists
    final shoppingListsResponse = await _supabase
        .from('shopping_lists')
        .select()
        .eq('user_id', userId);
    
    // Fetch recipes
    final recipesResponse = await _supabase
        .from('favorite_recipes')
        .select()
        .eq('user_id', userId);
    
    // Combine all data
    final userData = {
      'profile': profileResponse,
      'inventory': inventoryResponse,
      'shoppingLists': shoppingListsResponse,
      'recipes': recipesResponse,
      'exportDate': DateTime.now().toIso8601String(),
    };
    
    // Get app directory
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filePath = '$path/fridge_genius_export_$timestamp.json';
    
    // Write to file
    final file = File(filePath);
    await file.writeAsString(jsonEncode(userData));
    
    return filePath;
  }
  
  // Clear local data
  Future<void> clearLocalData() async {
    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    
    // Clear cache directories
    final cacheDir = await getTemporaryDirectory();
    if (await cacheDir.exists()) {
      try {
        await cacheDir.delete(recursive: true);
      } catch (e) {
        print('Error clearing cache: $e');
      }
    }
    
    // Clear app support directory files
    final appSupportDir = await getApplicationSupportDirectory();
    if (await appSupportDir.exists()) {
      try {
        final files = await appSupportDir.list().toList();
        for (var file in files) {
          await file.delete(recursive: true);
        }
      } catch (e) {
        print('Error clearing app support directory: $e');
      }
    }
  }
  
  // Import data from a file
  Future<bool> importData(String filePath) async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found');
      }
      
      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString);
      
      // Validate data structure
      if (!data.containsKey('profile') ||
          !data.containsKey('inventory') ||
          !data.containsKey('shoppingLists')) {
        throw Exception('Invalid data format');
      }
      
      final userId = _authService.currentUserId;
      
      // Clear existing data before import
      await _clearUserData();
      
      // Import inventory items
      final inventoryItems = List<Map<String, dynamic>>.from(data['inventory']);
      for (var item in inventoryItems) {
        item['user_id'] = userId;
        item.remove('id'); // Remove old ID to generate new one
      }
      
      if (inventoryItems.isNotEmpty) {
        await _supabase.from('inventory').insert(inventoryItems);
      }
      
      // Import shopping lists
      final shoppingLists = List<Map<String, dynamic>>.from(data['shoppingLists']);
      for (var list in shoppingLists) {
        list['user_id'] = userId;
        list.remove('id'); // Remove old ID to generate new one
      }
      
      if (shoppingLists.isNotEmpty) {
        await _supabase.from('shopping_lists').insert(shoppingLists);
      }
      
      // Import recipes
      if (data.containsKey('recipes')) {
        final recipes = List<Map<String, dynamic>>.from(data['recipes']);
        for (var recipe in recipes) {
          recipe['user_id'] = userId;
          recipe.remove('id'); // Remove old ID to generate new one
        }
        
        if (recipes.isNotEmpty) {
          await _supabase.from('favorite_recipes').insert(recipes);
        }
      }
      
      return true;
    } catch (e) {
      print('Error importing data: $e');
      return false;
    }
  }
  
  // Clear user data from database
  Future<void> _clearUserData() async {
    if (!_authService.isLoggedIn) return;
    
    final userId = _authService.currentUserId;
    
    // Delete user's items in inventory
    await _supabase
        .from('inventory')
        .delete()
        .eq('user_id', userId);
    
    // Delete user's shopping lists
    await _supabase
        .from('shopping_lists')
        .delete()
        .eq('user_id', userId);
    
    // Delete user's favorite recipes
    await _supabase
        .from('favorite_recipes')
        .delete()
        .eq('user_id', userId);
  }
}