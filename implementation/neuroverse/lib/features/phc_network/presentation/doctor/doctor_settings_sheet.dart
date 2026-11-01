import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../core/widgets/privacy_policy_dialog.dart';
import '../../data/phc_repository.dart';
import '../../../patient/common/language_selection_sheet.dart';
import '../../../patient/common/logout_confirm_dialog.dart';

class DoctorSettingsSheet extends StatelessWidget {
  const DoctorSettingsSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DoctorSettingsSheet(),
    );
  }

  // -------------------------------------------------------------
  // SOUND & AUDIO EFFECTS TOGGLE WITH CUES & SNACKBAR
  // -------------------------------------------------------------
  void _toggleSoundEffects(BuildContext context, bool val) {
    final appProvider = context.read<AppProvider>();
    appProvider.setAudioEffectsEnabled(val);

    VoiceService? voiceService;
    try {
      voiceService = context.read<VoiceService>();
      voiceService.setAudioEnabled(val);
    } catch (_) {}

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (val) {
      HapticFeedback.mediumImpact();
      SystemSound.play(SystemSoundType.click);
      try {
        voiceService?.playAudioTestCue(lang: appProvider.userLanguage ?? 'en');
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('sound_effects_sub_on'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF00796B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      HapticFeedback.lightImpact();
      try {
        voiceService?.stopGameAudio();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.volume_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('sound_effects_sub_off'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF475569),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  // -------------------------------------------------------------
  // PROTOCOL DIALOG (ICMR & WHO RURAL COGNITIVE STANDARDS)
  // -------------------------------------------------------------
  void _showClinicalProtocolDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2827) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_book_rounded, color: Color(0xFF00796B), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr('doc_clinical_protocols'),
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B3B36),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('doc_clinical_protocols_sub'),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : const Color(0xFF475569),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            _buildProtocolBullet(
              '1. Frontline Doorstep Mini-Assessment',
              'Frontline ASHA workers deploy 3-minute gamified memory, orientation & number trail stealth games with vernacular voice assistance.',
              isDark,
            ),
            const SizedBox(height: 10),
            _buildProtocolBullet(
              '2. Cognitive Score Triage Bands',
              'Score 8-10: Age-appropriate stable cognition.\nScore 5-7: Mild Cognitive Impairment (MCI) - monitor monthly.\nScore < 5: Severe Cognitive Decline - immediate Doctor OPD triage.',
              isDark,
            ),
            const SizedBox(height: 10),
            _buildProtocolBullet(
              '3. Telemetry & Referral Linkage',
              'All scores sync in real-time. Red alert cases automatically appear in the Doctor OPD triage hub with guardian call linkage.',
              isDark,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00796B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(context.tr('btn_cancel')),
          ),
        ],
      ),
    );
  }

  Widget _buildProtocolBullet(String title, String desc, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: isDark ? Colors.white70 : const Color(0xFF334155),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SECTION HEADER WITH ICON & SUBHEADING (PATIENT UI PARITY)
  // -------------------------------------------------------------
  Widget _buildSettingsSectionHeader({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: titleColor,
                  ),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: subtitleColor,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // CARD GROUP CONTAINER (CAREGIVER & PATIENT DESIGN SYSTEM)
  // -------------------------------------------------------------
  Widget _buildSettingsCardGroup({
    required Color cardBg,
    required Color cardBorder,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // SETTINGS TILE
  // -------------------------------------------------------------
  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    String? subtitle,
    required Color titleColor,
    required Color subtitleColor,
    Widget? trailing,
    VoidCallback? onTap,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: subtitleColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = PhcRepository();
    final doc = repo.doctor;
    final currentLang = appProvider.userLanguage ?? 'English';

    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final isSmall = screenWidth < 360;

    const primaryColor = Color(0xFF00796B);
    final titleColor = isDark ? Colors.white : const Color(0xFF1B3B36);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF4A6B63);
    final cardBg = isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9);
    final cardBorder = isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8);
    final dividerColor = isDark ? const Color(0xFF243330) : const Color(0xFFEAEFEF);
    final sheetBg = isDark ? const Color(0xFF182220) : Colors.white;

    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final viewPaddingBottom = mediaQuery.viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: screenHeight * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Drag Handle & Header
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isSmall ? 16 : 20,
                    14,
                    isSmall ? 16 : 20,
                    10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : const Color(0xFFD1E0DC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.settings_suggest_rounded,
                                    color: primaryColor,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('doctor_settings'),
                                        style: TextStyle(
                                          fontSize: isSmall ? 16.5 : 18,
                                          fontWeight: FontWeight.bold,
                                          color: titleColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        context.tr('doctor_settings_sub'),
                                        style: TextStyle(
                                          fontSize: isSmall ? 11 : 12,
                                          color: subtitleColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? Colors.white70 : Colors.grey.shade600,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: dividerColor),

                // 2. Scrollable Settings Body
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.fromLTRB(
                      isSmall ? 16 : 20,
                      14,
                      isSmall ? 16 : 20,
                      24 + viewPaddingBottom,
                    ),
                    children: [
                      // -------------------------------------------------
                      // TOP DOCTOR PROFILE SUMMARY CARD (Patient / ASHA Style)
                      // -------------------------------------------------
                      Container(
                        padding: EdgeInsets.all(isSmall ? 12 : 14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder, width: 1.1),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: isSmall ? 46 : 52,
                                  height: isSmall ? 46 : 52,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00897B), Color(0xFF004D40)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: primaryColor.withValues(alpha: 0.25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    doc.name.trim().isNotEmpty
                                        ? (doc.name.startsWith('Dr.') ? 'Dr' : doc.name[0].toUpperCase())
                                        : 'Dr',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: isSmall ? 17 : 19,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -1,
                                  bottom: -1,
                                  child: Container(
                                    width: 17,
                                    height: 17,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF141C1A) : Colors.white,
                                        width: 1.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.check_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: isSmall ? 10 : 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          doc.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: isSmall ? 14.5 : 15.5,
                                            color: titleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 14,
                                        color: Color(0xFF00796B),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    doc.designation.isNotEmpty
                                        ? doc.designation
                                        : 'Medical Officer In-Charge',
                                    style: TextStyle(
                                      fontSize: isSmall ? 11 : 12,
                                      color: subtitleColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      if (doc.doctorRegNo.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: isDark ? 0.25 : 0.10),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            doc.doctorRegNo,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.lightBlueAccent : Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(alpha: isDark ? 0.25 : 0.10),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          context.tr('doc_active_medical_officers'),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.greenAccent : Colors.green.shade800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // -------------------------------------------------
                      // SECTION 1: SYSTEM & DISPLAY PREFERENCES
                      // -------------------------------------------------
                      _buildSettingsSectionHeader(
                        icon: Icons.tune_rounded,
                        iconColor: const Color(0xFF00796B),
                        iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.12),
                        title: context.tr('doc_sec_preferences'),
                        subtitle: context.tr('doc_sec_preferences_sub'),
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                      ),
                      _buildSettingsCardGroup(
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        children: [
                          // Language Selector
                          _buildSettingsTile(
                            icon: Icons.translate_rounded,
                            iconColor: const Color(0xFF00796B),
                            iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.12),
                            title: context.tr('app_display_language'),
                            subtitle: currentLang,
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  currentLang,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF00796B),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 20),
                              ],
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              LanguageSelectionSheet.show(context, isVoice: false);
                            },
                          ),
                          Divider(height: 1, color: dividerColor),

                          // Dark Mode Switch
                          _buildSettingsTile(
                            icon: appProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            iconColor: appProvider.isDarkMode ? Colors.amber : const Color(0xFF00796B),
                            iconBgColor: (appProvider.isDarkMode ? Colors.amber : const Color(0xFF00796B))
                                .withValues(alpha: 0.12),
                            title: context.tr('dark_mode'),
                            subtitle: appProvider.isDarkMode
                                ? context.tr('dark_mode_sub_on')
                                : context.tr('dark_mode_sub_off'),
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                            trailing: Switch.adaptive(
                              value: appProvider.isDarkMode,
                              activeThumbColor: primaryColor,
                              onChanged: (val) {
                                HapticFeedback.selectionClick();
                                appProvider.setDarkMode(val);
                              },
                            ),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              appProvider.setDarkMode(!appProvider.isDarkMode);
                            },
                          ),
                          Divider(height: 1, color: dividerColor),

                          // Audio & Sound Effects Switch
                          _buildSettingsTile(
                            icon: appProvider.isAudioEffectsEnabled
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            iconColor: appProvider.isAudioEffectsEnabled ? const Color(0xFF00796B) : Colors.grey,
                            iconBgColor: (appProvider.isAudioEffectsEnabled ? const Color(0xFF00796B) : Colors.grey)
                                .withValues(alpha: 0.12),
                            title: context.tr('sound_effects'),
                            subtitle: appProvider.isAudioEffectsEnabled
                                ? context.tr('sound_effects_sub_on')
                                : context.tr('sound_effects_sub_off'),
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                            trailing: Switch.adaptive(
                              value: appProvider.isAudioEffectsEnabled,
                              activeThumbColor: primaryColor,
                              onChanged: (val) => _toggleSoundEffects(context, val),
                            ),
                            onTap: () => _toggleSoundEffects(context, !appProvider.isAudioEffectsEnabled),
                          ),
                        ],
                      ),


                      // -------------------------------------------------
                      // SECTION 2: CLINICAL OPERATIONS & TELEMETRY
                      // -------------------------------------------------
                      _buildSettingsSectionHeader(
                        icon: Icons.cloud_sync_rounded,
                        iconColor: const Color(0xFF00897B),
                        iconBgColor: const Color(0xFF00897B).withValues(alpha: 0.12),
                        title: context.tr('doc_sec_clinical_ops'),
                        subtitle: context.tr('doc_sec_clinical_ops_sub'),
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                      ),
                      _buildSettingsCardGroup(
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        children: [
                          // Field Data Sync Status
                          _buildSettingsTile(
                            icon: Icons.sync_rounded,
                            iconColor: const Color(0xFF00897B),
                            iconBgColor: const Color(0xFF00897B).withValues(alpha: 0.12),
                            title: context.tr('doc_field_sync'),
                            subtitle: context.tr('doc_field_sync_sub'),
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                            trailing: IconButton(
                              icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF00897B)),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF00796B),
                                    content: Text(context.tr('doc_field_sync_success')),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF00796B),
                                  content: Text(context.tr('doc_field_sync_success')),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                          Divider(height: 1, color: dividerColor),

                          // Clinical Screening Protocols
                          _buildSettingsTile(
                            icon: Icons.menu_book_rounded,
                            iconColor: const Color(0xFFE65100),
                            iconBgColor: const Color(0xFFE65100).withValues(alpha: 0.12),
                            title: context.tr('doc_clinical_protocols'),
                            subtitle: context.tr('doc_clinical_protocols_sub'),
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                            trailing: Icon(Icons.info_outline_rounded, color: subtitleColor, size: 20),
                            onTap: () => _showClinicalProtocolDialog(context),
                          ),
                        ],
                      ),

                      // -------------------------------------------------
                      // SECTION 3: APPLICATION & GOVERNANCE
                      // -------------------------------------------------
                      _buildSettingsSectionHeader(
                        icon: Icons.info_outline_rounded,
                        iconColor: const Color(0xFF455A64),
                        iconBgColor: const Color(0xFF455A64).withValues(alpha: 0.12),
                        title: context.tr('doc_sec_app_info'),
                        subtitle: context.tr('doc_sec_app_info_sub'),
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                      ),
                      _buildSettingsCardGroup(
                        cardBg: cardBg,
                        cardBorder: cardBorder,
                        children: [
                          // Platform Version
                          _buildSettingsTile(
                            icon: Icons.verified_rounded,
                            iconColor: const Color(0xFF00796B),
                            iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.12),
                            title: context.tr('doc_app_version_title'),
                            subtitle: context.tr('doc_app_version_sub'),
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                          ),
                          Divider(height: 1, color: dividerColor),

                          // Privacy Policy
                          _buildSettingsTile(
                            icon: Icons.privacy_tip_outlined,
                            iconColor: const Color(0xFF0288D1),
                            iconBgColor: const Color(0xFF0288D1).withValues(alpha: 0.12),
                            title: context.tr('doc_privacy_policy'),
                            subtitle: context.tr('doc_privacy_policy_sub'),
                            titleColor: titleColor,
                            subtitleColor: subtitleColor,
                            trailing: Icon(Icons.chevron_right_rounded, color: subtitleColor, size: 20),
                            onTap: () {
                              Navigator.pop(context);
                              showPrivacyPolicyDialog(context);
                            },
                          ),
                        ],
                      ),

                      // -------------------------------------------------
                      // SECTION 4: ACCOUNT & SESSION
                      // -------------------------------------------------
                      _buildSettingsSectionHeader(
                        icon: Icons.security_rounded,
                        iconColor: Colors.red,
                        iconBgColor: Colors.red.withValues(alpha: 0.12),
                        title: context.tr('doc_sec_account'),
                        subtitle: context.tr('doc_sec_account_sub'),
                        titleColor: titleColor,
                        subtitleColor: subtitleColor,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A1515) : const Color(0xFFFFF5F5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? const Color(0xFF5A2525) : const Color(0xFFFED7D7),
                            width: 1.2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                LogoutConfirmDialog.show(context);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            context.tr('doc_logout_session'),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            context.tr('doc_logout_sub'),
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: isDark ? Colors.red.shade200 : Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded, color: Colors.red.shade400, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
