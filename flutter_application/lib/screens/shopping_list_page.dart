import 'package:flutter/material.dart';
import 'package:flutter_application/services/gemini_shopping_list_service.dart'; // Import the service

class ShoppingListPage extends StatefulWidget {
  const ShoppingListPage({super.key});

  @override
  State<ShoppingListPage> createState() => _ShoppingListPageState();
}

class _ShoppingListPageState extends State<ShoppingListPage>
    with SingleTickerProviderStateMixin {
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

  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];

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

  // Fetch and generate shopping list using Gemini AI
  Future<void> generateShoppingList() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get a single response with all categories
      Map<String, List<String>> response =
          await shoppingListService.generateShoppingList();

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

  // Build shopping list view
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
                // Add to cart functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added $item to cart')),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // Bottom Navigation Bar
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
                  // Handle tap navigation if needed
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 230, 149),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icons[index],
                  size: 30,
                  color: Colors.white,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
