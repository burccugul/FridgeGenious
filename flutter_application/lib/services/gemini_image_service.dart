import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '/database/database_helper.dart'; // Import DatabaseHelper

class GeminiService {
  final String apiKey =
      "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM"; // Replace with your API Key
  late GenerativeModel model;

  GeminiService() {
    model = GenerativeModel(
      model: "gemini-1.5-flash", // Ensure you use the correct model
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
          Please do not write other things.
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
      // Split the response into food items (e.g., 'Apple, 2, Banana, 3')
      List<String> foodItems = aiResponse.split(',');

// Veriyi virgülle ayıralım

// İlgili bileşenleri işleyelim
      String foodName = foodItems[0].trim(); // Örneğin: Apple
      int quantity = int.tryParse(foodItems[1].trim()) ?? 1; // Örneğin: 1
      String expirationDate =
          foodItems[2].trim(); // Örneğin: 2025-03-18 00:22:28.911580

// Çıktıyı kontrol edelim
      print("Food Name: $foodName");
      print("Quantity: $quantity");
      print("Expiration Date: $expirationDate");

      // Insert food and quantity into the database
      await DatabaseHelper().insertInventory({
        'food_name': foodName,
        'quantity': quantity,
        'last_image_upload': currentDateTime,
        'expiration_date': expirationDate,
      });

      return aiResponse;
    } catch (e) {
      return "Error analyzing image: $e";
    }
  }
}
