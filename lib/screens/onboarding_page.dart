import 'package:flutter/material.dart';
import 'package:flutter_application/screens/login_page.dart';


class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/images/fridge.jpg', // Add your fridge background image
              fit: BoxFit.cover,
              color: Color.fromRGBO(0, 0, 0, 0.5),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          
          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Top dots
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),

                // Decorative Orange Image
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 32.0),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/orange.png',
                        width: 128,
                        height: 128,
                        fit: BoxFit.cover, // Ensures the image fills the circle without stretching
                      ),
                    ),
                  ),
                ),

                // Main Text Content
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'NEW ERA OF\nFOOD STORAGE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Discover smart refrigerators',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white70,
                            ),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'with AR',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white70,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.view_in_ar,
                                color: Colors.amber,
                                size: 24,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Navigation
                Padding(
                  padding: const EdgeInsets.only(bottom: 48.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildNavigationButton(
                        icon: Icons.chevron_left,
                        onPressed: () {},
                        isMain: false,
                      ),
                      const SizedBox(width: 16),
                      _buildNavigationButton(
                        icon: Icons.view_in_ar,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                        isMain: true,
                      ),
                      const SizedBox(width: 16),
                      _buildNavigationButton(
                        icon: Icons.chevron_right,
                        onPressed: () {},
                        isMain: false,
                      ),
                    ],
                  ),
                ),

                // Decorative Bottle Image
                Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 32.0, bottom: 32.0),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/bottle.png', // Add your bottle image
                      width: 128,
                      height: 128,
                      fit: BoxFit.cover, // Ensures the image fills the circle without stretching
                    ),
                  ),
                ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isMain,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isMain ? Colors.white : Colors.grey,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.all(isMain ? 20.0 : 12.0),
            child: Icon(
              icon,
              size: isMain ? 32 : 24,
              color: isMain ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}