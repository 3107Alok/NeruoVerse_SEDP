import 'package:flutter/material.dart';
import 'doctor_healthcare_decor_painter.dart';

class DoctorReportPreviewDialog extends StatelessWidget {
  final Map<String, dynamic> reportData;

  const DoctorReportPreviewDialog({super.key, required this.reportData});

  static void show(BuildContext context, Map<String, dynamic> reportData) {
    showDialog(
      context: context,
      builder: (ctx) => DoctorReportPreviewDialog(reportData: reportData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = reportData['title'] as String? ?? 'Clinical Report';
    final subtitle = reportData['subtitle'] as String? ?? 'PHC Telemetry';
    final facilityCode = reportData['facilityCode'] as String? ?? 'PHC-JHT-108';
    final hospital = reportData['hospital'] as String? ?? 'Primary Health Centre';
    final cmo = reportData['cmo'] as String? ?? 'Medical Officer In-Charge';
    final period = reportData['period'] as String? ?? 'Monthly';
    final metrics = (reportData['metrics'] as Map<String, dynamic>?) ?? {};
    final headers = (reportData['headers'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final rows = (reportData['rows'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final isCompact = screenSize.width < 480;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 18,
        vertical: isCompact ? 12 : 20,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: screenSize.height * 0.90,
        ),
        color: isDark ? const Color(0xFF131F1D) : Colors.white,
        child: Column(
          children: [
            // 1. Illustrated Header with Assam Leaves & Healthcare Decor
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF004D40), Color(0xFF00695C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DoctorHealthcareDecorPainter(
                        isDark: false,
                        leafColor: Colors.white.withValues(alpha: 0.14),
                        crossColor: Colors.white.withValues(alpha: 0.12),
                        pulseColor: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(isCompact ? 14 : 20, 14, 10, 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Clinical Report Preview',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Official PHC Telemetry Documentation',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Printable Document Canvas
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(isCompact ? 10 : 16),
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 14 : 20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF182624) : Colors.white,
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Official Classification & State Banner
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF142420) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFA5D6A7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF00796B)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'GOVT. OF ASSAM • HEALTH & FAMILY WELFARE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Document Title & Subtitle
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isCompact ? 15 : 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                      ),
                      const SizedBox(height: 14),

                      // Facility & CMO Information Section
                      _buildFacilityInfoSection(
                        hospital: hospital,
                        facilityCode: facilityCode,
                        cmo: cmo,
                        period: period,
                        isDark: isDark,
                        isCompact: isCompact,
                      ),
                      const SizedBox(height: 16),

                      // Executive Summary Metrics (KPI Cards)
                      if (metrics.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.analytics_rounded, size: 13, color: Color(0xFF00796B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'EXECUTIVE SUMMARY METRICS',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildExecutiveMetricsGrid(metrics, isDark, isCompact),
                        const SizedBox(height: 18),
                      ],

                      // Detailed Telemetry Table Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.table_chart_rounded, size: 13, color: Color(0xFF00796B)),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'DETAILED ROSTER TELEMETRY',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.swipe_rounded, size: 11, color: Color(0xFF00796B)),
                                SizedBox(width: 3),
                                Text(
                                  'Scroll ⇄',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF00796B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Responsive Telemetry Table
                      _buildTelemetryTable(headers, rows, isDark),
                      const SizedBox(height: 18),

                      // Official Observations Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF14201E) : const Color(0xFFF1F8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF263C36) : const Color(0xFFD3E7DE),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.health_and_safety_rounded, size: 16, color: Color(0xFF00796B)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Clinical Recommendation & Supervisory Note',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF004D40),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tele-triaged under MoHFW rural outreach protocols. Elders flagged with high-risk cognitive alerts receive priority home visits.',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Responsive Sign-off Footer
                      _buildSignoffFooter(isDark, isCompact),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Responsive Bottom Action Buttons
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 20,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF162321) : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Color(0xFF00796B),
                            content: Text('Report exported to PDF & saved to local storage! 📄'),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        'Export PDF',
                        style: TextStyle(
                          fontSize: isCompact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF2E403D) : const Color(0xFF00796B),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00796B), Color(0xFF004D40)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00796B).withValues(alpha: 0.35),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              backgroundColor: Color(0xFF00796B),
                              content: Text('Dispatching clinical report to District Health Officer (Jorhat)! 📨'),
                            ),
                          );
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                        label: Text(
                          'Share Report',
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
    );
  }

  // -------------------------------------------------------------
  // HELPER SUB-COMPONENTS
  // -------------------------------------------------------------

  Widget _buildFacilityInfoSection({
    required String hospital,
    required String facilityCode,
    required String cmo,
    required String period,
    required bool isDark,
    required bool isCompact,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14201E) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF263835) : const Color(0xFFEEF2F6),
        ),
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoTile('Hospital / PHC:', hospital, isDark, Icons.local_hospital_rounded),
                const SizedBox(height: 6),
                _buildInfoTile('Facility Code:', facilityCode, isDark, Icons.account_balance_rounded),
                const SizedBox(height: 6),
                _buildInfoTile('Supervising CMO:', cmo, isDark, Icons.medical_services_rounded),
                const SizedBox(height: 6),
                _buildInfoTile('Report Period:', period.toUpperCase(), isDark, Icons.event_note_rounded),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoTile('Hospital / PHC:', hospital, isDark, Icons.local_hospital_rounded),
                      const SizedBox(height: 6),
                      _buildInfoTile('Facility Code:', facilityCode, isDark, Icons.account_balance_rounded),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoTile('Supervising CMO:', cmo, isDark, Icons.medical_services_rounded),
                      const SizedBox(height: 6),
                      _buildInfoTile('Report Period:', period.toUpperCase(), isDark, Icons.event_note_rounded),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoTile(String label, String value, bool isDark, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 13,
          color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white70 : const Color(0xFF1E293B),
              ),
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white38 : const Color(0xFF64748B),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExecutiveMetricsGrid(
    Map<String, dynamic> metrics,
    bool isDark,
    bool isCompact,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metrics.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14201E) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: Color(0xFF00796B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${e.key}: ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              Text(
                '${e.value}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTelemetryTable(
    List<String> headers,
    List<Map<String, dynamic>> rows,
    bool isDark,
  ) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14201E) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Center(
          child: Text(
            'No patient screening telemetry recorded for this period.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: DataTable(
            columnSpacing: 16,
            headingRowHeight: 36,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 46,
            headingRowColor: WidgetStateProperty.all(
              const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.08),
            ),
            columns: headers
                .map(
                  (h) => DataColumn(
                    label: Text(
                      h,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                      ),
                    ),
                  ),
                )
                .toList(),
            rows: rows.map((r) {
              final cells = r.values.map((val) {
                final s = val.toString();
                final upper = s.toUpperCase();
                final isSevere = upper == 'SEVERE';
                final isNormal = upper == 'NORMAL';
                final isApproved = upper == 'APPROVED';

                if (isSevere || isNormal || isApproved) {
                  final bgColor = isSevere
                      ? (isDark ? const Color(0xFF3F1313) : const Color(0xFFFEE2E2))
                      : (isDark ? const Color(0xFF0B2D24) : const Color(0xFFD1FAE5));
                  final textColor = isSevere
                      ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B))
                      : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46));

                  return DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  );
                }

                return DataCell(
                  Text(
                    s,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                    ),
                  ),
                );
              }).toList();
              return DataRow(cells: cells);
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSignoffFooter(bool isDark, bool isCompact) {
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, size: 13, color: Color(0xFF00796B)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'NeuroVerse Clinical Telemetry Engine • MoHFW SIH-26003',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  width: 130,
                  height: 1.2,
                  color: isDark ? const Color(0xFF4A6B63) : Colors.grey.shade400,
                ),
                const SizedBox(height: 4),
                Text(
                  'Authorized CMO Stamp / Signature',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.verified_user_rounded, size: 13, color: Color(0xFF00796B)),
                  const SizedBox(width: 5),
                  Text(
                    'NeuroVerse Telemetry Engine',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'MoHFW / MDoNER SIH-26003 Official Roster',
                style: TextStyle(
                  fontSize: 9.5,
                  color: isDark ? Colors.white38 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 130,
              height: 1.2,
              color: isDark ? const Color(0xFF4A6B63) : Colors.grey.shade400,
            ),
            const SizedBox(height: 4),
            Text(
              'Authorized CMO Stamp / Signature',
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
