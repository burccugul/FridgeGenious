import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class FamilyPackagePage extends StatefulWidget {
  const FamilyPackagePage({super.key});

  @override
  _FamilyPackagePageState createState() => _FamilyPackagePageState();
}

class _FamilyPackagePageState extends State<FamilyPackagePage> {
  final _emailController = TextEditingController();
  final _familyNameController = TextEditingController();
  List<String> emailList = [];

  List<Map<String, dynamic>> _userFamilyPackages = [];
  bool _isLoadingFamilies = true;

  User? get _currentUser => supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _familyNameController.addListener(() {
      setState(() {});
    });
    _fetchUserFamilyPackages();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _familyNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserFamilyPackages() async {
    if (_currentUser == null) {
      return;
    }

    try {
      final currentUserProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('email', _currentUser!.email)
          .single();

      if (currentUserProfile == null) return;

      String currentUserId = currentUserProfile['id'];

      final response = await supabase
          .from('family_packages')
          .select('id, family_name, member_user_ids, owner_user_id')
          .or('owner_user_id.eq.$currentUserId,member_user_ids.cs.[\"$currentUserId\"]');

      final families = List<Map<String, dynamic>>.from(response);

      // --- Yeni: UUID'den Email çözümü ---
      for (var family in families) {
        // OWNER EMAIL
        final ownerProfile = await supabase
            .from('profiles')
            .select('email')
            .eq('id', family['owner_user_id'])
            .single();

        String ownerEmail =
            ownerProfile != null ? ownerProfile['email'] ?? '' : '';

        // MEMBERS EMAIL
        List<dynamic> memberUUIDs = family['member_user_ids'] ?? [];
        List<String> memberEmails = [];

        if (memberUUIDs.isNotEmpty) {
          final memberProfiles = await supabase
              .from('profiles')
              .select('id, email')
              .in_('id', memberUUIDs);

          for (var profile in memberProfiles) {
            if (profile['email'] != null) {
              memberEmails.add(profile['email']);
            }
          }
        }

        family['owner_email'] = ownerEmail;
        family['member_emails'] = memberEmails;
      }

      setState(() {
        _userFamilyPackages = families;
        _isLoadingFamilies = false;
      });
    } catch (e) {
      print("Error fetching family packages: $e");
      setState(() {
        _isLoadingFamilies = false;
      });
    }
  }

  Future<List<String>> getUserUUIDs(List<String> emailAddresses) async {
    final List<String> uuids = [];

    for (String email in emailAddresses) {
      try {
        final response = await supabase
            .from('profiles')
            .select('id')
            .eq('email', email)
            .single();

        if (response != null) {
          uuids.add(response['id']);
        }
      } catch (e) {
        print("Error querying for $email: $e");
      }
    }
    return uuids;
  }

  Future<void> createFamilyPackage(List<String> emailAddresses) async {
    if (_currentUser == null) {
      _showErrorSnackbar("No authenticated user found");
      return;
    }

    final currentUserProfile = await supabase
        .from('profiles')
        .select('id')
        .eq('email', _currentUser!.email)
        .single();

    if (currentUserProfile == null) {
      _showErrorSnackbar("Current user profile not found");
      return;
    }

    String ownerUserId = currentUserProfile['id'];

    List<String> memberUuids = await getUserUUIDs(emailAddresses);

    if (memberUuids.isNotEmpty) {
      try {
        await supabase.from('family_packages').insert({
          'family_name': _familyNameController.text.trim(),
          'owner_user_id': ownerUserId,
          'member_user_ids': memberUuids,
          'created_at': DateTime.now().toUtc().toString(),
        }).select();

        _showSuccessSnackbar("Family package created successfully!");

        setState(() {
          emailList.clear();
          _familyNameController.clear();
        });

        _fetchUserFamilyPackages(); // After creating, refresh
      } catch (e) {
        print("Error creating family package: $e");
        _showErrorSnackbar("Error creating family package: $e");
      }
    } else {
      _showErrorSnackbar("No valid family member UUIDs found.");
    }
  }

  void _createFamilyPackage() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    await createFamilyPackage(emailList);

    Navigator.of(context).pop();
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showEmailInputDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Email Address'),
          content: TextField(
            controller: _emailController,
            decoration: const InputDecoration(hintText: 'Email address'),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_emailController.text.isNotEmpty) {
                  setState(() {
                    emailList.add(_emailController.text.trim());
                    _emailController.clear();
                  });
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFamilyPackage(String familyId) async {
    try {
      await supabase.from('family_packages').delete().eq('id', familyId);
      _showSuccessSnackbar("Family package deleted successfully!");
      _fetchUserFamilyPackages(); // Refresh after deletion
    } catch (e) {
      print("Error deleting family package: $e");
      _showErrorSnackbar("Error deleting family package.");
    }
  }

  Future<void> _leaveFamilyPackage(String familyId) async {
    if (_currentUser == null) return;

    try {
      final currentUserProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('email', _currentUser!.email)
          .single();

      String currentUserId = currentUserProfile['id'];

      final familyPackage = _userFamilyPackages
          .firstWhere((package) => package['id'] == familyId, orElse: () => {});

      if (familyPackage != null) {
        List<dynamic> memberIds = familyPackage['member_user_ids'] ?? [];
        memberIds.remove(currentUserId);

        await supabase.from('family_packages').update({
          'member_user_ids': memberIds,
        }).eq('id', familyId);

        _showSuccessSnackbar("You left the family package.");
        _fetchUserFamilyPackages(); // Refresh after leaving
      }
    } catch (e) {
      print("Error leaving family package: $e");
      _showErrorSnackbar("Error leaving family package.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Package'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _familyNameController,
              decoration: const InputDecoration(
                labelText: 'Family Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _showEmailInputDialog,
                    child: const Text('Add Emails'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (emailList.isEmpty ||
                            _familyNameController.text.isEmpty)
                        ? null
                        : _createFamilyPackage,
                    child: const Text('Create Family Package'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            emailList.isEmpty
                ? const Center(
                    child: Text('No emails added yet. Add emails to continue.'),
                  )
                : Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            'Added Email Addresses:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: emailList.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(emailList[index]),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      emailList.removeAt(index);
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
            const SizedBox(height: 20),
            _isLoadingFamilies
                ? const Center(child: CircularProgressIndicator())
                : _userFamilyPackages.isEmpty
                    ? const Center(
                        child: Text("You are not part of any family package."),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: _userFamilyPackages.length,
                          itemBuilder: (context, index) {
                            final package = _userFamilyPackages[index];
                            final isOwner =
                                package['owner_user_id'] == _currentUser?.id;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                title: Text(
                                    package['family_name'] ?? 'Unnamed Family'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Owner: ${package['owner_email'] ?? ''}'),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Members: ${(package['member_emails'] as List<String>).join(", ")}',
                                    ),
                                  ],
                                ),
                                trailing: isOwner
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_forever),
                                        onPressed: () =>
                                            _deleteFamilyPackage(package['id']),
                                      )
                                    : (package['member_user_ids'] as List)
                                            .contains(_currentUser?.id)
                                        ? IconButton(
                                            icon: const Icon(Icons.exit_to_app),
                                            onPressed: () =>
                                                _leaveFamilyPackage(
                                                    package['id']),
                                          )
                                        : null,
                              ),
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
