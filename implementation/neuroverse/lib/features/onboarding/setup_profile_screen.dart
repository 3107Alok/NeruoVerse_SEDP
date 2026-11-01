import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/local/hive_service.dart';
import '../../providers/app_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../patient/home/patient_main_screen.dart';

class SetupProfileScreen extends StatefulWidget {
  final String? initialLanguage;
  const SetupProfileScreen({super.key, this.initialLanguage});

  @override
  State<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends State<SetupProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';
  late String _selectedLanguage;
  late String _selectedVoiceLanguage;
  bool _isLoading = false;

  static const List<Map<String, String>> _languages = [
    {'name': 'English', 'native': 'English'},
    {'name': 'Hindi', 'native': 'हिंदी (Hindi)'},
    {'name': 'Bengali', 'native': 'বাংলা (Bengali)'},
    {'name': 'Assamese', 'native': 'অসমীয়া (Assamese)'},
    {'name': 'Manipuri', 'native': 'মৈতৈলোন (Manipuri)'},
    {'name': 'Mizo', 'native': 'Mizo ṭawng'},
  ];

  String _normalize(String? lang) {
    if (lang == null) return 'English';
    final lower = lang.toLowerCase();
    if (lower.contains('hi') || lower.contains('हिंदी')) return 'Hindi';
    if (lower.contains('bn') || lower.contains('বাংলা') || lower.contains('bengali')) return 'Bengali';
    if (lower.contains('as') || lower.contains('অসমীয়া') || lower.contains('assamese')) return 'Assamese';
    if (lower.contains('mni') || lower.contains('মণিপুরী') || lower.contains('মৈতৈলোন') || lower.contains('manipuri')) return 'Manipuri';
    if (lower.contains('miz') || lower.contains('mizo')) return 'Mizo';
    return 'English';
  }

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _normalize(widget.initialLanguage);
    _selectedVoiceLanguage = _selectedLanguage;
  }


  Future<String> _getUniqueShareCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    for (int i = 0; i < 3; i++) {
      final code = String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('shareCode', isEqualTo: code)
            .get()
            .timeout(const Duration(seconds: 3));
        if (snapshot.docs.isEmpty) {
          return code;
        }
      } catch (e) {
        debugPrint('Firestore shareCode query note: $e');
        return code;
      }
    }
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Let's set up your\nprofile",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              _buildLabel('What\'s your name?'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration(),
              ),
              
              const SizedBox(height: 24),
              
              _buildLabel('Your age'),
              const SizedBox(height: 8),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(),
              ),

              const SizedBox(height: 24),

              _buildLabel('Your gender'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: _inputDecoration(),
                items: ['Male', 'Female', 'Other'].map((gender) {
                  return DropdownMenuItem(value: gender, child: Text(gender));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedGender = val);
                },
              ),

              const SizedBox(height: 24),
              
              _buildLabel('App Display Language'),
              const SizedBox(height: 4),
              Text(
                'Used for screens, buttons, and text',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedLanguage,
                decoration: _inputDecoration(),
                items: _languages.map((item) {
                  return DropdownMenuItem(
                    value: item['name']!,
                    child: Text(item['native']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedLanguage = val);
                },
              ),

              const SizedBox(height: 20),

              _buildLabel('Voice Assistant Language'),
              const SizedBox(height: 4),
              Text(
                'Used for voice replies and game guidance audio',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedVoiceLanguage,
                decoration: _inputDecoration(),
                items: _languages.map((item) {
                  return DropdownMenuItem(
                    value: item['name']!,
                    child: Text(item['native']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedVoiceLanguage = val);
                },
              ),

              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  if (_nameController.text.trim().isEmpty || _ageController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your name and age.')));
                    return;
                  }

                  final appProvider = context.read<AppProvider>();
                  final hive = context.read<HiveService>();
                  setState(() => _isLoading = true);

                  try {
                    final name = _nameController.text.trim();
                    final age = _ageController.text.trim();
                    final shareCode = await _getUniqueShareCode();
                    
                    // Save to AppProvider
                    appProvider.setUserProfile(
                      name,
                      age,
                      _selectedGender,
                      _selectedLanguage,
                      voiceLanguage: _selectedVoiceLanguage,
                    );
                    
                    final uid = FirebaseAuth.instance.currentUser?.uid;

                    // Save to Hive
                    await hive.saveUserProfile({
                      'uid': uid,
                      'role': 'patient',
                      'name': name,
                      'email': FirebaseAuth.instance.currentUser?.email ?? '',
                      'age': age,
                      'gender': _selectedGender,
                      'language': _selectedLanguage,
                      'voiceLanguage': _selectedVoiceLanguage,
                      'shareCode': shareCode,
                      'connectCode': shareCode,
                    });
                    
                    // Save to Firestore
                    if (uid != null) {
                      await FirebaseFirestore.instance.collection('users').doc(uid).set({
                        'role': 'patient',
                        'name': name,
                        'email': FirebaseAuth.instance.currentUser?.email ?? '',
                        'age': age,
                        'gender': _selectedGender,
                        'language': _selectedLanguage,
                        'voiceLanguage': _selectedVoiceLanguage,
                        'shareCode': shareCode,
                        'connectCode': shareCode,
                        'createdAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));
                    }

                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const PatientMainScreen()),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  } finally {
                    if (mounted) setState(() => _isLoading = false);
                  }
                },
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Start'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
      ),
    );
  }
}
