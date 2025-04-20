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

  /// ✅ Get current user UUID (string)
  String? _getCurrentUserUUID() {
    try {
      return _supabaseHelper.client.auth.currentUser?.id;
    } catch (e) {
      _logger.warning('Could not get current user UUID: $e');
      return null;
    }
  }

  Future<List<String>> getIngredientsFromDatabase() async {
    final uuid = _getCurrentUserUUID();
    if (uuid == null) {
      _logger.warning("No user is logged in.");
      return [];
    }

    final inventory = await _supabaseHelper.client
        .from('inventory')
        .select()
        .eq('uuid_userid', uuid)
        .gte('quantity', 1); // Quantity'si 0'dan büyük olanları seçiyoruz.

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
''';

    try {
      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt)])
      ]);

      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? '';
      }

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
      final uuid = _getCurrentUserUUID();
      if (uuid == null) {
        _logger.warning("No user logged in - cannot save recipe.");
        return;
      }

      final recipeName = recipeJson['recipe_name'] ?? "Unnamed Recipe";
      final List<dynamic> ingredients =
          recipeJson['ingredients'] is List ? recipeJson['ingredients'] : [];
      final int time =
          recipeJson['time_minutes'] is int ? recipeJson['time_minutes'] : 0;

      if (ingredients.isEmpty) {
        _logger.warning("Eksik veri: ingredients boş.");
        return;
      }

      // ✅ Supabase'e her bir içerik için satır ekle
      for (final ingredient in ingredients) {
        final data = {
          "uuid_userid": uuid,
          "recipe_name": recipeName,
          "food_name": ingredient,
          "time": time,
          "quantity": 1,
          "is_favorite": false,
        };

        try {
          await _supabaseHelper.client.from('recipes').insert(data);
          _logger.info("Tarif kaydedildi: $data");
        } catch (e) {
          _logger.severe("Kayıt eklenemedi: $e");
        }
      }
    } catch (e) {
      _logger.severe("Tarif eklenirken genel hata: $e");
      _logger.severe("recipeJson içeriği: $recipeJson");
    }
  }
}
