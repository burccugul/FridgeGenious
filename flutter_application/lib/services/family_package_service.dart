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

  // Maksimum aile üyesi sayısı (owner dahil)
  final int _maxFamilyMembers = 4;

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

  Future<bool> _checkUserInAnyFamily(String userId) async {
    try {
      // Kullanıcının owner olduğu aileler var mı?
      final ownerFamilies = await supabase
          .from('family_packages')
          .select('id')
          .eq('owner_user_id', userId);

      if (ownerFamilies != null && ownerFamilies.length > 0) {
        return true; // Kullanıcı zaten bir ailenin sahibi
      }

      // Kullanıcının üye olduğu aileler var mı?
      // Raw SQL kullanarak array içinde kullanıcı var mı kontrol ediyoruz
      final memberFamilies = await supabase
          .from('family_packages')
          .select('id')
          .filter('member_user_ids', 'cs', '["${userId}"]');

      if (memberFamilies != null && memberFamilies.length > 0) {
        return true; // Kullanıcı zaten bir ailenin üyesi
      }

      return false; // Kullanıcı herhangi bir ailede değil
    } catch (e) {
      print("Error checking user in families: $e");
      return false; // Hata durumunda varsayılan olarak false dön
    }
  }

  Future<void> createFamilyPackage(List<String> emailAddresses) async {
    if (_currentUser == null) {
      _showErrorSnackbar("No authenticated user found");
      return;
    }

    // Owner da bir kişi sayılır, bu yüzden liste uzunluğu maksimum aile üyesi sayısı - 1'i geçmemelidir
    if (emailAddresses.length > _maxFamilyMembers - 1) {
      _showErrorSnackbar(
          "Maximum family members allowed is $_maxFamilyMembers (including owner)");
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

    // Owner kullanıcının başka bir ailede olup olmadığını kontrol et
    bool isInAnyFamily = await _checkUserInAnyFamily(ownerUserId);
    if (isInAnyFamily) {
      _showErrorSnackbar("You are already a member or owner of another family");
      return;
    }

    List<String> memberUuids = await getUserUUIDs(emailAddresses);

    // Eklenecek üyelerin başka bir ailede olup olmadığını kontrol et
    bool anyMemberInFamily = false;
    List<String> availableMembers = [];

    for (String memberId in memberUuids) {
      bool isMemberInFamily = await _checkUserInAnyFamily(memberId);
      if (isMemberInFamily) {
        anyMemberInFamily = true;
      } else {
        availableMembers.add(memberId);
      }
    }

    if (anyMemberInFamily) {
      if (availableMembers.isEmpty) {
        _showErrorSnackbar(
            "All selected members are already in another family");
        return;
      } else {
        _showWarningSnackbar(
            "Some members are already in other families and will be skipped");
        // Sadece mevcut olmayan üyeleri ekle
        memberUuids = availableMembers;
      }
    }

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

  void _showWarningSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.orange,
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
    // Eğer maksimum üye sayısına ulaşıldıysa uyarı göster
    if (emailList.length >= _maxFamilyMembers - 1) {
      _showErrorSnackbar(
          "Maximum family members allowed is $_maxFamilyMembers (including owner)");
      return;
    }

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

  Future<void> _removeFamilyMember(
      Map<String, dynamic> familyPackage, String memberEmail) async {
    if (_currentUser == null) return;

    try {
      // Önce email adresinden member ID'sini bul
      final memberProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('email', memberEmail)
          .single();

      if (memberProfile == null) {
        _showErrorSnackbar("Member profile not found");
        return;
      }

      String memberUserId = memberProfile['id'];

      // Aile paketinden üye ID'sini çıkar
      List<dynamic> memberIds =
          List.from(familyPackage['member_user_ids'] ?? []);
      memberIds.remove(memberUserId);

      // Veritabanını güncelle
      await supabase
          .from('family_packages')
          .update({'member_user_ids': memberIds}).eq('id', familyPackage['id']);

      _showSuccessSnackbar("Member removed successfully");
      _fetchUserFamilyPackages(); // Listeyi yenile
    } catch (e) {
      print("Error removing family member: $e");
      _showErrorSnackbar("Error removing family member");
    }
  }

  void _showMemberManagementDialog(Map<String, dynamic> familyPackage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final List<String> memberEmails = familyPackage['member_emails'] != null
            ? List<String>.from(familyPackage['member_emails'])
            : [];

        return AlertDialog(
          title: Text('Manage Family Members'),
          content: Container(
            width: double.maxFinite,
            child: memberEmails.isEmpty
                ? Center(child: Text('No members in this family package'))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Family Name: ${familyPackage['family_name']}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Total members: ${memberEmails.length + 1}/${_maxFamilyMembers}',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                      SizedBox(height: 8),
                      Divider(),
                      Text('Members:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: memberEmails.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              title: Text(memberEmails[index]),
                              trailing: IconButton(
                                icon: Icon(Icons.remove_circle,
                                    color: Colors.red),
                                tooltip: 'Remove Member',
                                onPressed: () {
                                  Navigator.of(context).pop(); // Dialog'u kapat
                                  _removeFamilyMember(
                                      familyPackage, memberEmails[index]);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
            if (memberEmails.length < _maxFamilyMembers - 1)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _showAddMemberDialog(familyPackage);
                },
                child: Text('Add New Member'),
              ),
          ],
        );
      },
    );
  }

  void _showAddMemberDialog(Map<String, dynamic> familyPackage) {
    final newMemberController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Add New Member'),
          content: TextField(
            controller: newMemberController,
            decoration: InputDecoration(
              hintText: 'Email address',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final email = newMemberController.text.trim();
                if (email.isEmpty) return;

                Navigator.of(context).pop();

                // Email'i kontrol et ve üye ekle
                await _addNewMemberToFamily(familyPackage, email);
              },
              child: Text('Add'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addNewMemberToFamily(
      Map<String, dynamic> familyPackage, String email) async {
    try {
      // Mevcut üye sayısını kontrol et
      List<dynamic> memberIds =
          List.from(familyPackage['member_user_ids'] ?? []);
      if (memberIds.length >= _maxFamilyMembers - 1) {
        _showErrorSnackbar("Maximum family members reached");
        return;
      }

      // Email'den kullanıcı ID'sini bul
      final memberProfile = await supabase
          .from('profiles')
          .select('id')
          .eq('email', email)
          .maybeSingle();

      if (memberProfile == null) {
        _showErrorSnackbar("User with this email not found");
        return;
      }

      String memberUserId = memberProfile['id'];

      // Aynı kullanıcının zaten eklenip eklenmediğini kontrol et
      if (memberIds.contains(memberUserId)) {
        _showErrorSnackbar("This user is already a member");
        return;
      }

      // Kullanıcının başka bir ailede olup olmadığını kontrol et
      bool isInAnyFamily = await _checkUserInAnyFamily(memberUserId);
      if (isInAnyFamily) {
        _showErrorSnackbar(
            "This user is already a member or owner of another family");
        return;
      }

      // Kullanıcıyı aileye ekle
      memberIds.add(memberUserId);

      // Veritabanını güncelle
      await supabase
          .from('family_packages')
          .update({'member_user_ids': memberIds}).eq('id', familyPackage['id']);

      _showSuccessSnackbar("Member added successfully");
      _fetchUserFamilyPackages(); // Listeyi yenile
    } catch (e) {
      print("Error adding family member: $e");
      _showErrorSnackbar("Error adding family member");
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
            // Aile üye sınırlaması bilgisi
            Text(
              'Maximum family members: $_maxFamilyMembers (including owner)',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: emailList.length >= _maxFamilyMembers - 1
                        ? null
                        : _showEmailInputDialog,
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
            // Eklenen email'lerin listesi veya boş mesaj
            Expanded(
              flex: 1,
              child: emailList.isEmpty
                  ? const Center(
                      child:
                          Text('No emails added yet. Add emails to continue.'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Added Email Addresses:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${emailList.length}/${_maxFamilyMembers - 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      emailList.length >= _maxFamilyMembers - 1
                                          ? Colors.red
                                          : Colors.green,
                                ),
                              ),
                            ],
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
            // Mevcut aile paketleri
            const SizedBox(height: 20),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Your Family Packages:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _isLoadingFamilies
                        ? const Center(child: CircularProgressIndicator())
                        : _userFamilyPackages.isEmpty
                            ? const Center(
                                child: Text(
                                    "You are not part of any family package."),
                              )
                            : ListView.builder(
                                itemCount: _userFamilyPackages.length,
                                itemBuilder: (context, index) {
                                  final package = _userFamilyPackages[index];
                                  final isOwner = package['owner_user_id'] ==
                                      _currentUser?.id;

                                  // Toplam üye sayısı
                                  final int memberCount =
                                      (package['member_user_ids'] as List)
                                          .length;
                                  final String totalMembersText =
                                      'Total: ${memberCount + 1}/$_maxFamilyMembers members'; // +1 for owner

                                  return Card(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: ListTile(
                                      title: Text(package['family_name'] ??
                                          'Unnamed Family'),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              'Owner: ${package['owner_email'] ?? ''}'),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Members: ${(package['member_emails'] as List<String>).join(", ")}',
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            totalMembersText,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: memberCount + 1 >=
                                                      _maxFamilyMembers
                                                  ? Colors.orange[700]
                                                  : Colors.green[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: isOwner
                                          ? Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon:
                                                      const Icon(Icons.people),
                                                  tooltip: 'Manage Members',
                                                  onPressed: () =>
                                                      _showMemberManagementDialog(
                                                          package),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                      Icons.delete_forever),
                                                  tooltip:
                                                      'Delete Family Package',
                                                  onPressed: () =>
                                                      _deleteFamilyPackage(
                                                          package['id']),
                                                ),
                                              ],
                                            )
                                          : (package['member_user_ids'] as List)
                                                  .contains(_currentUser?.id)
                                              ? IconButton(
                                                  icon: const Icon(
                                                      Icons.exit_to_app),
                                                  tooltip:
                                                      'Leave Family Package',
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
          ],
        ),
      ),
    );
  }
}
