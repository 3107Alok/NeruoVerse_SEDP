import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_provider.dart';
import '../../../../core/localization/app_translations.dart';

class LanguageSelectionSheet extends StatelessWidget {
  final bool isVoice;
  const LanguageSelectionSheet({super.key, required this.isVoice});

  static const List<Map<String, String>> _voiceLanguages = [
    {
      'code': 'en',
      'name': 'English',
      'native': 'English',
      'greeting': 'Hello',
      'region': 'Universal / Global',
      'icon': '🌐',
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'native': 'हिंदी',
      'greeting': 'नमस्ते',
      'region': 'National / North India',
      'icon': '🇮🇳',
    },
    {
      'code': 'bn',
      'name': 'Bengali',
      'native': 'বাংলা',
      'greeting': 'নমস্কার',
      'region': 'Tripura / Assam / Bengal',
      'icon': '🪷',
    },
    {
      'code': 'as',
      'name': 'Assamese',
      'native': 'অসমীয়া',
      'greeting': 'নমস্কাৰ',
      'region': 'Assam & Brahmaputra Valley',
      'icon': '🦏',
    },
    {
      'code': 'mni',
      'name': 'Manipuri',
      'native': 'মৈতৈলোন (মণিপুরী)',
      'greeting': 'খুরুমজরি',
      'region': 'Manipur & Imphal Valley',
      'icon': '🌺',
    },
    {
      'code': 'miz',
      'name': 'Mizo',
      'native': 'Mizo ṭawng',
      'greeting': 'Chibai',
      'region': 'Mizoram & Lushai Hills',
      'icon': '🌄',
    },
  ];

  static const List<Map<String, String>> _appLanguages = [
    {
      'code': 'en',
      'name': 'English',
      'native': 'English',
      'greeting': 'Hello',
      'region': 'Universal / Global',
      'icon': '🌐',
    },
    {
      'code': 'hi',
      'name': 'Hindi',
      'native': 'हिंदी',
      'greeting': 'नमस्ते',
      'region': 'National / North India',
      'icon': '🇮🇳',
    },
    {
      'code': 'bn',
      'name': 'Bengali',
      'native': 'বাংলা',
      'greeting': 'নমস্কার',
      'region': 'Tripura / Assam / Bengal',
      'icon': '🪷',
    },
    {
      'code': 'as',
      'name': 'Assamese',
      'native': 'অসমীয়া',
      'greeting': 'নমস্কাৰ',
      'region': 'Assam & Brahmaputra Valley',
      'icon': '🦏',
    },
    {
      'code': 'kn',
      'name': 'Kannada',
      'native': 'ಕನ್ನಡ',
      'greeting': 'ನಮಸ್ಕಾರ',
      'region': 'Karnataka & South India',
      'icon': '🏛️',
      'isNew': 'true',
    },
    {
      'code': 'te',
      'name': 'Telugu',
      'native': 'తెలుగు',
      'greeting': 'నమస్కారం',
      'region': 'Andhra Pradesh & Telangana',
      'icon': '🌾',
      'isNew': 'true',
    },
    {
      'code': 'mr',
      'name': 'Marathi',
      'native': 'मराठी',
      'greeting': 'नमस्कार',
      'region': 'Maharashtra & West India',
      'icon': '🚩',
      'isNew': 'true',
    },
    {
      'code': 'mni',
      'name': 'Manipuri',
      'native': 'মৈতৈলোন (মণিপুরী)',
      'greeting': 'খুরুমজরি',
      'region': 'Manipur & Imphal Valley',
      'icon': '🌺',
    },
    {
      'code': 'miz',
      'name': 'Mizo',
      'native': 'Mizo ṭawng',
      'greeting': 'Chibai',
      'region': 'Mizoram & Lushai Hills',
      'icon': '🌄',
    },
  ];

