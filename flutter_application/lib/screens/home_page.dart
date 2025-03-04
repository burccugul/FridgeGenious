import 'package:flutter/material.dart';
import 'package:flutter_application/screens/fridge_page.dart';
import 'recipe_page.dart';
import 'shopping_list_page.dart';
import 'settings_page.dart';
import '../services/gemini_image_service.dart';
import 'dart:io';
import '../services/food_database_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Yellow background
          Container(
            color: const Color(0xFFFFB74D),
          ),
          // White curved section
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.4,
            child: CustomPaint(
              painter: CurvedPainter(),
              child: Container(),
            ),
          ),
          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Hey, Admin',
                      style: TextStyle(
                        fontSize: 32,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Let’s manage your fridge!',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildCustomButton(
                    text: "What's Inside My Fridge",
                    icon: Icons.kitchen,
                    iconSize: 90,
                    color: const Color.fromARGB(255, 255, 255, 255),
                    textColor: Colors.black,
                    onPressed: () async {
                      String imagePath =
                          "/Users/burcugul/FridgeGenious/test_image.jpg"; // Replace with your actual image path
                      File imageFile = File(imagePath);

                      if (!imageFile.existsSync()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text("Image not found: $imagePath")),
                        );
                        return;
                      }

                      GeminiService geminiService = GeminiService();
                      String aiResponse =
                          await geminiService.analyzeImage(imageFile);

                      // Log the response here for debugging
                      print("AI Response: $aiResponse");
                      WidgetsFlutterBinding.ensureInitialized();

                      // Initialize the SQLite database
                      final db = await FoodDatabaseService().initDatabase();
                      print("Database path: ${db.path}");

                      // Pass the response to GeminiResponsePage
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FridgePage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 70),
                  _buildCustomButton(
                    text: "Suggest Recipe",
                    icon: Icons.book,
                    iconSize: 40,
                    iconColor: const Color.fromARGB(255, 0, 0, 0),
                    color: const Color.fromARGB(255, 241, 147, 7),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RecipePage()),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildCustomButton(
                    text: "Suggest Shopping List",
                    icon: Icons.shopping_cart,
                    iconSize: 40,
                    iconColor: const Color.fromARGB(255, 0, 0, 0),
                    color: const Color.fromARGB(255, 241, 147, 7),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ShoppingListPage()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
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

                // Sayfa geçişi
                if (index == 2) {
                  // Settings Page
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

  Widget _buildCustomButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    double iconSize = 24,
    Color textColor = Colors.white,
    Color iconColor = Colors.black,
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
      icon: Icon(
        icon,
        size: iconSize,
        color: iconColor,
      ),
      label: Text(
        text,
        style: TextStyle(fontSize: 18, color: textColor),
      ),
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
      size.width * 0.25,
      size.height * 0.05,
      size.width,
      size.height * 0.15,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
