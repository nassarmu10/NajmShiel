import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:map_explorer/services/auth_service.dart';
import 'package:map_explorer/providers/location_data_provider.dart';
import 'package:map_explorer/logger.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String _userName = '';
  final TextEditingController _nameController = TextEditingController();
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        // Get user data from Firestore
        final userData = await authService.getUserData(user.uid);

        if (mounted) {
          setState(() {
            _userData = userData;
            _userName = userData?['name'] ?? user.displayName ?? 'مستخدم';
            _nameController.text = _userName;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      logger.e('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateUserName() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال اسم صحيح')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;

      if (user != null) {
        // Update display name
        await user.updateDisplayName(_nameController.text.trim());

        // Update in Firestore
        await authService.updateUserData(
          uid: user.uid,
          name: _nameController.text.trim(),
        );

        if (mounted) {
          setState(() {
            _userName = _nameController.text.trim();
            _isEditing = false;
            _isSaving = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث الاسم بنجاح')),
          );
        }
      }
    } catch (e) {
      logger.e('Error updating user name: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من أنك تريد تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                final authService = Provider.of<AuthService>(context, listen: false);
                await authService.signOut();
                
                // Will automatically redirect to login screen via AuthWrapper
              } catch (e) {
                logger.e('Error signing out: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('حدث خطأ: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'تسجيل الخروج',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Profile avatar
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // User name
                  if (_isEditing)
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'الاسم',
                                border: OutlineInputBorder(),
                              ),
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              enabled: !_isSaving,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _isSaving
                                      ? null
                                      : () {
                                          setState(() {
                                            _isEditing = false;
                                            _nameController.text = _userName;
                                          });
                                        },
                                  child: const Text('إلغاء'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: _isSaving ? null : _updateUserName,
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('حفظ'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 4,
                      child: ListTile(
                        title: const Text(
                          'الاسم',
                          textAlign: TextAlign.right,
                        ),
                        subtitle: Text(
                          _userName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          tooltip: 'تعديل الاسم',
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // User info
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'معلومات الحساب',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.right,
                          ),
                          const Divider(),
                          ListTile(
                            title: const Text(
                              'نوع الحساب',
                              textAlign: TextAlign.right,
                            ),
                            subtitle: Text(
                              _userData?['authType'] == 'anonymous'
                                  ? 'مستخدم زائر'
                                  : 'مستخدم مسجل',
                              textAlign: TextAlign.right,
                            ),
                            leading: const Icon(Icons.account_circle),
                          ),
                          if (_userData?['createdAt'] != null)
                            ListTile(
                              title: const Text(
                                'تاريخ الإنضمام',
                                textAlign: TextAlign.right,
                              ),
                              subtitle: Text(
                                _formatTimestamp(_userData?['createdAt']),
                                textAlign: TextAlign.right,
                              ),
                              leading: const Icon(Icons.calendar_today),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year}';
    }
    return 'غير معروف';
  }
}
