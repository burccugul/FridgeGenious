import 'package:flutter/material.dart';
import '/services/gemini_recipe_service.dart';
import '/services/recipe_image_service.dart'; // Import the new service
import 'dart:convert';
import 'recipe_detail_page.dart';
import 'package:flutter_application/screens/settings_page.dart';
import 'package:flutter_application/screens/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;
  String? effectiveUserID;
  final RecipeImageService _imageService =
      RecipeImageService(); // Initialize image service

  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];

  int _currentIndex = 0;
  int _currentTabIndex = 0; // Aktif sekme indeksi

  Map<String, dynamic>? generatedRecipe;
  List<Map<String, dynamic>> favoriteRecipes = []; // Favori tarifler listesi

  bool isLoading = false;
  bool isFavoritesLoading = false;

  // Image loading states
  String? suggestedRecipeImage;
  bool isLoadingSuggestedImage = false;
  Map<String, String?> favoriteRecipeImages = {};
  Map<String, bool> loadingFavoriteImages = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });

        // Favoriler sekmesine geçildiğinde favori tarifleri yükle
        if (_tabController.index == 1) {
          _loadFavoriteRecipes();
        }
      }
    });

    // Use Future.delayed to ensure the widget is fully built before fetching
    Future.delayed(Duration.zero, () {
      _getEffectiveUserID().then((_) {
        fetchGeneratedRecipe();
        _loadFavoriteRecipes(); // İlk açılışta favori tarifleri de yükle
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Get the actual user ID to use (considering family package)
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
        setState(() {
          effectiveUserID = familyPackage['owner_user_id'];
        });
        print(
            'User is part of family package: ${familyPackage['family_name']}');
        print('Using family owner ID: $effectiveUserID');
      } else {
        setState(() {
          effectiveUserID = currentUserID;
        });
        print(
            'User is not part of any family package, using personal ID: $effectiveUserID');
      }
    } catch (e) {
      print('Error getting effective user ID: $e');
      setState(() {
        effectiveUserID = _supabase.auth.currentUser?.id;
      });
    }
  }

  Future<void> _loadSuggestedRecipeImage() async {
    if (generatedRecipe == null || generatedRecipe!['recipe_name'] == null)
      return;

    setState(() {
      isLoadingSuggestedImage = true;
    });

    try {
      final recipeName = generatedRecipe!['recipe_name'];
      final imageUrl = await _imageService.getImageForRecipe(recipeName);

      if (mounted) {
        setState(() {
          suggestedRecipeImage = imageUrl;
          isLoadingSuggestedImage = false;
        });
      }

      // imageUrl'i Supabase veritabanına kaydet
      if (effectiveUserID != null && imageUrl != null) {
        await _supabase
            .from('recipes')
            .update({'image_url': imageUrl})
            .eq('uuid_userid', effectiveUserID)
            .eq('recipe_name', recipeName);
        print('Image URL saved to database for $recipeName');
      }
    } catch (e) {
      print('Error loading or saving suggested recipe image: $e');
      if (mounted) {
        setState(() {
          isLoadingSuggestedImage = false;
        });
      }
    }
  }

  // Load favorite recipe images
  Future<void> _loadFavoriteRecipeImage(int index, String recipeName) async {
    if (recipeName.isEmpty) return;

    setState(() {
      loadingFavoriteImages[recipeName] = true;
    });

    try {
      final imageUrl = await _imageService.getImageForRecipe(recipeName);

      if (mounted) {
        setState(() {
          favoriteRecipeImages[recipeName] = imageUrl;
          loadingFavoriteImages[recipeName] = false;
        });
      }
    } catch (e) {
      print('Error loading favorite recipe image for $recipeName: $e');
      if (mounted) {
        setState(() {
          loadingFavoriteImages[recipeName] = false;
        });
      }
    }
  }

  // Load all favorite recipe images
  Future<void> _loadAllFavoriteRecipeImages() async {
    for (int i = 0; i < favoriteRecipes.length; i++) {
      final recipeName = favoriteRecipes[i]['recipe_name'] ?? 'Unnamed Recipe';
      _loadFavoriteRecipeImage(i, recipeName);
    }
  }

  Future<void> _loadFavoriteRecipes() async {
    if (effectiveUserID == null) return;

    setState(() {
      isFavoritesLoading = true;
    });

    try {
      final response = await _supabase
          .from('recipes')
          .select()
          .eq('uuid_userid', effectiveUserID)
          .eq('is_favorite', true)
          .order('recipe_name', ascending: true);

      if (response != null) {
        // Create a map to store unique recipes by name
        final Map<String, Map<String, dynamic>> uniqueRecipes = {};

        // Process each recipe, keeping only the most recent one with a specific name
        for (final recipe in List<Map<String, dynamic>>.from(response)) {
          final recipeName =
              recipe['recipe_name']?.toString() ?? 'Unnamed Recipe';

          // If this recipe name hasn't been seen or if this is a newer version, save it
          if (!uniqueRecipes.containsKey(recipeName) ||
              (recipe['created_at'] != null &&
                  uniqueRecipes[recipeName]!['created_at'] != null &&
                  DateTime.parse(recipe['created_at']).isAfter(DateTime.parse(
                      uniqueRecipes[recipeName]!['created_at'])))) {
            uniqueRecipes[recipeName] = recipe;
          }
        }

        setState(() {
          // Convert the values from the uniqueRecipes map back to a list
          favoriteRecipes = uniqueRecipes.values.toList();
          isFavoritesLoading = false;
        });
        print('Loaded ${favoriteRecipes.length} unique favorite recipes');

        // Load images for all favorite recipes
        _loadAllFavoriteRecipeImages();
      }
    } catch (e) {
      print('Error loading favorite recipes: $e');
      setState(() {
        isFavoritesLoading = false;
      });
    }
  }

  Future<void> fetchGeneratedRecipe() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      List<String> ingredients =
          await GeminiRecipeService().getIngredientsFromDatabase();

      // Check if the ingredients list is empty
      if (ingredients.isEmpty) {
        if (mounted) {
          setState(() {
            generatedRecipe = {
              'error': 'No recipe available - inventory is empty.',
            };
            isLoading = false;
          });
        }
        return; // Exit the function early if no ingredients
      }

      String recipeJson =
          await GeminiRecipeService().generateRecipe(ingredients);

      final parsed = jsonDecode(recipeJson);

      if (mounted) {
        setState(() {
          generatedRecipe = parsed;
          isLoading = false;
        });

        // Load image for the generated recipe
        _loadSuggestedRecipeImage();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          generatedRecipe = {
            'error': 'Failed to generate recipe: $e',
          };
          isLoading = false;
        });
      }
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
          'Recipes',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Suggested sekmesindeyken yenileme butonunu göster
          if (_currentTabIndex == 0)
            IconButton(
              icon: const Icon(Icons.refresh,
                  color: Color.fromARGB(255, 0, 0, 0)),
              onPressed: fetchGeneratedRecipe,
            ),
          // Favorites sekmesindeyken yenileme butonunu göster
          if (_currentTabIndex == 1)
            IconButton(
              icon: const Icon(Icons.refresh,
                  color: Color.fromARGB(255, 0, 0, 0)),
              onPressed: _loadFavoriteRecipes,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color.fromARGB(255, 241, 147, 7),
          labelColor: Colors.black,
          tabs: const [
            Tab(text: 'Suggested'),
            Tab(text: 'Favorites'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Suggested Recipes Tab
            Column(
              children: [
                // Title with gradient background
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                        'Recipes From Your Ingredients',
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
                    ],
                  ),
                ),
                // Display the generated recipe or a placeholder
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
                                "Generating recipe from your ingredients...",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
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
                                    color: const Color.fromARGB(
                                        255, 255, 230, 149),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "No recipe available.",
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.black),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Tap the refresh button to generate a recipe\nbased on your ingredients.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Recipe Card
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color.fromARGB(
                                              255, 255, 255, 255),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                      border: Border.all(
                                        color:
                                            const Color.fromARGB(255, 0, 0, 0),
                                        width: 2,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Recipe Image
                                        Stack(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(14),
                                                topRight: Radius.circular(14),
                                              ),
                                              child: Container(
                                                height: 200,
                                                width: double.infinity,
                                                color: const Color.fromARGB(
                                                    255, 175, 175, 172),
                                                child: isLoadingSuggestedImage
                                                    ? const Center(
                                                        child:
                                                            CircularProgressIndicator(
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                  Color>(
                                                            Color.fromARGB(255,
                                                                241, 147, 7),
                                                          ),
                                                        ),
                                                      )
                                                    : suggestedRecipeImage !=
                                                            null
                                                        ? Image.network(
                                                            suggestedRecipeImage!,
                                                            fit: BoxFit.cover,
                                                            loadingBuilder:
                                                                (context, child,
                                                                    loadingProgress) {
                                                              if (loadingProgress ==
                                                                  null)
                                                                return child;
                                                              return Center(
                                                                child:
                                                                    CircularProgressIndicator(
                                                                  value: loadingProgress
                                                                              .expectedTotalBytes !=
                                                                          null
                                                                      ? loadingProgress
                                                                              .cumulativeBytesLoaded /
                                                                          loadingProgress
                                                                              .expectedTotalBytes!
                                                                      : null,
                                                                  valueColor:
                                                                      const AlwaysStoppedAnimation<
                                                                          Color>(
                                                                    Color
                                                                        .fromARGB(
                                                                            255,
                                                                            241,
                                                                            147,
                                                                            7),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                            errorBuilder:
                                                                (context, error,
                                                                    stackTrace) {
                                                              return const Center(
                                                                child: Icon(
                                                                    Icons
                                                                        .restaurant,
                                                                    size: 50,
                                                                    color: Colors
                                                                        .grey),
                                                              );
                                                            },
                                                          )
                                                        : const Center(
                                                            child: Icon(
                                                                Icons
                                                                    .restaurant,
                                                                size: 50,
                                                                color: Colors
                                                                    .grey),
                                                          ),
                                              ),
                                            ),
                                            Positioned(
                                              top: 10,
                                              right: 10,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color.fromARGB(
                                                      255, 241, 147, 7),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.timer,
                                                        color: Colors.white,
                                                        size: 16),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${generatedRecipe!['time_minutes'] ?? 20} mins',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Recipe Content
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                generatedRecipe![
                                                        'recipe_name'] ??
                                                    'Recipe',
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color.fromARGB(
                                                      255, 255, 255, 255),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Row(
                                                      children: [
                                                        Icon(
                                                          Icons.restaurant_menu,
                                                          color: Color.fromARGB(
                                                              255, 241, 147, 7),
                                                          size: 20,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Ingredients:',
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: Colors.black,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ...List.generate(
                                                      (generatedRecipe!['ingredients']
                                                                      as List)
                                                                  .length >
                                                              3
                                                          ? 3
                                                          : (generatedRecipe![
                                                                      'ingredients']
                                                                  as List)
                                                              .length,
                                                      (i) => Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                                bottom: 4),
                                                        child: Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              '• ',
                                                              style: TextStyle(
                                                                fontSize: 16,
                                                                color: Color
                                                                    .fromARGB(
                                                                        255,
                                                                        241,
                                                                        147,
                                                                        7),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                            Expanded(
                                                              child: Text(
                                                                '${generatedRecipe!['ingredients'][i]}',
                                                                style:
                                                                    const TextStyle(
                                                                        fontSize:
                                                                            16),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    if ((generatedRecipe![
                                                                    'ingredients']
                                                                as List)
                                                            .length >
                                                        3)
                                                      const Text(
                                                        '... and more',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontStyle:
                                                              FontStyle.italic,
                                                          color: Color.fromARGB(
                                                              255, 241, 147, 7),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              ElevatedButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) =>
                                                          RecipeDetailPage(
                                                              recipe:
                                                                  generatedRecipe),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color.fromARGB(
                                                          255, 241, 147, 7),
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(
                                                      double.infinity, 50),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
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
                            ),
                )
              ],
            ),

            // Favorites Tab (Yeni eklenen sekme)
            Column(
              children: [
                // Title with gradient background
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                        'Your Favorite Recipes',
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
                    ],
                  ),
                ),
                // Favori tarifleri listele
                Expanded(
                  child: isFavoritesLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color.fromARGB(255, 241, 147, 7),
                            ),
                          ),
                        )
                      : favoriteRecipes.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.favorite_border,
                                    size: 80,
                                    color: const Color.fromARGB(
                                        255, 255, 230, 149),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "No favorite recipes yet",
                                    style: TextStyle(
                                        fontSize: 18, color: Colors.black),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    "Add recipes to your favorites by clicking the heart icon\non the recipe detail page.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 14, color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: favoriteRecipes.length,
                              itemBuilder: (context, index) {
                                final recipe = favoriteRecipes[index];
                                final recipeName =
                                    recipe['recipe_name'] ?? 'Unnamed Recipe';
                                final isImageLoading =
                                    loadingFavoriteImages[recipeName] ?? false;
                                final imageUrl =
                                    favoriteRecipeImages[recipeName];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: Colors.grey.shade300,
                                      width: 1,
                                    ),
                                  ),
                                  child: InkWell(
                                    onTap: () async {
                                      final recipeName = recipe['recipe_name'];

                                      final fullRecipeRows = await _supabase
                                          .from('recipes')
                                          .select()
                                          .eq('uuid_userid', effectiveUserID)
                                          .eq('recipe_name', recipeName);

                                      if (fullRecipeRows != null &&
                                          fullRecipeRows.isNotEmpty) {
                                        final firstRow = fullRecipeRows.first;

                                        // ingredients listesini tüm satırlardan topla
                                        final ingredients = fullRecipeRows
                                            .map((row) =>
                                                row['food_name']?.toString())
                                            .where((item) =>
                                                item != null && item.isNotEmpty)
                                            .toList();

                                        final fullRecipe = {
                                          'recipe_name': recipeName,
                                          'time_minutes': firstRow['time'],
                                          'ingredients': ingredients,
                                        };

                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                RecipeDetailPage(
                                                    recipe: fullRecipe),
                                          ),
                                        );
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Recipe Image
                                        Container(
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade300,
                                            borderRadius:
                                                const BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              topRight: Radius.circular(12),
                                            ),
                                          ),
                                          child: isImageLoading
                                              ? const Center(
                                                  child:
                                                      CircularProgressIndicator(
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Color.fromARGB(
                                                          255, 241, 147, 7),
                                                    ),
                                                  ),
                                                )
                                              : imageUrl != null
                                                  ? Image.network(
                                                      imageUrl,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      loadingBuilder: (context,
                                                          child,
                                                          loadingProgress) {
                                                        if (loadingProgress ==
                                                            null) return child;
                                                        return Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                            value: loadingProgress
                                                                        .expectedTotalBytes !=
                                                                    null
                                                                ? loadingProgress
                                                                        .cumulativeBytesLoaded /
                                                                    loadingProgress
                                                                        .expectedTotalBytes!
                                                                : null,
                                                            valueColor:
                                                                const AlwaysStoppedAnimation<
                                                                    Color>(
                                                              Color.fromARGB(
                                                                  255,
                                                                  241,
                                                                  147,
                                                                  7),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        return const Center(
                                                          child: Icon(
                                                              Icons.restaurant,
                                                              size: 50,
                                                              color:
                                                                  Colors.grey),
                                                        );
                                                      },
                                                    )
                                                  : Center(
                                                      child: Icon(
                                                        Icons.restaurant,
                                                        size: 50,
                                                        color: Colors
                                                            .grey.shade400,
                                                      ),
                                                    ),
                                        ),
                                        // Recipe Content
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      recipe['recipe_name'] ??
                                                          'Unnamed Recipe',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const Icon(
                                                    Icons.favorite,
                                                    color: Color.fromARGB(
                                                        255, 241, 147, 7),
                                                    size: 24,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              // Preparation time badge
                                              if (recipe['time_minutes'] !=
                                                  null)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color.fromARGB(
                                                        40, 241, 147, 7),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons.timer,
                                                        color: Color.fromARGB(
                                                            255, 241, 147, 7),
                                                        size: 16,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '${recipe['time_minutes']} mins',
                                                        style: const TextStyle(
                                                          color: Color.fromARGB(
                                                              255, 241, 147, 7),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              const SizedBox(height: 12),
                                              // Preview of ingredients
                                              if (recipe['ingredients'] !=
                                                      null &&
                                                  (recipe['ingredients']
                                                          as List)
                                                      .isNotEmpty)
                                                Text(
                                                  'Ingredients: ${(recipe['ingredients'] as List).take(2).join(", ")}${(recipe['ingredients'] as List).length > 2 ? "..." : ""}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 14,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: const Color.fromARGB(255, 241, 147, 7),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) {
          if (index != _currentIndex) {
            setState(() {
              _currentIndex = index;
            });

            // Navigate to the appropriate page based on the selected index
            if (index == 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            } else if (index == 2) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            }
            // For index 1 (recipes), we're already on the RecipePage so no navigation needed
          }
        },
        items: List.generate(
          _icons.length,
          (index) => BottomNavigationBarItem(
            icon: Icon(_icons[index]),
            label: index == 0
                ? 'Home'
                : index == 1
                    ? 'Recipes'
                    : 'Settings',
          ),
        ),
      ),
    );
  }
}
