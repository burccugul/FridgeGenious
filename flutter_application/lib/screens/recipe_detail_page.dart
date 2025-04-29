import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer';
// Import our image service
import '../services/recipe_image_service.dart';

class RecipeDetailPage extends StatefulWidget {
  final Map<String, dynamic>? recipe;

  const RecipeDetailPage({super.key, this.recipe});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  int servings = 1;
  bool isIngredientsExpanded = false;
  bool isDirectionsExpanded = true;
  bool isFavorite = false;
  bool isUpdating = false;
  bool isLoadingImage = true;
  String? recipeImageUrl;
  final _supabase = Supabase.instance.client;
  String? effectiveUserID;
  final _imageService = RecipeImageService(); // Initialize our image service

  @override
  void initState() {
    super.initState();
    // Initialize favorite status from recipe data
    if (widget.recipe != null) {
      setState(() {
        isFavorite = widget.recipe!['is_favorite'] ?? false;
      });

      // Fetch recipe image
      _loadRecipeImage();
    }

    _getEffectiveUserID().then((_) {
      // Load favorite status after getting effective user ID
      _loadFavoriteStatus();
    });
  }

  // Load recipe image from Google Custom Search API
  Future<void> _loadRecipeImage() async {
    if (widget.recipe == null) return;

    final recipeName = widget.recipe!['recipe_name'];
    if (recipeName == null) return;

    setState(() {
      isLoadingImage = true;
    });

    try {
      // First check if there's an image_url in the recipe data
      final existingImageUrl = widget.recipe!['image_url'];
      if (existingImageUrl != null && existingImageUrl.toString().isNotEmpty) {
        setState(() {
          recipeImageUrl = existingImageUrl;
          isLoadingImage = false;
        });
        return;
      }

      // If no existing image URL, fetch from the image service
      final imageUrl = await _imageService.getImageForRecipe(recipeName);

      if (mounted) {
        setState(() {
          recipeImageUrl = imageUrl;
          isLoadingImage = false;
        });

        // Optionally: Update the recipe in Supabase with the image URL
        if (imageUrl != null && effectiveUserID != null) {
          try {
            await _supabase
                .from('recipes')
                .update({'image_url': imageUrl})
                .eq('recipe_name', recipeName)
                .eq('uuid_userid', effectiveUserID);
            log('Updated recipe with image URL in database');
          } catch (e) {
            log('Failed to update image URL in database: $e');
          }
        }
      }
    } catch (e) {
      log('Error loading recipe image: $e');
      if (mounted) {
        setState(() {
          isLoadingImage = false;
        });
      }
    }
  }

  // Sayfaya her geri dönüldüğünde çağrılacak
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (effectiveUserID != null && widget.recipe != null) {
      _loadFavoriteStatus();
    }
  }

