import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '/database/database_helper.dart'; // Import DatabaseHelper

class GeminiService {
  final String apiKey =
      "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM"; // Replace with your API Key
  late GenerativeModel model;

  GeminiService() {
    model = GenerativeModel(
      model: "gemini-2.0-flash", // Ensure you use the correct model
      apiKey: apiKey,
    );
  }

  // Convert a file to a DataPart
  Future<DataPart> fileToPart(String mimeType, String path) async {
    return DataPart(mimeType, await File(path).readAsBytes());
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

      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt), imagePart])
      ]);

      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? ''; // Append each response's text
      }

      if (aiResponse.isEmpty) {
        return "No food items detected in the image.";
      }
      print("AI Response: $aiResponse");

      // Split the response by lines to handle multiple food items
      List<String> foodItems = aiResponse.split('\n');

      // Process each food item line
      for (String item in foodItems) {
        // Split each line by commas
        List<String> itemDetails = item.split(',');

        if (itemDetails.length == 3) {
          String foodName = itemDetails[0].trim(); // Food name
          int quantity = int.tryParse(itemDetails[1].trim()) ?? 1; // Quantity
          String expirationDate = itemDetails[2].trim(); // Expiration Date

          // Output for debugging
          print("Food Name: $foodName");
          print("Quantity: $quantity");
          print("Expiration Date: $expirationDate");

          // Insert the item into the database
          await DatabaseHelper().insertInventory({
            'food_name': foodName,
            'quantity': quantity,
            'last_image_upload': currentDateTime,
            'expiration_date': expirationDate,
          });
        }
      }

      return aiResponse;
    } catch (e) {
      return "Error analyzing image: $e";
    }
  }
}
