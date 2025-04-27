import 'package:flutter/material.dart';
import 'package:flutter_application/services/gemini_shopping_list_service.dart'; // Import the service
import 'package:flutter_application/screens/settings_page.dart';
import 'package:flutter_application/screens/home_page.dart';

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

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

    // Generate shopping lists at startup
    generateShoppingList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  void addItem(String category, String newItem) {
  setState(() {
    // "You have no shopping list..." mesajını sil
    shoppingLists[category]?.removeWhere((item) => item.startsWith("You have no shopping list"));

    // Yeni ürünü ekle
    shoppingLists[category]?.add(newItem);
  });
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
            onPressed: () {
              String newItem = _itemController.text.trim();
              if (newItem.isNotEmpty) {
                addItem(category, newItem); // Yeni öğe ekleme
                Navigator.pop(context);
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
                  icon: const Icon(Icons.add_circle_outline,
                      color: Color.fromARGB(255, 241, 147, 7)),
                  onPressed: () {
                    setState(() {
                      shoppingLists[category]?.remove(item);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed "$item"')),
                    );
                  },
                ),
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
