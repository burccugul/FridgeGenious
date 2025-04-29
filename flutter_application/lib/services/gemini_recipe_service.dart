import 'package:google_generative_ai/google_generative_ai.dart';
import '/database/supabase_helper.dart';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'dart:developer';

final Logger _logger = Logger('GeminiRecipeService');

class GeminiRecipeService {
  final String apiKey = "AIzaSyBr_epn1mMGQMPnnTj14W7IyHcsS606kuw";
  late GenerativeModel model;
  final SupabaseHelper _supabaseHelper = SupabaseHelper();

  GeminiRecipeService() {
    model = GenerativeModel(
      model: "gemini-1.5-pro",
      apiKey: apiKey,
    );
    _supabaseHelper.initialize().catchError((error) {
      _logger.severe('Failed to initialize Supabase: $error');
    });
  }

  /// Get the actual user ID to use (considering family package)
  Future<String?> _getEffectiveUserID() async {
    try {
      // Get current user's ID
      final currentUserID = _supabaseHelper.client.auth.currentUser?.id;
      if (currentUserID == null) {
        _logger.warning('No current user found');
        return null;
      }
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

  Future<List<String>> getIngredientsFromDatabase() async {
    try {
      final effectiveUserID = await _getEffectiveUserID();
      if (effectiveUserID == null) {
        _logger.warning("No user is logged in.");
        return [];
      }

      final inventory = await _supabaseHelper.client
          .from('inventory')
          .select()
          .eq('uuid_userid', effectiveUserID)
          .gte('quantity', 1); // Quantity greater than 0

      log("Retrieved ${inventory.length} ingredients from inventory");

      // Add debug logging to see what ingredients we have
      final ingredients =
          inventory.map<String>((item) => item['food_name'] as String).toList();

      _logger.info("Ingredients: ${ingredients.join(', ')}");

      return ingredients;
    } catch (e) {
      _logger.severe("Error getting ingredients: $e");
      return [];
    }
  }

  Future<String> generateRecipe(List<String> ingredients) async {
    if (ingredients.isEmpty) {
      _logger.warning("No ingredients found in the database.");
      return jsonEncode({
        "error":
            "No ingredients found in your inventory. Please add some ingredients first."
      });
    }

    _logger
        .info("Generating recipe with ingredients: ${ingredients.join(', ')}");

    String prompt = '''Generate a recipe using the following ingredients: 
${ingredients.join(', ')}. 
You don't have to use all of foods in inventory for recipe but recipe's ingredients should be all in this list, do not add any other. 
The recipe should include the all ingredients and all detailed steps.
Show recipe name, ingredients, and steps in the format: RecipeName, Ingredient1, Ingredient2, ..., Step1, Step2, ..., time.
Do not write other things from there. 
Respond ONLY in JSON format, like this:

{
  "recipe_name": "Recipe Name",
  "ingredients": ["Ingredient1", "Ingredient2", "..."],
  "steps": ["Step 1", "Step 2", "..."],
  "time_minutes": 30,
  "description": "A brief description of the recipe"
}
''';

    try {
      _logger.info("Sending request to Gemini API");
      final response = await model.generateContent([Content.text(prompt)]);

      final aiResponse = response.text ?? '';
      _logger.info("Raw AI JSON Response: $aiResponse");

      if (aiResponse.isEmpty) {
        _logger.warning("Empty response from Gemini API");
        return jsonEncode({"error": "No recipe generated. Please try again."});
      }

      try {
        final jsonStart = aiResponse.indexOf('{');
        final jsonEnd = aiResponse.lastIndexOf('}');

        if (jsonStart == -1 || jsonEnd == -1 || jsonEnd <= jsonStart) {
          _logger.warning("Invalid JSON format in response");
          return jsonEncode({
            "error": "Invalid JSON response format",
            "raw_response": aiResponse
          });
        }

        final cleanJson = aiResponse.substring(jsonStart, jsonEnd + 1);
        _logger.info("Cleaned JSON: $cleanJson");

        final Map<String, dynamic> recipeJson = jsonDecode(cleanJson);

        if (!recipeJson.containsKey('recipe_name') ||
            !recipeJson.containsKey('ingredients') ||
            !recipeJson.containsKey('steps')) {
          _logger.warning("Missing required fields in response");
          return jsonEncode({
            "error": "Missing required fields in response",
            "parsed_response": recipeJson
          });
        }

        // Ensure time_minutes is present and is a number
        if (!recipeJson.containsKey('time_minutes')) {
          recipeJson['time_minutes'] = 30; // Default value
        } else if (recipeJson['time_minutes'] is String) {
          // Convert string to int if possible
          try {
            recipeJson['time_minutes'] =
                int.parse(recipeJson['time_minutes'].toString());
          } catch (e) {
            recipeJson['time_minutes'] = 30; // Default if parsing fails
          }
        }

        // Add description if missing
        if (!recipeJson.containsKey('description')) {
          recipeJson['description'] =
              "A delicious recipe made with ${ingredients.take(3).join(', ')} and more ingredients.";
        }

        if (recipeJson['ingredients'] is! List ||
            recipeJson['steps'] is! List) {
          _logger.warning("Invalid data types in response");
          return jsonEncode({
            "error": "Invalid data types in response",
            "parsed_response": recipeJson
          });
        }

        await saveRecipeToSupabase(recipeJson);
        _logger.info("Recipe generated and saved successfully");
        return const JsonEncoder.withIndent('  ').convert(recipeJson);
      } catch (jsonError) {
        _logger.severe("JSON parsing error: $jsonError");
        return jsonEncode({
          "error": "JSON parsing error: $jsonError",
          "raw_response": aiResponse
        });
      }
    } catch (e) {
      _logger.severe("Error generating recipe: $e");
      return jsonEncode({"error": "Error generating recipe: $e"});
    }
  }

  Future<void> saveRecipeToSupabase(Map<String, dynamic> recipeJson) async {
    try {
      final effectiveUserID = await _getEffectiveUserID();
      if (effectiveUserID == null) {
        _logger.warning("No user logged in - cannot save recipe.");
        return;
      }

      final recipeName = recipeJson['recipe_name'] ?? "Unnamed Recipe";
      final List<dynamic> ingredients =
          recipeJson['ingredients'] is List ? recipeJson['ingredients'] : [];
      final int time =
          recipeJson['time_minutes'] is int ? recipeJson['time_minutes'] : 0;

      if (ingredients.isEmpty) {
        _logger.warning("Missing data: ingredients is empty.");
        return;
      }

      // Add a row to the recipes table for each ingredient
      for (final ingredient in ingredients) {
        final data = {
          "uuid_userid": effectiveUserID,
          "recipe_name": recipeName,
          "food_name": ingredient,
          "time": time,
          "quantity": 1,
          "is_favorite": false,
        };

        try {
          await _supabaseHelper.client.from('recipes').insert(data);
          _logger.info("Recipe saved: $data");
        } catch (e) {
          _logger.severe("Failed to add record: $e");
        }
      }
    } catch (e) {
      _logger.severe("General error adding recipe: $e");
      _logger.severe("recipeJson content: $recipeJson");
    }
  }
}
