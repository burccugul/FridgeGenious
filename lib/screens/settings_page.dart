import 'package:flutter/material.dart';

// Enum for text sizes
enum TextSize { small, medium, large }

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          // Profile Settings Section
          _buildSection(
            'Profile Settings',
            [
              ListTile(
                title: const Text('Name'),
                subtitle: const Text('Sude Sarı'),
                trailing: TextButton(
                  onPressed: () {
                    // Implement name edit functionality
                  },
                  child: const Text('Edit'),
                ),
              ),
              const ListTile(
                title: Text('Email'),
                subtitle: Text('sude.sari@tedu.edu.tr'),
              ),
              ListTile(
                title: const Text('Change Password'),
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
                title: const Text('Dietary Preferences'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Implement dietary preferences screen
                },
              ),
              ListTile(
                title: const Text('Allergens'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // Implement allergens screen
                },
              ),
              ListTile(
                title: const Text('Favorite Ingredients'),
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
                title: const Text('Expiring Items'),
                value: expiringItemsNotification,
                onChanged: (bool value) {
                  setState(() {
                    expiringItemsNotification = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Recipe Suggestions'),
                value: recipeNotification,
                onChanged: (bool value) {
                  setState(() {
                    recipeNotification = value;
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Low-stock Items'),
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
                title: const Text('Language'),
                trailing: DropdownButton<String>(
                  value: selectedLanguage,
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'Turkish', child: Text('Turkish')),
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
                title: const Text('Sync with Cloud'),
                trailing: DropdownButton<String>(
                  value: syncMode,
                  items: const [
                    DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                    DropdownMenuItem(value: 'Auto', child: Text('Auto')),
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
                title: const Text('Export Data'),
                onTap: () {
                  // Implement export functionality
                },
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
              ListTile(
                title: const Text('Clear Local Data'),
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
                title: const Text('Dark Mode'),
                value: isDarkMode,
                onChanged: (bool value) {
                  setState(() {
                    isDarkMode = value;
                  });
                },
              ),
              ListTile(
                title: const Text('Text Size'),
                trailing: SegmentedButton<TextSize>(
                  segments: const [
                    ButtonSegment(value: TextSize.small, label: Text('S')),
                    ButtonSegment(value: TextSize.medium, label: Text('M')),
                    ButtonSegment(value: TextSize.large, label: Text('L')),
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
                title: const Text('Logout'),
                onTap: () {
                  _showLogoutDialog();
                },
                trailing: const Icon(Icons.logout),
              ),
              ListTile(
                title: const Text('Delete My Account'),
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
                title: Text('Version'),
                trailing: Text('1.0.0'),
              ),
              ListTile(
                title: const Text('Privacy Policy'),
                onTap: () {
                  // Implement privacy policy screen
                },
                trailing: const Icon(Icons.arrow_forward_ios),
              ),
              ListTile(
                title: const Text('Contact Support'),
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
          title: const Text('Clear Local Data'),
          content: const Text('Are you sure you want to clear all local data? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement clear data functionality
                Navigator.pop(context);
              },
              child: const Text('Clear'),
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
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement logout functionality
                Navigator.pop(context);
              },
              child: const Text('Logout'),
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
          title: const Text('Delete Account'),
          content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Implement account deletion functionality
                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