// Favori durumunu veritabanından yükle
  Future<void> _loadFavoriteStatus() async {
    if (effectiveUserID == null || widget.recipe == null) return;

    final recipeName = widget.recipe!['recipe_name'];
    if (recipeName == null) return;

    try {
      // Response yapısını anlamak için önce yazdıralım
      final response = await _supabase
          .from('recipes')
          .select('is_favorite')
          .eq('recipe_name', recipeName)
          .eq('uuid_userid', effectiveUserID)
          .limit(1);

      // Response formatını debug amaçlı yazdır
      log('Response type: ${response.runtimeType}');
      log('Response data: $response');

      // Doğru şekilde parse et
      if (response != null) {
        if (response is List && response.isNotEmpty) {
          // Liste ise ilk elemanı al
          setState(() {
            isFavorite = response[0]['is_favorite'] ?? false;
          });
          log('Loaded favorite status from list: $isFavorite');
        } else if (response is Map) {
          // Doğrudan bir Map ise
          setState(() {
            isFavorite = response['is_favorite'] ?? false;
          });
          log('Loaded favorite status from map: $isFavorite');
        } else {
          log('Unknown response format: $response');
        }
      }
    } catch (e) {
      log('Error loading favorite status: $e');
      log('Stack trace: ${StackTrace.current}');
    }
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
        setState(() {
          effectiveUserID = familyPackage['owner_user_id'];
        });
        log('User is part of family package: ${familyPackage['family_name']}');
        log('Using family owner ID: $effectiveUserID');
      } else {
        setState(() {
          effectiveUserID = currentUserID;
        });
        log('User is not part of any family package, using personal ID: $effectiveUserID');
      }
    } catch (e) {
      log('Error getting effective user ID: $e');
      setState(() {
        effectiveUserID = _supabase.auth.currentUser?.id;
      });
    }
  }

  Future<void> toggleFavorite() async {
    log("Toggle favorite clicked"); // Debug print

    if (widget.recipe == null) return;
    if (effectiveUserID == null) {
      log("No effective user ID found");
      return;
    }

    final recipeName = widget.recipe!['recipe_name'];
    if (recipeName == null) return;

    setState(() {
      isUpdating = true;
    });

    try {
      // Toggle favorite status
      final newFavoriteStatus = !isFavorite;

      // Update in Supabase - hem recipe_name hem de user_id ile eşleştirme yapıyoruz
      await _supabase
          .from('recipes')
          .update({'is_favorite': newFavoriteStatus})
          .eq('recipe_name', recipeName)
          .eq('uuid_userid',
              effectiveUserID); // Efektif kullanıcı kimliğini kullan

      // Update local state if successful
      setState(() {
        isFavorite = newFavoriteStatus;
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newFavoriteStatus
              ? 'Added to favorites'
              : 'Removed from favorites'),
          backgroundColor: const Color.fromARGB(255, 241, 147, 7),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update favorite status: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      // Revert back if failed
      setState(() {
        isFavorite = !isFavorite;
      });
    } finally {
      setState(() {
        isUpdating = false;
      });
    }
  }

  // First, add this function to the _RecipeDetailPageState class

  Future<void> _startCooking() async {
    // Show warning dialog
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Cooking?'),
        content: const Text(
          'The ingredients used in this recipe will be removed from your inventory. Do you want to proceed?',
          style: TextStyle(fontSize: 16),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 241, 147, 7),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Proceed',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldProceed != true) return;

    // Show loading indicator
    if (!mounted) return;
    _showLoadingDialog();

    try {
      if (widget.recipe == null)
        throw Exception('Recipe details not available');
      if (effectiveUserID == null) throw Exception('User ID not found');

      final recipeName = widget.recipe!['recipe_name'];
      if (recipeName == null) throw Exception('Recipe name not found');

      final recipeIngredientsResponse = await _supabase
          .from('recipes')
          .select('food_name, quantity')
          .eq('recipe_name', recipeName)
          .eq('uuid_userid', effectiveUserID);

      if (recipeIngredientsResponse == null ||
          recipeIngredientsResponse is! List ||
          recipeIngredientsResponse.isEmpty) {
        throw Exception('No ingredients found for this recipe');
      }

      // Remove ingredients and check if it was successful
      final success =
          await _removeIngredientsFromInventory(recipeIngredientsResponse);

      if (!mounted) return;
      Navigator.of(context).pop(); // Remove loading dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingredients have been removed from your inventory'),
            backgroundColor: Color.fromARGB(255, 241, 147, 7),
            duration: Duration(seconds: 2),
          ),
        );
      }
      // else: Başarısızlık mesajı zaten içeride gösteriliyor
    } catch (e) {
      log('Error in _startCooking: $e');
      log('Stack trace: ${StackTrace.current}');

      if (mounted) {
        Navigator.of(context).pop(); // Remove loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

// Helper function to show a loading dialog
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.fromARGB(255, 241, 147, 7),
              ),
            ),
            SizedBox(height: 16),
            Text('Updating inventory...'),
          ],
        ),
      ),
    );
  }

  Future<bool> _removeIngredientsFromInventory(List recipeIngredients) async {
    if (effectiveUserID == null) return false;

    final inventoryResponse = await _supabase
        .from('inventory')
        .select()
        .eq('uuid_userid', effectiveUserID);

    if (inventoryResponse == null || inventoryResponse is! List) {
      throw Exception('Failed to retrieve inventory');
    }

    final inventoryMap = {
      for (var item in inventoryResponse)
        item['food_name'].toString().toLowerCase(): item
    };

    bool hasZeroQuantityIngredient = false;
    List<String> zeroQuantityIngredients = [];

    for (final ingredient in recipeIngredients) {
      final foodName = ingredient['food_name'].toString().toLowerCase();

      if (inventoryMap.containsKey(foodName)) {
        final inventoryItem = inventoryMap[foodName];
        final currentQuantity =
            int.tryParse('${inventoryItem['quantity']}') ?? 0;

        if (currentQuantity == 0) {
          hasZeroQuantityIngredient = true;
          zeroQuantityIngredients.add(foodName);
        }
      } else {
        hasZeroQuantityIngredient = true;
        zeroQuantityIngredients.add(foodName);
      }
    }

    if (hasZeroQuantityIngredient) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot reduce ingredients: Some required ingredients have zero quantity: ${zeroQuantityIngredients.join(", ")}',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }

    final updates = <Future>[];
    final updatedIngredients = <String>[];
    final today = DateTime.now().toIso8601String().split('T')[0];
    final shoppingListItems = <Map<String, dynamic>>[];

    for (final ingredient in recipeIngredients) {
      final foodName = ingredient['food_name'].toString().toLowerCase();
      final recipeQuantity = ingredient['quantity'] ?? 1;

      final inventoryItem = inventoryMap[foodName];
      final currentQuantity = int.tryParse('${inventoryItem['quantity']}') ?? 0;
      final recipeQty = int.tryParse('$recipeQuantity') ?? 1;
      final newQuantity = currentQuantity - recipeQty;

      final update = _supabase
          .from('inventory')
          .update({'quantity': newQuantity})
          .eq('food_name', inventoryItem['food_name'])
          .eq('uuid_userid', effectiveUserID);

      updates.add(update);
      updatedIngredients.add(foodName);

      if (newQuantity == 0) {
        shoppingListItems.add({
          'food_name': inventoryItem['food_name'],
          'remove_date': today,
          'consumation_rate_by_week': 1,
          'uuid_userid': effectiveUserID,
        });
      }
    }

    if (updates.isNotEmpty) {
      await Future.wait(updates);
    }

    if (shoppingListItems.isNotEmpty) {
      try {
        for (final item in shoppingListItems) {
          final existingItems = await _supabase
              .from('shoppinglist')
              .select()
              .eq('food_name', item['food_name'])
              .eq('uuid_userid', effectiveUserID);

          if (existingItems is List && existingItems.isEmpty) {
            await _supabase.from('shoppinglist').insert(item);
          } else {
            await _supabase
                .from('shoppinglist')
                .update({
                  'remove_date': today,
                  'consumation_rate_by_week': (int.tryParse(
                              '${existingItems[0]['consumation_rate_by_week']}') ??
                          0) +
                      1
                })
                .eq('food_name', item['food_name'])
                .eq('uuid_userid', effectiveUserID);
          }
        }
      } catch (e) {
        log('Error updating shopping list: $e');
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;

    if (recipe == null) {
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
            'Recipe',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.fromARGB(255, 241, 147, 7),
                ),
              ),
              SizedBox(height: 16),
              Text("Loading recipe details...", style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Bar with back button, title and favorite
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 255, 255, 255),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color.fromARGB(255, 9, 9, 9), size: 20),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                    // Title
                    const Text(
                      'Recipe',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Favorite button - Using GestureDetector instead of Container with IconButton
                    GestureDetector(
                      onTap: isUpdating ? null : toggleFavorite,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color.fromARGB(255, 0, 0, 0),
                            width: 2,
                          ),
                        ),
                        child: isUpdating
                            ? const Padding(
                                padding: EdgeInsets.all(10.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color.fromARGB(255, 241, 147, 7),
                                  ),
                                ),
                              )
                            : Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isFavorite
                                    ? const Color.fromARGB(255, 241, 147, 7)
                                    : const Color.fromARGB(255, 0, 0, 0),
                                size: 20,
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              // Recipe Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe['recipe_name'] ?? 'Recipe',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
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

              // Recipe Image - Now showing from our image service
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color.fromARGB(255, 245, 245, 245),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: isLoadingImage
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color.fromARGB(255, 241, 147, 7),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "Loading recipe image...",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : recipeImageUrl != null
                            ? Image.network(
                                recipeImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  log('Error loading image: $error');
                                  return Container(
                                    color: const Color.fromARGB(
                                        255, 175, 175, 172),
                                    child: const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.restaurant,
                                              size: 50, color: Colors.white),
                                          SizedBox(height: 8),
                                          Text(
                                            "Image not available",
                                            style:
                                                TextStyle(color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color.fromARGB(255, 175, 175, 172),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.image_not_supported,
                                          size: 50, color: Colors.white),
                                      SizedBox(height: 8),
                                      Text(
                                        "No image available",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                  ),
                ),
              ),

              // Description - You can add this to your recipe data model
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color.fromARGB(255, 255, 230, 149),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    recipe['description'] ??
                        'A delicious recipe made with ingredients from your fridge.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),

              // Servings and Time
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 249, 231, 173),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color.fromARGB(255, 241, 147, 7),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Cook Time
                      Column(
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.timer,
                                color: Color.fromARGB(255, 241, 147, 7),
                                size: 18,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Cook Time',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 241, 147, 7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${recipe['time_minutes'] ?? recipe['time'] ?? 20} mins',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Ingredients Section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 230, 149),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ingredients Header with expand/collapse functionality
                      InkWell(
                        onTap: () {
                          setState(() {
                            isIngredientsExpanded = !isIngredientsExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.shopping_basket,
                                    color: Color.fromARGB(255, 241, 147, 7),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Ingredients',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                isIngredientsExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: const Color.fromARGB(255, 241, 147, 7),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Ingredients List - Expanded or collapsed
                      if (isIngredientsExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: _buildIngredientsList(recipe),
                        ),
                    ],
                  ),
                ),
              ),

              // Directions Section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 255, 230, 149),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Directions Header with expand/collapse functionality
                      InkWell(
                        onTap: () {
                          setState(() {
                            isDirectionsExpanded = !isDirectionsExpanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.menu_book,
                                    color: Color.fromARGB(255, 241, 147, 7),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Directions',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                isDirectionsExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: const Color.fromARGB(255, 241, 147, 7),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Directions List - Expanded or collapsed
                      if (isDirectionsExpanded)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: _buildDirectionsList(recipe),
                        ),
                    ],
                  ),
                ),
              ),

              // Start Cooking Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _startCooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 241, 147, 7),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Start Cooking',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Function to build ingredients list
  Widget _buildIngredientsList(Map<String, dynamic> recipe) {
    // Filter recipe data to get only ingredients items
    final List<Map<String, dynamic>> ingredients = [];
    if (recipe['ingredients'] != null && recipe['ingredients'] is List) {
      for (var item in recipe['ingredients']) {
        if (item is Map<String, dynamic>) {
          ingredients.add(item);
        } else if (item is String) {
          // Handle string format if your data might be in that format
          ingredients.add({'name': item, 'quantity': '1', 'unit': ''});
        }
      }
    } else {
      // If ingredients aren't in a nested structure, check for food_name and quantity fields
      if (recipe['food_name'] != null) {
        ingredients.add({
          'name': recipe['food_name'],
          'quantity': recipe['quantity'] ?? '1',
          'unit': recipe['unit'] ?? ''
        });
      }
    }

    if (ingredients.isEmpty) {
      // Fallback for when we can't parse ingredients properly
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text(
          'No ingredients information available.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    return Column(
      children: ingredients.map((ingredient) {
        // Try to extract ingredient information with fallbacks
        final name = ingredient['name'] ??
            ingredient['food_name'] ??
            'Unknown ingredient';
        final quantity = ingredient['quantity'] ?? '1';
        final unit = ingredient['unit'] ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 241, 147, 7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$quantity ${unit.isNotEmpty ? '$unit ' : ''}$name',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Function to build directions list
  Widget _buildDirectionsList(Map<String, dynamic> recipe) {
    // Try to extract directions from recipe
    List<String> directions = [];

    if (recipe['directions'] != null) {
      if (recipe['directions'] is List) {
        for (var direction in recipe['directions']) {
          if (direction is String) {
            directions.add(direction);
          } else if (direction is Map && direction['step'] != null) {
            directions.add(direction['step'].toString());
          }
        }
      } else if (recipe['directions'] is String) {
        // If directions is a single string, split by periods or newlines
        String dirText = recipe['directions'];
        if (dirText.contains('\n')) {
          directions = dirText
              .split('\n')
              .where((step) => step.trim().isNotEmpty)
              .toList();
        } else {
          directions = dirText
              .split('.')
              .where((step) => step.trim().isNotEmpty)
              .map((step) => '${step.trim()}.')
              .toList();
        }
      }
    } else if (recipe['steps'] != null) {
      // Alternative field name
      if (recipe['steps'] is List) {
        for (var step in recipe['steps']) {
          if (step is String) {
            directions.add(step);
          } else if (step is Map && step['instruction'] != null) {
            directions.add(step['instruction'].toString());
          }
        }
      } else if (recipe['steps'] is String) {
        String stepsText = recipe['steps'];
        if (stepsText.contains('\n')) {
          directions = stepsText
              .split('\n')
              .where((step) => step.trim().isNotEmpty)
              .toList();
        } else {
          directions = stepsText
              .split('.')
              .where((step) => step.trim().isNotEmpty)
              .map((step) => '${step.trim()}.')
              .toList();
        }
      }
    }

    if (directions.isEmpty) {
      // Fallback text
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: Text(
          'No cooking directions available.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: directions.asMap().entries.map((entry) {
        final index = entry.key;
        final direction = entry.value;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
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
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  direction,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
