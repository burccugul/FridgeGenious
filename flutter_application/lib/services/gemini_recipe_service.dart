import 'package:google_generative_ai/google_generative_ai.dart';
import '/database/database_helper.dart'; // Güncel DatabaseHelper'ı buraya import et

class GeminiRecipeService {
  final String apiKey =
      "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM"; // Replace with your API Key
  late GenerativeModel model;

  GeminiRecipeService() {
    model = GenerativeModel(
      model: "gemini-2.0-flash", // Ensure you use the correct model
      apiKey: apiKey,
    );
  }

  // Function to get ingredients from the inventory database
  Future<List<String>> getIngredientsFromDatabase() async {
    // Fetch inventory items from the new database
    final inventory = await DatabaseHelper().getInventory();

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
        Do not write other things from there. But write in nice format.
        ''';

    try {
      // Generate the recipe using Gemini
      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt)])
      ]);

      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? ''; // Append each response's text
      }
      print("AI Response: $aiResponse"); // This will print the full response

      // If there's no response text, return a default message
      if (aiResponse.isEmpty) {
        return "No recipe generated. Please try again.";
      }

      return aiResponse;
    } catch (e) {
      return "Error generating recipe: $e";
    }
  }
}
