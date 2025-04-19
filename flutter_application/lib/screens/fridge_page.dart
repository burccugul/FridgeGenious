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
      final currentUser = supabase.auth.currentUser;
      final uuidUserId = currentUser?.id;

      if (uuidUserId == null) {
        _logger.warning('No user is logged in');
        return;
      }

      final response = await supabase
          .from('inventory')
          .select()
          .eq('uuid_userid', uuidUserId);

      _logger.info('Inventory response: $response');

      setState(() {
        inventoryItems = (response as List).map((item) {
          String foodName = item['food_name'];
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
      final uuidUserId = currentUser?.id;

      if (uuidUserId == null) {
        _logger.warning('No user is logged in');
        return;
      }

      if (newQuantity <= 0) {
        await supabase.from('shoppinglist').insert({
          'food_name': foodName,
          'remove_date': DateTime.now().toIso8601String(),
          'uuid_userid': uuidUserId,
        });

        await supabase
            .from('inventory')
            .update({'quantity': 0})
            .eq('food_name', foodName)
            .eq('uuid_userid', uuidUserId);
      } else {
        await supabase
            .from('inventory')
            .update({'quantity': newQuantity})
            .eq('food_name', foodName)
            .eq('uuid_userid', uuidUserId);
      }

      setState(() {
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
