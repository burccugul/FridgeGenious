import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_application/database/supabase_helper.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('GeminiService');

class GeminiService {
  final String apiKey =
      "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM"; // Replace with your API Key
  late GenerativeModel model;
  final SupabaseHelper _supabaseHelper = SupabaseHelper();

  // Default user ID - in a real app, this should come from auth
  final int defaultUserId = 1;

  GeminiService() {
    model = GenerativeModel(
      model: "gemini-2.0-flash",
      apiKey: apiKey,
    );
    // Initialize Supabase connection
    _supabaseHelper.initialize().catchError((error) {
      _logger.severe('Failed to initialize Supabase: $error');
    });
  }

  // Convert a file to a DataPart
  Future<DataPart> fileToPart(String mimeType, String path) async {
    return DataPart(mimeType, await File(path).readAsBytes());
  }

  // Get the current user ID from Supabase auth
  int _getCurrentUserId() {
    try {
      final userIdString = _supabaseHelper.client.auth.currentUser?.id;
      return int.tryParse(userIdString ?? '') ?? defaultUserId;
    } catch (e) {
      _logger.warning('Could not get current user ID: $e');
      return defaultUserId;
    }
  }

  // Function to analyze an image
  Future<String> analyzeImage(File imageFile) async {
    try {
      final imagePart = await fileToPart('image/jpeg', imageFile.path);
      String currentDateTime = DateTime.now().toString();
      final prompt = '''Analyze the food items in this image. 
          List them along with their quantities in the format: FoodName, Quantity (e.g., Apple, 2, Banana, 3).
          If a food item has an expiration date visible, provide it as well.
          If a food item hasn't an expiration date visible, provide a reasonable estimate based on the type of food. 
          You can add your estimated time into $currentDateTime.
          You should write only food name, quantity, and expiration date in the format: FoodName, Quantity, ExpirationDate (e.g., Apple, 2, 2025-03-11 00:06:22.880006).
          Please do not write other things, do not write food names as plural form, write them as singular form.
          ''';

      _logger.info('Sending image to Gemini for analysis');
      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt), imagePart])
      ]);

      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? '';
      }

      if (aiResponse.isEmpty) {
        _logger.warning('No food items detected in the image');
        return "No food items detected in the image.";
      }
      _logger.info("AI Response: $aiResponse");

      // Ensure Supabase is initialized before proceeding
      await _supabaseHelper.initialize();

      // Get user ID for database operations
      final userId = _getCurrentUserId();
      _logger.info("Using user ID: $userId for database operations");

      // Split the response by lines to handle multiple food items
      List<String> foodItems = aiResponse.split('\n');
      int processedItems = 0;

      // Process each food item line
      for (String item in foodItems) {
        if (item.trim().isEmpty) continue;

        List<String> itemDetails = item.split(',');

        if (itemDetails.length >= 3) {
          String foodName = itemDetails[0].trim(); // Food name
          int quantity = int.tryParse(itemDetails[1].trim()) ?? 1; // Quantity
          String expirationDate = itemDetails[2].trim(); // Expiration Date

          _logger.info("Processing: $foodName, $quantity, $expirationDate");

          try {
            // Check if item already exists in inventory for this user
            final existingItems = await _supabaseHelper.client
                .from('inventory')
                .select()
                .eq('food_name', foodName)
                .eq('userid', userId);

            if (existingItems != null && existingItems.isNotEmpty) {
              // Item exists, update quantity
              int currentQuantity =
                  int.tryParse(existingItems[0]['quantity'].toString()) ?? 0;
              int newQuantity = currentQuantity + quantity;

              await _supabaseHelper.client
                  .from('inventory')
                  .update({
                    'quantity': newQuantity,
                    'last_image_upload': currentDateTime,
                    'expiration_date': expirationDate,
                  })
                  .eq('food_name', foodName)
                  .eq('userid', userId);

              _logger.info(
                  "Updated existing item: $foodName, new quantity: $newQuantity");
            } else {
              // Item doesn't exist, insert new item
              await _supabaseHelper.client.from('inventory').insert({
                'food_name': foodName,
                'quantity': quantity,
                'last_image_upload': currentDateTime,
                'expiration_date': expirationDate,
                'userid': userId, // Adding the user ID here
              });

              _logger.info("Inserted new item: $foodName, quantity: $quantity");
            }
            processedItems++;
          } catch (e) {
            _logger.severe("Error saving item to database: $e");
          }
        } else {
          _logger.warning("Skipping improperly formatted item: $item");
        }
      }

      if (processedItems > 0) {
        return "Successfully processed $processedItems food items.";
      } else {
        return "No valid food items were found in the image.";
      }
    } catch (e) {
      _logger.severe("Error analyzing image: $e");
      return "Error analyzing image: $e";
    }
  }
}
