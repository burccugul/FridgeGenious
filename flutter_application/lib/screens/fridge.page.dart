import 'package:flutter/material.dart';
import 'recipe_page.dart';

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  FridgePageState createState() => FridgePageState();
}

class FridgePageState extends State<FridgePage> with SingleTickerProviderStateMixin{
  late TabController _tabController;
  final List<Map<String, dynamic>> allIngredients = [
    {'name': 'Apple', 'emoji': '🍎', 'selected': false},
    {'name': 'Banana', 'emoji': '🍌', 'selected': false},
    {'name': 'Grapes', 'emoji': '🍇', 'selected': false},
    {'name': 'Orange', 'emoji': '🍊', 'selected': false},
    {'name': 'Strawberry', 'emoji': '🍓', 'selected': false},
    {'name': 'Potato', 'emoji': '🥔', 'selected': false},
    {'name': 'Carrot', 'emoji': '🥕', 'selected': false},
    {'name': 'Broccoli', 'emoji': '🥦', 'selected': false},
    {'name': 'Onion', 'emoji': '🧅', 'selected': false},
    {'name': 'Garlic', 'emoji': '🧄', 'selected': false},
    {'name': 'Tomato', 'emoji': '🍅', 'selected': false},
    {'name': 'Eggplant', 'emoji': '🍆', 'selected': false},
    {'name': 'Corn', 'emoji': '🌽', 'selected': false},
    {'name': 'Lettuce', 'emoji': '🥬', 'selected': false},
    {'name': 'Mushroom', 'emoji': '🍄', 'selected': false},
    {'name': 'Cheese', 'emoji': '🧀', 'selected': false},
    {'name': 'Milk', 'emoji': '🥛', 'selected': false},
    {'name': 'Butter', 'emoji': '🧈', 'selected': false},
    {'name': 'Egg', 'emoji': '🥚', 'selected': false},
    {'name': 'Yogurt', 'emoji': '🍦', 'selected': false},
    {'name': 'Fish', 'emoji': '🐟', 'selected': false},
    {'name': 'Meat', 'emoji': '🥩', 'selected': false},
    {'name': 'Chicken', 'emoji': '🍗', 'selected': false},
    {'name': 'Rice', 'emoji': '🍚', 'selected': false},
    {'name': 'Bread', 'emoji': '🍞', 'selected': false},
    {'name': 'Pasta', 'emoji': '🍝', 'selected': false},
    {'name': 'Peanut Butter', 'emoji': '🥜', 'selected': false},
    {'name': 'Jam', 'emoji': '🍯', 'selected': false},
    {'name': 'Honey', 'emoji': '🍯', 'selected': false},
    {'name': 'Chili Pepper', 'emoji': '🌶️', 'selected': false},
    {'name': 'Cucumber', 'emoji': '🥒', 'selected': false},
    {'name': 'Pumpkin', 'emoji': '🎃', 'selected': false},
  ];
  int _currentIndex = 0;

  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  List<Map<String, dynamic>> filteredIngredients = [];
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    filteredIngredients = allIngredients;
    _tabController = TabController(length: 3, vsync: this);
  }

  void searchIngredients(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredIngredients = allIngredients;
      } else {
        filteredIngredients = allIngredients
            .where((ingredient) =>
                ingredient['name'].toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  int get selectedCount => allIngredients.where((i) => i['selected']).length;

  void toggleIngredient(int index) {
    setState(() {
      filteredIngredients[index]['selected'] = !filteredIngredients[index]['selected'];
      // Update the corresponding ingredient in allIngredients
      int allIngredientsIndex = allIngredients.indexWhere((ingredient) => ingredient['name'] == filteredIngredients[index]['name']);
      if (allIngredientsIndex != -1) {
        allIngredients[allIngredientsIndex]['selected'] = filteredIngredients[index]['selected'];
      }
    });
  }

  void resetSelection() {
    setState(() {
      for (var ingredient in allIngredients) {
        ingredient['selected'] = false;
      }
      searchIngredients(searchQuery); // Reapply the current search
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          "What's In Your Fridge",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                onChanged: searchIngredients,
                decoration: InputDecoration(
                  hintText: 'Search for a product...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // Grid of Ingredients
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filteredIngredients.length,
                itemBuilder: (context, index) {
                  final ingredient = filteredIngredients[index];
                  return GestureDetector(
                    onTap: () => toggleIngredient(index),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ingredient['selected']
                              ? Colors.blue
                              : Colors.blue[100]!,
                          width: ingredient['selected'] ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ingredient['emoji'],
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ingredient['name'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Section (Conditional)
            if (selectedCount > 0)
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: const BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$selectedCount ingredients selected',
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: resetSelection,
                          child: const Text(
                            'Reset',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RecipePage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color.fromARGB(255, 241, 147, 7),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Find Recipes',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
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

