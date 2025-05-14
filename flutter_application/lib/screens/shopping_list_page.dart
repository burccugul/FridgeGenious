import 'package:flutter/material.dart';
import 'package:flutter_application/services/gemini_shopping_list_service.dart'; // Import the service
import 'package:flutter_application/screens/settings_page.dart';
import 'package:flutter_application/screens/home_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingListPage extends StatefulWidget {
  final Future<void> Function()
      pickImage; // pickImage fonksiyonunu burada alıyoruz

  ShoppingListPage({super.key, required this.pickImage});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late GeminiShoppingListService shoppingListService;
  final supabase = Supabase.instance.client;
  String? effectiveUserID;

  // Store the AI response for all categories
  Map<String, List<String>> shoppingLists = {
    "daily": [],
    "weekly": [],
    "monthly": [],
  };

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    shoppingListService = GeminiShoppingListService();
    _getEffectiveUserID(); // burada çağrılmalı

    // Generate shopping lists at startup
    generateShoppingList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
        effectiveUserID = supabase.auth.currentUser?.id;
      });
    }
  }

  Future<void> addItemToDatabase({
    required String foodName,
    required int consumationRateByWeek,
  }) async {
    final currentUserID = supabase.auth.currentUser?.id;
    final userIDArray = '["$currentUserID"]';

    String effectiveUserID;

    try {
      final familyPackagesResponse = await supabase
          .from('family_packages')
          .select()
          .or('owner_user_id.eq.$currentUserID,member_user_ids.cs.$userIDArray');

      if (familyPackagesResponse != null && familyPackagesResponse.isNotEmpty) {
        final familyPackage = familyPackagesResponse[0];
        effectiveUserID = familyPackage['owner_user_id'];
        print(
            'User is part of family package: ${familyPackage['family_name']}');
        print('Using family owner ID: $effectiveUserID');
      } else {
        effectiveUserID = currentUserID!;
        print('User is not part of any family package, using personal ID.');
      }
    } catch (e) {
      print('Error fetching family package info: $e');
      effectiveUserID = currentUserID!;
    }

    // Bugünün tarihi
    final today = DateTime.now();

    // Supabase'e veri ekleme
    final response = await supabase.from('shoppinglist').insert({
      'food_name': foodName,
      'remove_date': today.toIso8601String(),
      'consumation_rate_by_week': consumationRateByWeek,
      'uuid_userid': effectiveUserID,
    });

    if (response == null) {
      throw Exception("Item could not be added to shoppinglist.");
    }

    print("Item added to shoppinglist for user $effectiveUserID");
  }

  // Fetch and generate shopping list using Gemini AI
  Future<void> generateShoppingList() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get a single response with all categories
      Map<String, List<String>> response =
          await shoppingListService.generateShoppingList();
      print("Gelen response: $response");
      setState(() {
        shoppingLists = response;
        isLoading = false;
      });
    } catch (e) {
      print("Error in generateShoppingList: $e");
      setState(() {
        shoppingLists = {
          "daily": ["Error: $e"],
          "weekly": ["Error: $e"],
          "monthly": ["Error: $e"],
        };
        isLoading = false;
      });
    }
  }

  void _showAddItemDialog(String category) {
    final TextEditingController _itemController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Item to $category list'),
          content: TextField(
            controller: _itemController,
            decoration: InputDecoration(hintText: 'Enter item name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                String newItem = _itemController.text.trim();
                if (newItem.isNotEmpty && effectiveUserID != null) {
                  try {
                    final today = DateTime.now();

                    // Insert the item into Supabase
                    await supabase.from('shoppinglist').insert({
                      'food_name': newItem,
                      'remove_date':
                          today.toIso8601String().split('T')[0], // only date
                      'consumation_rate_by_week':
                          1, // example value, can be modified
                      'uuid_userid': effectiveUserID,
                    });

                    // Update the shopping list in state
                    setState(() {
                      shoppingLists[category]?.add(newItem);
                    });

                    Navigator.pop(
                        context); // Close the dialog after successful add
                  } catch (e) {
                    print('Error adding item: $e');
                    // You can show an error message if needed
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 241, 147, 7),
              ),
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _handleSearch() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) return;

    List<String> results = [];

    shoppingLists.forEach((category, items) {
      for (String item in items) {
        if (item.toLowerCase().contains(query)) {
          results.add('"$item" found in $category list');
        }
      }
    });

    if (results.isEmpty) {
      results.add('No match found for "$query"');
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search Result'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: results.map((r) => Text(r)).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  void _removeItemFromDatabase(String item, String category) async {
    try {
      final currentUserID = supabase.auth.currentUser?.id;
      final userIDArray = '["$currentUserID"]';

      String effectiveUserID;

      // Fetch the effective user ID (same logic as earlier)
      final familyPackagesResponse = await supabase
          .from('family_packages')
          .select()
          .or('owner_user_id.eq.$currentUserID,member_user_ids.cs.$userIDArray');

      if (familyPackagesResponse != null && familyPackagesResponse.isNotEmpty) {
        final familyPackage = familyPackagesResponse[0];
        effectiveUserID = familyPackage['owner_user_id'];
      } else {
        effectiveUserID = currentUserID!;
      }

      print('Effective User ID: $effectiveUserID');
      print('Item to delete: $item');

      // Attempt to remove the item from the shopping list
      final response = await supabase
          .from('shoppinglist')
          .delete()
          .match({'food_name': item, 'uuid_userid': effectiveUserID});

      // Log the response to debug
      //print('Delete response: $response');

      // if (response == null || response.isEmpty) {
      // throw Exception("Item not found or could not be removed.");
      // }

      print('Item removed successfully: $item');

      // Remove the item from the local list and update the UI
      setState(() {
        shoppingLists[category]?.remove(item);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "$item" from $category list')),
      );
    } catch (e) {
      print('Error removing item: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing "$item": $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 241, 147, 7),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 241, 147, 7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Shopping List',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          // Add refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: isLoading ? null : generateShoppingList,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search and Cart Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'Search for "Grocery"',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20),
                        ),
                        textAlignVertical: TextAlignVertical.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: _handleSearch,
                  )
                ],
              ),
            ),

            // Shopping List Categories Tabs
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Daily'),
                  Tab(text: 'Weekly'),
                  Tab(text: 'Monthly'),
                ],
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                labelStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 16,
                ),
              ),
            ),

            // Shopping List Display
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildShoppingListView(
                            shoppingLists["daily"] ?? [], 'daily'),
                        _buildShoppingListView(
                            shoppingLists["weekly"] ?? [], 'weekly'),
                        _buildShoppingListView(
                            shoppingLists["monthly"] ?? [], 'monthly'),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCurvedNavigationBar(),
    );
  }

  Widget _buildShoppingListView(List<String> items, String category) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          "No items found for $category shopping list",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddItemDialog(category),
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 241, 147, 7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: isLoading ? null : generateShoppingList,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 241, 147, 7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                String item = items[index].trim();
                return ListTile(
                  leading: const Icon(Icons.shopping_basket,
                      color: Color.fromARGB(255, 241, 147, 7)),
                  title: Text(item),
                  trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Color.fromARGB(255, 241, 147, 7)),
                      onPressed: () {
                        _removeItemFromDatabase(item, category);
                      }),
                );
              },
            ),
          ),
        ],
      ),
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
                if (index == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            const HomePage()), // HomePage'e yönlendir
                  );
                } else if (index == 1) {
                  // widget.pickImage fonksiyonunu çağırıyoruz
                  widget.pickImage(); // pickImage'ı burada çağırıyoruz
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
