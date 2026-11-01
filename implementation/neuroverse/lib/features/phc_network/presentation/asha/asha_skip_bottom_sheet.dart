import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_translations.dart';
import '../../models/phc_patient_model.dart';
import '../../data/phc_repository.dart';

class AshaSkipBottomSheet extends StatefulWidget {
  final PhcPatientModel patient;

  const AshaSkipBottomSheet({super.key, required this.patient});

  @override
  State<AshaSkipBottomSheet> createState() => _AshaSkipBottomSheetState();
}

class _AshaSkipBottomSheetState extends State<AshaSkipBottomSheet> {
  String _selectedReason = 'not_home';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final p = widget.patient;
    final isCritical = p.isCriticalDecline || p.riskLevel == 'severe_decline';
    final statusDotColor = isCritical
        ? const Color(0xFFDC2626)
        : (p.status == 'visited_today' ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    final reasons = [
      {
        'id': 'not_home',
        'icon': '🏠',
        'title': context.tr('skip_reason_not_home_title'),
        'subtitle': context.tr('skip_reason_not_home_sub'),
      },
      {
        'id': 'unwell',
        'icon': '😴',
        'title': context.tr('skip_reason_unwell_title'),
        'subtitle': context.tr('skip_reason_unwell_sub'),
      },
      {
        'id': 'flood_inaccessible',
        'icon': '🌧️',
        'title': context.tr('skip_reason_flood_title'),
        'subtitle': context.tr('skip_reason_flood_sub'),
      },
      {
        'id': 'refused',
        'icon': '❌',
        'title': context.tr('skip_reason_refused_title'),
        'subtitle': context.tr('skip_reason_refused_sub'),
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162422) : theme.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle (Caregiver Modal Pattern)
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Modal Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.fast_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('skip_bottom_title'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr('skip_bottom_sub'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? Colors.white70 : const Color(0xFF64748B)),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                    tooltip: context.tr('close'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Elder Context Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2B29) : const Color(0xFFE8F5ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E4540) : const Color(0xFFC8E6C9),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF00796B),
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : 'E',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 8.5,
                          height: 8.5,
                          decoration: BoxDecoration(
                            color: statusDotColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1C2B29) : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.name} (${p.age} ${context.tr('field_age_yrs')})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF1B3B36),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${p.houseNo} • ${context.localizeVillage(p.village)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : const Color(0xFF4A6B63),
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
            const SizedBox(height: 14),

            Text(
              context.tr('skip_select_reason'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),

            // Selectable Reason Cards
            ...reasons.map((r) {
              final isSelected = _selectedReason == r['id'];
              return InkWell(
                onTap: () => setState(() => _selectedReason = r['id']!),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF00796B).withValues(alpha: isDark ? 0.22 : 0.08)
                        : (isDark ? const Color(0xFF1D2928) : const Color(0xFFF8FAF9)),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00796B)
                          : (isDark ? const Color(0xFF2B3D3A) : const Color(0xFFE2ECE8)),
                      width: isSelected ? 1.8 : 1.1,
                    ),
                    boxShadow: isSelected && !isDark
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00796B).withValues(alpha: 0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00796B).withValues(alpha: 0.16)
                              : (isDark ? Colors.white10 : Colors.white),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF00796B).withValues(alpha: 0.3)
                                : (isDark ? Colors.white10 : const Color(0xFFE2ECE8)),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(r['icon']!, style: const TextStyle(fontSize: 20)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['title']!,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : (isSelected ? const Color(0xFF004D40) : const Color(0xFF1E293B)),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              r['subtitle']!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.grey.shade600,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Custom Radio Indicator (Caregiver Style)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? const Color(0xFF00796B) : Colors.grey.shade400,
                            width: isSelected ? 6.5 : 1.8,
                          ),
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),

            // Confirm Action Button
            Container(
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
              child: ElevatedButton(
                onPressed: () {
                  PhcRepository().recordSkippedVisit(
                    patientId: widget.patient.id,
                    skipReason: _selectedReason,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.warning,
                      content: Text(
                        context.tr('skip_logged_snack', params: {'name': widget.patient.name}),
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  context.tr('skip_confirm_btn'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
