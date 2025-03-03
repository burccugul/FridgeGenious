import 'package:flutter/material.dart';
import 'recipe_detail_page.dart';

class Recipe {
  final String name;
  final String imagePath;
  final int cookingTime;
  final bool isBookmarked;

  Recipe({
    required this.name,
    required this.imagePath,
    required this.cookingTime,
    this.isBookmarked = false,
  });
}

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Recipe> recipes = [
    Recipe(name: 'Oven Baked Fried Fries', imagePath: 'assets/images/fries.png', cookingTime: 45),
    Recipe(name: 'Omelet Egg Roll', imagePath: 'assets/images/omelet.png', cookingTime: 10),
    Recipe(name: 'Easy Hard Boiled Egg', imagePath: 'assets/images/egg.png', cookingTime: 10),
  ];

  int _currentIndex = 0;

  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Title
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recipes Matching Your Fridge',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(202, 0, 0, 0),
                  ),
                ),
              ),
            ),
            // Recipe List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  return GestureDetector(
                    onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => RecipeDetailPage(
        name: recipe.name,
        imagePath: recipe.imagePath,
        cookingTime: recipe.cookingTime,
        description: "Crispy on the outside, fluffy on the inside - these oven-baked fries are a healthier alternative to deep-fried potatoes.",
        ingredients: [
          "4 large potatoes, cut into even strips",
          "2 tablespoons olive oil",
          "1 teaspoon garlic powder",
          "1 teaspoon paprika",
          "1/2 teaspoon black pepper",
          "1 teaspoon sea salt",
        ],
        directions: [
          "Preheat oven to 425°F (220°C). Line a baking sheet with parchment paper.",
          "Soak potato strips in cold water for 30 minutes, then pat dry.",
          "Toss potatoes with olive oil and spices in a large bowl.",
          "Arrange on the baking sheet in a single layer.",
          "Bake for 20-25 minutes, flipping halfway through.",
          "Season with additional salt and serve hot.",
        ],
      ),
    ),
  );
},

                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(168, 158, 158, 158),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recipe Image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.asset(recipe.imagePath, fit: BoxFit.cover),
                            ),
                          ),
                          // Recipe Details
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      recipe.name,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Color.fromARGB(255, 141, 141, 141),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        recipe.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                        color: recipe.isBookmarked
                                            ? const Color.fromARGB(255, 101, 101, 101)
                                            : Colors.grey,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          recipes[index] = Recipe(
                                            name: recipe.name,
                                            imagePath: recipe.imagePath,
                                            cookingTime: recipe.cookingTime,
                                            isBookmarked: !recipe.isBookmarked,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Cooking Time: ${recipe.cookingTime} minutes',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
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
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: _currentIndex == index ? 60 : 50,
                height: _currentIndex == index ? 60 : 50,
                decoration: BoxDecoration(
                  color: _currentIndex == index ? const Color.fromARGB(255, 255, 230, 149) : Colors.grey[300],
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
}