  static void show(BuildContext context, {required bool isVoice}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguageSelectionSheet(isVoice: isVoice),
    );
  }

  String _normalize(String? lang) {
    if (lang == null) return 'English';
    final lower = lang.toLowerCase().trim();
    if (lower == 'mr' || lower.contains('मराठी') || lower.contains('marathi')) return 'Marathi';
    if (lower == 'kn' || lower.contains('ಕನ್ನಡ') || lower.contains('kannada')) return 'Kannada';
    if (lower == 'te' || lower.contains('తెలుగు') || lower.contains('telugu')) return 'Telugu';
    if (lower == 'hi' || lower.contains('हिंदी') || lower.contains('hindi')) return 'Hindi';
    if (lower == 'bn' || lower.contains('বাংলা') || lower.contains('bengali')) return 'Bengali';
    if (lower == 'as' || lower.contains('অসমীয়া') || lower.contains('assamese')) return 'Assamese';
    if (lower == 'mni' || lower.contains('মণিপুরী') || lower.contains('মৈতৈলোন') || lower.contains('manipuri')) return 'Manipuri';
    if (lower == 'miz' || lower.contains('mizo')) return 'Mizo';
    return 'English';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<AppProvider>();

    final current = isVoice
        ? _normalize(provider.voiceLanguage ?? provider.userLanguage)
        : _normalize(provider.userLanguage);

    final bg = isDark ? const Color(0xFF141F1D) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1C2C29) : const Color(0xFFF7FBF9);
    final activeBorder = const Color(0xFF00796B);
    final inactiveBorder = isDark ? Colors.white12 : Colors.grey.shade200;

    final languages = isVoice ? _voiceLanguages : _appLanguages;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewPadding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header with Icon
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isVoice ? const Color(0xFF8B5CF6) : const Color(0xFF00796B)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isVoice ? Icons.record_voice_over_rounded : Icons.translate_rounded,
                  color: isVoice ? const Color(0xFF8B5CF6) : const Color(0xFF00796B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVoice ? context.tr('voice_language') : context.tr('app_language'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isVoice
                          ? context.tr('voice_language_sub')
                          : context.tr('app_language_sub'),
                      style: TextStyle(fontSize: 12.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Language Cards
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: languages.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = languages[index];
              final isSelected = current.toLowerCase() == item['name']!.toLowerCase();

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    if (isVoice) {
                      await provider.setVoiceLanguage(item['name']!);
                    } else {
                      await provider.setAppLanguage(item['name']!);
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      try {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: const Color(0xFF00796B),
                            content: Row(
                              children: [
                                Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${isVoice ? "Voice" : "App"} language set to ${item['native']} (${item['name']})',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } catch (_) {}
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isVoice ? const Color(0xFF8B5CF6) : const Color(0xFF00796B)).withValues(alpha: 0.08)
                          : cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? (isVoice ? const Color(0xFF8B5CF6) : activeBorder)
                            : inactiveBorder,
                        width: isSelected ? 2.0 : 1.2,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: (isVoice ? const Color(0xFF8B5CF6) : const Color(0xFF00796B)).withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? (isVoice ? const Color(0xFF8B5CF6) : activeBorder)
                                  : (isDark ? Colors.white12 : Colors.grey.shade300),
                            ),
                          ),
                          child: Text(
                            item['icon']!,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
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
                                      color: isSelected
                                          ? (isVoice ? const Color(0xFF8B5CF6) : const Color(0xFF00796B))
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '"${item['greeting']}"',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  if (!isVoice && item['isNew'] == 'true') ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                              const SizedBox(height: 2),
                              Text(
                                '${item['name']} • ${item['region']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? (isVoice ? const Color(0xFF8B5CF6) : const Color(0xFF00796B))
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? (isVoice ? const Color(0xFF8B5CF6) : const Color(0xFF00796B))
                                  : (isDark ? Colors.white30 : Colors.grey.shade400),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 16, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ],
      ),
    );
  }
}
