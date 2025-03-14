import 'package:flutter/material.dart';
import 'package:flutter_application/database/database_helper.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('FridgeApp');

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  FridgePageState createState() => FridgePageState();
}

class FridgePageState extends State<FridgePage> {
  List<Map<String, dynamic>> inventoryItems = [];

  final Map<String, String> emojiMap = {
    'Apple': '🍎',
    'Banana': '🍌',
    'Grapes': '🍇',
    'Orange': '🍊',
    'Strawberry': '🍓',
    'Potato': '🥔',
    'Carrot': '🥕',
    'Broccoli': '🥦',
    'Onion': '🧅',
    'Garlic': '🧄',
    'Tomato': '🍅',
    'Eggplant': '🍆',
    'Corn': '🌽',
    'Lettuce': '🥬',
    'Mushroom': '🍄',
    'Cheese': '🧀',
    'Milk': '🥛',
    'Butter': '🧈',
    'Egg': '🥚',
    'Yogurt': '🍦',
    'Fish': '🐟',
    'Meat': '🥩',
    'Chicken': '🍗',
    'Rice': '🍚',
    'Bread': '🍞',
    'Pasta': '🍝',
    'Peanut Butter': '🥜',
    'Jam': '🍯',
    'Honey': '🍯',
    'Chili Pepper': '🌶️',
    'Cucumber': '🥒',
    'Pumpkin': '🎃',
  };

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  Future<void> fetchInventory() async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();
      List<Map<String, dynamic>> inventory = await dbHelper.getInventory();

      setState(() {
        inventoryItems = inventory.map((item) {
          String foodName = item['food_name'];
          // Ensure quantity is converted to int
          int quantity = int.tryParse(item['quantity'].toString()) ?? 0;
          return {
            'name': foodName,
            'emoji': emojiMap[foodName] ?? '❓',
            'quantity': quantity,
            'selected': false,
          };
        }).toList();
      });
    } catch (e) {
      _logger.severe('Error fetching inventory: $e');
    }
  }

  Future<void> updateQuantity(String foodName, int newQuantity) async {
    try {
      DatabaseHelper dbHelper = DatabaseHelper();

      // If the quantity is 0 or less, don't delete from inventory
      if (newQuantity <= 0) {
        // Add the item to the shopping list if the quantity reaches 0
        await dbHelper.insertShoppingList({
          'food_name': foodName,
          'remove_date': DateTime.now()
              .toString(), // Store when it was added to shopping list
        });

        // Update the inventory to set the quantity to 0 instead of deleting it
        await dbHelper.updateInventoryQuantity(foodName, 0);
      } else {
        // If the quantity is greater than 0, update the inventory
        await dbHelper.updateInventoryQuantity(foodName, newQuantity);
      }

      fetchInventory(); // Refresh the inventory list after update
    } catch (e) {
      _logger.severe('Error updating quantity: $e');
    }
  }

  void toggleIngredient(int index) {
    setState(() {
      inventoryItems[index]['selected'] = !inventoryItems[index]['selected'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("What's In Your Fridge"),
      ),
      body: inventoryItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: inventoryItems.length,
              itemBuilder: (context, index) {
                final ingredient = inventoryItems[index];
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
                        Text(ingredient['emoji'],
                            style: const TextStyle(fontSize: 40)),
                        const SizedBox(height: 8),
                        Text(ingredient['name'],
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                if (ingredient['quantity'] > 0) {
                                  int newQuantity = ingredient['quantity'] - 1;
                                  updateQuantity(
                                      ingredient['name'], newQuantity);
                                }
                              },
                            ),
                            Text('${ingredient['quantity']}',
                                style: const TextStyle(fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                int newQuantity = ingredient['quantity'] + 1;
                                updateQuantity(ingredient['name'], newQuantity);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
