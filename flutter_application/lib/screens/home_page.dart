import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'recipe_page.dart';
import 'shopping_list_page.dart';
import 'fridge.page.dart';
import 'settings_page.dart';
import 'image_preview_page.dart';

// ✅ Gemini API Key'in:
const String geminiApiKey = 'AIzaSyBu12BW-XfmHaTcf_giQnPKTn2Bdb7-HkE';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;

  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];

  Future<void> pickImageAndSend() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
      print('Seçilen resim: ${image.path}');

      // ✅ Gemini'ye gönder:
      await sendImageToGemini(File(image.path));

      // ✅ Seçilen resmi göster:
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImagePreviewPage(imagePath: image.path),
        ),
      );
    } else {
      print('Hiçbir resim seçilmedi.');
    }
  }

  Future<void> sendImageToGemini(File imageFile) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: geminiApiKey,
    );

    final imageBytes = await imageFile.readAsBytes();
    final prompt = 'Bu görselde kaç tane yiyecek var, sayar mısın?';

    try {
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ]);

      print('✅ Gemini Yanıtı: ${response.text}');
    } catch (e) {
      print('❌ Gemini Hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(color: const Color(0xFFFFB74D)),
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'Hey, Admin',
                    style: TextStyle(
                      fontSize: 32,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Let’s manage your fridge!',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildCustomButton(
                    text: "What's Inside My Fridge",
                    icon: Icons.kitchen,
                    iconSize: 90,
                    color: Colors.white,
                    textColor: Colors.black,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const FridgePage()),
                      );
                    },
                  ),
                  const SizedBox(height: 70),
                  _buildCustomButton(
                    text: "Suggest Recipe",
                    icon: Icons.book,
                    iconSize: 40,
                    iconColor: Colors.black,
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
                    iconColor: Colors.black,
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

                if (index == 1) {
                  pickImageAndSend();
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
                width: _currentIndex == index ? 60 : 50,
                height: _currentIndex == index ? 60 : 50,
                decoration: BoxDecoration(
                  color: _currentIndex == index
                      ? const Color(0xFFFFE695)
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icons[index],
                  size: _currentIndex == index ? 30 : 24,
                  color:
                      _currentIndex == index ? Colors.white : Colors.black54,
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
      icon: Icon(icon, size: iconSize, color: iconColor),
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
