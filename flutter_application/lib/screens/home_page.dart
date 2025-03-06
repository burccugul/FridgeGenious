import 'package:flutter/material.dart';
import 'package:flutter_application/screens/fridge_page.dart';
import 'recipe_page.dart';
import 'shopping_list_page.dart';
import 'settings_page.dart';
import '../services/gemini_image_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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

  // Kamera ve galeri seçimi için image picker
  final ImagePicker _picker = ImagePicker();

  // Seçilen fotoğrafı saklamak için bir değişken
  File? _image;

  // Kamera veya galeriden fotoğraf seçme işlemi
  Future<void> _pickImage() async {
    final pickedFile = await showDialog<File>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Choose an option"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text("Take a Photo"),
                onTap: () async {
                  final image =
                      await _picker.pickImage(source: ImageSource.camera);
                  Navigator.pop(
                      context, image == null ? null : File(image.path));
                },
              ),
              ListTile(
                title: Text("Choose from Gallery"),
                onTap: () async {
                  final image =
                      await _picker.pickImage(source: ImageSource.gallery);
                  Navigator.pop(
                      context, image == null ? null : File(image.path));
                },
              ),
            ],
          ),
        );
      },
    );

    if (pickedFile != null) {
      setState(() {
        _image = pickedFile; // Seçilen fotoğrafı sakla
      });
    }
  }

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
                  // "What's Inside My Fridge" butonu
                  _buildCustomButton(
                    text: "What's Inside My Fridge",
                    icon: Icons.kitchen,
                    iconSize: 90,
                    color: const Color.fromARGB(255, 255, 255, 255),
                    textColor: Colors.black,
                    onPressed: () async {
                      if (_image == null) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("No image selected")),
                          );
                        }
                        return;
                      }

                      // Fotoğraf seçildiyse Gemini API'ye gönder
                      GeminiService geminiService = GeminiService();
                      String aiResponse =
                          await geminiService.analyzeImage(_image!);

                      // Gemini'den gelen yanıtı göster
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(aiResponse)),
                        );
                      }

                      // FridgePage'e geçiş
                      if (mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FridgePage(),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 70),
                  // Diğer butonlar
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

  // Custom navigation bar
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

                // Kamera iconuna tıklanması
                if (index == 1) {
                  _pickImage(); // Kamera veya galeriden fotoğraf seçme
                } else if (index == 2) {
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

  // Custom button widget
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
