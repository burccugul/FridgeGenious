import 'package:flutter/material.dart';
import '/services/gemini_recipe_service.dart';

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

  int _currentIndex = 0; // Ensure this is defined

  String generatedRecipe = "";
  bool isLoading = false;

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

  Future<void> fetchGeneratedRecipe() async {
    setState(() {
      isLoading = true;
    });

    // Get food items from the database
    List<String> ingredients =
        await GeminiRecipeService().getIngredientsFromDatabase();

    // Generate a recipe based on the ingredients
    String recipe = await GeminiRecipeService().generateRecipe(ingredients);

    setState(() {
      generatedRecipe = recipe;
      isLoading = false;
    });
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
            color: Colors.black, // Set text color to black
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
                    color: Colors.black, // Set text color to black
                  ),
                ),
              ),
            ),
            // Button to fetch the recipe
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () {
                  fetchGeneratedRecipe();
                },
                child: isLoading
                    ? CircularProgressIndicator()
                    : Text(
                        "Suggest Recipe",
                        style: TextStyle(
                            color: Colors.black), // Set button text to black
                      ),
              ),
            ),
            // Display the generated recipe or a placeholder
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        generatedRecipe.isEmpty
                            ? "No recipe generated yet."
                            : generatedRecipe,
                        style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.black), // Set text color to black
                      ),
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
}
