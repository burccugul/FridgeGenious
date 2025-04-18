import 'package:flutter/material.dart';
import '/services/gemini_recipe_service.dart';
import 'dart:convert';
import 'recipe_detail_page.dart';
import 'package:flutter_application/screens/settings_page.dart';
import 'package:flutter_application/screens/home_page.dart';

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];

  int _currentIndex = 0;

  Map<String, dynamic>? generatedRecipe;

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Use Future.delayed to ensure the widget is fully built before fetching
    Future.delayed(Duration.zero, () {
      fetchGeneratedRecipe();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

      String recipeJson =
          await GeminiRecipeService().generateRecipe(ingredients);

      final parsed = jsonDecode(recipeJson);

      if (mounted) {
        setState(() {
          generatedRecipe = parsed;
          isLoading = false;
        });
      }

      // Don't automatically navigate to detail page
      // Let the user view the recipe summary first
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
          'Suggested Recipes',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          // Add refresh button to generate new recipes
          IconButton(
            icon:
                const Icon(Icons.refresh, color: Color.fromARGB(255, 0, 0, 0)),
            onPressed: fetchGeneratedRecipe,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Title with gradient background
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
                            style: TextStyle(fontSize: 16, color: Colors.black),
                          ),
                        ],
                      ),
                    )
                  : generatedRecipe == null
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
                              const Text(
                                "No recipe available.",
                                style: TextStyle(
                                    fontSize: 16, color: Colors.black),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Tap the refresh button to generate a recipe\nbased on your ingredients.",
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : generatedRecipe!.containsKey('error')
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 60,
                                    color: Color.fromARGB(255, 241, 147, 7),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    generatedRecipe!['error'],
                                    style: const TextStyle(
                                        fontSize: 16, color: Colors.red),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: fetchGeneratedRecipe,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color.fromARGB(
                                          255, 241, 147, 7),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text("Try Again"),
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
