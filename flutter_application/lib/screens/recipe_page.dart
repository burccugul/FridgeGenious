import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '/services/gemini_recipe_service.dart';

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<IconData> _icons = [
    Icons.home,
    Icons.camera_alt_outlined,
    Icons.settings,
  ];

  int _currentIndex = 0;
  String generatedRecipe = "";
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 🔹 Supabase Entegre: Envanterden malzemeleri çek ve AI ile tarif oluştur
  Future<void> fetchGeneratedRecipe() async {
    setState(() {
      isLoading = true;
    });

    try {
      // ✅ Supabase üzerinden inventory tablosundan yiyecekleri çek
      final supabase = Supabase.instance.client;
      final response = await supabase.from('inventory').select('food_name');

      if (response.isEmpty) {
        setState(() {
          generatedRecipe = "No ingredients found in the database.";
          isLoading = false;
        });
        return;
      }

      // ✅ Çekilen yiyecekleri listeye çevir
      List<String> ingredients = response.map((item) => item['food_name'] as String).toList();

      // ✅ Gemini API ile tarif oluştur
      String recipe = await GeminiRecipeService().generateRecipe(ingredients);

      setState(() {
        generatedRecipe = recipe;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        generatedRecipe = "Error fetching recipe: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Suggested Recipes',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ✅ Başlık
            const Padding(
              padding: EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recipes Matching Your Fridge',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            // ✅ Buton: Tarif Öner
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: fetchGeneratedRecipe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Suggest Recipe",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            // ✅ Tarif Gösterme Alanı
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        generatedRecipe.isEmpty
                            ? "No recipe generated yet."
                            : generatedRecipe,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: Colors.black,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCurvedNavigationBar(),
    );
  }

  // ✅ Navigasyon Çubuğu (Alt Menü)
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
}
