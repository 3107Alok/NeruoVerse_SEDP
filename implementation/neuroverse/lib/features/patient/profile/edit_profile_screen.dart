import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../providers/app_provider.dart';
import '../../../../data/local/hive_service.dart' as app_hive;
import '../../../../core/localization/app_translations.dart';
import '../../../../core/services/emergency_sos_service.dart';

/// Dedicated, responsive Edit Profile screen designed with a warm, calm,
/// elderly-friendly aesthetic consistent with the NeuroVerse teal theme (#00796B).
class EditProfileScreen extends StatefulWidget {
  final String? linkedCaregiverName;
  final List<String>? linkedCaregiverNames;
  final Map<String, dynamic>? currentFirestoreData;

  const EditProfileScreen({
    super.key,
    this.linkedCaregiverName,
    this.linkedCaregiverNames,
    this.currentFirestoreData,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _phoneController;
  late final TextEditingController _caregiverPhoneController;
  late final TextEditingController _caretakerController;
  late String _selectedGender;
  late String _selectedAppLanguage;
  late String _selectedVoiceLanguage;
  bool _isSaving = false;

  String _normalizeLang(String? val) {
    final v = (val ?? '').toLowerCase();
    if (v.contains('hindi') || v == 'hi') return 'Hindi';
    if (v.contains('bengali') || v.contains('বাংলা') || v == 'bn') return 'Bengali';
    if (v.contains('assam') || v.contains('অসমীয়া') || v == 'as') return 'Assamese';
    if (v.contains('manipuri') || v.contains('মৈতৈলোন') || v == 'mni') return 'Manipuri';
    if (v.contains('mizo') || v == 'miz') return 'Mizo';
    return 'English';
  }

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();

    final initialName = (provider.userName != null && provider.userName!.trim().isNotEmpty)
        ? provider.userName!
        : (widget.currentFirestoreData?['name']?.toString() ?? '');

    final initialAge = (provider.userAge != null && provider.userAge!.trim().isNotEmpty)
        ? provider.userAge!
        : (widget.currentFirestoreData?['age']?.toString() ?? '');

    final initialCaretaker = (provider.caretakerName != null && provider.caretakerName!.trim().isNotEmpty)
        ? provider.caretakerName!
        : (widget.currentFirestoreData?['caretakerName']?.toString() ?? '');

    final rawGender = (provider.userGender != null && provider.userGender!.trim().isNotEmpty)
        ? provider.userGender!.trim()
        : (widget.currentFirestoreData?['gender']?.toString().trim() ?? 'Male');

    // Strict normalization to avoid DropdownButton assertion crash
    if (rawGender.toLowerCase() == 'female') {
      _selectedGender = 'Female';
    } else if (rawGender.toLowerCase() == 'other') {
      _selectedGender = 'Other';
    } else {
      _selectedGender = 'Male';
    }

    _selectedAppLanguage = _normalizeLang(provider.userLanguage ?? widget.currentFirestoreData?['language']?.toString());
    _selectedVoiceLanguage = _normalizeLang(provider.voiceLanguage ?? widget.currentFirestoreData?['voiceLanguage']?.toString() ?? _selectedAppLanguage);

    final hiveProfile = app_hive.HiveService().getUserProfile();
    final initialPhone = (widget.currentFirestoreData?['phone'] ?? hiveProfile?['phone'] ?? '').toString();
    final initialCaregiverPhone = (widget.currentFirestoreData?['caregiverPhone'] ?? widget.currentFirestoreData?['guardianPhone'] ?? hiveProfile?['caregiverPhone'] ?? '').toString();

    _nameController = TextEditingController(text: initialName);
    _ageController = TextEditingController(text: initialAge);
    _phoneController = TextEditingController(text: initialPhone);
    _caregiverPhoneController = TextEditingController(text: initialCaregiverPhone);
    _caretakerController = TextEditingController(text: initialCaretaker);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _caregiverPhoneController.dispose();
    _caretakerController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'P';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Future<void> _saveProfile() async {
    // Dismiss soft keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final successMsg = context.tr('profile_updated');
    setState(() => _isSaving = true);
    final provider = context.read<AppProvider>();
    final updatedName = _nameController.text.trim();
    final updatedAge = _ageController.text.trim();
    final updatedCaretaker = (widget.linkedCaregiverName != null && widget.linkedCaregiverName!.isNotEmpty)
        ? widget.linkedCaregiverName!
        : _caretakerController.text.trim();

    final updatedPhone = _phoneController.text.trim();
    final updatedCaregiverPhone = _caregiverPhoneController.text.trim();

    provider.setUserProfile(
      updatedName,
      updatedAge,
      _selectedGender,
      _selectedAppLanguage,
      voiceLanguage: _selectedVoiceLanguage,
      caretakerName: updatedCaretaker,
    );

    // Save locally to Hive safely
    try {
      final hive = context.read<app_hive.HiveService>();
      final existingProf = hive.getUserProfile() ?? {};
      existingProf.addAll({
        'name': updatedName,
        'age': updatedAge,
        'phone': updatedPhone,
        'caregiverPhone': updatedCaregiverPhone,
        'gender': _selectedGender,
        'language': _selectedAppLanguage,
        'voiceLanguage': _selectedVoiceLanguage,
        'role': 'patient',
        'caretakerName': updatedCaretaker,
      });
      await hive.saveUserProfile(existingProf);

      if (updatedCaregiverPhone.isNotEmpty) {
        await EmergencySosService().addEmergencyContact(updatedCaregiverPhone);
      }
    } catch (e) {
      debugPrint("Error saving to Hive: $e");
    }

    // Sync to Firestore safely
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': updatedName,
          'age': updatedAge,
          'phone': updatedPhone,
          'caregiverPhone': updatedCaregiverPhone,
          'gender': _selectedGender,
          'language': _selectedAppLanguage,
          'voiceLanguage': _selectedVoiceLanguage,
          'caretakerName': updatedCaretaker,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error saving to Firestore: $e");
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: const Color(0xFF00796B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final padding = MediaQuery.of(context).padding;

    final primaryColor = const Color(0xFF00796B);
    final titleColor = isDark ? Colors.white : const Color(0xFF1B3B36);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF4A6B63);
    final cardColor = isDark ? const Color(0xFF1A2422) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final inputBg = isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9);
    final inputBorder = isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFD1E0DC);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFBF9F5),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF182220) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: titleColor,
            size: 24,
          ),
          tooltip: context.tr('back_to_profile'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.tr('edit_profile'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: titleColor,
            letterSpacing: -0.2,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    // Adaptive bottom padding: generous breathing room whether keyboard is open or closed
                    bottom: viewInsets.bottom > 0
                        ? (viewInsets.bottom + 24)
                        : (padding.bottom + 32),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Hero Card: Avatar & Guidance
                        _buildHeroAvatarCard(isDark, cardColor, borderColor, titleColor, subtitleColor),
                        const SizedBox(height: 18),

                        // Personal Information Card
                        _buildSectionContainer(
                          isDark: isDark,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          title: context.tr('personal_info'),
                          icon: Icons.badge_outlined,
                          children: [
                            // Full Name
                            _buildFieldLabel(context.tr('full_name'), isDark, isRequired: true),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1E2829),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _inputDecoration(
                                hint: context.tr('enter_name'),
                                icon: Icons.person_outline_rounded,
                                isDark: isDark,
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                primaryColor: primaryColor,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('please_enter_name') : null,
                            ),
                            const SizedBox(height: 16),

                            // Age
                            _buildFieldLabel(context.tr('age'), isDark, isRequired: true),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1E2829),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _inputDecoration(
                                hint: context.tr('enter_age'),
                                icon: Icons.cake_outlined,
                                isDark: isDark,
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                primaryColor: primaryColor,
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return context.tr('please_enter_age');
                                }
                                final ageNum = int.tryParse(v.trim());
                                if (ageNum == null || ageNum <= 0 || ageNum > 130) {
                                  return context.tr('enter_valid_age');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Gender
                            _buildFieldLabel(context.tr('gender'), isDark),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: ['Male', 'Female', 'Other'].contains(_selectedGender) ? _selectedGender : 'Male',
                              dropdownColor: isDark ? const Color(0xFF1E2826) : Colors.white,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : const Color(0xFF1E2829),
                              ),
                              items: [
                                DropdownMenuItem<String>(
                                  value: 'Male',
                                  child: Text(
                                    context.tr('male'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF1E2829),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Female',
                                  child: Text(
                                    context.tr('female'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF1E2829),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                DropdownMenuItem<String>(
                                  value: 'Other',
                                  child: Text(
                                    context.tr('other'),
                                    style: TextStyle(
                                      color: isDark ? Colors.white : const Color(0xFF1E2829),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (newVal) {
                                if (newVal != null) {
                                  setState(() => _selectedGender = newVal);
                                }
                              },
                              decoration: _inputDecoration(
                                hint: context.tr('select_gender'),
                                icon: Icons.people_outline_rounded,
                                isDark: isDark,
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                primaryColor: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Mobile Number
                            _buildFieldLabel('Mobile Number', isDark),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : const Color(0xFF1E2829),
                              ),
                              decoration: _inputDecoration(
                                hint: 'Enter your phone number',
                                icon: Icons.phone_outlined,
                                isDark: isDark,
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                primaryColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Language & Speech Preferences Card
                        _buildSectionContainer(
                          isDark: isDark,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          title: context.tr('language_preferences'),
                          icon: Icons.translate_rounded,
                          children: [
                            _buildFieldLabel(context.tr('app_language'), isDark),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('app_language_desc'),
                              style: TextStyle(fontSize: 12.5, color: subtitleColor),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedAppLanguage,
                              dropdownColor: isDark ? const Color(0xFF1B2422) : Colors.white,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1E2829),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'English', child: Text('🇮🇳 English', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Hindi', child: Text('🇮🇳 हिंदी (Hindi)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Bengali', child: Text('🌿 বাংলা (Bengali)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Assamese', child: Text('🌿 অসমীয়া (Assamese)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Manipuri', child: Text('🌿 মৈতৈলোন (Manipuri)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Mizo', child: Text('🌿 Mizo ṭawng (Mizo)', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (newVal) {
                                if (newVal != null) {
                                  setState(() => _selectedAppLanguage = newVal);
                                }
                              },
                              decoration: _inputDecoration(
                                hint: context.tr('app_language'),
                                icon: Icons.language_rounded,
                                isDark: isDark,
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                primaryColor: primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFieldLabel(context.tr('voice_language'), isDark),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('voice_language_desc'),
                              style: TextStyle(fontSize: 12.5, color: subtitleColor),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _selectedVoiceLanguage,
                              dropdownColor: isDark ? const Color(0xFF1B2422) : Colors.white,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1E2829),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'English', child: Text('🇮🇳 English (Natural Indian)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Hindi', child: Text('🇮🇳 हिंदी (Swara Neural)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Bengali', child: Text('🌿 বাংলা (Tanishaa Neural)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Assamese', child: Text('🌿 অসমীয়া (Assamese Neural)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Manipuri', child: Text('🌿 মৈতৈলোন (Manipuri Neural)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Mizo', child: Text('🌿 Mizo ṭawng (Mizo Neural)', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (newVal) {
                                if (newVal != null) {
                                  setState(() => _selectedVoiceLanguage = newVal);
                                }
                              },
                              decoration: _inputDecoration(
                                hint: context.tr('voice_language'),
                                icon: Icons.record_voice_over_rounded,
                                isDark: isDark,
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                primaryColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Caregiver & Support Card
                        _buildSectionContainer(
                          isDark: isDark,
                          cardColor: cardColor,
                          borderColor: borderColor,
                          title: context.tr('caregiver_support'),
                          icon: Icons.volunteer_activism_outlined,
                          children: [
                            if (widget.linkedCaregiverNames != null && widget.linkedCaregiverNames!.isNotEmpty) ...[
                              for (final cgName in widget.linkedCaregiverNames!)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _buildLinkedCaregiverTile(cgName, isDark),
                                ),
                            ] else if (widget.linkedCaregiverName != null && widget.linkedCaregiverName!.isNotEmpty) ...[
                              _buildLinkedCaregiverTile(widget.linkedCaregiverName!, isDark),
                            ] else ...[
                              _buildFieldLabel(context.tr('caretaker_name'), isDark),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('caretaker_desc'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _caretakerController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF1E2829),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _inputDecoration(
                                  hint: context.tr('enter_caretaker'),
                                  icon: Icons.shield_outlined,
                                  isDark: isDark,
                                  inputBg: inputBg,
                                  inputBorder: inputBorder,
                                  primaryColor: primaryColor,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            _buildFieldLabel('Caregiver Phone / SOS Emergency Contact', isDark),
                            const SizedBox(height: 2),
                            Text(
                              'Phone number used for 1-tap direct calling and emergency SOS alerts.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _caregiverPhoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.done,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1E2829),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: _inputDecoration(
                                hint: 'Enter phone number',
                                icon: Icons.phone_in_talk_rounded,
                                isDark: isDark,
                                inputBg: inputBg,
                                inputBorder: inputBorder,
                                primaryColor: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Action Buttons: Save Changes & Cancel
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: primaryColor.withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        context.tr('save_changes'),
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Discard / Cancel Link Button
                        Center(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              context.tr('cancel'),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroAvatarCard(
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color titleColor,
    Color subtitleColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Gradient Circular Avatar
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF00796B), Color(0xFF004D40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00796B).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _getInitials(_nameController.text),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('profile_settings'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr('profile_settings_sub'),
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required bool isDark,
    required Color cardColor,
    required Color borderColor,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF00796B), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B3B36),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label, bool isDark, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF1B3B36),
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: Color(0xFF00796B),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLinkedCaregiverTile(String caregiverName, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16281E) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF22543D) : const Color(0xFFBBF7D0),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caregiverName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : const Color(0xFF14532D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-synced from linked caregiver account',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color inputBg,
    required Color inputBorder,
    required Color primaryColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
        fontSize: 15,
      ),
      prefixIcon: Icon(icon, color: primaryColor, size: 22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: inputBorder, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: inputBorder, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
      ),
    );
  }
}
