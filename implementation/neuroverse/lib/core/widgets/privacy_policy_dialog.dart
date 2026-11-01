import 'package:flutter/material.dart';
import '../localization/app_translations.dart';

void showPrivacyPolicyDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surfaceColor = isDark ? const Color(0xFF1E2829) : Colors.white;
  final cardColor = isDark ? const Color(0xFF253335) : const Color(0xFFF8FAFC);
  final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;
  final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
  final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF475569);

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return Dialog(
        backgroundColor: surfaceColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Header with Healthcare Shield Gradient
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00695C), Color(0xFF004D40)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.security_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('privacy_policy'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Clinical Data Protection & Patient Privacy',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                    ),
                  ],
                ),
              ),

              // 2. Scrollable Body with Privacy Protections
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Compliance Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF00796B).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.verified_user_rounded, color: Color(0xFF00796B), size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'DPDP Act 2023 & DISHA Healthcare Compliant',
                                style: TextStyle(
                                  color: Color(0xFF00796B),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      _buildPolicySection(
                        icon: Icons.psychology_outlined,
                        iconColor: const Color(0xFF0284C7),
                        title: '1. Cognitive Telemetry & Session Data',
                        content:
                            'NeuroVerse logs cognitive exercise metrics (game completion time, accuracy scores, response latency, and memory recall streaks). This data is strictly used to measure individual cognitive maintenance and adapt game difficulty for dementia care.',
                        cardColor: cardColor,
                        borderColor: borderColor,
                        primaryColor: primaryTextColor,
                        secondaryColor: secondaryTextColor,
                      ),
                      const SizedBox(height: 12),

                      _buildPolicySection(
                        icon: Icons.photo_camera_front_outlined,
                        iconColor: const Color(0xFFD97706),
                        title: '2. Family Photos & Media Security',
                        content:
                            'Photographs uploaded for Face Recall are stored in private, access-controlled cloud collections and encrypted in local device memory (Hive). These photos are NEVER shared publicly, indexed by search engines, or used for AI model training.',
                        cardColor: cardColor,
                        borderColor: borderColor,
                        primaryColor: primaryTextColor,
                        secondaryColor: secondaryTextColor,
                      ),
                      const SizedBox(height: 12),

                      _buildPolicySection(
                        icon: Icons.no_accounts_outlined,
                        iconColor: const Color(0xFFDC2626),
                        title: '3. Zero Commercial Data Sharing',
                        content:
                            'Your health and cognitive records are strictly confidential. NeuroVerse does NOT sell, rent, or monetize patient information with insurance companies, third-party advertisers, or data brokers.',
                        cardColor: cardColor,
                        borderColor: borderColor,
                        primaryColor: primaryTextColor,
                        secondaryColor: secondaryTextColor,
                      ),
                      const SizedBox(height: 12),

                      _buildPolicySection(
                        icon: Icons.people_outline_rounded,
                        iconColor: const Color(0xFF059669),
                        title: '4. Authorized Caregiver & Medical Access',
                        content:
                            'Telemetry insights, anomaly alerts, and game progress reports are exclusively accessible to linked family caregivers through verified patient ID codes, and authorized community medical officers (PHC / Doctors).',
                        cardColor: cardColor,
                        borderColor: borderColor,
                        primaryColor: primaryTextColor,
                        secondaryColor: secondaryTextColor,
                      ),
                      const SizedBox(height: 12),

                      _buildPolicySection(
                        icon: Icons.delete_forever_outlined,
                        iconColor: const Color(0xFF7C3AED),
                        title: '5. Patient Rights & Data Erasure',
                        content:
                            'You and your caregiver maintain complete ownership of all data. You have the permanent right to request full export or permanent deletion of all stored photos, logs, and account details at any time.',
                        cardColor: cardColor,
                        borderColor: borderColor,
                        primaryColor: primaryTextColor,
                        secondaryColor: secondaryTextColor,
                      ),
                      const SizedBox(height: 16),

                      // Clinical safety disclaimer
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 16, color: secondaryTextColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'NeuroVerse is a non-pharmacological digital therapeutic assistive tool designed to support cognitive stimulation. In medical emergencies, always contact your local hospital or emergency healthcare helpline.',
                                style: TextStyle(
                                  fontSize: 11,
                                  height: 1.35,
                                  color: secondaryTextColor,
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

              // 3. Bottom Action
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text(
                      'Understood',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildPolicySection({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String content,
  required Color cardColor,
  required Color borderColor,
  required Color primaryColor,
  required Color secondaryColor,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            color: secondaryColor,
            fontSize: 12.5,
            height: 1.45,
          ),
        ),
      ],
    ),
  );
}
