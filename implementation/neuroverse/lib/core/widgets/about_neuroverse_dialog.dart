import 'package:flutter/material.dart';

void showAboutNeuroVerseDialog(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primaryTeal = const Color(0xFF00796B);
  final primaryTextColor = isDark ? Colors.white : const Color(0xFF1E293B);
  final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
  final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
  final cardColor = isDark ? const Color(0xFF252D2E) : const Color(0xFFF8FAFC);
  final borderColor = isDark ? Colors.white12 : Colors.grey.shade200;

  showDialog(
    context: context,
    builder: (dialogCtx) {
      return Dialog(
        backgroundColor: surfaceColor,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header with Teal Gradient
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF00382E), const Color(0xFF004D40)]
                        : [const Color(0xFF00695C), const Color(0xFF004D40)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    // App Logo Icon
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(
                        'assets/images/app_icon.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.psychology_rounded,
                          color: Color(0xFF00796B),
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'NeuroVerse',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Cognitive Therapy Platform',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Version chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.circle, color: Color(0xFF69F0AE), size: 7),
                                SizedBox(width: 5),
                                Text(
                                  'Prototype',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(dialogCtx),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Mission Description
                      Text(
                        'About NeuroVerse',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'NeuroVerse is an adaptive digital cognitive health and therapeutic intervention platform designed for individuals with mild cognitive impairment (MCI) and neurodegenerative conditions. Powered by clinically informed task architectures and tabular reinforcement learning (Q-Learning), it delivers individualized cognitive stimulation, longitudinal telemetry tracking, and proactive risk detection for family caregivers.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Core Features Grid
                      Text(
                        'Core Capabilities',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 10),

                      _buildFeatureTile(
                        icon: Icons.psychology_rounded,
                        iconColor: Colors.teal,
                        title: 'Adaptive Q-Learning AI',
                        description:
                            'Dynamically adjusts game difficulty in real time based on user performance.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),

                      _buildFeatureTile(
                        icon: Icons.volunteer_activism_rounded,
                        iconColor: Colors.green,
                        title: 'Caregiver Telemetry & Alerts',
                        description:
                            'Secure share code linking for live score monitoring, session history, and alerts.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),

                      _buildFeatureTile(
                        icon: Icons.mic_rounded,
                        iconColor: Colors.indigo,
                        title: 'Voice Assistant & Mode',
                        description:
                            'Multilingual interactive vocal prompts and guidance for frictionless therapy.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),

                      _buildFeatureTile(
                        icon: Icons.cloud_sync_rounded,
                        iconColor: Colors.amber.shade800,
                        title: 'Offline-First Resilience',
                        description:
                            'Zero data loss with local Hive caching and seamless cloud synchronization.',
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),

                      // Technical Specifications Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Technical Specifications',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildSpecRow('Client Engine', 'Flutter 3.x Cross-Platform', primaryTextColor, secondaryTextColor),
                            const Divider(height: 14),
                            _buildSpecRow('Local Storage', 'Hive NoSQL (Encrypted)', primaryTextColor, secondaryTextColor),
                            const Divider(height: 14),
                            _buildSpecRow('Cloud Backend', 'Firebase Firestore & Auth', primaryTextColor, secondaryTextColor),
                            const Divider(height: 14),
                            _buildSpecRow('AI Model', 'Q-Learning Adaptive Matrix', primaryTextColor, secondaryTextColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Copyright & Credits
                      Center(
                        child: Text(
                          '© 2026 NeuroVerse Health Labs\nEmpowering Cognitive Health Worldwide',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Action Footer
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

Widget _buildFeatureTile({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String description,
  required bool isDark,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF252D2E) : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark ? Colors.white70 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildSpecRow(String label, String value, Color primaryColor, Color secondaryColor) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 12, color: secondaryColor, fontWeight: FontWeight.w500),
      ),
      Text(
        value,
        style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.w600),
      ),
    ],
  );
}
