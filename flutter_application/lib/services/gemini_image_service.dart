import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/supabase_helper.dart'; // Supabase Helper'ı ekledik

class GeminiService {
  final String apiKey = "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM"; // API Key buraya eklenecek
  late GenerativeModel model;

  GeminiService() {
    model = GenerativeModel(
      model: "gemini-1.5-flash",
      apiKey: apiKey,
    );
  }

  Future<DataPart> fileToPart(String mimeType, String path) async {
    return DataPart(mimeType, await File(path).readAsBytes());
  }

  Future<String> analyzeImage(File imageFile) async {
    try {
      final imagePart = await fileToPart('image/jpeg', imageFile.path);
      String currentDateTime = DateTime.now().toIso8601String();
      
      final prompt = '''Analyze the food items in this image. 
          List them along with their quantities in the format: 
          FoodName, Quantity, ExpirationDate (e.g., Apple, 2, 2025-03-18 00:22:28.911580).
          If an expiration date isn't visible, estimate it.
          Do NOT include any additional text.
          ''';

      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt), imagePart])
      ]);

      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? '';
      }

      if (aiResponse.isEmpty) {
        return "No food items detected in the image.";
      }
      print("AI Response: $aiResponse");

      // Veriyi satırlara ayır
      List<String> foodItems = aiResponse.split('\n');

      for (String item in foodItems) {
        List<String> itemDetails = item.split(',');

        if (itemDetails.length == 3) {
          String foodName = itemDetails[0].trim();
          int quantity = int.tryParse(itemDetails[1].trim()) ?? 1;
          String expirationDate = itemDetails[2].trim();

          print("Food Name: $foodName");
          print("Quantity: $quantity");
          print("Expiration Date: $expirationDate");

          // **Supabase'e kaydet**
          await SupabaseHelper().insertInventoryItem(foodName, quantity, expirationDate);
        }
      }

      return aiResponse;
    } catch (e) {
      print("❌ Hata: $e");
      return "Error analyzing image: $e";
    }
  }
}
