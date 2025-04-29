import 'package:flutter/material.dart';
import '/services/gemini_recipe_service.dart';
import '/services/recipe_image_service.dart'; // RecipeImageService'i import ediyoruz
import 'dart:convert';
import 'recipe_detail_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpecialRecipePage extends StatefulWidget {
  final List<String> selectedIngredients;

  const SpecialRecipePage({
    Key? key,
    required this.selectedIngredients,
  }) : super(key: key);

  @override
  _SpecialRecipePageState createState() => _SpecialRecipePageState();
}

class _SpecialRecipePageState extends State<SpecialRecipePage> {
  bool isLoading = true;
  Map<String, dynamic>? generatedRecipe;
  final GeminiRecipeService _recipeService = GeminiRecipeService();
  final RecipeImageService _imageService =
      RecipeImageService(); // RecipeImageService örneği oluşturuyoruz
  String? recipeImageUrl; // Resim URL'sini saklamak için
  final _supabase = Supabase.instance.client;
  String? effectiveUserID;

  @override
  void initState() {
    super.initState();
    _getEffectiveUserID().then((_) {
      _generateSpecialRecipe();
    });
  }

  Future<void> _getEffectiveUserID() async {
    try {
      final currentUserID = _supabase.auth.currentUser?.id;
      final userIDArray = '["$currentUserID"]';

      final familyPackagesResponse = await _supabase
          .from('family_packages')
          .select()
          .or('owner_user_id.eq.$currentUserID,member_user_ids.cs.$userIDArray');

      if (familyPackagesResponse != null && familyPackagesResponse.isNotEmpty) {
        final familyPackage = familyPackagesResponse[0];
        effectiveUserID = familyPackage['owner_user_id'];
      } else {
        effectiveUserID = currentUserID;
      }
    } catch (e) {
      print('Error getting effective user ID: $e');
      effectiveUserID = _supabase.auth.currentUser?.id;
    }
  }

  Future<void> _generateSpecialRecipe() async {
    setState(() {
      isLoading = true;
      recipeImageUrl = null; // Yeni tarif ürettiğimizde resmi sıfırlıyoruz
    });

    try {
      // Use the Gemini service directly with our selected ingredients
      String recipeJson =
          await _recipeService.generateRecipe(widget.selectedIngredients);

      // Trim whitespace and validate JSON format
      recipeJson = recipeJson.trim();

      // Check if JSON starts with { or [ to validate it's likely JSON format
      if (!recipeJson.startsWith('{') && !recipeJson.startsWith('[')) {
        throw FormatException('Response is not in valid JSON format');
      }

      // Try to parse the JSON, catch any format exceptions
      Map<String, dynamic> parsed;
      try {
        parsed = jsonDecode(recipeJson);
      } catch (jsonError) {
        // If JSON is invalid, try to clean it up
        // Sometimes LLMs add explanatory text before or after the JSON
        final jsonStartIndex = recipeJson.indexOf('{');
        final jsonEndIndex = recipeJson.lastIndexOf('}') + 1;

        if (jsonStartIndex >= 0 && jsonEndIndex > jsonStartIndex) {
          final extractedJson =
              recipeJson.substring(jsonStartIndex, jsonEndIndex);
          parsed = jsonDecode(extractedJson);
        } else {
          throw FormatException('Could not extract valid JSON from response');
        }
      }

      setState(() {
        generatedRecipe = parsed;
        isLoading = false;
      });

      // Tarif başarıyla oluşturulduktan sonra resim URL'sini al
      if (parsed.containsKey('recipe_name')) {
        _fetchRecipeImage(parsed['recipe_name']);
      }
    } catch (e) {
      print('Recipe generation error: $e');
      setState(() {
        generatedRecipe = {
          'error': 'Failed to generate recipe. Please try again.',
          'debug_info': e.toString(),
        };
        isLoading = false;
      });
    }
  }

