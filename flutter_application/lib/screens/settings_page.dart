import 'package:flutter/material.dart';
import 'package:flutter_application/services/family_package_service.dart';

// Enum for text sizes
enum TextSize { small, medium, large }

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  // State variables
  bool isDarkMode = false;
  String selectedLanguage = 'English';
  TextSize selectedTextSize = TextSize.medium;
  bool expiringItemsNotification = true;
  bool recipeNotification = true;
  bool lowStockNotification = false;
  String syncMode = 'Manual';

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
      body: ListView(
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
                subtitle: const Text(
                  'Sude Sarı',
                  style: TextStyle(color: Colors.black),
                ),
                trailing: TextButton(
                  onPressed: () {
                    // Implement name edit functionality
                  },
                  child: const Text(
                    'Edit',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ),
              const ListTile(
                title: Text(
                  'Email',
                  style: TextStyle(color: Colors.black),
                ),
                subtitle: Text(
                  'sude.sari@tedu.edu.tr',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              ListTile(
                title: const Text(
                  'Change Password',
                  style: TextStyle(color: Colors.black),
                ),
                onTap: () {
                  // Implement password change functionality
                },
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
                  // Implement dietary preferences screen
                },
              ),
              ListTile(
                title: const Text(
                  'Allergens',
                  style: TextStyle(color: Colors.black),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Implement allergens screen
                },
              ),
              ListTile(
                title: const Text(
                  'Favorite Ingredients',
                  style: TextStyle(color: Colors.black),
                ),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Implement favorite ingredients screen
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
                onChanged: (bool value) {
                  setState(() {
                    expiringItemsNotification = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Recipe Suggestions',
                  style: TextStyle(color: Colors.black),
                ),
                value: recipeNotification,
                onChanged: (bool value) {
                  setState(() {
                    recipeNotification = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text(
                  'Low-stock Items',
                  style: TextStyle(color: Colors.black),
                ),
                value: lowStockNotification,
                onChanged: (bool value) {
                  setState(() {
                    lowStockNotification = value;
                  });
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
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        selectedLanguage = value;
                      });
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
                  onChanged: (String? value) {
                    if (value != null) {
                      setState(() {
                        syncMode = value;
                      });
                    }
                  },
                ),
              ),
              ListTile(
                title: const Text(
                  'Export Data',
                  style: TextStyle(color: Colors.black),
                ),
                onTap: () {
                  // Implement export functionality
                },
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
                onChanged: (bool value) {
                  setState(() {
                    isDarkMode = value;
                  });
                },
              ),
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
                  onSelectionChanged: (Set<TextSize> selection) {
                    setState(() {
                      selectedTextSize = selection.first;
                    });
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
                  // Buraya ileride yeni bir sayfa açacağız
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
                  // Implement privacy policy screen
                },
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
              ListTile(
                title: const Text(
                  'Contact Support',
                  style: TextStyle(color: Colors.black),
                ),
                onTap: () {
                  // Implement contact support functionality
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
              onPressed: () {
                // Implement clear data functionality
                Navigator.pop(context);
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
              onPressed: () {
                // Implement logout functionality
                Navigator.pop(context);
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
              onPressed: () {
                // Implement account deletion functionality
                Navigator.pop(context);
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
