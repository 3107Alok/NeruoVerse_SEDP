import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/local/hive_service.dart';
import '../../providers/app_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../caregiver/overview/caregiver_main_screen.dart';

class CaregiverSetupProfileScreen extends StatefulWidget {
  const CaregiverSetupProfileScreen({super.key});

  @override
  State<CaregiverSetupProfileScreen> createState() => _CaregiverSetupProfileScreenState();
}

class _CaregiverSetupProfileScreenState extends State<CaregiverSetupProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Welcome,\nCaregiver",
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Set up your caregiver profile to get started.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF00796B).withOpacity(0.1),
                  child: const Icon(
                    Icons.favorite,
                    size: 60,
                    color: Color(0xFF00796B),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              _buildLabel('Your Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration(hint: 'e.g. Ramesh Singh'),
              ),
              
              const SizedBox(height: 16),
              
              _buildLabel('Your Age'),
              const SizedBox(height: 8),
              TextField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(hint: 'e.g. 45'),
              ),
              
              const SizedBox(height: 16),
              
              _buildLabel('Gender'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: ['Male', 'Female', 'Other'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() => _selectedGender = newValue);
                  }
                },
                decoration: _inputDecoration(),
              ),
              
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Continue to Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty || _ageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final age = _ageController.text.trim();
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final email = FirebaseAuth.instance.currentUser?.email ?? '';

      // Save local profile and update provider
      final hive = context.read<HiveService>();
      final appProvider = context.read<AppProvider>();
      appProvider.setUserProfile(name, age, _selectedGender, 'English');

      await hive.saveUserProfile({
        'uid': uid,
        'role': 'caregiver',
        'name': name,
        'email': email,
        'age': age,
        'gender': _selectedGender,
      });

      // Save to Firestore
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'role': 'caregiver',
          'name': name,
          'email': FirebaseAuth.instance.currentUser?.email ?? '',
          'age': age,
          'gender': _selectedGender,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const CaregiverMainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
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
        borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
      ),
    );
  }
}
