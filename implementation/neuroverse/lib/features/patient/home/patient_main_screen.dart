import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/services/firebase_link_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/voice_service.dart';
import 'patient_home_tab.dart';
import 'widgets/games_navigation_hint.dart';
import '../games/game_hub/game_hub_tab.dart';
import '../progress/patient_progress_tab.dart';
import '../profile/patient_profile_tab.dart';
import '../voice/voice_mode_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../data/local/hive_service.dart';
import '../../../../core/services/sync_service.dart';
import '../../auth/auth_screen.dart';
import '../../../../core/localization/app_translations.dart';
import '../common/language_selection_sheet.dart';
import '../common/logout_confirm_dialog.dart';
import '../reminders/patient_reminders_screen.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/widgets/privacy_policy_dialog.dart';

class PatientMainScreen extends StatefulWidget {
  const PatientMainScreen({super.key});

  static Widget buildSettingsSectionHeader(String title, Color subtitleColor) {
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

  static Widget buildSettingsCardGroup({
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

  static Widget buildSettingsTile({
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
          padding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                        fontSize: 15,
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
                          fontSize: 12.5,
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

  static void openSettingsSheet(
    BuildContext context, {
    bool initialNotifications = true,
    bool initialAudio = true,
    ValueChanged<bool>? onNotificationsChanged,
    ValueChanged<bool>? onAudioChanged,
    VoidCallback? onEditProfile,
    VoidCallback? onSignOut,
  }) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final provider = context.watch<AppProvider>();
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final mediaQuery = MediaQuery.of(ctx);
            final screenHeight = mediaQuery.size.height;
            final screenWidth = mediaQuery.size.width;
            final viewInsetsBottom = mediaQuery.viewInsets.bottom;
            final viewPaddingBottom = mediaQuery.viewPadding.bottom;
            final isSmall = screenWidth < 360;

            const primaryColor = Color(0xFF00796B);
            final titleColor = isDark ? Colors.white : const Color(0xFF1B3B36);
            final subtitleColor = isDark ? Colors.white60 : const Color(0xFF4A6B63);
            final sheetBg = isDark ? const Color(0xFF182220) : Colors.white;
            final cardBg = isDark ? const Color(0xFF141C1A) : const Color(0xFFF7FAF9);
            final cardBorder = isDark ? const Color(0xFF2B3A36) : const Color(0xFFE2ECE8);
            final dividerColor = isDark ? const Color(0xFF243330) : const Color(0xFFEAEFEF);

            final userName = provider.userName?.trim().isNotEmpty == true
                ? provider.userName!.trim()
                : 'Patient User';
            final userInitial = userName.isNotEmpty ? userName[0].toUpperCase() : 'P';

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
                                          color: Color(0xFF00796B),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ctx.tr('patient_settings'),
                                              style: TextStyle(
                                                fontSize: isSmall ? 17 : 18.5,
                                                fontWeight: FontWeight.bold,
                                                color: titleColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              ctx.tr('settings_sub'),
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
                                  onPressed: () => Navigator.pop(ctx),
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
                            0,
                          ),
                          children: [
                            // Profile Summary Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cardBorder, width: 1.1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF00796B), Color(0xFF004D40)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      userInitial,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          userName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: titleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          user?.email ?? 'Logged in patient',
                                          style: TextStyle(
                                            fontSize: (user?.email?.length ?? 0) > 24 ? 11.5 : 12.0,
                                            color: subtitleColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(ctx);
                                      onEditProfile?.call();
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                                            Icons.mode_edit_outline_rounded,
                                            size: 14,
                                            color: Color(0xFF00796B),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            ctx.tr('edit'),
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF00796B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Section 1: PREFERENCES
                            buildSettingsSectionHeader(ctx.tr('preferences'), subtitleColor),
                            buildSettingsCardGroup(
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              children: [
                                // 1. Dark Mode
                                buildSettingsTile(
                                  icon: provider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  iconColor: provider.isDarkMode ? const Color(0xFFD97706) : const Color(0xFF00796B),
                                  iconBgColor: (provider.isDarkMode ? const Color(0xFFD97706) : const Color(0xFF00796B)).withValues(alpha: 0.1),
                                  title: ctx.tr('dark_mode'),
                                  subtitle: provider.isDarkMode ? ctx.tr('dark_theme_on') : ctx.tr('light_theme_on'),
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Switch.adaptive(
                                    value: provider.isDarkMode,
                                    activeThumbColor: const Color(0xFF00796B),
                                    activeTrackColor: const Color(0xFF00796B).withValues(alpha: 0.5),
                                    onChanged: (val) {
                                      provider.setDarkMode(val);
                                      setSheetState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    provider.setDarkMode(!provider.isDarkMode);
                                    setSheetState(() {});
                                  },
                                ),
                                Divider(height: 1, thickness: 1, color: dividerColor),

                                // 2. Sound & Audio Effects
                                buildSettingsTile(
                                  icon: provider.isAudioEffectsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                                  iconColor: provider.isAudioEffectsEnabled ? const Color(0xFF00796B) : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                                  iconBgColor: (provider.isAudioEffectsEnabled ? const Color(0xFF00796B) : Colors.grey).withValues(alpha: 0.1),
                                  title: ctx.tr('sound_effects'),
                                  subtitle: provider.isAudioEffectsEnabled
                                      ? ctx.tr('sound_effects_sub')
                                      : ctx.tr('sound_effects_off'),
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Switch.adaptive(
                                    value: provider.isAudioEffectsEnabled,
                                    activeThumbColor: const Color(0xFF00796B),
                                    activeTrackColor: const Color(0xFF00796B).withValues(alpha: 0.5),
                                    onChanged: (val) {
                                      provider.setAudioEffectsEnabled(val);
                                      final voiceService = ctx.read<VoiceService>();
                                      voiceService.setAudioEnabled(val);
                                      setSheetState(() {});
                                      onAudioChanged?.call(val);
                                      if (val) {
                                        HapticFeedback.mediumImpact();
                                        SystemSound.play(SystemSoundType.click);
                                        voiceService.playAudioTestCue(lang: provider.userLanguage ?? 'en');
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  ctx.tr('sound_effects_on'),
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                                        voiceService.stopGameAudio();
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.volume_off_rounded, color: Colors.white, size: 20),
                                                const SizedBox(width: 8),
                                                Text(
                                                  ctx.tr('sound_effects_off'),
                                                  style: const TextStyle(fontWeight: FontWeight.bold),
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
                                    },
                                  ),
                                  onTap: () {
                                    final val = !provider.isAudioEffectsEnabled;
                                    provider.setAudioEffectsEnabled(val);
                                    final voiceService = ctx.read<VoiceService>();
                                    voiceService.setAudioEnabled(val);
                                    setSheetState(() {});
                                    onAudioChanged?.call(val);
                                    if (val) {
                                      HapticFeedback.mediumImpact();
                                      SystemSound.play(SystemSoundType.click);
                                      voiceService.playAudioTestCue(lang: provider.userLanguage ?? 'en');
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                ctx.tr('sound_effects_on'),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
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
                                      voiceService.stopGameAudio();
                                      ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              const Icon(Icons.volume_off_rounded, color: Colors.white, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                ctx.tr('sound_effects_off'),
                                                style: const TextStyle(fontWeight: FontWeight.bold),
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
                                  },
                                ),
                                Divider(height: 1, thickness: 1, color: dividerColor),

                                // 3. App Display Language
                                buildSettingsTile(
                                  icon: Icons.translate_rounded,
                                  iconColor: const Color(0xFF00796B),
                                  iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  title: ctx.tr('app_language'),
                                  subtitle: ctx.tr('app_language_sub'),
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00796B).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF00796B).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          provider.userLanguage ?? 'English',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF00796B),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.edit_rounded, size: 14, color: Color(0xFF00796B)),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    LanguageSelectionSheet.show(ctx, isVoice: false);
                                  },
                                ),
                                Divider(height: 1, thickness: 1, color: dividerColor),

                                // 4. Voice Assistant Language
                                buildSettingsTile(
                                  icon: Icons.record_voice_over_rounded,
                                  iconColor: const Color(0xFF8B5CF6),
                                  iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                  title: ctx.tr('voice_language'),
                                  subtitle: ctx.tr('voice_language_sub'),
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          provider.voiceLanguage ?? provider.userLanguage ?? 'English',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.mic_rounded, size: 14, color: Color(0xFF8B5CF6)),
                                      ],
                                    ),
                                  ),
                                  onTap: () {
                                    LanguageSelectionSheet.show(ctx, isVoice: true);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Section 2: SCHEDULE & REMINDERS
                            buildSettingsSectionHeader(ctx.tr('schedule_reminders'), subtitleColor),
                            buildSettingsCardGroup(
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              children: [
                                // Reminders Screen Navigation
                                buildSettingsTile(
                                  icon: Icons.alarm_rounded,
                                  iconColor: const Color(0xFF00796B),
                                  iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  title: ctx.tr('reminders'),
                                  subtitle: ctx.tr('reminders_sub'),
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  onTap: () {
                                    Navigator.of(ctx).push(
                                      MaterialPageRoute(
                                        builder: (_) => const PatientRemindersScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Section 3: APPLICATION INFO
                            buildSettingsSectionHeader(ctx.tr('application_info'), subtitleColor),
                            buildSettingsCardGroup(
                              cardBg: cardBg,
                              cardBorder: cardBorder,
                              children: [
                                buildSettingsTile(
                                  icon: Icons.shield_outlined,
                                  iconColor: const Color(0xFF00796B),
                                  iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  title: ctx.tr('privacy_policy'),
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    showPrivacyPolicyDialog(context);
                                  },
                                ),
                                Divider(height: 1, thickness: 1, color: dividerColor),
                                buildSettingsTile(
                                  icon: Icons.info_outline_rounded,
                                  iconColor: const Color(0xFF00796B),
                                  iconBgColor: const Color(0xFF00796B).withValues(alpha: 0.1),
                                  title: ctx.tr('app_version'),
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                  trailing: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(
                                      'v1.0.0',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF00796B),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Section 4: ACCOUNT
                            buildSettingsSectionHeader(ctx.tr('account'), subtitleColor),
                            buildSettingsCardGroup(
                              cardBg: isDark ? const Color(0xFF241616) : const Color(0xFFFFF7F7),
                              cardBorder: isDark ? const Color(0xFF422222) : const Color(0xFFFED7D7),
                              children: [
                                // Logout
                                buildSettingsTile(
                                  icon: Icons.logout_rounded,
                                  iconColor: const Color(0xFFDC2626),
                                  iconBgColor: const Color(0xFFDC2626).withValues(alpha: 0.1),
                                  title: ctx.tr('logout'),
                                  titleColor: const Color(0xFFDC2626),
                                  subtitleColor: subtitleColor,
                                  trailing: const Icon(
                                    Icons.chevron_right_rounded,
                                    size: 20,
                                    color: Color(0xFFDC2626),
                                  ),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    LogoutConfirmDialog.show(context);
                                  },
                                ),
                              ],
                            ),

                            // Extra comfortable bottom spacing respecting system navigation
                            const SizedBox(height: 14),
                            SizedBox(height: viewPaddingBottom > 0 ? viewPaddingBottom : 12.0),
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
      },
    );
  }

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final List<int> _tabHistory = [];
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    _dismissHint();
    if (index == 0) {
      _tabHistory.clear();
    } else {
      _tabHistory.remove(index);
      _tabHistory.add(_currentIndex);
    }
    setState(() => _currentIndex = index);
  }
  bool _notifications = true;
  StreamSubscription<QuerySnapshot>? _patientNotificationSub;
  StreamSubscription<QuerySnapshot>? _announcementsSub;
  StreamSubscription<DocumentSnapshot>? _userStatusSub;
  final Set<String> _initialSeenDocIds = {};
  bool _isFirstNotificationBatch = true;
  bool _isFirstAnnouncementBatch = true;
  Timer? _oneAMScheduleTimer;
  late AnimationController _syncController;
  late AnimationController _micPulseController;
  late Animation<double> _micBorderPulse;

  bool _showGamesHint = false;
  Timer? _gamesHintTimer;
  final GlobalKey _gamesTabKey = GlobalKey();

  void _dismissHint() {
    if (_showGamesHint) {
      _gamesHintTimer?.cancel();
      setState(() => _showGamesHint = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _micBorderPulse = Tween<double>(begin: 2.0, end: 4.5).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );
    
    // Schedule daily morning & evening catch-up reminders for patient
    try {
      NotificationService().scheduleDailyReminders().catchError((_) {});
    } catch (_) {}

    // One-time sync of Medicine & Hydration reminders from Firestore on app open
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        ReminderService().syncAndSchedulePatientReminders(uid).catchError((e) {
          debugPrint('Reminder sync on app launch notice: $e');
        });
      }
    } catch (_) {}

    _initRealtimeNotificationListeners();
    _autoClearPastNotifications();
    _scheduleNext1AMAutoClear();
    _listenToUserSuspension();

    // Show Games navigation hint only once per fresh app launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appProvider = context.read<AppProvider>();
      if (!appProvider.hasShownGamesHintThisSession && _currentIndex == 0) {
        appProvider.markGamesHintShown();
        setState(() => _showGamesHint = true);
        _gamesHintTimer = Timer(const Duration(seconds: 5), () {
          if (mounted && _showGamesHint) {
            setState(() => _showGamesHint = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _gamesHintTimer?.cancel();
    _userStatusSub?.cancel();
    _patientNotificationSub?.cancel();
    _announcementsSub?.cancel();
    _oneAMScheduleTimer?.cancel();
    _syncController.dispose();
    _micPulseController.dispose();
    super.dispose();
  }

  final List<Widget> _tabs = [
    const PatientHomeTab(),
    const GameHubTab(),
    const PatientProgressTab(),
    const PatientProfileTab(),
  ];

  Stream<QuerySnapshot>? _getLinkRequestsStream() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      return FirebaseFirestore.instance
          .collection('link_requests')
          .where('patientId', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    } catch (_) {
      return null;
    }
  }

  Stream<QuerySnapshot>? _getDirectNotificationsStream() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return null;
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
    } catch (_) {
      return null;
    }
  }

  void _listenToUserSuspension() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        _userStatusSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((doc) async {
          if (doc.exists && doc.data() != null) {
            final isSuspended = doc.data()?['isSuspended'] == true;
            if (isSuspended) {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.red,
                    content: Text(context.tr('account_suspended_msg')),
                    duration: const Duration(seconds: 5),
                  ),
                );
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            }
          }
        }, onError: (_) {});
      }
    } catch (_) {}
  }

  DateTime _getLatest1AMCutoff() {
    final now = DateTime.now();
    if (now.hour >= 1) {
      return DateTime(now.year, now.month, now.day, 1, 0, 0);
    } else {
      return DateTime(now.year, now.month, now.day, 1, 0, 0).subtract(const Duration(days: 1));
    }
  }

  void _scheduleNext1AMAutoClear() {
    _oneAMScheduleTimer?.cancel();
    final now = DateTime.now();
    DateTime next1AM = DateTime(now.year, now.month, now.day, 1, 0, 0);
    if (!next1AM.isAfter(now)) {
      next1AM = next1AM.add(const Duration(days: 1));
    }
    final delay = next1AM.difference(now);
    _oneAMScheduleTimer = Timer(delay, () {
      _autoClearPastNotifications();
      _scheduleNext1AMAutoClear();
      if (mounted) setState(() {});
    });
  }

  Future<void> _autoClearPastNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final cutoff1AM = _getLatest1AMCutoff();
      final oldDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      int deleteCount = 0;
      for (final doc in oldDocs.docs) {
        final data = doc.data();
        final ts = data['createdAt'];
        if (ts is Timestamp && ts.toDate().isBefore(cutoff1AM)) {
          batch.delete(doc.reference);
          deleteCount++;
        }
      }
      if (deleteCount > 0) {
        await batch.commit();
        debugPrint('Auto-cleared $deleteCount expired notifications before 1:00 AM.');
      }
    } catch (e) {
      debugPrint('Note on auto-clearing past notifications: $e');
    }
  }

  Stream<QuerySnapshot>? _getAnnouncementsStream() {
    try {
      return FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots();
    } catch (_) {
      return null;
    }
  }

  void _initRealtimeNotificationListeners() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    try {
      _patientNotificationSub = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .listen((snapshot) {
        if (_isFirstNotificationBatch) {
          for (final doc in snapshot.docs) {
            _initialSeenDocIds.add(doc.id);
          }
          _isFirstNotificationBatch = false;
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final doc = change.doc;
            if (!_initialSeenDocIds.contains(doc.id)) {
              _initialSeenDocIds.add(doc.id);
              final data = doc.data();
              if (data != null && data['isRead'] != true) {
                final title = data['title'] as String? ?? 'Caregiver Reminder';
                final body = data['body'] as String? ?? 'You have a new cognitive health reminder.';
                NotificationService().showNotification(
                  id: (doc.id.hashCode).abs() % 100000,
                  title: title,
                  body: body,
                );
              }
            }
          }
        }
      }, onError: (_) {});
    } catch (_) {}

    try {
      _announcementsSub = FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots()
          .listen((snapshot) {
        if (_isFirstAnnouncementBatch) {
          for (final doc in snapshot.docs) {
            _initialSeenDocIds.add(doc.id);
          }
          _isFirstAnnouncementBatch = false;
          return;
        }

        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final doc = change.doc;
            if (!_initialSeenDocIds.contains(doc.id)) {
              _initialSeenDocIds.add(doc.id);
              final data = doc.data();
              if (data != null) {
                final target = data['target'] as String? ?? 'all';
                if (target == 'all' || target == 'patient') {
                  final title = data['title'] as String? ?? 'System Announcement';
                  final body = data['message'] as String? ?? 'A new announcement has been posted.';
                  NotificationService().showNotification(
                    id: (doc.id.hashCode).abs() % 100000,
                    title: title,
                    body: body,
                  );
                }
              }
            }
          }
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDataSynced = context.watch<AppProvider>().isDataSynced;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

    final scaffold = Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/app_icon.jpg',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.psychology_rounded, size: 20, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NeuroVerse',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.5,
                    letterSpacing: 0.2,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                ),
                Text(
                  context.tr('care_together_tagline'),
                  style: TextStyle(
                    fontSize: 9.6,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    letterSpacing: -0.25,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            height: 1.0,
          ),
        ),
        actions: [
          // 1. Sync Button with Center Checkmark / Exclamation (Left of Notification)
          IconButton(
            icon: Container(
              padding: EdgeInsets.all(isSmall ? 3.5 : 4.5),
              decoration: BoxDecoration(
                color: isDataSynced
                    ? (isDark ? const Color(0xFF122822) : const Color(0xFFE0F2F1))
                    : (isDark ? const Color(0xFF2A1B1B) : const Color(0xFFFFEBEE)),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _syncController,
                    child: Icon(
                      Icons.sync_rounded,
                      size: isSmall ? 25 : 28,
                      color: isDataSynced
                          ? (isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B))
                          : (isDark ? const Color(0xFFEF5350) : const Color(0xFFDC2626)),
                    ),
                  ),
                  Icon(
                    isDataSynced ? Icons.check_rounded : Icons.priority_high_rounded,
                    size: isSmall ? 10 : 11.5,
                    color: isDataSynced
                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                        : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                    shadows: [
                      Shadow(
                        color: (isDataSynced
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF047857))
                                : (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)))
                            .withValues(alpha: 0.5),
                        blurRadius: 0.8,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            tooltip: 'Cloud Sync',
            onPressed: () async {
              if (_syncController.isAnimating) return;
              
              if (isDataSynced) {
                _showAlreadySyncedDialog(context);
                return;
              }

              _triggerForceSync();
            },
          ),

          // 2. Notification Button (Middle)
          StreamBuilder<QuerySnapshot>(
            stream: _getLinkRequestsStream(),
            builder: (context, linkSnap) {
              final requestCount = linkSnap.data?.docs.length ?? 0;
              return StreamBuilder<QuerySnapshot>(
                stream: _getDirectNotificationsStream(),
                builder: (context, notifSnap) {
                  final cutoff1AM = _getLatest1AMCutoff();
                  final unreadNotifs = (notifSnap.data?.docs ?? []).where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    if (data['isRead'] == true) return false;
                    final ts = data['createdAt'];
                    if (ts is Timestamp) {
                      return ts.toDate().isAfter(cutoff1AM);
                    }
                    return true;
                  }).length;
                  final totalCount = requestCount + unreadNotifs;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Builder(
                        builder: (innerContext) => IconButton(
                          icon: const Icon(Icons.notifications_none_rounded, size: 24),
                          tooltip: 'Notifications',
                          onPressed: () {
                            Scaffold.of(innerContext).openEndDrawer();
                          },
                        ),
                      ),
                      if (totalCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$totalCount',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              );
            },
          ),

          // 3. Settings Button (Top Right Outer Edge)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings_outlined, color: Color(0xFF00796B), size: 20),
            ),
            tooltip: 'Settings',
            onPressed: _openPatientSettingsSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),
      endDrawer: _buildNotificationDrawer(),
      body: _tabs[_currentIndex],
      floatingActionButton: AnimatedBuilder(
        animation: _micPulseController,
        builder: (context, child) {
          final pulseVal = _micPulseController.value;
          return Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.55 + (pulseVal * 0.45)),
                width: _micBorderPulse.value,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.35 + (pulseVal * 0.35)),
                  blurRadius: 10 + (pulseVal * 8),
                  spreadRadius: 1 + (pulseVal * 2),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (context) => const VoiceModeScreen(),
                );
              },
              backgroundColor: Theme.of(context).primaryColor,
              shape: const CircleBorder(),
              elevation: 4,
              child: const Icon(Icons.mic, color: Colors.white, size: 28),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Theme.of(context).scaffoldBackgroundColor,
        elevation: 16,
        shadowColor: Colors.black45,
        surfaceTintColor: Colors.transparent,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias, // Ensures internal borders follow the notch
        child: Container(
          height: 65,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: context.tr('nav_home'), index: 0)),
              Expanded(child: _buildNavItem(icon: Icons.sports_esports_outlined, activeIcon: Icons.sports_esports, label: context.tr('nav_games'), index: 1)),
              const SizedBox(width: 48), // Empty space for FAB
              Expanded(child: _buildNavItem(icon: Icons.bar_chart_rounded, activeIcon: Icons.bar_chart_rounded, label: context.tr('nav_progress'), index: 2)),
              Expanded(child: _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: context.tr('nav_profile'), index: 3)),
            ],
          ),
        ),
      ),
    );

    final Widget rootContent = (!_showGamesHint || _currentIndex != 0)
        ? scaffold
        : Stack(
            children: [
              scaffold,
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _dismissHint(),
                  child: IgnorePointer(
                    child: GamesNavigationHint(
                      isVisible: true,
                      targetKey: _gamesTabKey,
                    ),
                  ),
                ),
              ),
            ],
          );

    return PopScope(
      canPop: _currentIndex == 0 && _tabHistory.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeEndDrawer();
          return;
        }
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }
        if (_showGamesHint) {
          _dismissHint();
        }
        if (_tabHistory.isNotEmpty) {
          final prevTab = _tabHistory.removeLast();
          setState(() => _currentIndex = prevTab);
        } else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: rootContent,
    );
  }

  Widget _buildNotificationDrawer() {
    return PatientNotificationDrawer(
      linkRequestsStream: _getLinkRequestsStream(),
      directNotificationsStream: _getDirectNotificationsStream(),
      announcementsStream: _getAnnouncementsStream(),
      latest1AMCutoff: _getLatest1AMCutoff(),
      connectionRequestCardBuilder: _buildConnectionRequestCard,
      caregiverReminderCardBuilder: _buildCaregiverReminderCard,
      announcementCardBuilder: _buildAnnouncementCard,
    );
  }

  Widget _buildConnectionRequestCard(DocumentSnapshot doc, bool isDark) {
    final data = doc.data() as Map<String, dynamic>;
    final requestId = doc.id;
    final caregiverName = data['caregiverName'] ?? 'Caregiver';
    final caregiverId = data['caregiverId'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2829) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green circular app-themed avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00796B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00796B).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              caregiverName.isNotEmpty ? caregiverName[0].toUpperCase() : 'C',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right side: Heading + Grey message + compact actions
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Heading in black/dark bold
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Caregiver Request: $caregiverName',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PENDING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),

                // Grey message
                Text(
                  '$caregiverName wants to connect to monitor cognitive activity.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: isDark ? Colors.white70 : const Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 10),

                // Compact buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    InkWell(
                      onTap: () async {
                        await context.read<FirebaseLinkService>().rejectLinkRequest(requestId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.tr('declined_invitation_from_fmt', params: {'name': caregiverName})),
                              backgroundColor: Colors.grey.shade800,
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.tr('decline'),
                          style: const TextStyle(color: Colors.redAccent, fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        await context.read<FirebaseLinkService>().acceptLinkRequest(requestId, caregiverId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.tr('connected_with_caregiver_fmt', params: {'name': caregiverName})),
                              backgroundColor: const Color(0xFF00796B),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('accept'),
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ],
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
    );
  }

  Widget _buildCaregiverReminderCard(DocumentSnapshot doc, bool isDark) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Reminder';
    final body = data['body'] as String? ?? '';
    final senderName = data['senderName'] as String? ?? 'Caregiver';
    final isHighPriority = data['isHighPriority'] == true;
    final isRead = data['isRead'] == true;
    final type = data['type'] as String? ?? 'game_reminder';
    final isAppointment = type == 'doctor_appointment' ||
        title.toLowerCase().contains('doctor') ||
        title.toLowerCase().contains('appointment');
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return CaregiverReminderCard(
      title: title,
      body: body,
      senderName: senderName,
      isHighPriority: isHighPriority,
      isRead: isRead,
      isDark: isDark,
      isAppointment: isAppointment,
      onPlayNow: () async {
        if (uid != null) {
          try {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('notifications')
                .doc(doc.id)
                .update({'isRead': true});
          } catch (_) {}
        }
        if (!mounted) return;
        if (isAppointment) {
          _showAppointmentDetailsDialog(data, isDark);
        } else {
          Navigator.of(context).pop();
          _onTabTapped(1);
        }
      },
    );
  }

  void _showAppointmentDetailsDialog(Map<String, dynamic> data, bool isDark) {
    final doctorName = data['doctorName'] as String? ?? 'Doctor';
    final hospitalName = data['hospitalName'] as String? ?? 'Hospital / Clinic';
    final notes = data['notes'] as String? ?? '';
    final appointmentDateTimeStr = data['appointmentDateTime'] as String?;
    DateTime? dt;
    if (appointmentDateTimeStr != null) {
      try {
        dt = DateTime.parse(appointmentDateTimeStr);
      } catch (_) {}
    }
    final formattedDate = dt != null ? context.formatDate(dt, includeWeekday: true, includeYear: true) : context.tr('status_upcoming');
    final formattedTime = dt != null ? DateFormat('h:mm a').format(dt) : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E2829) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.medical_services_rounded, color: Color(0xFF00796B), size: 24),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Doctor Appointment',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAppointmentDetailItem('Doctor', doctorName, Icons.person_rounded, isDark),
              const SizedBox(height: 10),
              _buildAppointmentDetailItem('Hospital / Clinic', hospitalName, Icons.local_hospital_rounded, isDark),
              const SizedBox(height: 10),
              _buildAppointmentDetailItem('Date & Time', '$formattedDate ${formattedTime.isNotEmpty ? 'at $formattedTime' : ''}'.trim(), Icons.calendar_month_rounded, isDark),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildAppointmentDetailItem('Notes', notes, Icons.note_rounded, isDark),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.tr('close'), style: const TextStyle(color: Color(0xFF00796B), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentDetailItem(String label, String value, IconData icon, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00796B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementCard(DocumentSnapshot doc, bool isDark) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Announcement';
    final message = data['message'] as String? ?? '';
    final priority = data['priority'] as String? ?? 'normal';
    final isHigh = priority == 'urgent' || priority == 'high';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2829) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isHigh ? Colors.amber.shade700 : const Color(0xFF00796B)).withValues(alpha: isDark ? 0.35 : 0.2),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isHigh ? Colors.amber.shade700 : const Color(0xFF00796B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isHigh ? Colors.amber : const Color(0xFF00796B)).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHigh)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'IMPORTANT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: isDark ? Colors.white70 : const Color(0xFF616161),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required String label, required int index}) {
    final isSelected = _currentIndex == index;
    final isGamesHintActive = _showGamesHint && index == 1 && _currentIndex == 0;
    final primaryColor = Theme.of(context).primaryColor;
    final color = isSelected
        ? primaryColor
        : (isGamesHintActive ? const Color(0xFF00796B) : Colors.grey);

    final navContent = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          (isSelected || isGamesHintActive) ? activeIcon : icon,
          color: color,
          size: 24,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: (isSelected || isGamesHintActive) ? FontWeight.bold : FontWeight.normal,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    Widget itemWidget;
    if (isGamesHintActive) {
      itemWidget = Container(
        key: _gamesTabKey,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.55),
              blurRadius: 14,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: navContent,
      );
    } else {
      itemWidget = Container(
        key: index == 1 ? _gamesTabKey : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: isSelected
            ? BoxDecoration(
                color: primaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        child: navContent,
      );
    }

    return InkWell(
      onTap: () {
        _onTabTapped(index);
      },
      child: Center(
        child: itemWidget,
      ),
    );
  }

  void _openPatientSettingsSheet() {
    PatientMainScreen.openSettingsSheet(
      context,
      initialNotifications: _notifications,
      initialAudio: context.read<AppProvider>().isAudioEffectsEnabled,
      onNotificationsChanged: (val) => setState(() => _notifications = val),
      onAudioChanged: (val) {},
      onEditProfile: () => _onTabTapped(3),
      onSignOut: () => _handleSignOut(context),
    );
  }

  Future<void> _handleSignOut(BuildContext? sheetContext) async {
    final appProvider = context.read<AppProvider>();
    final isSynced = appProvider.isDataSynced;
    final hive = context.read<HiveService>();
    final syncService = SyncService(hive);
    final nav = Navigator.of(context);

    if (!isSynced) {
      final syncedNow = await syncService.syncLocalDataToCloud();
      if (syncedNow && mounted) {
        appProvider.setSyncStatus(true);
      } else {
        if (!mounted) return;
        final bool? proceed = await showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                const SizedBox(width: 10),
                Text(context.tr('unsynced_data'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Text(
              context.tr('unsynced_data_desc'),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: Text(context.tr('cancel_stay'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: Text(context.tr('sign_out_anyway')),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    } else {
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(context.tr('logout_title')),
          content: Text(context.tr('logout_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: Text(context.tr('cancel'))),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text(context.tr('logout')),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    if (sheetContext != null && sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }

    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      await hive.clearGameSessions();
      await hive.saveUserProfile({});
      appProvider.clearUserProfile();
      appProvider.clearProgress();
      appProvider.setSyncStatus(true);
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _triggerForceSync() async {
    if (_syncController.isAnimating) return;
    _syncController.repeat();
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _SyncDialog(),
    );
    if (mounted) {
      _syncController.stop();
      _syncController.reset();
    }
  }

  void _showAlreadySyncedDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        // Auto-close after 2.3 seconds (2-3 seconds)
        Future.delayed(const Duration(milliseconds: 2300), () {
          if (dialogCtx.mounted && Navigator.canPop(dialogCtx)) {
            Navigator.pop(dialogCtx);
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_done_rounded,
                          color: Color(0xFF00796B),
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr('data_already_synced'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('everything_up_to_date'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: InkWell(
                  onTap: () {
                    if (dialogCtx.mounted && Navigator.canPop(dialogCtx)) {
                      Navigator.pop(dialogCtx);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncDialog extends StatefulWidget {
  const _SyncDialog();

  @override
  State<_SyncDialog> createState() => _SyncDialogState();
}

class _SyncDialogState extends State<_SyncDialog> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  bool _isDone = false;
  String _title = "";
  String _subtitle = "";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_title.isEmpty) {
      _title = context.tr('syncing_cloud');
      _subtitle = context.tr('saving_progress');
    }
  }

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _startSync();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _startSync() async {
    final hive = context.read<HiveService>();
    final syncService = SyncService(hive);
    final success = await syncService.syncLocalDataToCloud();
    if (mounted) {
      if (success) {
        context.read<AppProvider>().setSyncStatus(true);
        setState(() {
          _isDone = true;
          _title = context.tr('synced_success');
          _subtitle = context.tr('progress_saved_cloud');
        });
        await Future.delayed(const Duration(milliseconds: 1400));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _title = context.tr('sync_failed');
          _subtitle = context.tr('sync_failed_sub');
        });
        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: _isDone
                  ? Container(
                      key: const ValueKey('done'),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
                    )
                  : Stack(
                      key: const ValueKey('syncing'),
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
                            backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.15),
                          ),
                        ),
                        RotationTransition(
                          turns: _spinController,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sync_rounded,
                              color: Color(0xFF00796B),
                              size: 32,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 20),
            Text(
              _title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Elderly-friendly caregiver reminder card displayed under "CAREGIVER REMINDERS".
/// Features a prominent, accessible "Play Now" button that routes directly to Games.
class CaregiverReminderCard extends StatelessWidget {
  final String title;
  final String body;
  final String senderName;
  final bool isHighPriority;
  final bool isRead;
  final bool isDark;
  final VoidCallback onPlayNow;
  final bool isAppointment;

  const CaregiverReminderCard({
    super.key,
    required this.title,
    required this.body,
    required this.senderName,
    required this.isHighPriority,
    required this.isRead,
    required this.isDark,
    required this.onPlayNow,
    this.isAppointment = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool appointmentMode = isAppointment ||
        title.contains('Doctor') ||
        title.contains('Appointment');

    IconData icon = Icons.psychology_rounded;
    if (appointmentMode) {
      icon = Icons.medical_services_rounded;
    } else if (title.contains('Hydrat') || title.contains('Water')) {
      icon = Icons.water_drop_rounded;
    } else if (title.contains('Medic') || title.contains('Pill')) {
      icon = Icons.medication_rounded;
    } else if (title.contains('Wellness') || title.contains('Check')) {
      icon = Icons.favorite_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2829) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighPriority
              ? Colors.redAccent.withValues(alpha: isDark ? 0.6 : 0.4)
              : const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.15),
          width: isHighPriority ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green circular app-themed avatar/icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00796B),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00796B).withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),

          // Right side: Black heading + Grey message + elderly-friendly button
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Heading in black/dark bold + high priority tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHighPriority)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'URGENT',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                      )
                    else if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00BFA5),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),

                // Grey message
                Text(
                  body.isNotEmpty ? body : 'From $senderName',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: isDark ? Colors.white70 : const Color(0xFF616161),
                  ),
                ),
                const SizedBox(height: 10),

                // Action button: View Details for appointment, Play Now for games
                Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onPlayNow,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              appointmentMode ? Icons.info_outline_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              appointmentMode ? 'View Details' : context.tr('play_now'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PatientNotificationDrawer extends StatelessWidget {
  final Stream<QuerySnapshot>? linkRequestsStream;
  final Stream<QuerySnapshot>? directNotificationsStream;
  final Stream<QuerySnapshot>? announcementsStream;
  final DateTime? latest1AMCutoff;
  final VoidCallback? onClose;
  final Widget Function(DocumentSnapshot doc, bool isDark)? connectionRequestCardBuilder;
  final Widget Function(DocumentSnapshot doc, bool isDark)? caregiverReminderCardBuilder;
  final Widget Function(DocumentSnapshot doc, bool isDark)? announcementCardBuilder;

  const PatientNotificationDrawer({
    super.key,
    this.linkRequestsStream,
    this.directNotificationsStream,
    this.announcementsStream,
    this.latest1AMCutoff,
    this.onClose,
    this.connectionRequestCardBuilder,
    this.caregiverReminderCardBuilder,
    this.announcementCardBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF141A1B) : const Color(0xFFFBFDFC);
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth > 420 ? 380.0 : screenWidth * 0.88;

    return Drawer(
      width: drawerWidth,
      backgroundColor: drawerBg,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildHeader(context, isDark),
          Expanded(
            child: _buildBody(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (linkRequestsStream == null && directNotificationsStream == null && announcementsStream == null) {
      return _buildEmptyNotificationsView(context, isDark);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: linkRequestsStream,
      builder: (context, linkSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: directNotificationsStream,
          builder: (context, notifSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: announcementsStream,
              builder: (context, announceSnap) {
                if (linkSnap.connectionState == ConnectionState.waiting &&
                    notifSnap.connectionState == ConnectionState.waiting &&
                    announceSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final cutoff1AM = latest1AMCutoff ?? DateTime(1970);
                final linkDocs = linkSnap.data?.docs ?? [];
                final notifDocs = (notifSnap.data?.docs ?? []).where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final ts = data['createdAt'];
                  if (ts is Timestamp) {
                    return ts.toDate().isAfter(cutoff1AM);
                  }
                  return true;
                }).toList();
                final announceDocs = (announceSnap.data?.docs ?? []).where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final t = data['target'] as String? ?? 'all';
                  if (t != 'all' && t != 'patient') return false;
                  final ts = data['createdAt'];
                  if (ts is Timestamp) {
                    return ts.toDate().isAfter(cutoff1AM);
                  }
                  return true;
                }).toList();

                final totalItems = linkDocs.length + notifDocs.length + announceDocs.length;
                if (totalItems == 0) {
                  return _buildEmptyNotificationsView(context, isDark);
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  children: [
                    // 1. Link Requests (if any)
                    if (linkDocs.isNotEmpty && connectionRequestCardBuilder != null) ...[
                      _buildSectionTag('CARE PARTNER INVITATIONS', Icons.link_rounded, const Color(0xFF00796B)),
                      const SizedBox(height: 8),
                      for (final doc in linkDocs)
                        connectionRequestCardBuilder!(doc, isDark),
                      const SizedBox(height: 14),
                    ],

                    // 2. Direct Caregiver Reminders (if any)
                    if (notifDocs.isNotEmpty && caregiverReminderCardBuilder != null) ...[
                      _buildSectionTag('CAREGIVER REMINDERS', Icons.notifications_active_rounded, const Color(0xFF00BFA5)),
                      const SizedBox(height: 8),
                      for (final doc in notifDocs)
                        caregiverReminderCardBuilder!(doc, isDark),
                      const SizedBox(height: 14),
                    ],

                    // 3. Admin Announcements (if any)
                    if (announceDocs.isNotEmpty && announcementCardBuilder != null) ...[
                      _buildSectionTag('SYSTEM ANNOUNCEMENTS', Icons.campaign_rounded, Colors.amber.shade800),
                      const SizedBox(height: 8),
                      for (final doc in announceDocs)
                        announcementCardBuilder!(doc, isDark),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. Accent Wave (underneath)
        Positioned.fill(
          child: ClipPath(
            clipper: const _NotificationHeaderAccentWaveClipper(),
            child: Container(
              color: isDark ? const Color(0xFF142B24) : const Color(0xFFC8E6D7),
            ),
          ),
        ),

        // 2. Main Wave (with gradient)
        Positioned.fill(
          child: ClipPath(
            clipper: const _NotificationHeaderWaveClipper(),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF18332A), const Color(0xFF1B3C32)]
                      : [const Color(0xFFE4F4EC), const Color(0xFFD3EDE0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),

        // 3. Decorative Leaf Element on right
        Positioned(
          right: -6,
          bottom: -10,
          child: IgnorePointer(
            child: Opacity(
              opacity: isDark ? 0.8 : 0.95,
              child: Image.asset(
                'assets/images/notifications_leaf_bg.png',
                width: 120,
                height: 142,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // 4. Header Content (Non-positioned: dynamically drives header height!)
        Padding(
          padding: EdgeInsets.only(
            top: topPadding + 14,
            left: 20,
            right: 18,
            bottom: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Badge + Close Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E342D) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2D4B41) : const Color(0xFFCEE9DC),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_active_rounded,
                            color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00796B),
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context.tr('invitations_alerts'),
                              style: TextStyle(
                                color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF00796B),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onClose ?? () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E342D) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF2D4B41) : const Color(0xFFCEE9DC),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white70 : const Color(0xFF143B33),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                context.tr('notifications'),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF10362D),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                context.tr('caregiver_requests_sub'),
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF43675E),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyNotificationsView(BuildContext context, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),
                  // Bell + leaves illustration
                  Image.asset(
                    'assets/images/notifications_bell_empty.png',
                    width: 195,
                    height: 165,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  // Heading
                  Text(
                    context.tr('no_pending_invitations'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: isDark ? Colors.white : const Color(0xFF10362D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Subtitle
                  Text(
                    context.tr('notifications_empty_sub'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: isDark ? Colors.white60 : const Color(0xFF53746C),
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Info Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF182723) : const Color(0xFFEEF6F2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? const Color(0xFF274139) : const Color(0xFFD6EAE0),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF223831) : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.eco_rounded,
                            color: isDark ? const Color(0xFF48C9A8) : const Color(0xFF0D5D4D),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            context.tr('notifications_empty_hint'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: isDark ? Colors.white70 : const Color(0xFF386055),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTag(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _NotificationHeaderWaveClipper extends CustomClipper<Path> {
  const _NotificationHeaderWaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 24);
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height + 4,
      size.width * 0.70,
      size.height - 18,
    );
    path.quadraticBezierTo(
      size.width * 0.88,
      size.height - 20,
      size.width,
      size.height - 6,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _NotificationHeaderAccentWaveClipper extends CustomClipper<Path> {
  const _NotificationHeaderAccentWaveClipper();

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height + 25);
    path.quadraticBezierTo(
      size.width * 0.35,
      size.height + 15,
      size.width * 0.85,
      size.height - 15,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
