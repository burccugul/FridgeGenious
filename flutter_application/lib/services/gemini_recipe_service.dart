import 'package:google_generative_ai/google_generative_ai.dart';
import '/database/supabase_helper.dart';
import 'dart:convert';
import 'package:logging/logging.dart';

final Logger _logger = Logger('GeminiRecipeService');

class GeminiRecipeService {
  final String apiKey = "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM";
  late GenerativeModel model;
  final SupabaseHelper _supabaseHelper = SupabaseHelper();

  GeminiRecipeService() {
    model = GenerativeModel(
      model: "gemini-2.0-flash",
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

    return inventory
        .map<String>((item) => item['food_name'] as String)
        .toList();
  }

  Future<String> generateRecipe(List<String> ingredients) async {
    if (ingredients.isEmpty) {
      return "No ingredients found in the database.";
    }

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
  "time_minutes": 30
}
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);

      final aiResponse = response.text ?? '';
      _logger.info("Raw AI JSON Response: $aiResponse");

      _logger.info("Raw AI JSON Response: $aiResponse");

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
        final Map<String, dynamic> recipeJson = jsonDecode(cleanJson);

        if (!recipeJson.containsKey('recipe_name') ||
            !recipeJson.containsKey('ingredients') ||
            !recipeJson.containsKey('steps') ||
            !recipeJson.containsKey('time_minutes')) {
          return jsonEncode({
            "error": "Missing required fields in response",
            "parsed_response": recipeJson
          });
        }

        if (recipeJson['ingredients'] is! List ||
            recipeJson['steps'] is! List) {
          return jsonEncode({
            "error": "Invalid data types in response",
            "parsed_response": recipeJson
          });
        }

        await saveRecipeToSupabase(recipeJson);
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
