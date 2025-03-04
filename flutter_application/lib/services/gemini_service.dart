import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'database_service.dart';

class GeminiService {
  final String apiKey = "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM"; // API Anahtarını buraya ekle
  late GenerativeModel model;
  final DatabaseService _dbService = DatabaseService();

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
      final prompt = 'Analyze the food items in this image and return only food names.';

      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt), imagePart])
      ]);

      String finalResponse = "";

      await for (final response in responses) {
        if (response.text != null) {
          finalResponse = response.text!;

          // 📌 LLM yanıtını satırlara böl ve her satırı veritabanına kaydet
          List<String> foodItems = finalResponse.split('\n');
          for (String food in foodItems) {
            if (food.trim().isNotEmpty) {
              await _dbService.insertFood(food.trim());
            }
          }
        }
      }

      return finalResponse.isNotEmpty ? finalResponse : "No response from AI";

    } catch (e) {
      return "Error analyzing image: $e";
    }
  }
}
