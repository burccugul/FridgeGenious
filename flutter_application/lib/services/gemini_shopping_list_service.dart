import 'package:google_generative_ai/google_generative_ai.dart';
import '/database/supabase_helper.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class GeminiShoppingListService {
  final String apiKey = "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM";
  late GenerativeModel model;

  GeminiShoppingListService() {
    model = GenerativeModel(
      model: "gemini-2.0-flash",
      apiKey: apiKey,
    );
  }

  // Kullanıcının veritabanından alışveriş geçmişini al
  Future<List<Map<String, dynamic>>> getShoppingHistory() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception("No user logged in.");
    }

    String userUUID = user.id; // Burada UUID alınıyor

    // Kullanıcıya özel verileri çekmek için sorguyu güncelle
    final inventory = await SupabaseHelper().getInventoryByUserId(userUUID);
    final shoppingList =
        await SupabaseHelper().getShoppingListByUserId(userUUID);

    List<Map<String, dynamic>> history = [];

    for (var item in inventory) {
      String foodName = item['food_name'];

      // Son yükleme tarihini çözümle
      DateTime? lastUpload = DateTime.tryParse(item['last_image_upload'] ?? '');
      if (lastUpload == null) {
        continue; // Eğer son yükleme tarihi geçersizse bu öğeyi atla
      }

      // İlgili alışveriş listesi öğesini bul ve remove_date'i al
      var removedItem = shoppingList.firstWhere(
        (s) => s['food_name'] == foodName,
        orElse: () => {},
      );

      // Remove tarihi çözümle
      DateTime? removeDate =
          DateTime.tryParse(removedItem['remove_date'] ?? '');
      if (removeDate == null) {
        continue; // Eğer remove tarihi geçersizse bu öğeyi atla
      }

      // Tüketim oranını hesapla
      history.add({
        'food_name': foodName,
        'last_upload': lastUpload,
        'remove_date': removeDate,
        'days_to_consume': removeDate.difference(lastUpload).inDays,
      });
    }

    return history;
  }

  // Kullanıcı bazlı alışveriş listesi oluştur
  Future<Map<String, List<String>>> generateShoppingList() async {
    final history = await getShoppingHistory();
    if (history.isEmpty) {
      return {
        "daily": ["No consumption data available."],
        "weekly": ["No consumption data available."],
        "monthly": ["No consumption data available."]
      };
    }

    String prompt = '''
Based on the following food consumption patterns, suggest a shopping list organized into three categories: daily, weekly, and monthly needs.
The following explains the data:
- The "last image upload date" indicates when an image of the food was last uploaded (this marks the beginning of the consumption cycle).
- The "remove date" indicates when the food was removed from the shopping list (this marks the end of the consumption cycle).
- The "days_to_consume" shows how many days it took to consume the item.

Please format your response as a JSON object with three keys: "daily", "weekly", and "monthly", each containing an array of food items.
For example:
{
  "daily": ["Milk", "Bread", "Eggs"],
  "weekly": ["Chicken", "Rice", "Vegetables"],
  "monthly": ["Flour", "Sugar", "Spices"]
}

Categorize items as follows:
- Daily: Items consumed within 1-2 days
- Weekly: Items consumed within 3-7 days
- Monthly: Items consumed within 8-30 days

Only include the food names in the lists, no additional text.
''';

    // Add each food item to the prompt
    for (var item in history) {
      prompt +=
          "${item['food_name']}: Consumed in ${item['days_to_consume']} days.\n";
    }

    try {
      final responses = model.generateContentStream([
        Content.multi([TextPart(prompt)])
      ]);

      String aiResponse = '';
      await for (final response in responses) {
        aiResponse += response.text ?? '';
      }

      if (aiResponse.isEmpty) {
        return {
          "daily": ["No shopping list generated. Try again."],
          "weekly": ["No shopping list generated. Try again."],
          "monthly": ["No shopping list generated. Try again."]
        };
      }

      // Try to parse the JSON response
      try {
        final jsonRegExp = RegExp(r'{[\s\S]*}');
        final match = jsonRegExp.firstMatch(aiResponse);
        final jsonStr = match != null ? match.group(0) : aiResponse;

        Map<String, dynamic> parsedJson = json.decode(jsonStr!);

        Map<String, List<String>> result = {
          "daily": List<String>.from(parsedJson["daily"] ?? []),
          "weekly": List<String>.from(parsedJson["weekly"] ?? []),
          "monthly": List<String>.from(parsedJson["monthly"] ?? [])
        };

        return result;
      } catch (e) {
        print("Error parsing JSON response: $e");

        // Fallback: try to parse the response manually
        Map<String, List<String>> manualParsed = {
          "daily": [],
          "weekly": [],
          "monthly": []
        };

        bool inDaily = false, inWeekly = false, inMonthly = false;

        for (String line in aiResponse.split('\n')) {
          line = line.trim();
          if (line.isEmpty) continue;

          if (line.toLowerCase().contains("daily")) {
            inDaily = true;
            inWeekly = false;
            inMonthly = false;
            continue;
          } else if (line.toLowerCase().contains("weekly")) {
            inDaily = false;
            inWeekly = true;
            inMonthly = false;
            continue;
          } else if (line.toLowerCase().contains("monthly")) {
            inDaily = false;
            inWeekly = false;
            inMonthly = true;
            continue;
          }

          // Remove bullet points and other formatting
          line = line.replaceAll(RegExp(r'^\s*[-•*]\s*'), '');

          if (inDaily) {
            manualParsed["daily"]!.add(line);
          } else if (inWeekly) {
            manualParsed["weekly"]!.add(line);
          } else if (inMonthly) {
            manualParsed["monthly"]!.add(line);
          }
        }

        // If we couldn't parse anything, provide a default message
        if (manualParsed["daily"]!.isEmpty &&
            manualParsed["weekly"]!.isEmpty &&
            manualParsed["monthly"]!.isEmpty) {
          return {
            "daily": ["Could not parse AI response. Please try again."],
            "weekly": ["Could not parse AI response. Please try again."],
            "monthly": ["Could not parse AI response. Please try again."]
          };
        }

        return manualParsed;
      }
    } catch (e) {
      print("Error generating shopping list: $e");
      return {
        "daily": ["Error generating shopping list: $e"],
        "weekly": ["Error generating shopping list: $e"],
        "monthly": ["Error generating shopping list: $e"]
      };
    }
  }
}
