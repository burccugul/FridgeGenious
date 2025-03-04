import 'package:flutter/material.dart';
import '/services/database_service.dart';

class GeminiResponsePage extends StatefulWidget {
  final String response;

  const GeminiResponsePage({super.key, required this.response});

  @override
  _GeminiResponsePageState createState() => _GeminiResponsePageState();
}

class _GeminiResponsePageState extends State<GeminiResponsePage> {
  final DatabaseService _dbService = DatabaseService();
  List<String> _foods = [];

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  // 📌 Verileri SQLite'dan yükle
  void _loadFoods() async {
    List<String> foods = await _dbService.getFoods();
    setState(() {
      _foods = foods;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analysis Result")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "LLM Response:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              widget.response,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),
            Text(
              "Saved Foods:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: _foods.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: Icon(Icons.food_bank),
                    title: Text(_foods[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
