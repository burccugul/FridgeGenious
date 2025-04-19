import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_application/database/supabase_helper.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('GeminiService');

class GeminiService {
  final String apiKey = "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM";
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

  String? _getCurrentUserUUID() {
    try {
      return _supabaseHelper.client.auth.currentUser?.id;
    } catch (e) {
      _logger.warning('Could not get current user UUID: $e');
      return null;
    }
  }

  Future<String> analyzeImage(File imageFile) async {
    try {
      final imagePart = await fileToPart('image/jpeg', imageFile.path);
      String currentDateTime = DateTime.now().toString();

      final prompt = '''Analyze the food items in this image. 
          List them along with their quantities in the format: FoodName, Quantity, ExpirationDate.
          Do not write anything else. Use singular food names only.
          Time reference: $currentDateTime
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
      final userUUID = _getCurrentUserUUID();
      if (userUUID == null) {
        return "No user logged in. Please sign in to continue.";
      }
      _logger.info("Using user ID: $userUUID for database operations");

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
            await _supabaseHelper.client.from('inventory').upsert({
              'food_name': foodName,
              'quantity': quantity,
              'last_image_upload': currentDateTime,
              'expiration_date': expirationDate,
              'uuid_userid': userUUID,
            });

            _logger.info("✅ Upserted item: $foodName, quantity: $quantity");
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
