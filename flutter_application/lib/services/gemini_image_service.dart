import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'food_database_service.dart'; // Import the FoodDatabaseHelper

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
      // Create the image DataPart
      final imagePart = await fileToPart('image/jpeg', imageFile.path);

      // Create the prompt TextPart
      final prompt =
          'Analyze the food items in this image.Do not write anything else than food names.';

      // Send the content to Gemini and collect the responses
      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt), imagePart])
      ]);

      // Collect all the responses and combine them
      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? ''; // Append each response's text
      }

      // If there's no response text, return a default message
      if (aiResponse.isEmpty) {
        return "No food items detected in the image.";
      }

      // Insert food items into the database
      List<String> foodItems =
          aiResponse.split(',').map((e) => e.trim()).toList();
      for (var food in foodItems) {
        if (food.isNotEmpty) {
          await FoodDatabaseService().insertFood(food);
        }
      }

      return aiResponse; // Return the full response
    } catch (e) {
      // If an error occurs, return the error message
      return "Error analyzing image: $e";
    }
  }
}
