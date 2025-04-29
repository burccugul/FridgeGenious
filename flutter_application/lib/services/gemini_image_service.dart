import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_application/database/supabase_helper.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('GeminiService');

class GeminiService {
  final String apiKey = "AIzaSyBr_epn1mMGQMPnnTj14W7IyHcsS606kuw";
  late GenerativeModel model;
  final SupabaseHelper _supabaseHelper = SupabaseHelper();

  GeminiService() {
    model = GenerativeModel(
      model: "gemini-2.0-flash",
      apiKey: apiKey,
    );
    _supabaseHelper.initialize().catchError((error) {
      _logger.severe('Failed to initialize Supabase: $error');
    });
  }

  Future<DataPart> fileToPart(String mimeType, String path) async {
    return DataPart(mimeType, await File(path).readAsBytes());
  }

  // Get the actual user ID to use (considering family package)
  Future<String?> _getEffectiveUserID() async {
    try {
      // Get current user's ID
      final currentUserID = _supabaseHelper.client.auth.currentUser?.id;
      if (currentUserID == null) {
        _logger.warning('No current user found');
        return null;
      }

      // Check if user is part of a family package
      final userIDArray = '["$currentUserID"]';
      final familyPackagesResponse = await _supabaseHelper.client
          .from('family_packages')
          .select()
          .or('owner_user_id.eq.$currentUserID,member_user_ids.cs.$userIDArray');

      if (familyPackagesResponse != null && familyPackagesResponse.isNotEmpty) {
        // User is part of a family package, return the owner's ID
        final familyPackage = familyPackagesResponse[0];
        _logger.info(
            'User is part of family package: ${familyPackage['family_name']}');
        return familyPackage['owner_user_id'];
      }

      // User is not part of a family package, return their own ID
      return currentUserID;
    } catch (e) {
      _logger.warning('Error getting effective user ID: $e');
      // Fallback to current user
      return _supabaseHelper.client.auth.currentUser?.id;
    }
  }

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

      await _supabaseHelper.initialize();
      final effectiveUserID = await _getEffectiveUserID();
      if (effectiveUserID == null) {
        return "No user logged in. Please sign in to continue.";
      }
      _logger.info(
          "Using effective user ID: $effectiveUserID for database operations");

      List<String> foodItems = aiResponse.split('\n');
      int processedItems = 0;

      for (String item in foodItems) {
        if (item.trim().isEmpty) continue;

        List<String> itemDetails = item.split(',');
        if (itemDetails.length >= 3) {
          String foodName = itemDetails[0].trim();
          int quantity = int.tryParse(itemDetails[1].trim()) ?? 1;
          String expirationDate = itemDetails[2].trim();

          _logger.info("Processing: $foodName, $quantity, $expirationDate");

          try {
            // Aynı kullanıcı ve aynı food_name varsa mevcut kaydı al
            final existingRecords = await _supabaseHelper.client
                .from('inventory')
                .select()
                .eq('food_name', foodName)
                .eq('uuid_userid', effectiveUserID);

            if (existingRecords != null && existingRecords.isNotEmpty) {
              final existing = existingRecords[0];
              int existingQuantity =
                  int.tryParse(existing['quantity'].toString()) ?? 0;
              int updatedQuantity = existingQuantity + quantity;

              await _supabaseHelper.client
                  .from('inventory')
                  .update({
                    'quantity': updatedQuantity.toString(),
                    'last_image_upload': currentDateTime,
                    'expiration_date': expirationDate,
                  })
                  .eq('food_name', foodName)
                  .eq('uuid_userid', effectiveUserID);

              _logger.info(
                  "✅ Updated item: $foodName, quantity: $updatedQuantity");
            } else {
              // Eğer kayıt yoksa yeni kayıt ekle
              await _supabaseHelper.client.from('inventory').insert({
                'food_name': foodName,
                'quantity': quantity.toString(),
                'last_image_upload': currentDateTime,
                'expiration_date': expirationDate,
                'uuid_userid': effectiveUserID,
              });

              _logger
                  .info("✅ Inserted new item: $foodName, quantity: $quantity");
            }

            processedItems++;
          } catch (e) {
            _logger.severe("❌ Error saving item to database: $e");
          }
        } else {
          _logger.warning("Skipping improperly formatted item: $item");
        }
      }

      return processedItems > 0
          ? "Successfully processed $processedItems food items."
          : "No valid food items were found in the image.";
    } catch (e) {
      _logger.severe("Error analyzing image: $e");
      return "Error analyzing image: $e";
    }
  }
}
