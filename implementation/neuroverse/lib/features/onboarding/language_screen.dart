import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'setup_profile_screen.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'English';

  final List<Map<String, String>> _languages = const [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिंदी'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'as', 'name': 'Assamese', 'native': 'অসমীয়া'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ', 'isNew': 'true'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు', 'isNew': 'true'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी', 'isNew': 'true'},
    {'code': 'mni', 'name': 'Manipuri', 'native': 'মৈতৈলোন / মণিপুরী'},
    {'code': 'miz', 'name': 'Mizo', 'native': 'Mizo ṭawng'},
  ];

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose your\nlanguage',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Select your primary language. You can customize voice and display languages separately anytime in settings.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Expanded(
                child: ListView.builder(
                  itemCount: _languages.length,
                  itemBuilder: (context, index) {
                    final item = _languages[index];
                    final langName = item['name']!;
                    final isSelected = _selectedLanguage == langName;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedLanguage = langName;
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.06) : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                              width: isSelected ? 2.0 : 1.2,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade400,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          item['native']!,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            color: isSelected ? Theme.of(context).primaryColor : null,
                                          ),
                                        ),
                                        if (item['isNew'] == 'true') ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF059669),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'NEW',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (item['native'] != item['name'])
                                      Text(
                                        item['name']!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).primaryColor,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  final provider = context.read<AppProvider>();
                  provider.setAppLanguage(_selectedLanguage);
                  const voiceSupported = ['English', 'Hindi', 'Bengali', 'Assamese', 'Manipuri', 'Mizo'];
                  if (voiceSupported.contains(_selectedLanguage)) {
                    provider.setVoiceLanguage(_selectedLanguage);
                  } else {
                    provider.setVoiceLanguage('English');
                  }

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SetupProfileScreen(
                        initialLanguage: _selectedLanguage,
                      ),
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Continue'),
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
}
