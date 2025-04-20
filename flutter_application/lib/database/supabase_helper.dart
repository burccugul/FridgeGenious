// supabase_helper.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('SupabaseHelper');

class SupabaseHelper {
  static final SupabaseHelper _instance = SupabaseHelper._internal();
  factory SupabaseHelper() => _instance;

  late final SupabaseClient client;
  bool _initialized = false;

  SupabaseHelper._internal();

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      client = Supabase.instance.client;
      _initialized = true;
    } catch (e) {
      _logger.severe('Supabase not initialized properly: $e');
      throw Exception(
          'Supabase is not initialized. Make sure to call Supabase.initialize() in main.dart');
    }
  }

  // Fetch inventory items from the database
  Future<List<Map<String, dynamic>>> getInventory() async {
    try {
      if (!_initialized) await initialize();

      final response = await client.from('inventory').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logger.severe('Error fetching inventory: $e');
      return [];
    }
  }

  // Update quantity of an item in the inventory
  Future<void> updateInventoryQuantity(String foodName, int newQuantity) async {
    try {
      if (!_initialized) await initialize();

      await client
          .from('inventory')
          .update({'quantity': newQuantity}).eq('food_name', foodName);
    } catch (e) {
      _logger.severe('Error updating inventory quantity: $e');
      throw e;
    }
  }

  // Insert an item into the shopping list
  Future<void> insertShoppingList(Map<String, dynamic> item) async {
    try {
      if (!_initialized) await initialize();

      await client.from('shoppinglist').insert(item);
    } catch (e) {
      _logger.severe('Error inserting into shopping list: $e');
      throw e;
    }
  }

  // Get shopping list items
  Future<List<Map<String, dynamic>>> getShoppingList() async {
    try {
      if (!_initialized) await initialize();

      final response = await client.from('shoppinglist').select();
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      _logger.severe('Error fetching shopping list: $e');
      return [];
    }
  }

  // Get inventory by UUID user ID
  Future<List<Map<String, dynamic>>> getInventoryByUserId(
      String uuidUserId) async {
    await initialize();

    final response =
        await client.from('inventory').select().eq('uuid_userid', uuidUserId);

    return List<Map<String, dynamic>>.from(response);
  }

  // Get shopping list by UUID user ID
  Future<List<Map<String, dynamic>>> getShoppingListByUserId(
      String uuidUserId) async {
    await initialize();

    final response = await client
        .from('shoppinglist')
        .select()
        .eq('uuid_userid', uuidUserId);

    return List<Map<String, dynamic>>.from(response);
  }
}
