import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseHelper {
  static final SupabaseHelper _instance = SupabaseHelper._internal();
  factory SupabaseHelper() => _instance;

  static SupabaseClient? _supabase; // Supabase client (lazy initialization)

  SupabaseHelper._internal();

  /// **Supabase'i başlat**
  static Future<void> initialize() async {
    if (_supabase == null) {
      await Supabase.initialize(
        url: "https://fczqhqaeofgbzjikdjcb.supabase.co",
        anonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjenFocWFlb2ZnYnpqaWtkamNiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE5OTA1OTUsImV4cCI6MjA1NzU2NjU5NX0.r06RWhjtCfRPsm1R-6wIksz4pZYueJ3osQWgDagO0hw",
      );
      _supabase = Supabase.instance.client;
      print("✅ Supabase başarıyla başlatıldı.");
    }
  }

  /// **Supabase client getter (initialize() çağırmadan kullanmak için)**
  SupabaseClient get supabase {
    if (_supabase == null) {
      throw Exception("Supabase is not initialized. Call SupabaseHelper.initialize() first.");
    }
    return _supabase!;
  }

  // 🥕 **Envanter verilerini Supabase'den çekme**
  Future<List<Map<String, dynamic>>> getInventory() async {
    try {
      final response = await supabase.from('inventory').select();
      print("✅ Envanter çekildi: ${response.length} kayıt");
      return response;
    } catch (e) {
      print("❌ Envanter verileri çekilirken hata oluştu: $e");
      return [];
    }
  }

  // 🛒 **Alışveriş listesine veri ekleme**
  Future<void> insertShoppingItem(int userId, String foodName, String removeDate, int rate) async {
    try {
      await supabase.from('shoppinglist').insert([
        {
          'userid': userId,
          'food_name': foodName,
          'remove_date': removeDate,
          'consumation_rate_by_week': rate
        }
      ]);
      print("✅ Alışveriş listesine veri eklendi: $foodName");
    } catch (e) {
      print("❌ Veri eklerken hata oluştu: $e");
    }
  }

  // 🛒 **Alışveriş listesi verilerini çekme**
  Future<List<Map<String, dynamic>>> getShoppingList() async {
    try {
      final response = await supabase.from('shoppinglist').select();
      print("✅ Alışveriş listesi çekildi: ${response.length} kayıt");
      return response;
    } catch (e) {
      print("❌ Alışveriş listesi çekilirken hata oluştu: $e");
      return [];
    }
  }

  // 🥦 **Yeni yiyecekleri envantere kaydetme**
  Future<void> insertInventoryItem(String foodName, int quantity, String expirationDate) async {
    try {
      await supabase.from('inventory').insert([
        {
          'food_name': foodName,
          'quantity': quantity,
          'last_image_upload': DateTime.now().toIso8601String(),
          'expiration_date': expirationDate,
        }
      ]);
      print("✅ Envantere yeni yiyecek eklendi: $foodName");
    } catch (e) {
      print("❌ Envantere veri eklerken hata oluştu: $e");
    }
  }
}
