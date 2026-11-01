import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../onboarding/language_screen.dart';
import '../onboarding/caregiver_setup_profile_screen.dart';
import '../phc_network/presentation/phc_role_selection_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NeuroVerse')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Who is using the app?',
                style: Theme.of(context).textTheme.displayLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AppProvider>().setRole('patient');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen()));
                },
                icon: const Icon(Icons.person, size: 32),
                label: const Text('I am a Patient'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<AppProvider>().setRole('caregiver');
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CaregiverSetupProfileScreen()));
                },
                icon: const Icon(Icons.favorite, size: 32),
                label: const Text('I am a Caregiver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF004D40),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PhcRoleSelectionScreen()));
                },
                icon: const Icon(Icons.local_hospital_rounded, size: 32),
                label: const Text('PHC & Community Network (ASHA / Doctor)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
