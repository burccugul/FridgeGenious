import 'package:flutter/material.dart';
import '../services/food_database_service.dart'; // Import the FoodDatabaseHelper

class GeminiResponsePage extends StatelessWidget {
  final String response;

  const GeminiResponsePage({super.key, required this.response});

  @override
  Widget build(BuildContext context) {
    // Fetch food items from the database
    Future<List<String>> _fetchFoodItems() async {
      return await FoodDatabaseService().getAllFood();
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Analysis Result")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display the Gemini response
              Text(
                response.isEmpty ? "No meaningful response from AI" : response,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              const Text(
                'Food Items Detected:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // Display the food items from the database
              FutureBuilder<List<String>>(
                future: _fetchFoodItems(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  } else if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No food items found.'));
                  } else {
                    final foodItems = snapshot.data!;
                    return Column(
                      children: foodItems
                          .map((food) => Text(
                                food,
                                style: TextStyle(fontSize: 18),
                              ))
                          .toList(),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
