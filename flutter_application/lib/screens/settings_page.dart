import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application/services/family_package_service.dart';
import 'package:flutter_application/services/auth_service.dart';
import 'package:flutter_application/services/user_service.dart';
import 'package:flutter_application/services/notification_service.dart';
import 'package:flutter_application/services/data_export_service.dart';
import 'package:flutter_application/services/theme_service.dart';
import 'package:flutter_application/models/user_model.dart';
import 'package:provider/provider.dart'; // Bu satırı ekle
import 'package:flutter_application/main.dart'; 
import 'package:flutter_application/database/supabase_helper.dart';
import 'package:flutter_application/providers/theme_notifier.dart';
import 'package:http/http.dart' as http; // ← http POST için
import 'dart:convert'; // ← jsonEncode için
import 'package:flutter_application/main.dart' show ThemeNotifier, TextSizeNotifier;
// ThemeNotifier ve TextSizeNotifier burada tanımlı
// Adjust this import path based on your project structure
//import 'package:flutter_application/pages/family_package_page.dart'; // Import for FamilyPackagePage
import 'package:flutter_application/services/family_package_service.dart';
// Enum for text sizes
enum TextSize { small, medium, large }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  // Services
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();
  final DataExportService _dataExportService = DataExportService();
  final ThemeService _themeService = ThemeService();

  // State variables
  bool isDarkMode = false;
  String selectedLanguage = 'English';
  TextSize selectedTextSize = TextSize.medium;
  bool expiringItemsNotification = true;
  bool recipeNotification = true;
  bool lowStockNotification = false;
  String syncMode = 'Manual';

  // User data
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSettings();
  }

  // Load user data from backend
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _userService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load user data: ${e.toString()}');
    }
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        isDarkMode = prefs.getBool('isDarkMode') ?? false;
        selectedLanguage = prefs.getString('language') ?? 'English';
        selectedTextSize = TextSize.values[prefs.getInt('textSize') ?? 1];
        expiringItemsNotification = prefs.getBool('expiringItemsNotification') ?? true;
        recipeNotification = prefs.getBool('recipeNotification') ?? true;
        lowStockNotification = prefs.getBool('lowStockNotification') ?? false;
        syncMode = prefs.getString('syncMode') ?? 'Manual';
      });

      // Apply theme (şimdilik sadece state'i güncelliyoruz, tema ana widget'ta uygulanacak)
      Provider.of<ThemeNotifier>(context, listen: false).setThemeMode(isDarkMode);

      // Apply text size (şimdilik sadece state'i güncelliyoruz)
      final textSizeString = selectedTextSize.name;
      Provider.of<TextSizeNotifier>(context, listen: false).setTextSize(textSizeString);

      // Apply notification settings
      await _updateNotificationSettings();

    } catch (e) {
      _showErrorSnackBar('Failed to load settings: ${e.toString()}');
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('isDarkMode', isDarkMode);
      await prefs.setString('language', selectedLanguage);
      await prefs.setInt('textSize', selectedTextSize.index);
      await prefs.setBool('expiringItemsNotification', expiringItemsNotification);
      await prefs.setBool('recipeNotification', recipeNotification);
      await prefs.setBool('lowStockNotification', lowStockNotification);
      await prefs.setString('syncMode', syncMode);

      _showSuccessSnackBar('Settings saved successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to save settings: ${e.toString()}');
    }
  }

  // Update notification settings
  Future<void> _updateNotificationSettings() async {
    try {
      await _notificationService.setExpiringItemsNotification(expiringItemsNotification);
      await _notificationService.setRecipeNotification(recipeNotification);
      await _notificationService.setLowStockNotification(lowStockNotification);
    } catch (e) {
      _showErrorSnackBar('Failed to update notification settings: ${e.toString()}');
    }
  }

  // Update user profile
  Future<void> _updateUserName(String newName) async {
    try {
      await _userService.updateUserName(newName);
      await _loadUserData();
      _showSuccessSnackBar('Name updated successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to update name: ${e.toString()}');
    }
  }

  // Change user password
  Future<void> _changePassword(String newPassword) async { // Sadece yeni şifreyi alıyor
    try {
      await _authService.changePassword(newPassword); // Sadece yeni şifreyi gönderiyor
      _showSuccessSnackBar('Password changed successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to change password: ${e.toString()}');
    }
  }

  // Export user data
  Future<void> _exportData() async {
    try {
      final exportPath = await _dataExportService.exportUserData();
      _showSuccessSnackBar('Data exported successfully to: $exportPath');
    } catch (e) {
      _showErrorSnackBar('Failed to export data: ${e.toString()}');
    }
  }

  // Clear local data
  Future<void> _clearLocalData() async {
    try {
      await _dataExportService.clearLocalData();
      _showSuccessSnackBar('Local data cleared successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to clear data: ${e.toString()}');
    }
  }

  // Logout user
  Future<void> _logout() async {
    try {
      await _authService.logout();
      // Navigate to login page
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      _showErrorSnackBar('Failed to logout: ${e.toString()}');
    }
  }

 Future<void> _deleteAccount() async {
  try {
    final supabase = SupabaseHelper();
    await supabase.initialize();

    final userId = await supabase.getCurrentUserId();
    if (userId == null) throw Exception("User ID not found");

    // 1. Uygulamadan çıkış yap
    await supabase.client.auth.signOut();

    // 2. Kullanıcıya ait diğer tabloları temizle
    await supabase.client.from('inventory').delete().eq('uuid_userid', userId);
    await supabase.client.from('shoppinglist').delete().eq('uuid_userid', userId);
    await supabase.client.from('recipes').delete().eq('uuid_userid', userId);
    await supabase.client.from('family_packages').delete().eq('owner_user_id', userId);

    // 3. Flask API ile auth.users'dan sil
    final response = await http.post(
      Uri.parse('http://127.0.0.1:5000/delete_user'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"user_id": userId}),
    );

    if (response.statusCode == 200) {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } else {
      throw Exception("Backend delete failed: ${response.body}");
    }

  } catch (e) {
    _showErrorSnackBar('Failed to delete account: ${e.toString()}');
  }
}
  // Show name edit dialog
  void _showNameEditDialog() {
    final TextEditingController nameController = TextEditingController(text: _currentUser?.name ?? '');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Edit Name',
            style: TextStyle(color: Colors.black),
          ),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter your new name',
            ),
            style: const TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (nameController.text.isNotEmpty) {
                  _updateUserName(nameController.text);
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show password change dialog
  void _showPasswordChangeDialog() {
    final TextEditingController currentPasswordController = TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Change Password',
            style: TextStyle(color: Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                decoration: const InputDecoration(
                  hintText: 'Current Password',
                ),
                obscureText: true,
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newPasswordController,
                decoration: const InputDecoration(
                  hintText: 'New Password',
                ),
                obscureText: true,
                style: const TextStyle(color: Colors.black),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmPasswordController,
                decoration: const InputDecoration(
                  hintText: 'Confirm New Password',
                ),
                obscureText: true,
                style: const TextStyle(color: Colors.black),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (newPasswordController.text.isEmpty) {
                  _showErrorSnackBar('Password cannot be empty');
                  return;
                }
                if (newPasswordController.text != confirmPasswordController.text) {
                  _showErrorSnackBar('Passwords do not match');
                  return;
                }
                _changePassword( // Mevcut şifre argümanı kaldırıldı
                  newPasswordController.text,
                );
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show success SnackBar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Show error SnackBar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }



@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, // White background
        iconTheme: const IconThemeData(color: Colors.black), // Black icons
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.black), // Black text
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Profile Settings Section
                _buildSection(
                  'Profile Settings',
                  [
                    ListTile(
                      title: const Text(
                        'Name',
                        style: TextStyle(color: Colors.black),
                      ),
                      subtitle: Text(
                        _currentUser?.name ?? 'Sude Sarı',
                        style: const TextStyle(color: Colors.black),
                      ),
                      trailing: TextButton(
                        onPressed: _showNameEditDialog,
                        child: const Text(
                          'Edit',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text(
                        'Email',
                        style: TextStyle(color: Colors.black),
                      ),
                      subtitle: Text(
                        _currentUser?.email ?? 'sude.sari@tedu.edu.tr',
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    ListTile(
                      title: const Text(
                        'Change Password',
                        style: TextStyle(color: Colors.black),
                      ),
                      onTap: _showPasswordChangeDialog,
                      trailing: const Icon(Icons.arrow_forward_ios),
                    ),
                  ],
                ),

                // Preferences Section
                _buildSection(
                  'Preferences',
                  [
                    ListTile(
                      title: const Text(
                        'Dietary Preferences',
                        style: TextStyle(color: Colors.black),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(context, '/dietary-preferences');
                      },
                    ),
                    ListTile(
                      title: const Text(
                        'Allergens',
                        style: TextStyle(color: Colors.black),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(context, '/allergens');
                      },
                    ),
                    ListTile(
                      title: const Text(
                        'Favorite Ingredients',
                        style: TextStyle(color: Colors.black),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pushNamed(context, '/favorite-ingredients');
                      },
                    ),
                  ],
                ),

                // Notifications Section
                _buildSection(
                  'Notifications',
                  [
                    SwitchListTile(
                      title: const Text(
                        'Expiring Items',
                        style: TextStyle(color: Colors.black),
                      ),
                      value: expiringItemsNotification,
                      onChanged: (bool value) async {
                        setState(() {
                          expiringItemsNotification = value;
                        });
                        await _updateNotificationSettings();
                        await _saveSettings();
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Recipe Suggestions',
                        style: TextStyle(color: Colors.black),
                      ),
                      value: recipeNotification,
                      onChanged: (bool value) async {
                        setState(() {
                          recipeNotification = value;
                        });
                        await _updateNotificationSettings();
                        await _saveSettings();
                      },
                    ),
                    SwitchListTile(
                      title: const Text(
                        'Low-stock Items',
                        style: TextStyle(color: Colors.black),
                      ),
                      value: lowStockNotification,
                      onChanged: (bool value) async {
                        setState(() {
                          lowStockNotification = value;
                        });
                        await _updateNotificationSettings();
                        await _saveSettings();
                      },
                    ),
                  ],
                ),

                // Language Settings
                _buildSection(
                  'Language',
                  [
                    ListTile(
                      title: const Text(
                        'Language',
                        style: TextStyle(color: Colors.black),
                      ),
                      trailing: DropdownButton<String>(
                        value: selectedLanguage,
                        items: const [
                          DropdownMenuItem(
                            value: 'English',
                            child: Text(
                              'English',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Turkish',
                            child: Text(
                              'Turkish',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                        onChanged: (String? value) async {
                          if (value != null) {
                            setState(() {
                              selectedLanguage = value;
                            });
                            await _saveSettings();
                          }
                        },
                      ),
                    ),
                  ],
                ),

                // Data Management Section
                _buildSection(
                  'Data Management',
                  [
                    ListTile(
                      title: const Text(
                        'Sync with Cloud',
                        style: TextStyle(color: Colors.black),
                      ),
                      trailing: DropdownButton<String>(
                        value: syncMode,
                        items: const [
                          DropdownMenuItem(
                            value: 'Manual',
                            child: Text(
                              'Manual',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'Auto',
                            child: Text(
                              'Auto',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                        onChanged: (String? value) async {
                          if (value != null) {
                              setState(() {
                                syncMode = value;
                              });
                              await _saveSettings();
                            }
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text(
                          'Export Data',
                          style: TextStyle(color: Colors.black),
                        ),
                        onTap: _exportData,
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                      ListTile(
                        title: const Text(
                          'Clear Local Data',
                          style: TextStyle(color: Colors.black),
                        ),
                        onTap: () {
                          _showClearDataDialog();
                        },
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                    ],
                  ),

                  // Theme & Display Section
                  _buildSection(
                    'Theme & Display',
                    [
                      SwitchListTile(
                        title: const Text(
                          'Dark Mode',
                          style: TextStyle(color: Colors.black),
                        ),
                        value: isDarkMode,
                        onChanged: (bool value) async {
                          setState(() {
                            isDarkMode = value;
                          });
                          // Tema değişikliğini ThemeNotifier'a bildiriyoruz
                          Provider.of<ThemeNotifier>(context, listen: false).setThemeMode(value);
                          await _saveSettings();
                        },
                      ),
                      // If SegmentedButton causes errors, uncomment this alternative implementation
                      // and comment out the ListTile below that uses SegmentedButton
                      /*
                      ListTile(
                        title: const Text(
                          'Text Size',
                          style: TextStyle(color: Colors.black),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  selectedTextSize = TextSize.small;
                                });
                                _saveSettings();
                              },
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(
                                  selectedTextSize == TextSize.small
                                      ? Colors.grey.shade300
                                      : Colors.transparent
                                ),
                              ),
                              child: const Text('S'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  selectedTextSize = TextSize.medium;
                                });
                                _saveSettings();
                              },
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(
                                  selectedTextSize == TextSize.medium
                                      ? Colors.grey.shade300
                                      : Colors.transparent
                                ),
                              ),
                              child: const Text('M'),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  selectedTextSize = TextSize.large;
                                });
                                _saveSettings();
                              },
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all(
                                  selectedTextSize == TextSize.large
                                      ? Colors.grey.shade300
                                      : Colors.transparent
                                ),
                              ),
                              child: const Text('L'),
                            ),
                          ],
                        ),
                      ),
                      */
                      // Use this if you have Flutter 3.0+ with SegmentedButton support
                      ListTile(
                        title: const Text(
                          'Text Size',
                          style: TextStyle(color: Colors.black),
                        ),
                        trailing: SegmentedButton<TextSize>(
                          segments: const [
                            ButtonSegment(
                              value: TextSize.small,
                              label: Text(
                                'S',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            ButtonSegment(
                              value: TextSize.medium,
                              label: Text(
                                'M',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                            ButtonSegment(
                              value: TextSize.large,
                              label: Text(
                                'L',
                                style: TextStyle(color: Colors.black),
                              ),
                            ),
                          ],
                          selected: {selectedTextSize},
                          onSelectionChanged: (Set<TextSize> selection) async {
                            setState(() {
                              selectedTextSize = selection.first;
                            });
                            final textSizeString = selectedTextSize.name;
                            // Metin boyutu değişikliğini TextSizeNotifier'a bildiriyoruz
                            Provider.of<TextSizeNotifier>(context, listen: false).setTextSize(textSizeString);
                            await _saveSettings();
                          },
                        ),
                      ),
                    ],
                  ),

                  // Account Management Section
                  _buildSection(
                    'Account Management',
                    [
                      ListTile(
                        title: const Text(
                          'Create Family Package',
                          style: TextStyle(color: Colors.black),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const FamilyPackagePage(),
                            ),
                          );
                        },
                        trailing: const Icon(Icons.group_add),
                      ),
                      ListTile(
                        title: const Text(
                          'Logout',
                          style: TextStyle(color: Colors.black),
                        ),
                        onTap: () {
                          _showLogoutDialog();
                        },
                        trailing: const Icon(Icons.logout),
                      ),
                      ListTile(
                        title: const Text(
                          'Delete My Account',
                          style: TextStyle(color: Colors.black),
                        ),
                        onTap: () {
                          _showDeleteAccountDialog();
                        },
                        trailing: const Icon(Icons.delete_forever),
                      ),
                    ],
                  ),

                  // About & Support Section
                  _buildSection(
                    'About & Support',
                    [
                      const ListTile(
                        title: Text(
                          'Version',
                          style: TextStyle(color: Colors.black),
                        ),
                        trailing: Text(
                          '1.0.0',
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                      ListTile(
                        title: const Text(
                          'Privacy Policy',
                          style: TextStyle(color: Colors.black),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, '/privacy-policy');
                        },
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                      ListTile(
                        title: const Text(
                          'Contact Support',
                          style: TextStyle(color: Colors.black),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, '/contact-support');
                        },
                        trailing: const Icon(Icons.arrow_forward_ios),
                      ),
                    ],
                  ),
                ],
              ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  // Dialog methods
  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Clear Local Data',
            style: TextStyle(color: Colors.black),
          ),
          content: const Text(
            'Are you sure you want to clear all local data? This action cannot be undone.',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _clearLocalData();
              },
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.black),
          ),
          content: const Text(
            'Are you sure you want to logout?',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _logout();
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Delete Account',
            style: TextStyle(color: Colors.black),
          ),
          content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.black),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _deleteAccount();
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FamilyPackagePage extends StatelessWidget {
  const FamilyPackagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Family Package'),
      ),
      body: const Center(
        child: Text('Family Package Creation Page Content'),
      ),
    );
  }
}