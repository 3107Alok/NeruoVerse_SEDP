import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../providers/app_provider.dart';
import '../../../../data/local/hive_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/services/emergency_sos_service.dart';
import '../common/logout_confirm_dialog.dart';
import 'edit_profile_screen.dart';

class PatientProfileTab extends StatefulWidget {
  const PatientProfileTab({super.key});

  @override
  State<PatientProfileTab> createState() => _PatientProfileTabState();
}

class _PatientProfileTabState extends State<PatientProfileTab> {
  void _openEditProfile(BuildContext context, {String? linkedCaregiverName, List<String>? linkedCaregiverNames, Map<String, dynamic>? currentFirestoreData}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          linkedCaregiverName: linkedCaregiverName,
          linkedCaregiverNames: linkedCaregiverNames,
          currentFirestoreData: currentFirestoreData,
        ),
      ),
    );
  }

  void _openEditProfileSheet(BuildContext context, {String? linkedCaregiverName, List<String>? linkedCaregiverNames, Map<String, dynamic>? currentFirestoreData}) {
    _openEditProfile(context, linkedCaregiverName: linkedCaregiverName, linkedCaregiverNames: linkedCaregiverNames, currentFirestoreData: currentFirestoreData);
  }

  Future<void> _setPrimaryCaregiver({
    required String uid,
    required String cgId,
    required String cgName,
    required String cgPhone,
  }) async {
    try {
      HapticFeedback.mediumImpact();
      final hive = Provider.of<HiveService?>(context, listen: false);
      final profile = hive?.getUserProfile() ?? {};
      profile['primaryCaregiverId'] = cgId;
      profile['caretakerName'] = cgName;
      if (cgPhone.isNotEmpty) {
        profile['caregiverPhone'] = cgPhone;
        await EmergencySosService().addEmergencyContact(cgPhone);
      }
      await hive?.saveUserProfile(profile);

      if (uid.isNotEmpty && uid != 'Unknown ID') {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'primaryCaregiverId': cgId,
          'caretakerName': cgName,
          if (cgPhone.isNotEmpty) 'caregiverPhone': cgPhone,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('$cgName set as Primary Contact! ✨'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00796B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error setting primary caregiver: $e');
    }
  }

  bool _isGeneratingCode = false;
  Future<void> _ensureShareCode(String uid) async {
    if (_isGeneratingCode || uid.isEmpty || uid == 'Unknown ID') return;
    _isGeneratingCode = true;
    try {
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      final rand = Random();
      String code = '';
      for (int i = 0; i < 3; i++) {
        code = String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rand.nextInt(chars.length))));
        try {
          final snap = await FirebaseFirestore.instance
              .collection('users')
              .where('shareCode', isEqualTo: code)
              .get()
              .timeout(const Duration(seconds: 3));
          if (snap.docs.isEmpty) break;
        } catch (_) {
          break;
        }
      }
      if (code.isEmpty) {
        code = String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rand.nextInt(chars.length))));
      }
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'shareCode': code,
        'connectCode': code,
      }, SetOptions(merge: true));
      if (mounted) {
        try {
          final hive = Provider.of<HiveService?>(context, listen: false);
          if (hive != null) {
            final prof = hive.getUserProfile() ?? {};
            prof['shareCode'] = code;
            prof['connectCode'] = code;
            await hive.saveUserProfile(prof);
          }
        } catch (_) {}
        setState(() {});
      }
    } catch (_) {} finally {
      _isGeneratingCode = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'Unknown ID';
    final provider = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final rawCode = userData?['shareCode']?.toString() ?? userData?['connectCode']?.toString();
        String shareCode = (rawCode != null && rawCode.isNotEmpty && rawCode != '---') ? rawCode : '';
        if (shareCode.isEmpty) {
          try {
            final hiveProfile = Provider.of<HiveService?>(context, listen: false)?.getUserProfile();
            shareCode = hiveProfile?['shareCode']?.toString() ?? hiveProfile?['connectCode']?.toString() ?? '';
          } catch (_) {}
        }
        if (shareCode.isEmpty && uid.isNotEmpty && uid != 'Unknown ID') {
          _ensureShareCode(uid);
          shareCode = '---';
        }

        final pName = provider.userName?.trim();
        final pAge = provider.userAge?.trim();
        final pGender = provider.userGender?.trim();
        final pLang = provider.userLanguage?.trim();

        final fName = userData?['name']?.toString().trim();
        final fAge = userData?['age']?.toString().trim();
        final fGender = userData?['gender']?.toString().trim();
        final fLang = userData?['language']?.toString().trim();

        final name = (pName != null && pName.isNotEmpty)
            ? pName
            : (fName != null && fName.isNotEmpty ? fName : 'Patient');

        final age = (pAge != null && pAge.isNotEmpty)
            ? pAge
            : (fAge != null && fAge.isNotEmpty ? fAge : 'Not set');

        final rawG = (pGender != null && pGender.isNotEmpty)
            ? pGender
            : (fGender != null && fGender.isNotEmpty ? fGender : '');

        final gender = rawG.isNotEmpty
            ? (rawG[0].toUpperCase() + rawG.substring(1).toLowerCase())
            : 'Not set';

        final language = (pLang != null && pLang.isNotEmpty)
            ? pLang
            : (fLang != null && fLang.isNotEmpty ? fLang : 'English');

        final voiceLang = (provider.voiceLanguage != null && provider.voiceLanguage!.isNotEmpty)
            ? provider.voiceLanguage!
            : (userData?['voiceLanguage']?.toString() ?? language);

        final phone = (userData?['phone']?.toString().trim() ?? '').isNotEmpty
            ? userData!['phone'].toString().trim()
            : (Provider.of<HiveService?>(context, listen: false)?.getUserProfile()?['phone']?.toString().trim() ?? '');

        final caregiverPhone = (userData?['caregiverPhone']?.toString().trim() ?? '').isNotEmpty
            ? userData!['caregiverPhone'].toString().trim()
            : (Provider.of<HiveService?>(context, listen: false)?.getUserProfile()?['caregiverPhone']?.toString().trim() ?? '');

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('linkedPatients', arrayContains: uid)
              .snapshots(),
          builder: (context, cgQuerySnapshot) {
            final caregiverDocs = cgQuerySnapshot.data?.docs ?? [];
            final List<Map<String, dynamic>> linkedCaregivers = caregiverDocs
                .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
                .toList();

            final autoCaregiverName = linkedCaregivers.isNotEmpty 
                ? linkedCaregivers.first['name']?.toString() 
                : null;

            // Determine caretaker name: prioritize auto-fetched caregiver, then provider fallback
            final effectiveCaretaker = autoCaregiverName ?? (provider.caretakerName != null && provider.caretakerName!.isNotEmpty ? provider.caretakerName! : 'Not linked yet');

            // Keep AppProvider in sync if loaded empty
            if ((pGender == null || pGender.isEmpty) && fGender != null && fGender.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                provider.setUserProfile(name, age, gender, language, voiceLanguage: voiceLang, caretakerName: effectiveCaretaker);
              });
            }

            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Header: Warm title and refined Edit button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('my_profile'),
                                    style: theme.textTheme.displayLarge?.copyWith(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    context.tr('profile_sub'),
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              fit: FlexFit.loose,
                              child: TextButton.icon(
                                onPressed: () => _openEditProfileSheet(
                                  context,
                                  linkedCaregiverName: autoCaregiverName,
                                  linkedCaregiverNames: linkedCaregivers.map((c) => c['name']?.toString() ?? 'Caregiver').toList(),
                                  currentFirestoreData: userData,
                                ),
                                icon: const Icon(Icons.mode_edit_outline_rounded, size: 16, color: Color(0xFF00796B)),
                                label: Text(
                                  context.tr('edit_profile'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: Color(0xFF00796B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.08),
                                  side: BorderSide(
                                    color: const Color(0xFF00796B).withValues(alpha: 0.25),
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Hero Avatar & Identification Card (Modern, calm, elderly-friendly)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2422) : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8),
                              width: 1.2,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.05),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 62,
                                height: 62,
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
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : 'P',
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
                                      name,
                                      style: TextStyle(
                                        fontSize: 18.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      user?.email ?? 'No email associated',
                                      style: TextStyle(
                                        fontSize: (user?.email?.length ?? 0) > 24 ? 11.5 : 12.5,
                                        color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00796B).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF00796B).withValues(alpha: 0.18),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified_user_rounded, size: 12.5, color: Color(0xFF00796B)),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              context.tr('active_patient'),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF00796B),
                                                letterSpacing: 0.2,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Caregiver Linked Status Card (Highlights verified link)
                        if (autoCaregiverName != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF13261C) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? const Color(0xFF1E4631) : const Color(0xFFBBF7D0),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E4631) : const Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.volunteer_activism_rounded,
                                    color: Color(0xFF16A34A),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              context.tr('linked_caregiver'),
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF16A34A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 13),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        autoCaregiverName,
                                        style: TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : const Color(0xFF14532D),
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        context.tr('caregiver_syncing'),
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? Colors.white60 : const Color(0xFF166534),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Connect Code Card
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2422) : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8),
                              width: 1.2,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.04),
                                      blurRadius: 14,
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
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.qr_code_2_rounded, size: 19, color: Color(0xFF00796B)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.tr('connect_code'),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.tr('connect_code_sub'),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF141C1A) : const Color(0xFFF4F8F6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF00796B).withValues(alpha: 0.22),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      shareCode,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        color: Color(0xFF00796B),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: shareCode));
                                          HapticFeedback.lightImpact();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                                  const SizedBox(width: 8),
                                                  Text(context.tr('code_copied')),
                                                ],
                                              ),
                                              backgroundColor: const Color(0xFF00796B),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00796B).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFF00796B).withValues(alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF00796B)),
                                              const SizedBox(width: 5),
                                              Flexible(
                                                child: Text(
                                                  context.tr('copy_code'),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF00796B),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Aesthetic Personal Details Card
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2422) : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8),
                              width: 1.2,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.04),
                                      blurRadius: 14,
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
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.badge_outlined, size: 19, color: Color(0xFF00796B)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.tr('personal_details'),
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
                              _buildDetailRow(
                                icon: Icons.email_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                label: context.tr('email'),
                                value: user?.email ?? context.tr('not_set'),
                              ),
                              const Divider(height: 22),
                              _buildDetailRow(
                                icon: Icons.cake_outlined,
                                iconColor: const Color(0xFFE11D48),
                                label: context.tr('age'),
                                value: age.isNotEmpty && age != 'Not set' ? context.tr('age_years_fmt', params: {'age': age}) : context.tr('not_set'),
                              ),
                              const Divider(height: 22),
                              _buildDetailRow(
                                icon: Icons.people_outline_rounded,
                                iconColor: const Color(0xFF0284C7),
                                label: context.tr('gender'),
                                value: gender.toLowerCase() == 'male'
                                    ? context.tr('male')
                                    : (gender.toLowerCase() == 'female'
                                        ? context.tr('female')
                                        : (gender.toLowerCase() == 'other' ? context.tr('other') : (gender.isEmpty ? context.tr('not_set') : gender))),
                              ),
                              const Divider(height: 22),
                              _buildDetailRow(
                                icon: Icons.phone_android_rounded,
                                iconColor: const Color(0xFF0D9488),
                                label: 'Phone',
                                value: phone.isNotEmpty ? phone : 'Not set',
                                trailing: phone.isEmpty
                                    ? InkWell(
                                        onTap: () => _openEditProfileSheet(
                                          context,
                                          linkedCaregiverName: autoCaregiverName,
                                          linkedCaregiverNames: linkedCaregivers.map((c) => c['name']?.toString() ?? 'Caregiver').toList(),
                                          currentFirestoreData: userData,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00796B).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '+ Add',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00796B),
                                            ),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Connected Caregivers Card (Supports Multiple Caregivers)
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1B2422) : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8),
                              width: 1.2,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.04),
                                      blurRadius: 14,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.shield_outlined, size: 19, color: Color(0xFF16A34A)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            context.tr('connected_caregivers'),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      context.tr('active_caregivers_fmt', params: {'count': linkedCaregivers.length.toString()}),
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              if (linkedCaregivers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, size: 18, color: isDark ? Colors.white38 : Colors.grey.shade500),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          context.tr('no_caregivers'),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ...linkedCaregivers.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final cg = entry.value;
                                  final cgId = cg['id']?.toString() ?? '';
                                  final cgName = cg['name']?.toString() ?? 'Caregiver';
                                  final cgEmail = cg['email']?.toString() ?? '';
                                  final dialNum = (cg['phone']?.toString().trim() ?? '').isNotEmpty
                                      ? cg['phone'].toString().trim()
                                      : caregiverPhone;
                                  final primaryCgId = userData?['primaryCaregiverId']?.toString().trim() ?? '';
                                  final isPrimary = primaryCgId.isNotEmpty
                                      ? (primaryCgId == cgId)
                                      : (index == 0);
                                  final isLast = index == linkedCaregivers.length - 1;

                                  return Container(
                                    margin: EdgeInsets.only(bottom: isLast ? 0 : 12),
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF141C1A) : const Color(0xFFF8FAFA),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isPrimary
                                            ? const Color(0xFF00796B)
                                            : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                                        width: isPrimary ? 1.6 : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 1. Top Row: Avatar + Name + Linked Badge + Call button
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.15),
                                              child: Text(
                                                cgName.isNotEmpty ? cgName[0].toUpperCase() : 'C',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF00796B),
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    cgName,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        context.tr('linked'),
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF16A34A),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (dialNum.isNotEmpty)
                                              InkWell(
                                                onTap: () {
                                                  launchUrl(Uri.parse('tel:$dialNum'), mode: LaunchMode.externalApplication);
                                                },
                                                borderRadius: BorderRadius.circular(10),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF00796B),
                                                    borderRadius: BorderRadius.circular(10),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFF00796B).withValues(alpha: 0.25),
                                                        blurRadius: 6,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: const Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.phone_in_talk_rounded, size: 14, color: Colors.white),
                                                      SizedBox(width: 5),
                                                      Text(
                                                        'Call',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Divider(
                                          height: 1,
                                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                                        ),
                                        const SizedBox(height: 10),

                                        // 2. Email Row (Full width, clear, no cut-off!)
                                        if (cgEmail.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              children: [
                                                Icon(Icons.email_outlined, size: 15, color: isDark ? Colors.white60 : const Color(0xFF4A6B63)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    cgEmail,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // 3. Phone Row (if available)
                                        if (dialNum.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 6),
                                            child: Row(
                                              children: [
                                                Icon(Icons.phone_android_rounded, size: 15, color: isDark ? Colors.white60 : const Color(0xFF4A6B63)),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    dialNum,
                                                    style: TextStyle(
                                                      fontSize: 12.5,
                                                      color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                        // 4. Primary SOS & 1-Tap Call Selector (When 2 or more caregivers are connected)
                                        if (linkedCaregivers.length > 1) ...[
                                          const SizedBox(height: 4),
                                          InkWell(
                                            onTap: () => _setPrimaryCaregiver(
                                              uid: uid,
                                              cgId: cgId,
                                              cgName: cgName,
                                              cgPhone: dialNum,
                                            ),
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: isPrimary
                                                    ? const Color(0xFF00796B).withValues(alpha: 0.12)
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isPrimary
                                                      ? const Color(0xFF00796B).withValues(alpha: 0.3)
                                                      : (isDark ? Colors.white12 : const Color(0xFFD1E0DC)),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    isPrimary
                                                        ? Icons.radio_button_checked_rounded
                                                        : Icons.radio_button_off_rounded,
                                                    size: 16,
                                                    color: isPrimary ? const Color(0xFF00796B) : Colors.grey,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      isPrimary
                                                          ? 'Primary Contact'
                                                          : 'Set as Primary Contact',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
                                                        color: isPrimary
                                                          ? const Color(0xFF00796B)
                                                          : (isDark ? Colors.white60 : Colors.grey.shade700),
                                                      ),
                                                    ),
                                                  ),
                                                  if (isPrimary)
                                                    const Icon(Icons.star_rounded, size: 16, color: Color(0xFF00796B)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),



                        // Aesthetic Log Out Button Card
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => LogoutConfirmDialog.show(context),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF261414) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF5A2525) : const Color(0xFFFECACA),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.logout_rounded,
                                      color: Color(0xFFDC2626),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.tr('logout'),
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFDC2626),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          context.tr('sign_out_device'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEmail = label.toLowerCase().contains('email');
    final double valueFontSize = isEmail
        ? (value.length > 26 ? 11.5 : (value.length > 20 ? 12.5 : 13.5))
        : 14.5;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white70 : const Color(0xFF4A6B63),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: valueColor ?? (isDark ? Colors.white : const Color(0xFF1B3B36)),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }
}