  Future<void> _fetchRecipeImage(String recipeName) async {
    try {
      final imageUrl = await _imageService.getImageForRecipe(recipeName);
      setState(() {
        recipeImageUrl = imageUrl;
      });

      // Supabase'e görsel URL'sini kaydet
      if (effectiveUserID != null && imageUrl != null) {
        await _supabase
            .from('recipes')
            .update({'image_url': imageUrl})
            .eq('uuid_userid', effectiveUserID)
            .eq('recipe_name', recipeName);
        print('Image URL saved to database for $recipeName');
      }
    } catch (e) {
      print('Error fetching or saving recipe image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Special Recipe',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh, color: Color.fromARGB(255, 0, 0, 0)),
            onPressed: _generateSpecialRecipe,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Selected ingredients display with updated styling
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 255, 255, 255),
                    Colors.white,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Selected Ingredients',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 3,
                    width: 100,
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 241, 147, 7),
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: widget.selectedIngredients.map((ingredient) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 255, 212, 130),
                              Color.fromARGB(255, 255, 236, 170),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color.fromARGB(255, 255, 193, 77),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle,
                                size: 18, color: Color(0xFFef6c00)),
                            const SizedBox(width: 6),
                            Text(
                              ingredient,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Recipe display with updated styling
            Expanded(
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.fromARGB(255, 241, 147, 7),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Creating a special recipe just for you...",
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    )
                  : generatedRecipe == null ||
                          generatedRecipe!.containsKey('error')
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.restaurant,
                                size: 80,
                                color: const Color.fromARGB(255, 255, 230, 149),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                generatedRecipe?['error'] ??
                                    "Couldn't generate a recipe with these ingredients.",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _generateSpecialRecipe,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color.fromARGB(255, 241, 147, 7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        )
                      : _buildRecipeContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeContent() {
    // Safe access to nested properties
    List<dynamic> ingredients = [];
    List<dynamic> steps = [];

    if (generatedRecipe != null) {
      if (generatedRecipe!['ingredients'] is List) {
        ingredients = generatedRecipe!['ingredients'] as List;
      }

      if (generatedRecipe!['steps'] is List) {
        steps = generatedRecipe!['steps'] as List;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe Card with updated styling
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
              border: Border.all(
                color: const Color.fromARGB(255, 0, 0, 0),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe Image/Header - RecipeImageService ile alınan resmi kullanıyoruz
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                      ),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        color: const Color.fromARGB(255, 175, 175, 172),
                        child: recipeImageUrl != null
                            ? Image.network(
                                recipeImageUrl!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  // Resim yüklenemezse placeholder göster
                                  return const Center(
                                    child: Icon(Icons.restaurant,
                                        size: 50, color: Colors.grey),
                                  );
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Color.fromARGB(255, 241, 147, 7),
                                      ),
                                    ),
                                  );
                                },
                              )
                            : const Center(
                                child: Icon(Icons.restaurant,
                                    size: 50, color: Colors.grey),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 241, 147, 7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${generatedRecipe!['time_minutes'] ?? 20} mins',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Recipe Content with updated styling
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        generatedRecipe!['recipe_name'] ?? 'Recipe',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  color: Color.fromARGB(255, 241, 147, 7),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Ingredients:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              ingredients.length > 3 ? 3 : ingredients.length,
                              (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '• ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color.fromARGB(255, 241, 147, 7),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${ingredients[i]}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (ingredients.length > 3)
                              const Text(
                                '... and more',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Color.fromARGB(255, 241, 147, 7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.format_list_numbered,
                                  color: Color.fromARGB(255, 241, 147, 7),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Instructions:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              steps.length > 2 ? 2 : steps.length,
                              (i) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Color.fromARGB(255, 241, 147, 7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${steps[i]}',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (steps.length > 2)
                              const Text(
                                '... and more steps',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: Color.fromARGB(255, 241, 147, 7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // RecipeDetailPage'e sadece recipe değerini gönderiyoruz
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailPage(
                                recipe: generatedRecipe,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 241, 147, 7),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        child: const Text(
                          "View Full Recipe",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
