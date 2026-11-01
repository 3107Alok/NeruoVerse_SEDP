import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../data/phc_repository.dart';
import 'asha_sync_screen.dart';
import 'asha_profile_tab.dart';
import '../../../patient/common/language_selection_sheet.dart';
import '../../../patient/common/logout_confirm_dialog.dart';

class AshaSettingsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  const AshaSettingsScreen({super.key, this.onNavigateToProfile});

  static void show(BuildContext context, {VoidCallback? onNavigateToProfile}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AshaSettingsScreen(onNavigateToProfile: onNavigateToProfile),
    );
  }

  @override
  State<AshaSettingsScreen> createState() => _AshaSettingsScreenState();
}

typedef AshaSettingsSheet = AshaSettingsScreen;

class _AshaSettingsScreenState extends State<AshaSettingsScreen> {
  // -------------------------------------------------------------
  // SOUND & AUDIO EFFECTS (PATIENT ACCOUNT PARITY)
  // -------------------------------------------------------------
  void _toggleSoundEffects(bool val) {
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
                  context.tr('sound_effects_on'),
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
                  context.tr('sound_effects_off'),
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
  // DIALOG: 6-LANGUAGE SELECTION (SILENT & IMMEDIATE)
  // -------------------------------------------------------------
  void _showLanguageDialog() {
    LanguageSelectionSheet.show(context, isVoice: false);
  }

  // -------------------------------------------------------------
  // DIALOG: UPDATE PHC FACILITY CODE & JURISDICTION
  // -------------------------------------------------------------
  void _showUpdatePhcDialog() {
    final repo = PhcRepository();
    final asha = repo.currentAsha;
    final phcController = TextEditingController(text: asha.facilityCode);
    final villageController = TextEditingController(text: asha.villageCluster);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final theme = Theme.of(ctx);
        final fieldFill = isDark ? const Color(0xFF1E2827) : const Color(0xFFF8FAFC);
        final fieldBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8)),
        );
        final fieldFocused = OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
        );

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162422) : theme.cardColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('asha_update_phc_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                context.tr('asha_update_phc_sub'),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                            padding: const EdgeInsets.all(7),
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: phcController,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                          decoration: InputDecoration(
                            labelText: context.tr('asha_phc_code_input'),
                            labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            hintText: 'e.g. PHC-JHT-108',
                            prefixIcon: const Icon(Icons.pin_outlined, size: 20, color: Color(0xFF00796B)),
                            filled: true,
                            fillColor: fieldFill,
                            border: fieldBorder,
                            enabledBorder: fieldBorder,
                            focusedBorder: fieldFocused,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: villageController,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                          decoration: InputDecoration(
                            labelText: context.tr('asha_assigned_cluster'),
                            labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            hintText: 'e.g. Majuli North, Teok',
                            prefixIcon: const Icon(Icons.location_city_outlined, size: 20, color: Color(0xFF00796B)),
                            filled: true,
                            fillColor: fieldFill,
                            border: fieldBorder,
                            enabledBorder: fieldBorder,
                            focusedBorder: fieldFocused,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00897B), Color(0xFF004D40)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00796B).withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final newCode = phcController.text.trim();
                              if (newCode.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text(context.tr('asha_valid_phc_warning')),
                                  ),
                                );
                                return;
                              }

                              await repo.updateAshaPhcFacility(
                                facilityCode: newCode,
                                villageCluster: villageController.text.trim(),
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF00796B),
                                    content: Text(context.tr('asha_phc_updated_snack', params: {'code': newCode})),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                            label: Text(context.tr('asha_save_phc_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // DIALOG: CLINICAL SCREENING PROTOCOL INFORMATION
  // -------------------------------------------------------------
  void _showClinicalProtocolDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final theme = Theme.of(ctx);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF162422) : theme.cardColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF00897B), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('clinical_protocol'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                context.tr('clinical_protocol_sub'),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProtocolPoint(
                            icon: Icons.filter_1_rounded,
                            title: 'Frontline Community Baseline',
                            desc: 'Screen all elders aged 60+ in your assigned cluster twice a year using standardized tablet exercises.',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          _buildProtocolPoint(
                            icon: Icons.filter_2_rounded,
                            title: 'Multi-Domain Evaluation',
                            desc: 'Assesses temporal orientation, memory recall, visuospatial clock drawing, and reaction response accuracy.',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          _buildProtocolPoint(
                            icon: Icons.filter_3_rounded,
                            title: 'Automatic Risk Stratification',
                            desc: 'Scores >= 70%: Age-normal baseline. Scores 50-69%: Mild cognitive risk. Scores < 50%: High Risk.',
                            isDark: isDark,
                          ),
                          const SizedBox(height: 14),
                          _buildProtocolPoint(
                            icon: Icons.medical_services_outlined,
                            title: 'Medical Officer Escalation',
                            desc: 'Elders with steep score drops (>= 15 pts) or High Risk are prioritized for Medical Officer OPD consultation.',
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00796B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Understood', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProtocolPoint({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF00796B), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: isDark ? Colors.white : const Color(0xFF1B3B36),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF475569),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  // -------------------------------------------------------------
  // SETTINGS UI BUILDING BLOCKS (CAREGIVER & PATIENT DESIGN SYSTEM)
  // -------------------------------------------------------------
  Widget _buildSettingsSectionHeader(String title, Color subtitleColor) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6, top: 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: subtitleColor,
        ),
      ),
    );
  }

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
          padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.5,
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
                          fontSize: 12,
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
                Flexible(
                  flex: 0,
                  fit: FlexFit.loose,
                  child: trailing,
                ),
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
    final asha = repo.currentAsha;
    final currentLang = appProvider.userLanguage ?? 'English';
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isSmall = screenWidth < 360;

    const primaryColor = Color(0xFF00796B);
    final titleColor = isDark ? Colors.white : const Color(0xFF1B3B36);
    final subtitleColor = isDark ? Colors.white60 : const Color(0xFF4A6B63);
    final cardBg = isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9);
    final cardBorder = isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8);
    final dividerColor = isDark ? const Color(0xFF243330) : const Color(0xFFEAEFEF);

    final viewInsetsBottom = mediaQuery.viewInsets.bottom;
    final viewPaddingBottom = mediaQuery.viewPadding.bottom;
    final screenHeight = mediaQuery.size.height;
    final sheetBg = isDark ? const Color(0xFF182220) : Colors.white;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsetsBottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 540,
          maxHeight: screenHeight * 0.88,
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
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.settings_rounded,
                                  color: primaryColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.tr('asha_settings'),
                                      style: TextStyle(
                                        fontSize: isSmall ? 17 : 18.5,
                                        fontWeight: FontWeight.bold,
                                        color: titleColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      context.tr('asha_settings_sub'),
                                      style: TextStyle(
                                        fontSize: isSmall ? 11.5 : 12.5,
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
          // ---------------------------------------------------------
          // TOP PROFILE SUMMARY CARD (Patient / Caregiver Style)
          // ---------------------------------------------------------
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 14),
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
                      width: isSmall ? 44 : 50,
                      height: isSmall ? 44 : 50,
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
                        asha.name.trim().isNotEmpty ? asha.name.trim()[0].toUpperCase() : 'A',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: isSmall ? 19 : 22,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: isSmall ? 15 : 17,
                        height: isSmall ? 15 : 17,
                        decoration: BoxDecoration(
                          color: asha.isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF141C1A) : Colors.white,
                            width: 1.8,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: isSmall ? 9 : 10,
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
                      Text(
                        asha.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isSmall ? 14 : 15.5,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${context.localizeVillage(asha.villageCluster)} · ${asha.facilityCode}',
                        style: TextStyle(
                          fontSize: isSmall ? 11 : 12,
                          color: subtitleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.tr('asha_id_prefix_fmt', params: {'id': asha.id}),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    if (widget.onNavigateToProfile != null) {
                      widget.onNavigateToProfile!();
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AshaProfileTab(isStandalone: true),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: primaryColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: primaryColor,
                        ),
                        if (!isSmall) ...[
                          const SizedBox(width: 4),
                          Text(
                            context.tr('view_profile'),
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // SECTION 1: PREFERENCES
          // ---------------------------------------------------------
          _buildSettingsSectionHeader(context.tr('preferences'), subtitleColor),
          _buildSettingsCardGroup(
            cardBg: cardBg,
            cardBorder: cardBorder,
            children: [
              // 1. Dark Mode
              _buildSettingsTile(
                icon: appProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                iconColor: appProvider.isDarkMode ? const Color(0xFFD97706) : primaryColor,
                iconBgColor: (appProvider.isDarkMode ? const Color(0xFFD97706) : primaryColor).withValues(alpha: 0.1),
                title: context.tr('dark_mode'),
                subtitle: appProvider.isDarkMode ? context.tr('dark_theme_on') : context.tr('light_theme_on'),
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Switch.adaptive(
                  value: appProvider.isDarkMode,
                  activeThumbColor: primaryColor,
                  activeTrackColor: primaryColor.withValues(alpha: 0.5),
                  onChanged: (val) => appProvider.setDarkMode(val),
                ),
                onTap: () => appProvider.setDarkMode(!appProvider.isDarkMode),
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),

              // 2. Sound & Audio Effects
              _buildSettingsTile(
                icon: appProvider.isAudioEffectsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                iconColor: appProvider.isAudioEffectsEnabled ? primaryColor : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                iconBgColor: (appProvider.isAudioEffectsEnabled ? primaryColor : Colors.grey).withValues(alpha: 0.1),
                title: context.tr('sound_effects'),
                subtitle: appProvider.isAudioEffectsEnabled
                    ? context.tr('sound_effects_sub')
                    : context.tr('sound_effects_off'),
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Switch.adaptive(
                  value: appProvider.isAudioEffectsEnabled,
                  activeThumbColor: primaryColor,
                  activeTrackColor: primaryColor.withValues(alpha: 0.5),
                  onChanged: (val) => _toggleSoundEffects(val),
                ),
                onTap: () => _toggleSoundEffects(!appProvider.isAudioEffectsEnabled),
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),

              // 3. App Display Language (6-language instant silent switch)
              _buildSettingsTile(
                icon: Icons.translate_rounded,
                iconColor: primaryColor,
                iconBgColor: primaryColor.withValues(alpha: 0.1),
                title: context.tr('app_language'),
                subtitle: context.tr('app_language_sub'),
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: primaryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currentLang,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 14, color: primaryColor),
                    ],
                  ),
                ),
                onTap: _showLanguageDialog,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // SECTION 2: FIELD OPERATIONS & PHC JURISDICTION
          // ---------------------------------------------------------
          _buildSettingsSectionHeader(context.tr('field_operations'), subtitleColor),
          _buildSettingsCardGroup(
            cardBg: cardBg,
            cardBorder: cardBorder,
            children: [
              // 1. PHC Facility Code
              _buildSettingsTile(
                icon: Icons.local_hospital_rounded,
                iconColor: primaryColor,
                iconBgColor: primaryColor.withValues(alpha: 0.1),
                title: context.tr('asha_phc_code_input'),
                subtitle: asha.facilityCode,
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        asha.facilityCode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_rounded, size: 13, color: primaryColor),
                    ],
                  ),
                ),
                onTap: _showUpdatePhcDialog,
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),

              // 2. Assigned Village Cluster
              _buildSettingsTile(
                icon: Icons.location_on_rounded,
                iconColor: primaryColor,
                iconBgColor: primaryColor.withValues(alpha: 0.1),
                title: context.tr('asha_assigned_cluster'),
                subtitle: context.localizeVillage(asha.villageCluster),
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
                onTap: _showUpdatePhcDialog,
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),

              // 3. Field Data Synchronization
              _buildSettingsTile(
                icon: Icons.sync_rounded,
                iconColor: repo.pendingSyncCount > 0 ? const Color(0xFFD97706) : primaryColor,
                iconBgColor: (repo.pendingSyncCount > 0 ? const Color(0xFFD97706) : primaryColor).withValues(alpha: 0.1),
                title: context.tr('asha_sync_overview'),
                subtitle: repo.pendingSyncCount == 0
                    ? context.tr('offline_sync_done')
                    : context.tr('offline_sync_pending', params: {'count': repo.pendingSyncCount.toString()}),
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isSmall ? 85 : 120),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (repo.pendingSyncCount > 0 ? const Color(0xFFD97706) : const Color(0xFF10B981)).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          repo.pendingSyncCount > 0
                              ? '${repo.pendingSyncCount} ${context.tr('status_pending')}'
                              : context.tr('status_synced'),
                          style: TextStyle(
                            fontSize: isSmall ? 10 : 11,
                            fontWeight: FontWeight.bold,
                            color: repo.pendingSyncCount > 0 ? const Color(0xFFD97706) : const Color(0xFF10B981),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isDark ? Colors.white38 : Colors.grey.shade400,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AshaSyncScreen()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // SECTION 3: CARE & NOTIFICATIONS
          // ---------------------------------------------------------
          _buildSettingsSectionHeader(context.tr('notifications'), subtitleColor),
          _buildSettingsCardGroup(
            cardBg: cardBg,
            cardBorder: cardBorder,
            children: [
              // Critical Case Alerts
              _buildSettingsTile(
                icon: Icons.notifications_active_outlined,
                iconColor: primaryColor,
                iconBgColor: primaryColor.withValues(alpha: 0.1),
                title: context.tr('critical_alerts'),
                subtitle: context.tr('critical_alerts_sub'),
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Switch.adaptive(
                  value: appProvider.criticalAlerts,
                  activeThumbColor: primaryColor,
                  activeTrackColor: primaryColor.withValues(alpha: 0.5),
                  onChanged: (val) => appProvider.setCriticalAlerts(val),
                ),
                onTap: () => appProvider.setCriticalAlerts(!appProvider.criticalAlerts),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // SECTION 4: APPLICATION INFO
          // ---------------------------------------------------------
          _buildSettingsSectionHeader(context.tr('application_info'), subtitleColor),
          _buildSettingsCardGroup(
            cardBg: cardBg,
            cardBorder: cardBorder,
            children: [
              // 1. Frontline Screening Protocol
              _buildSettingsTile(
                icon: Icons.assignment_outlined,
                iconColor: primaryColor,
                iconBgColor: primaryColor.withValues(alpha: 0.1),
                title: context.tr('clinical_protocol'),
                subtitle: context.tr('clinical_protocol_sub'),
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.grey.shade400,
                ),
                onTap: _showClinicalProtocolDialog,
              ),
              Divider(height: 1, thickness: 1, color: dividerColor),

              // 2. App Version
              _buildSettingsTile(
                icon: Icons.verified_outlined,
                iconColor: const Color(0xFF64748B),
                iconBgColor: const Color(0xFF64748B).withValues(alpha: 0.1),
                title: context.tr('app_version'),
                subtitle: 'NeuroVerse Frontline Health Suite',
                titleColor: titleColor,
                subtitleColor: subtitleColor,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'v2.4 PHC',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ---------------------------------------------------------
          // SECTION 5: ACCOUNT
          // ---------------------------------------------------------
          _buildSettingsSectionHeader(context.tr('account'), subtitleColor),

          // Aesthetic Log Out Button Card
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => LogoutConfirmDialog.show(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF261414) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF5A2525) : const Color(0xFFFECACA),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.08 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
