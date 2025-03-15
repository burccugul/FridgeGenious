import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/supabase_helper.dart'; // Güncellenmiş SupabaseHelper import edildi

class GeminiRecipeService {
  final String apiKey =  "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM";// API Key buraya eklenecek
  late GenerativeModel model;

  GeminiRecipeService() {
    model = GenerativeModel(
      model: "gemini-1.5-flash", 
      apiKey: apiKey,
    );
  }

  // 📌 **Supabase'den envanterdeki yiyecekleri al**
  Future<List<String>> getIngredientsFromDatabase() async {
    try {
      // Envanterden malzemeleri çek
      final inventory = await SupabaseHelper().getInventory();

      // Yalnızca `food_name` değerlerini liste olarak döndür
      return inventory.map((item) => item['food_name'] as String).toList();
    } catch (e) {
      print("❌ Envanter verileri alınırken hata oluştu: $e");
      return [];
    }
  }

  // 📌 **AI ile tarif oluşturma**
  Future<String> generateRecipe(List<String> ingredients) async {
    if (ingredients.isEmpty) {
      return "No ingredients found in the database.";
    }

    // 📝 Gemini'ye gönderilecek prompt
    String prompt = '''Generate a unique recipe using the following ingredients: 
        ${ingredients.join(', ')}. 
        The recipe should include:
        - A creative recipe name
        - A list of ingredients
        - Step-by-step cooking instructions.
        - Estimated cooking time.

        **Response format:**
        Recipe Name: (name)
        Ingredients: (list all ingredients)
        Steps:
        1. (Step 1)
        2. (Step 2)
        3. ...
        Estimated Time: (time in minutes)

        Do NOT include extra text, only return the recipe.
        ''';

    try {
      // **AI'ye tarif oluşturması için istekte bulun**
      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt)])
      ]);

      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? '';
      }

      // **Yanıt boşsa hata mesajı döndür**
      if (aiResponse.isEmpty) {
        return "No recipe generated. Please try again.";
      }

      print("✅ AI Generated Recipe: \n$aiResponse");
      return aiResponse;
    } catch (e) {
      print("❌ Tarif oluşturulurken hata oluştu: $e");
      return "Error generating recipe: $e";
    }
  }
}
