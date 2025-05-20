import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'package:flutter_application/screens/special_recipe_page.dart';

final Logger _logger = Logger('FridgeApp');

class FridgePage extends StatefulWidget {
  const FridgePage({super.key});

  @override
  FridgePageState createState() => FridgePageState();
}

class FridgePageState extends State<FridgePage> {
  List<Map<String, dynamic>> inventoryItems = [];
  final supabase = Supabase.instance.client;
  String? effectiveUserID;
  bool isLoading = true; // Veri yükleniyor mu kontrolü
  TextEditingController foodController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  DateTime? selectedExpirationDate;

  final Map<String, String> emojiMap = {
    'Apple': '🍎',
    'Banana': '🍌',
    'Grapes': '🍇',
    'Orange': '🍊',
    'Strawberry': '🍓',
    'Blueberry': '🫐',
    'Pineapple': '🍍',
    'Watermelon': '🍉',
    'Lemon': '🍋',
    'Peach': '🍑',
    'Mango': '🥭',
    'Kiwi': '🥝',
    'Melon': '🍈',
    'Cherry': '🍒',
    'Coconut': '🥥',
    'Tomato': '🍅',
    'Avocado': '🥑',
    'Cucumber': '🥒',
    'Carrot': '🥕',
    'Broccoli': '🥦',
    'Corn': '🌽',
    'Lettuce': '🥬',
    'Onion': '🧅',
    'Garlic': '🧄',
    'Mushroom': '🍄',
    'Potato': '🥔',
    'Eggplant': '🍆',
    'Pumpkin': '🎃',
    'Cheese': '🧀',
    'Milk': '🥛',
    'Butter': '🧈',
    'Egg': '🥚',
    'Yogurt': '🍦',
    'Fish': '🐟',
    'Meat': '🥩',
    'Chicken': '🍗',
    'Bacon': '🥓',
    'Shrimp': '🦐',
    'Crab': '🦀',
    'Lobster': '🦞',
    'Rice': '🍚',
    'Curry': '🍛',
    'Spaghetti': '🍝',
    'Stew': '🍲',
    'Salad': '🥗',
    'Sandwich': '🥪',
    'Hamburger': '🍔',
    'Pizza': '🍕',
    'Fries': '🍟',
    'Hot Dog': '🌭',
    'Taco': '🌮',
    'Burrito': '🌯',
    'Sushi': '🍣',
    'Dumpling': '🥟',
    'Ramen': '🍜',
    'Bread': '🍞',
    'Croissant': '🥐',
    'Baguette': '🥖',
    'Pretzel': '🥨',
    'Bagel': '🥯',
    'Pancakes': '🥞',
    'Waffle': '🧇',
    'Honey': '🍯',
    'Jam': '🍯',
    'Peanut Butter': '🥜',
    'Nuts': '🌰',
    'Bean': '🫘',
    'Ice Cream': '🍨',
    'Cake': '🍰',
    'Cupcake': '🧁',
    'Chocolate': '🍫',
    'Cookie': '🍪',
    'Doughnut': '🍩',
    'Popcorn': '🍿',
    'Candy': '🍬',
    'Lollipop': '🍭',
    'Pie': '🥧',
    'Chili Pepper': '🌶️',
    'Herbs': '🌿',
    'Basil': '🌿',
    'Juice': '🧃',
    'Soda': '🥤',
    'Coffee': '☕',
    'Tea': '🍵',
    'Bubble Tea': '🧋',
    'Beer': '🍺',
    'Wine': '🍷',
    'Cocktail': '🍸',
    'Tumbler': '🥃',
    'Champagne': '🍾',
    'Bottle': '🍼',
    'Fork and Knife': '🍴',
    'Spoon': '🥄',
    'Apricot': '🍑',
    'Ham': '🥓',
    'Grapefruit': '🍊',
    'Ginger': '🫚',
    'Almond': '🌰',
    'Spinach': '🥬',
    'Pepper': '🌶️',
    'Dried Apricot': '🍑',
    'Oat': '🌾',
    'Fig': '🍈',
    'Salmon': '🐟',
    'Preserved Ginger': '🫚',
    'Cardamom': '🌿',
    'Peppercorn': '🌶️',
    'Pasta': '🍝',
    'Raisin': '🍇',
    'Grape': '🍇',
    'Noodle': '🍜',
    'Flaxseed': '🌾',
    'Orange Juice': '🍊',
    'Pomegranate': '🍎',
    'Peanut': '🥜',
    'Hazelnut': '🌰'
  };

