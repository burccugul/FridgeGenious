import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('FridgeApp');

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  FridgePageState createState() => FridgePageState();
}

class FridgePageState extends State<FridgePage> {
  List<Map<String, dynamic>> inventoryItems = [];
  // Get reference to Supabase client
  final supabase = Supabase.instance.client;

  final Map<String, String> emojiMap = {
    'Apple': '🍎',
    'Banana': '🍌',
    'Grape': '🍇',
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
    'Blueberry': '🫐',
    'Fig': '🍇',
    'Apricot': '🍑',
    'Kiwi': '🥝',
    'Curry': '🍛',
    'Hazelnut': '🌰',
    'Bean': '🫘',
    'Peanut': '🥜',
    'Raisin': '🍇',
    'Juice': '🧃',
    'Basil': '🌿',
    'Pepper': '🌶️',
    'Ginger': '🧄',
  };

  @override
  void initState() {
    super.initState();
    fetchInventory();
  }

  Future<void> fetchInventory() async {
    try {
      // Fetch from Supabase 'inventory' table
      final response = await supabase.from('inventory').select();
      print(response);
      setState(() {
        inventoryItems = (response as List).map((item) {
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
      final currentUser = supabase.auth.currentUser;
      final userId = currentUser?.id ?? '1'; // Use '1' if no user is logged in

      // If the user is not logged in, you can handle this scenario
      //if (userId == null) {
      // _logger.severe('No user is logged in');
      // return;
      // }

      // If the quantity is 0 or less, add to shopping list
      if (newQuantity <= 0) {
        // Add the item to the shopping list with the user ID
        await supabase.from('shoppinglist').insert({
          'food_name': foodName,
          'remove_date': DateTime.now()
              .toString(), // Store when it was added to shopping list
          'userid': userId, // Add the user ID to the shopping list entry
        });

        // Update the inventory to set the quantity to 0 instead of deleting it
        await supabase
            .from('inventory')
            .update({'quantity': 0}).eq('food_name', foodName);
      } else {
        // If the quantity is greater than 0, update the inventory
        await supabase
            .from('inventory')
            .update({'quantity': newQuantity}).eq('food_name', foodName);
      }
      setState(() {
        // Find the item in the list and update its quantity
        final index =
            inventoryItems.indexWhere((item) => item['name'] == foodName);
        if (index != -1) {
          inventoryItems[index]['quantity'] = newQuantity;
        }
      });
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
