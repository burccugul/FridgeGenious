import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final Logger _logger = Logger('FridgeApp');

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  FridgePageState createState() => FridgePageState();
}

class FridgePageState extends State<FridgePage>
    with SingleTickerProviderStateMixin {
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

  /// ✅ **Supabase'ten envanteri çek**
  Future<void> fetchInventory() async {
    try {
      final response =
          await Supabase.instance.client.from('inventory').select();
      setState(() {
        inventoryItems = List<Map<String, dynamic>>.from(response).map((item) {
          String foodName = item['food_name'];
          return {
            'name': foodName,
            'emoji': emojiMap[foodName] ?? '❓',
            'selected': false
          };
        }).toList();
      });
    } catch (e) {
      _logger.severe('❌ Envanter verileri çekilirken hata oluştu: $e');
    }
  }

  /// ✅ **Supabase ile yeni bir yiyecek ekle**
  Future<void> addFoodToInventory(String foodName) async {
    try {
      // Veritabanında zaten var mı kontrol et
      final response = await Supabase.instance.client
          .from('inventory')
          .select()
          .eq('food_name', foodName)
          .maybeSingle();

      if (response == null) {
        // Eğer yoksa, ekle
        await Supabase.instance.client.from('inventory').insert({
          'food_name': foodName,
          'quantity': 1, // Varsayılan miktar 1
          'expiration_date': DateTime.now().toIso8601String(), // Geçici SKT
        });

        fetchInventory(); // Güncellenmiş verileri çek
      }
    } catch (e) {
      _logger.severe('❌ Hata: Yiyecek eklenirken bir hata oluştu: $e');
    }
  }

  /// ✅ **Seçili ürünü aç/kapat**
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
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