  @override
  void initState() {
    super.initState();
    _getEffectiveUserID().then((_) => fetchInventory());
  }

  // Son kullanma tarihine kalan gün sayısını hesapla
  int? getDaysUntilExpiration(String? expirationDateStr) {
    if (expirationDateStr == null) return null;

    final expirationDate = DateTime.tryParse(expirationDateStr)?.toLocal();
    if (expirationDate == null) return null;

    final today = DateTime.now();
    final difference = expirationDate.difference(today).inDays;
    return difference;
  }

  Future<void> addItemToInventory() async {
    final foodName = foodController.text.trim();
    final quantity = int.tryParse(quantityController.text) ?? 1;
    final expirationDate = selectedExpirationDate;

    if (foodName.isEmpty || expirationDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Please enter food name and expiration date.")),
      );
      return;
    }

    if (effectiveUserID == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not logged in.")),
      );
      return;
    }

    try {
      FocusScope.of(context).unfocus();

      // Show loading indicator
      setState(() {
        isLoading = true;
      });

      // Aynı isimde bir ürün var mı kontrol et
      final existingItemIndex = inventoryItems.indexWhere(
          (item) => item['name'].toLowerCase() == foodName.toLowerCase());

      if (existingItemIndex != -1) {
        // Aynı isimde ürün varsa, miktarını güncelle
        final existingItem = inventoryItems[existingItemIndex];
        final newQuantity = (existingItem['quantity'] as int) + quantity;

        // Veritabanında güncelle
        await supabase
            .from('inventory')
            .update({
              'quantity': newQuantity,
              'expiration_date': expirationDate
                  .toIso8601String(), // Son kullanma tarihini de güncelle
              'last_image_upload': DateTime.now().toIso8601String(),
            })
            .eq('food_name', existingItem['name'])
            .eq('uuid_userid', effectiveUserID);

        // UI'yi güncelle
        setState(() {
          // Mevcut öğeyi listeden kaldır
          inventoryItems.removeAt(existingItemIndex);

          // Güncellenmiş öğeyi listenin başına ekle
          inventoryItems.insert(0, {
            'name': existingItem['name'],
            'emoji': existingItem['emoji'],
            'quantity': newQuantity,
            'selected': existingItem['selected'],
            'expiration_date': expirationDate.toIso8601String(),
          });

          isLoading = false;
        });

        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "${existingItem['name']} quantity updated to $newQuantity!")),
        );
      } else {
        // Yeni ürün ekle
        final response = await supabase.from('inventory').insert([
          {
            'food_name': foodName,
            'quantity': quantity,
            'expiration_date': expirationDate.toIso8601String(),
            'uuid_userid': effectiveUserID,
            'last_image_upload': DateTime.now().toIso8601String(),
          }
        ]).select();

        // Immediately add the new item to the local list
        if (response != null && response.isNotEmpty) {
          final expirationDateStr = expirationDate.toIso8601String();

          // Add the new item to the beginning of the local inventory list
          setState(() {
            inventoryItems.insert(0, {
              'name': foodName,
              'emoji': emojiMap[foodName] ?? '🍽️',
              'quantity': quantity,
              'selected': false,
              'expiration_date': expirationDateStr,
            });
            isLoading = false;
          });

          // Başarı mesajı göster
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$foodName added successfully!")),
          );
        }
      }

      // Input alanlarını temizle
      foodController.clear();
      quantityController.clear();
      selectedExpirationDate = null;
    } catch (e, stackTrace) {
      setState(() {
        isLoading = false;
      });
      _logger.severe('Error adding item: $e', e, stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error adding item: $e")),
      );
    }
  }

  Future<void> _selectExpirationDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != selectedExpirationDate)
      setState(() {
        selectedExpirationDate = picked;
      });
  }

  // Get the actual user ID to use (considering family package)
  Future<void> _getEffectiveUserID() async {
    try {
      final currentUserID = supabase.auth.currentUser?.id;
      final userIDArray = '["$currentUserID"]';

      final familyPackagesResponse = await supabase
          .from('family_packages')
          .select()
          .or('owner_user_id.eq.$currentUserID,member_user_ids.cs.$userIDArray');

      if (familyPackagesResponse != null && familyPackagesResponse.isNotEmpty) {
        final familyPackage = familyPackagesResponse[0];
        setState(() {
          effectiveUserID = familyPackage['owner_user_id'];
        });
        _logger.info(
            'User is part of family package: ${familyPackage['family_name']}');
        _logger.info('Using family owner ID: $effectiveUserID');
      } else {
        setState(() {
          effectiveUserID = currentUserID;
        });
        _logger.info(
            'User is not part of any family package, using personal ID: $effectiveUserID');
      }
    } catch (e) {
      _logger.warning('Error getting effective user ID: $e');
      setState(() {
        effectiveUserID = supabase.auth.currentUser?.id;
      });
    }
  }

  Future<void> fetchInventory() async {
    try {
      if (effectiveUserID == null) {
        _logger.warning('No user is logged in');
        return;
      }

      setState(() {
        isLoading = true;
      });

      final response = await supabase
          .from('inventory')
          .select()
          .eq('uuid_userid', effectiveUserID);

      _logger.info('Inventory response: $response');

      setState(() {
        inventoryItems = (response as List).map((item) {
          String foodName = item['food_name'];
          int quantity = int.tryParse(item['quantity'].toString()) ?? 0;
          return {
            'name': foodName,
            'emoji': emojiMap[foodName] ?? '🍽️',
            'quantity': quantity,
            'selected': false,
            'expiration_date': item['expiration_date'],
          };
        }).toList();
        isLoading = false; // Veriler yüklendi
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _logger.severe('Error fetching inventory: $e');
    }
  }

  Future<void> updateQuantity(String foodName, int newQuantity) async {
    try {
      if (effectiveUserID == null) {
        _logger.warning('No user is logged in');
        return;
      }
      // UI'yi hemen güncelle
      setState(() {
        final index =
            inventoryItems.indexWhere((item) => item['name'] == foodName);
        if (index != -1) {
          inventoryItems[index]['quantity'] = newQuantity;
        }
      });

      if (newQuantity <= 0) {
        await supabase.from('shoppinglist').insert({
          'food_name': foodName,
          'remove_date': DateTime.now().toIso8601String(),
          'uuid_userid': effectiveUserID,
        });

        await supabase
            .from('inventory')
            .update({
              'quantity': 0,
              'last_image_upload': DateTime.now().toIso8601String(),
            })
            .eq('food_name', foodName)
            .eq('uuid_userid', effectiveUserID);
      } else {
        await supabase
            .from('inventory')
            .update({
              'quantity': newQuantity,
              'last_image_upload': DateTime.now().toIso8601String(),
            })
            .eq('food_name', foodName)
            .eq('uuid_userid', effectiveUserID);
      }
    } catch (e) {
      _logger.severe('Error updating quantity: $e');
    }
  }

  void toggleIngredient(int index) {
    setState(() {
      // Only toggle the ingredient if the quantity is greater than 0
      if (inventoryItems[index]['quantity'] > 0) {
        inventoryItems[index]['selected'] = !inventoryItems[index]['selected'];
      }
    });
  }

  // Property to track the count of selected ingredients
  int get selectedIngredientsCount =>
      inventoryItems.where((item) => item['selected'] == true).length;

  // Navigate to SpecialRecipePage with selected ingredients
  void _navigateToSpecialRecipe() {
    final selectedIngredients = inventoryItems
        .where((item) => item['selected'] == true)
        .map((item) => item['name'].toString())
        .toList();

    if (selectedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one ingredient')));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SpecialRecipePage(
          selectedIngredients: selectedIngredients,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("What's In Your Fridge"),
        backgroundColor: Color.fromARGB(255, 241, 147, 7)
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: foodController,
                    decoration: InputDecoration(
                      labelText: "Enter food name",
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showAddItemDialog(context),
                ),
              ],
            ),
          ),
          isLoading
              ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.fromARGB(255, 241, 147, 7),
                      ),
                    ),
                  ),
                )
              : inventoryItems.isEmpty
                  ? const Expanded(
                      child: Center(
                        child: Text('You have no items in your fridge.'),
                      ),
                    )
                  : Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: inventoryItems.length,
                        itemBuilder: (context, index) {
                          final ingredient = inventoryItems[index];
                          final expirationDate =
                              ingredient['expiration_date'] != null
                                  ? DateTime.tryParse(
                                          ingredient['expiration_date'])
                                      ?.toLocal()
                                  : null;
                          final expirationDateFormatted = expirationDate != null
                              ? DateFormat('yyyy-MM-dd').format(expirationDate)
                              : null;

                          // Son kullanma tarihine kalan gün sayısını hesapla
                          final daysUntilExpiration = getDaysUntilExpiration(
                              ingredient['expiration_date']);

                          // Son kullanma tarihine 5 gün veya daha az kaldıysa uyarı göster
                          final bool isExpiringSoon =
                              daysUntilExpiration != null &&
                                  daysUntilExpiration >= 0 &&
                                  daysUntilExpiration <= 5;

                          // Son kullanma tarihi geçtiyse
                          final bool isExpired = daysUntilExpiration != null &&
                              daysUntilExpiration < 0;

                          return GestureDetector(
                            onTap: () => toggleIngredient(index),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: ingredient['selected']
                                      ? Colors.orangeAccent
                                      : Colors.blue[100]!,
                                  width: ingredient['selected'] ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(ingredient['emoji'],
                                          style: const TextStyle(fontSize: 40)),
                                      const SizedBox(height: 8),
                                      Text(ingredient['name'],
                                          style: const TextStyle(fontSize: 16)),
                                      if (expirationDateFormatted != null)
                                        Text(
                                          'Expires on: $expirationDateFormatted',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isExpired
                                                ? Colors.red
                                                : isExpiringSoon
                                                    ? Colors.orange
                                                    : Colors.grey,
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove),
                                            onPressed: () {
                                              if (ingredient['quantity'] > 0) {
                                                int newQuantity =
                                                    ingredient['quantity'] - 1;
                                                updateQuantity(
                                                    ingredient['name'],
                                                    newQuantity);
                                              }
                                            },
                                          ),
                                          Text('${ingredient['quantity']}',
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          IconButton(
                                            icon: const Icon(Icons.add),
                                            onPressed: () {
                                              int newQuantity =
                                                  ingredient['quantity'] + 1;
                                              updateQuantity(ingredient['name'],
                                                  newQuantity);
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // Son kullanma tarihine 5 gün veya daha az kaldıysa uyarı göster
                                  if (isExpiringSoon)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$daysUntilExpiration days left',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),

                                  // Son kullanma tarihi geçtiyse uyarı göster
                                  if (isExpired)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'Expired!',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
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
      floatingActionButton: selectedIngredientsCount > 0
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToSpecialRecipe(),
              label: Text('Get Recipe ($selectedIngredientsCount)'),
              icon: Icon(Icons.restaurant_menu),
              backgroundColor: const Color.fromARGB(255, 241, 147, 7),
            )
          : null,
    );
  }

  void _showAddItemDialog(BuildContext context) {
    // Reset controllers and selected date when opening dialog
    quantityController.text = "1"; // Default quantity

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add New Item"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: foodController,
                    decoration: const InputDecoration(
                      labelText: "Food Name",
                    ),
                  ),
                  TextField(
                    controller: quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Quantity",
                    ),
                  ),
                  ListTile(
                    title: Text(
                      selectedExpirationDate == null
                          ? 'Select Expiration Date'
                          : 'Expiration Date: ${DateFormat('yyyy-MM-dd').format(selectedExpirationDate!)}',
                    ),
                    onTap: () async {
                      // Takvim seçiciyi gösteriyoruz
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2101),
                      );

                      if (picked != null && picked != selectedExpirationDate) {
                        setDialogState(() {
                          selectedExpirationDate =
                              picked; // Tarihi güncelliyoruz
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    addItemToInventory(); // Dialog kapandıktan sonra ekleme işlemini yapıyoruz
                  },
                  child: const Text("Add Item"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
