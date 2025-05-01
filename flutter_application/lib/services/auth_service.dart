// lib/services/auth_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('AuthService');

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  bool get isLoggedIn => _supabase.auth.currentUser != null;
  String? get currentUserId => _supabase.auth.currentUser?.id;
  
  // Sign up with email and password
  Future<void> signUp(String email, String password, String name) async {
    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      
      if (response.user != null) {
        // Create user profile in the profiles table
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email,
          'name': name,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      _logger.severe('Error during signup: $e');
      throw e;
    }
  }
  
  // Sign in with email and password
  Future<void> signIn(String email, String password) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      _logger.severe('Error during signin: $e');
      throw e;
    }
  }
  
  // Sign in with provider (Google, Apple, etc.)
  Future<void> signInWithProvider(Provider provider) async {
    try {
      await _supabase.auth.signInWithOAuth(provider);
    } catch (e) {
      _logger.severe('Error during provider signin: $e');
      throw e;
    }
  }
  
  // Sign out
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      _logger.severe('Error during logout: $e');
      throw e;
    }
  }
  
  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      _logger.severe('Error sending password reset: $e');
      throw e;
    }
  }
  
  // Change password
  Future<void> changePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } catch (e) {
      _logger.severe('Error changing password: $e');
      throw e;
    }
  }
  
  // Get current session
  Session? getCurrentSession() {
    return _supabase.auth.currentSession;
  }
}