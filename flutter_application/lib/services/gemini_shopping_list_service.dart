import 'package:google_generative_ai/google_generative_ai.dart';
import '/database/supabase_helper.dart';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('GeminiShoppingListService');

class GeminiShoppingListService {
  final String apiKey = "AIzaSyBfJAn7qJ_gKyLR4xBvTguQzY7nb_GtLjM";
  late GenerativeModel model;
  final SupabaseHelper _supabaseHelper = SupabaseHelper();

  GeminiShoppingListService() {
    model = GenerativeModel(
      model: "gemini-2.0-flash",
      apiKey: apiKey,
    );
    _supabaseHelper.initialize().catchError((error) {
      _logger.severe('Failed to initialize Supabase: $error');
    });
  }

  /// Get the actual user ID to use (considering family package)
  Future<String?> _getEffectiveUserID() async {
    try {
      // Get current user's ID
      final currentUserID = Supabase.instance.client.auth.currentUser?.id;
      if (currentUserID == null) {
        _logger.warning('No current user found');
        return null;
      }

      // Check if user is part of a family package
      final userIDArray = '[\"$currentUserID\"]';
      final familyPackagesResponse = await _supabaseHelper.client
          .from('family_packages')
          .select()
          .or('owner_user_id.eq.$currentUserID,member_user_ids.cs.$userIDArray');

      if (familyPackagesResponse != null && familyPackagesResponse.isNotEmpty) {
        // User is part of a family package, return the owner's ID
        final familyPackage = familyPackagesResponse[0];
        _logger.info(
            'User is part of family package: ${familyPackage['family_name']}');
        return familyPackage['owner_user_id'];
      }

      // User is not part of a family package, return their own ID
      return currentUserID;
    } catch (e) {
      _logger.warning('Error getting effective user ID: $e');
      // Fallback to current user
      return Supabase.instance.client.auth.currentUser?.id;
    }
  }

  // Get the user's shopping history
  Future<List<Map<String, dynamic>>> getShoppingHistory() async {
    final effectiveUserID = await _getEffectiveUserID();
    if (effectiveUserID == null) {
      throw Exception("No user logged in.");
    }

    // Get data specific to the effective user ID
    final inventory =
        await _supabaseHelper.getInventoryByUserId(effectiveUserID);
    final shoppingList =
        await _supabaseHelper.getShoppingListByUserId(effectiveUserID);

    List<Map<String, dynamic>> history = [];

    for (var item in inventory) {
      String foodName = item['food_name'];

      // Parse last upload date
      DateTime? lastUpload = DateTime.tryParse(item['last_image_upload'] ?? '');
      if (lastUpload == null) {
        continue; // Skip if last upload date is invalid
      }

      // Find the related shopping list item and get remove_date
      var removedItem = shoppingList.firstWhere(
        (s) => s['food_name'] == foodName,
        orElse: () => {},
      );

      // Parse remove date
      DateTime? removeDate =
          DateTime.tryParse(removedItem['remove_date'] ?? '');
      if (removeDate == null) {
        continue; // Skip if remove date is invalid
      }

      // Calculate consumption rate
      history.add({
        'food_name': foodName,
        'last_upload': lastUpload,
        'remove_date': removeDate,
        'days_to_consume': removeDate.difference(lastUpload).inDays,
      });
    }

    return history;
  }

  // Generate user-specific shopping list
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
        _logger.severe("Error parsing JSON response: $e");

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
      _logger.severe("Error generating shopping list: $e");
      return {
        "daily": ["Error generating shopping list: $e"],
        "weekly": ["Error generating shopping list: $e"],
        "monthly": ["Error generating shopping list: $e"]
      };
    }
  }
}
