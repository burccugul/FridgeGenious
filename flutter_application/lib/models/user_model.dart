// lib/models/user_model.dart
class UserModel {
  final String id;
  final String? email;
  final String name;
  final bool isPremium;
  final List<String>? dietaryPreferences;
  final List<String>? allergens;
  final List<String>? favoriteIngredients;
  final String? familyId;
  final bool isFamilyMember;

  UserModel({
    required this.id,
    this.email,
    required this.name,
    this.isPremium = false,
    this.dietaryPreferences,
    this.allergens,
    this.favoriteIngredients,
    this.familyId,
    this.isFamilyMember = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      name: json['name'] ?? '',
      isPremium: json['isPremium'] ?? false,
      dietaryPreferences: json['dietaryPreferences'] != null 
          ? List<String>.from(json['dietaryPreferences']) 
          : null,
      allergens: json['allergens'] != null 
          ? List<String>.from(json['allergens']) 
          : null,
      favoriteIngredients: json['favoriteIngredients'] != null 
          ? List<String>.from(json['favoriteIngredients']) 
          : null,
      familyId: json['family_id'],
      isFamilyMember: json['is_family_member'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'isPremium': isPremium,
      'dietaryPreferences': dietaryPreferences,
      'allergens': allergens,
      'favoriteIngredients': favoriteIngredients,
      'family_id': familyId,
      'is_family_member': isFamilyMember,
    };
  }
}