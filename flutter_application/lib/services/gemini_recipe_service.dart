import 'package:google_generative_ai/google_generative_ai.dart';
import '/database/supabase_helper.dart'; // SupabaseHelper'ı doğru klasörden import et
import 'dart:convert';

class GeminiRecipeService {
  final String apiKey =
      "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM"; // Replace with your API Key
  late GenerativeModel model;
  final SupabaseHelper _supabaseHelper = SupabaseHelper();

  GeminiRecipeService() {
    model = GenerativeModel(
      model: "gemini-2.0-flash", // Ensure you use the correct model
      apiKey: apiKey,
    );
  }
  int _getCurrentUserId() {
    try {
      final userIdString = _supabaseHelper.client.auth.currentUser?.id;
      return int.tryParse(userIdString ?? '') ??
          1; // Default to 1 if parsing fails
    } catch (e) {
      print('Could not get current user ID: $e');
      return 1; // Default user ID
    }
  }

  Future<List<String>> getIngredientsFromDatabase() async {
    // Get current user ID
    final userId = _getCurrentUserId();

    // Fetch inventory items from Supabase FOR THE SPECIFIC USER
    final inventory = await _supabaseHelper.getInventoryByUserId(userId);

    // Extract food names from the inventory and return them
    return inventory.map((item) => item['food_name'] as String).toList();
  }

  // Function to generate a recipe from the ingredients
  Future<String> generateRecipe(List<String> ingredients) async {
    if (ingredients.isEmpty) {
      return "No ingredients found in the database.";
    }

    // Create the prompt for the Gemini model
    String prompt = '''Generate a recipe using the following ingredients: 
        ${ingredients.join(', ')}. 
        Don't have to use all of them but recipe's ingredients should be all in this list. 
        The recipe should include the all ingredients and all detailed steps.
        Show recipe name, ingredients, and steps in the format: RecipeName, Ingredient1, Ingredient2, ..., Step1, Step2, ..., time.
        Do not write other things from there. 
        Respond ONLY in JSON format, like this:

{
  "recipe_name": "Recipe Name",
  "ingredients": ["Ingredient1", "Ingredient2", "..."],
  "steps": ["Step 1", "Step 2", "..."],
  "time_minutes": 30
}

Don't add any text before or after the JSON. Just respond with valid JSON.
Return the recipe strictly in this JSON format (and nothing else):

        ''';

    try {
      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt)])
      ]);

      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? '';
      }

      print("Raw AI JSON Response: $aiResponse");

      if (aiResponse.isEmpty) {
        return jsonEncode({"error": "No recipe generated. Please try again."});
      }
      try {
        final jsonStart = aiResponse.indexOf('{');
        final jsonEnd = aiResponse.lastIndexOf('}');

        if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
          return jsonEncode({
            "error": "Invalid JSON response format",
            "raw_response": aiResponse
          });
        }

        final cleanJson = aiResponse.substring(jsonStart, jsonEnd + 1);

        // Validate the JSON structure before returning
        final Map<String, dynamic> recipeJson = jsonDecode(cleanJson);

        // Ensure all required fields exist
        if (!recipeJson.containsKey('recipe_name') ||
            !recipeJson.containsKey('ingredients') ||
            !recipeJson.containsKey('steps') ||
            !recipeJson.containsKey('time_minutes')) {
          return jsonEncode({
            "error": "Missing required fields in response",
            "parsed_response": recipeJson
          });
        }

        // Ensure fields are of correct type
        if (recipeJson['ingredients'] is! List ||
            recipeJson['steps'] is! List) {
          return jsonEncode({
            "error": "Invalid data types in response",
            "parsed_response": recipeJson
          });
        }
        saveRecipeToSupabase(recipeJson);
        return const JsonEncoder.withIndent('  ').convert(recipeJson);
      } catch (jsonError) {
        return jsonEncode({
          "error": "JSON parsing error: $jsonError",
          "raw_response": aiResponse
        });
      }
    } catch (e) {
      return jsonEncode({"error": "Error generating recipe: $e"});
    }
  }

  Future<void> saveRecipeToSupabase(Map<String, dynamic> recipeJson) async {
    try {
      final recipeName = recipeJson['recipe_name'] ?? "Unnamed Recipe";

      // Make sure we have lists, even if they're empty
      final List<dynamic> ingredients =
          recipeJson['ingredients'] is List ? recipeJson['ingredients'] : [];

      final List<dynamic> steps =
          recipeJson['steps'] is List ? recipeJson['steps'] : [];

      final int time =
          recipeJson['time_minutes'] is int ? recipeJson['time_minutes'] : 0;

      // Validate that we have sufficient data before saving
      if (ingredients.isEmpty || steps.isEmpty) {
        print("Eksik veri: ingredients veya steps boş.");
        return;
      }

      // Insert recipe into Supabase
      await SupabaseHelper().client.from('recipes').insert({
        "recipe_name": recipeName,
        "ingredients": jsonEncode(ingredients),
        "steps": jsonEncode(steps),
        "time": time,
        "is_favorite": false,
      });

      print("Tarif başarıyla Supabase'e eklendi.");
    } catch (e) {
      print("Tarif eklenirken hata oluştu: $e");
      // For debugging, print the full details of recipeJson
      print("recipeJson içeriği: $recipeJson");
    }
  }
}
