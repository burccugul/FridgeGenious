// AIzaSyB7jOd6-7xvAFLq1SiYqz--BssCYADJr88 chrome search key
// gemini api key AIzaSyBr_epn1mMGQMPnnTj14W7IyHcsS606kuw
// search engine <script async src="https://cse.google.com/cse.js?cx=119e4e3bb894a4ca3">
// </script>
// <div class="gcse-search"></div>

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:developer';

class RecipeImageService {
  // Your credentials
  final String _apiKey = 'AIzaSyB7jOd6-7xvAFLq1SiYqz--BssCYADJr88';
  final String _searchEngineId = '119e4e3bb894a4ca3';

  // Simple in-memory cache
  static final Map<String, String> _imageCache = {};

  // Singleton pattern
  static final RecipeImageService _instance = RecipeImageService._internal();
  factory RecipeImageService() => _instance;
  RecipeImageService._internal();

  /// Get image URL for a recipe name
  Future<String?> getImageForRecipe(String recipeName) async {
    if (recipeName.isEmpty) return null;

    // Check cache first
    if (_imageCache.containsKey(recipeName)) {
      return _imageCache[recipeName];
    }

    try {
      // Construct the URL for Google Custom Search API
      final Uri url = Uri.parse('https://www.googleapis.com/customsearch/v1'
          '?key=$_apiKey'
          '&cx=$_searchEngineId'
          '&q=${Uri.encodeComponent(recipeName)}'
          '&searchType=image'
          '&imgSize=large'
          '&num=1');

      // Make the HTTP request
      final response = await http.get(url);

      // Check if the request was successful
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        if (data.containsKey('items') && data['items'].isNotEmpty) {
          final imageUrl = data['items'][0]['link'];
          // Save to cache
          _imageCache[recipeName] = imageUrl;
          return imageUrl;
        }
      }
      return null;
    } catch (e) {
      log('Error getting image for $recipeName: $e');
      return null;
    }
  }
}
