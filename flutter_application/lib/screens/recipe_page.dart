import 'package:flutter/material.dart';
import '/services/gemini_recipe_service.dart';
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

  // Favori tarifleri yükle
// Modify the _loadFavoriteRecipes method in the _RecipePageState class

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
                                                child: const Center(
                                                  child: Icon(Icons.restaurant,
                                                      size: 50,
                                                      color: Colors.grey),
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
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              RecipeDetailPage(recipe: recipe),
                                        ),
                                      ).then((_) {
                                        // Detay sayfasından dönünce favori durumlarını yenile
                                        _loadFavoriteRecipes();
                                      });
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
                                          child: Center(
                                            child: Icon(
                                              Icons.restaurant,
                                              size: 40,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ),
                                        // Recipe Details
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      recipe['recipe_name'] ??
                                                          'Unnamed Recipe',
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    if (recipe[
                                                                'ingredients'] !=
                                                            null &&
                                                        recipe['ingredients']
                                                            is List &&
                                                        (recipe['ingredients']
                                                                as List)
                                                            .isNotEmpty)
                                                      Text(
                                                        'Ingredients: ${(recipe['ingredients'] as List).take(3).join(", ")}${(recipe['ingredients'] as List).length > 3 ? "..." : ""}',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey.shade600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color.fromARGB(
                                                      255, 241, 147, 7),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.timer,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${recipe['time_minutes'] ?? 20} min',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                );
                              },
                            ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCurvedNavigationBar(),
    );
  }

  Widget _buildCurvedNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_icons.length, (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentIndex = index;
                });

                if (index == 1) {
                  final GlobalKey<HomePageState> _homeKey =
                      GlobalKey<HomePageState>();

                  _homeKey.currentState?.pickImage();
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: _currentIndex == index ? 60 : 50,
                height: _currentIndex == index ? 60 : 50,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? const Color.fromARGB(255, 255, 230, 149)
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icons[index],
                  size: _currentIndex == index ? 30 : 24,
                  color: _currentIndex == index ? Colors.white : Colors.black54,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget buildCustomButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double iconSize = 24,
    Color textColor = Colors.white,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
      ),
      icon: Icon(icon, size: iconSize, color: Colors.black),
      label: Text(text, style: TextStyle(fontSize: 18, color: textColor)),
    );
  }
}

class CurvedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    var path = Path();
    path.moveTo(0, size.height * 0.2);
    path.quadraticBezierTo(
        size.width * 0.25, size.height * 0.05, size.width, size.height * 0.15);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
