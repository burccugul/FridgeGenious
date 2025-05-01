// lib/services/user_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application/database/supabase_helper.dart';
import 'package:flutter_application/models/user_model.dart';
import 'package:flutter_application/services/auth_service.dart';

class UserService {
  final SupabaseClient _supabase = SupabaseHelper().client;
  final AuthService _authService = AuthService();
  
  // Get current user data
  Future<UserModel> getCurrentUser() async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    final response = await _supabase
      .from('profiles')
      .select()
      .eq('id', userId)
      .single();
    
    return UserModel.fromJson(response);
  }
  
  // Update user name
  Future<void> updateUserName(String name) async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    
    // Update profile in database
    await _supabase
      .from('profiles')
      .update({'name': name})
      .eq('id', userId);
      
    // Also update auth metadata
    await _supabase.auth.updateUser(
      UserAttributes(data: {'name': name}),
    );
  }
  
  // Update dietary preferences
  Future<void> updateDietaryPreferences(List<String> preferences) async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    await _supabase
      .from('profiles')
      .update({'dietaryPreferences': preferences})
      .eq('id', userId);
  }
  
  // Update allergens
  Future<void> updateAllergens(List<String> allergens) async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    await _supabase
      .from('profiles')
      .update({'allergens': allergens})
      .eq('id', userId);
  }
  
  // Update favorite ingredients
  Future<void> updateFavoriteIngredients(List<String> ingredients) async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    await _supabase
      .from('profiles')
      .update({'favoriteIngredients': ingredients})
      .eq('id', userId);
  }
  
  // Delete account
  Future<void> deleteAccount() async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    
    // Delete user data from various tables
    // Note: Use transactions if available for atomic operations
    
    // Delete profile
    await _supabase
      .from('profiles')
      .delete()
      .eq('id', userId);
      
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
      
    // Finally delete the user authentication record
    await _supabase.auth.admin.deleteUser(userId!);
    
    // Sign out
    await _authService.logout();
  }
  
  // Upgrade to premium
  Future<void> upgradeToPremium() async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    await _supabase
      .from('profiles')
      .update({'isPremium': true})
      .eq('id', userId);
  }
  
  // Cancel premium
  Future<void> cancelPremium() async {
    if (!_authService.isLoggedIn) {
      throw Exception('Not logged in');
    }
    
    final userId = _authService.currentUserId;
    await _supabase
      .from('profiles')
      .update({'isPremium': false})
      .eq('id', userId);
  }
}