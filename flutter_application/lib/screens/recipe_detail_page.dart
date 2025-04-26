import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _supabase = Supabase.instance.client;
  String? effectiveUserID;

  @override
  void initState() {
    super.initState();
    // Initialize favorite status from recipe data
    if (widget.recipe != null) {
      setState(() {
        isFavorite = widget.recipe!['is_favorite'] ?? false;
      });
    }
    _getEffectiveUserID().then((_) {
      // Load favorite status after getting effective user ID
      _loadFavoriteStatus();
    });
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
      print('Response type: ${response.runtimeType}');
      print('Response data: $response');

      // Doğru şekilde parse et
      if (response != null) {
        if (response is List && response.isNotEmpty) {
          // Liste ise ilk elemanı al
          setState(() {
            isFavorite = response[0]['is_favorite'] ?? false;
          });
          print('Loaded favorite status from list: $isFavorite');
        } else if (response is Map) {
          // Doğrudan bir Map ise
          setState(() {
            isFavorite = response['is_favorite'] ?? false;
          });
          print('Loaded favorite status from map: $isFavorite');
        } else {
          print('Unknown response format: $response');
        }
      }
    } catch (e) {
      print('Error loading favorite status: $e');
      print('Stack trace: ${StackTrace.current}');
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

  Future<void> toggleFavorite() async {
    print("Toggle favorite clicked"); // Debug print

    if (widget.recipe == null) return;
    if (effectiveUserID == null) {
      print("No effective user ID found");
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

              // Recipe Image - Using a placeholder or you can add image URL to your recipe data
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      recipe['image_url'] ??
                          'https://via.placeholder.com/400x300',
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: const Color.fromARGB(255, 175, 175, 172),
                          child: const Center(
                            child: Icon(Icons.restaurant,
                                size: 50, color: Colors.grey),
                          ),
                        );
                      },
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
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: isIngredientsExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          isIngredientsExpanded = expanded;
                        });
                      },
                      title: const Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            color: Color.fromARGB(255, 241, 147, 7),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Ingredients',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 241, 147, 7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isIngredientsExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (recipe['ingredients'] != null)
                                ...List.generate(
                                  (recipe['ingredients'] as List).length,
                                  (i) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8.0),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '• ',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Color.fromARGB(
                                                255, 241, 147, 7),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            '${recipe['ingredients'][i]}',
                                            style:
                                                const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: isDirectionsExpanded,
                      onExpansionChanged: (expanded) {
                        setState(() {
                          isDirectionsExpanded = expanded;
                        });
                      },
                      title: const Row(
                        children: [
                          Icon(
                            Icons.menu_book,
                            color: Color.fromARGB(255, 241, 147, 7),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Direction',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      trailing: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 241, 147, 7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDirectionsExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (recipe['steps'] != null)
                                ...List.generate(
                                  (recipe['steps'] as List).length,
                                  (i) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 16.0),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color.fromARGB(
                                              255, 255, 230, 149),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: const BoxDecoration(
                                              color: Color.fromARGB(
                                                  255, 241, 147, 7),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${i + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '${recipe['steps'][i]}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Start Cooking Button
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: () {},
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
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_filled, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Start cooking',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
