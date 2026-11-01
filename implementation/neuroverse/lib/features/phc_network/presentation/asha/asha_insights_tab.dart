import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/localization/app_translations.dart';
import '../../data/phc_repository.dart';
import '../../models/phc_visit_model.dart';
import '../../models/phc_patient_model.dart';

class AshaInsightsTab extends StatefulWidget {
  const AshaInsightsTab({super.key});

  @override
  State<AshaInsightsTab> createState() => _AshaInsightsTabState();
}

class _AshaInsightsTabState extends State<AshaInsightsTab> {
  String _selectedVillage = 'All Villages';

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final repo = PhcRepository();
    final filterOptions = ['All Villages', ...repo.availableVillages];

    // Relevant patients for this filter
    final List<PhcPatientModel> patients = _selectedVillage == 'All Villages'
        ? repo.patients
        : repo.getPatientsByVillage(_selectedVillage);

    // Relevant visit logs for this filter
    final List<PhcVisitModel> visitLogs = repo.getVisitLogsByVillage(_selectedVillage);

    final totalElders = patients.length;
    final screenedCount = patients.where((p) => p.status == 'visited_today').length;
    final mciCount = patients.where((p) => p.riskLevel == 'mci_warning').length;
    final criticalCount = patients.where((p) => p.isCriticalDecline || p.riskLevel == 'severe_decline').length;
    final normalCount = totalElders - mciCount - criticalCount;
    final coveragePercent = totalElders > 0 ? ((screenedCount / totalElders) * 100).toInt() : 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF131D1B) : const Color(0xFFF2F8F5),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Integrated Top Hero Section with Subtle Background Illustration
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF142421), const Color(0xFF101C1A)]
                      : [const Color(0xFFEDF7F2), const Color(0xFFE2F3EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(26),
                  bottomRight: Radius.circular(26),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Subtle background illustration on the right
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 220,
                    child: Opacity(
                      opacity: isDark ? 0.38 : 0.85,
                      child: Image.asset(
                        'assets/images/insights_banner_art.png',
                        fit: BoxFit.cover,
                        alignment: Alignment.centerRight,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    ),
                  ),

                  // Decorative botanical leaf accent from Patient UI
                  Positioned(
                    right: 165,
                    bottom: -8,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: isDark ? 0.22 : 0.40,
                        child: Image.asset(
                          'assets/images/greeting_botanical_accent.png',
                          height: 82,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const SizedBox(),
                        ),
                      ),
                    ),
                  ),

                  // Handwritten accent text on top right: "Small Data Big Impact ♡"
                  Positioned(
                    right: 18,
                    top: 14,
                    child: Text(
                      'Small Data\nBig Impact ♡',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.85 : 0.82),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),

                  // Smooth gradient blend overlay ensuring high contrast & text readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF142421),
                                  const Color(0xFF142421).withValues(alpha: 0.94),
                                  const Color(0xFF142421).withValues(alpha: 0.12),
                                ]
                              : [
                                  const Color(0xFFEDF7F2),
                                  const Color(0xFFEDF7F2).withValues(alpha: 0.93),
                                  const Color(0xFFEDF7F2).withValues(alpha: 0.05),
                                ],
                          stops: const [0.0, 0.56, 1.0],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                  ),

                  // Hero Title & Subtitle Content on Left
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cute 3-leaf sprout accent icon
                        Container(
                          padding: const EdgeInsets.all(4.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.eco_rounded,
                            size: 15,
                            color: Color(0xFF00796B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('tab_insights'),
                          style: TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F3D37),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.56,
                          ),
                          child: Text(
                            'Data for healthier communities',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : const Color(0xFF4A6B65),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Main Insights Content Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Filter Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2827) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                        width: 1.2,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF00796B).withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_outlined,
                          color: Color(0xFF00796B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.tr('insights_filter_by'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedVillage,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E2827) : Colors.white,
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white10 : const Color(0xFFE0F2F1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: Color(0xFF00796B),
                                  size: 18,
                                ),
                              ),
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              selectedItemBuilder: (BuildContext ctx) {
                                return filterOptions.map<Widget>((String v) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      ctx.localizeVillage(v),
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList();
                              },
                              items: filterOptions.map((v) {
                                return DropdownMenuItem(
                                  value: v,
                                  child: Text(
                                    context.localizeVillage(v),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedVillage = val);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 1. Village Cognitive Coverage Card (Deep Teal Gradient)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00695C), Color(0xFF004D40)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF004D40).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Subtle ghost botanical / chart decoration in background
                        Positioned(
                          left: -10,
                          bottom: -15,
                          child: Icon(
                            Icons.eco_rounded,
                            size: 80,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        Positioned(
                          right: -5,
                          bottom: -10,
                          child: Icon(
                            Icons.bar_chart_rounded,
                            size: 85,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    context.localizeVillage(_selectedVillage).toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    context.tr('insights_screened_pct_fmt', params: {'pct': coveragePercent.toString()}),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('insights_cognitive_coverage'),
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: totalElders > 0 ? (screenedCount / totalElders) : 0,
                                minHeight: 7,
                                backgroundColor: Colors.white24,
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4DB6AC)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildWhiteStat(
                                  icon: Icons.groups_rounded,
                                  label: context.tr('total_elders'),
                                  val: '$totalElders',
                                ),
                                _buildWhiteStat(
                                  icon: Icons.assignment_turned_in_outlined,
                                  label: context.tr('status_screened'),
                                  val: '$screenedCount',
                                ),
                                _buildWhiteStat(
                                  statusDotColor: const Color(0xFFF59E0B),
                                  label: context.tr('status_mci_watch'),
                                  val: '$mciCount',
                                ),
                                _buildWhiteStat(
                                  statusDotColor: const Color(0xFFEF4444),
                                  label: context.tr('status_high_risk'),
                                  val: '$criticalCount',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Cognitive Risk Distribution Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2827) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                        width: 1.2,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF00796B).withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.bar_chart_rounded, size: 20, color: Color(0xFF00796B)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          context.tr('insights_cognitive_breakdown'),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    context.tr('insights_stealth_tests_sub'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Cute Glowing Brain Illustration on top right
                            Image.asset(
                              'assets/images/insights_brain_art.png',
                              width: 52,
                              height: 52,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildRiskBar(context.tr('risk_age_appropriate_stable'), normalCount, totalElders, const Color(0xFF16A34A)),
                        const SizedBox(height: 12),
                        _buildRiskBar(context.tr('risk_mci_mild'), mciCount, totalElders, const Color(0xFFF59E0B)),
                        const SizedBox(height: 12),
                        _buildRiskBar(context.tr('risk_severe_phc_referral'), criticalCount, totalElders, const Color(0xFFDC2626)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Field Visit History Log Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2827) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                        width: 1.2,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: const Color(0xFF00796B).withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 19, color: Color(0xFF00796B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('history_field_visits_log'),
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.tr('history_total_visits_fmt', params: {'count': visitLogs.length.toString()}),
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF00796B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Divider(
                          height: 22,
                          color: isDark ? Colors.white12 : const Color(0xFFF0F4F2),
                        ),

                        if (visitLogs.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Column(
                                children: [
                                  // Empty state document with magnifying glass illustration
                                  Image.asset(
                                    'assets/images/insights_empty_history_art.png',
                                    width: 120,
                                    height: 88,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    context.tr('history_empty_note'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Keep visiting and supporting elders in your community!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ...visitLogs.map((log) => _buildVisitLogCard(log)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 88),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhiteStat({
    IconData? icon,
    Color? statusDotColor,
    required String label,
    required String val,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 16, color: Colors.white70)
          else if (statusDotColor != null)
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: statusDotColor,
                shape: BoxShape.circle,
              ),
            )
          else
            const SizedBox(height: 16),
          const SizedBox(height: 4),
          Text(
            val,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBar(String label, int count, int total, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pct = total > 0 ? (count / total) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count (${(pct * 100).toInt()}%)',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2ECE8),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildVisitLogCard(PhcVisitModel log) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVisited = log.status == 'visited';
    final dateStr = context.tr('date_time_at_fmt', params: {
      'date': '${log.timestamp.day}/${log.timestamp.month}',
      'time': '${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}',
    });

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162220) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: isVisited ? Colors.green.shade50 : Colors.orange.shade50,
            child: Icon(
              isVisited ? Icons.check_circle_outline_rounded : Icons.fast_forward_rounded,
              color: isVisited ? Colors.green.shade700 : Colors.orange.shade800,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.patientName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  context.tr('history_village_asha_fmt', params: {'village': context.localizeVillage(log.village), 'asha': log.ashaName}),
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isVisited ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isVisited
                              ? context.tr('history_score_time_fmt', params: {'score': log.score.toString(), 'sec': log.durationSeconds.toString()})
                              : context.tr('history_skipped_fmt', params: {'reason': _formatSkipReason(context, log.skipReason)}),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isVisited ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      log.isSynced ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 15,
                      color: log.isSynced ? Colors.teal : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      log.isSynced ? context.tr('sync_status_synced') : context.tr('sync_status_offline'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: log.isSynced ? Colors.teal : Colors.grey,
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

  String _formatSkipReason(BuildContext context, String? reason) {
    switch (reason) {
      case 'not_home':
        return context.tr('skip_reason_not_home_short');
      case 'unwell':
        return context.tr('skip_reason_unwell_short');
      case 'flood_inaccessible':
        return context.tr('skip_reason_flood_short');
      case 'refused':
        return context.tr('skip_reason_refused_short');
      default:
        return context.tr('status_logged');
    }
  }
}
