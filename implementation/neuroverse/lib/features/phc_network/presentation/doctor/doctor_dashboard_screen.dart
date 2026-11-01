import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/phc_repository.dart';
import '../../models/phc_patient_model.dart';
import '../../models/phc_asha_model.dart';
import '../../models/phc_doctor_model.dart';
import '../../models/phc_visit_model.dart';
import 'doctor_clinical_thoughts.dart';
import 'doctor_schedule_visit_dialog.dart';
import 'doctor_report_preview_dialog.dart';
import 'doctor_settings_sheet.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../patient/games/common/ner_illustrations.dart';
import '../asha/caregiver_illustration_painter.dart';
import 'doctor_healthcare_decor_painter.dart';

class DoctorDashboardScreen extends StatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  int _currentNavIndex = 0;

  // Home Tab State
  int _visitSubTabIndex = 0; // 0: Scheduled, 1: Previous History
  String _criticalVillageFilter = 'All Villages';

  // Care Team Tab State
  int _careTeamSubTabIndex = 0; // 0: ASHA Workers, 1: Patients
  String _careTeamSearchQuery = '';
  String _careTeamVillageFilter = 'All Villages';

  // Insights Tab State
  int _insightsSubTabIndex = 0; // 0: Patient Insights, 1: ASHA Insights

  // Profile Tab (Report Generator State)
  String _reportPeriod = 'monthly'; // 'daily' or 'monthly'
  String _reportType = 'patient'; // 'patient' or 'asha'

  @override
  void initState() {
    super.initState();
    DoctorClinicalThoughts.refresh();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: PhcRepository(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121B19) : const Color(0xFFF2F8F5),
          appBar: _buildAppBar(),
          body: _buildCurrentTab(),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TOP APP BAR (Settings & Sync on Right Top)
  // -------------------------------------------------------------
  PreferredSizeWidget _buildAppBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark ? const Color(0xFF162422) : Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 16,
      foregroundColor: isDark ? Colors.white : AppColors.textPrimaryLight,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          height: 1,
        ),
      ),
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
                'Care Together. Grow Together.',
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
      actions: [
        // Sync Button
        IconButton(
          tooltip: context.tr('doc_field_sync'),
          icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.primary,
                content: Text(context.tr('doc_field_sync_success')),
              ),
            );
          },
        ),
        // Settings Button
        IconButton(
          tooltip: context.tr('doctor_settings'),
          icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
          onPressed: () => DoctorSettingsSheet.show(context),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentNavIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return _buildCareTeamTab();
      case 2:
        return _buildInsightsTab();
      case 3:
      default:
        return _buildProfileTab();
    }
  }

  // =============================================================
  // TAB 1: HOME TAB
  // =============================================================
  Widget _buildHomeTab() {
    final repo = PhcRepository();
    final doctor = repo.doctor;
    final pendingAshas = repo.pendingAshaWorkers;
    final scheduledDrives = repo.scheduledDrives;
    final visitLogs = repo.visitLogs;

    // Filter critical cases
    var criticalList = repo.criticalAlertPatients;
    if (_criticalVillageFilter != 'All Villages') {
      criticalList = criticalList.where((p) => p.village == _criticalVillageFilter).toList();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Soft Illustrated Hero Section (Replaces old solid green banner)
          _buildDoctorHeroSection(repo, doctor),
          const SizedBox(height: 16),

          // 2. Action Cards: Schedule Visit + Pending ASHA
          _buildActionCardsRow(pendingAshas),
          const SizedBox(height: 16),

          // 3. Field Visits & Outcomes Card (Scheduled vs Previous)
          _buildVisitsCard(scheduledDrives, visitLogs),
          const SizedBox(height: 16),

          // 4. Critical Cases Alert Hub (with Village Filter & Call Guardian)
          _buildCriticalCasesCard(repo, criticalList),
          const SizedBox(height: 16),

          // 5. Clinical Wisdom / Leadership Thought Card
          _buildClinicalQuoteCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // 1. Soft Illustrated Hero Section with Animated Landscape & Healthcare Motifs
  Widget _buildDoctorHeroSection(PhcRepository repo, PhcDoctorModel doctor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    String greeting = context.tr('greeting_morning');
    String greetingEmoji = '🌅';
    if (now.hour >= 12 && now.hour < 17) {
      greeting = context.tr('greeting_afternoon');
      greetingEmoji = '☀️';
    } else if (now.hour >= 17 && now.hour < 21) {
      greeting = context.tr('greeting_evening');
      greetingEmoji = '🌇';
    } else if (now.hour >= 21 || now.hour < 5) {
      greeting = context.tr('greeting_night');
      greetingEmoji = '🌙';
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E27) : const Color(0xFFE8F5ED),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFC8E6C9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Meditative NER Landscape Background
            Positioned.fill(
              child: AnimatedNerLandscape(
                isDark: isDark,
                duration: const Duration(seconds: 14),
              ),
            ),
            // Healthcare Theme Accent Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _DoctorHealthcareDecorPainter(isDark: isDark),
              ),
            ),
            // Hero Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Greeting & Facility Code Pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(greetingEmoji, style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    '$greeting,',
                                    style: TextStyle(
                                      color: isDark ? Colors.white70 : const Color(0xFF2E7D32),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              doctor.name,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Facility Code Copy Chip
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: doctor.facilityCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF00796B),
                              content: Text(context.tr('doc_facility_code_copied')),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2827).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.6 : 0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_balance_rounded, color: Color(0xFF00796B), size: 16),
                              const SizedBox(width: 7),
                              Text(
                                doctor.facilityCode,
                                style: const TextStyle(
                                  color: Color(0xFF00796B),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded, color: Color(0xFF00796B), size: 13),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Hospital Name & Command Hub Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.local_hospital_rounded, size: 14, color: Color(0xFF00796B)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          doctor.hospitalName,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.tr('doc_command_hub').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00796B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Duty Officer Row with Edit Button
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${context.tr("doc_duty_officer")}: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        doctor.name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                        ),
                      ),
                      InkWell(
                        onTap: () => _showEditDoctorDialog(context),
                        borderRadius: BorderRadius.circular(5),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_rounded, size: 10, color: Color(0xFF00796B)),
                              const SizedBox(width: 3),
                              Text(
                                context.tr('doc_edit_credentials'),
                                style: const TextStyle(
                                  fontSize: 10,
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
                  const SizedBox(height: 12),

                  // Active Monitoring Stats Pill & Illustration
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF142420).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFD7E8E2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFF00796B)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('doc_active_asha_chip', params: {'count': '${repo.approvedAshaWorkers.length}'}),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('doc_monitored_elders_chip', params: {'count': '${repo.patients.length}'}),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 44,
                          height: 34,
                          child: CustomPaint(
                            painter: CaregiverIllustrationPainter(),
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
    );
  }

  // 2. Action Cards: Schedule Visit + Pending ASHA Requests
  Widget _buildActionCardsRow(List<PhcAshaModel> pendingAshas) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Schedule Visit Card
          Expanded(
            child: InkWell(
              onTap: () => DoctorScheduleVisitDialog.show(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2827) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 10,
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00897B), Color(0xFF004D40)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00796B).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: isDark ? Colors.white38 : Colors.grey),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('doc_schedule_drive'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('doc_schedule_sub'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Right: Pending ASHA Square Card with Outward Count Badge
          Expanded(
            child: InkWell(
              onTap: () => _showPendingAshasDialog(context),
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pendingAshas.isNotEmpty
                          ? (isDark ? const Color(0xFF2B1D12) : const Color(0xFFFFFBEB))
                          : (isDark ? const Color(0xFF1E2827) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: pendingAshas.isNotEmpty
                            ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A))
                            : (isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8)),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (pendingAshas.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF00796B))
                              .withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: pendingAshas.isNotEmpty
                                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                                  : [const Color(0xFF00897B), const Color(0xFF004D40)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: (pendingAshas.isNotEmpty ? const Color(0xFFD97706) : const Color(0xFF00796B))
                                    .withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.tr('doc_pending_ashas'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          pendingAshas.isNotEmpty ? context.tr('doc_tap_to_approve') : context.tr('doc_all_approved'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: pendingAshas.isNotEmpty ? FontWeight.w700 : FontWeight.normal,
                            color: pendingAshas.isNotEmpty
                                ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                                : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Outward Count Badge!
                  if (pendingAshas.isNotEmpty)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          context.tr('doc_badge_new_count', params: {'count': '${pendingAshas.length}'}),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. Visits Card (Scheduled vs Previous & Visited vs Skipped)
  Widget _buildVisitsCard(List<PhcScheduledDrive> scheduledDrives, List<PhcVisitModel> visitLogs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
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
                  color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.history_edu_rounded, color: Color(0xFF00796B), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('doc_visits_history'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Full-width Sub-tab toggle: Scheduled vs Previous
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14201E) : const Color(0xFFF1F5F3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF243633) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMiniTabButton(context.tr('doc_upcoming_scheduled'), 0, _visitSubTabIndex, (i) => setState(() => _visitSubTabIndex = i)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildMiniTabButton(context.tr('doc_completed_history'), 1, _visitSubTabIndex, (i) => setState(() => _visitSubTabIndex = i)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Sub-tab Content
          if (_visitSubTabIndex == 0) ...[
            // Scheduled Visits List
            if (scheduledDrives.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_available_rounded, size: 36, color: isDark ? Colors.white24 : Colors.grey.shade300),
                      const SizedBox(height: 8),
                      Text(
                        context.tr('doc_no_drives_scheduled'),
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.grey.shade600, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...scheduledDrives.take(3).map((drive) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF172523) : const Color(0xFFF4F9F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF293D39) : const Color(0xFFD4E6DF),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF004D40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00796B).withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text('${drive.date.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(
                              _getMonthName(drive.date.month),
                              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              drive.village,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${context.tr("doc_asha_label")}s: ${drive.ashaNames.join(", ")}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF00796B).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          context.tr('doc_elders_count', params: {'count': '${drive.totalAssignedPatients}'}),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ] else ...[
            // Previous Visits & Outcomes (Visited vs Skipped)
            ...visitLogs.take(4).map((log) {
              final isVisited = log.status == 'visited';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isVisited
                      ? (isDark ? const Color(0xFF172523) : const Color(0xFFF8FAFC))
                      : (isDark ? const Color(0xFF281C10) : const Color(0xFFFFFBEB)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isVisited
                        ? (isDark ? const Color(0xFF293D39) : const Color(0xFFE2ECE8))
                        : (isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A)),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isVisited ? Icons.check_circle_rounded : Icons.cancel_rounded,
                      color: isVisited ? const Color(0xFF00796B) : const Color(0xFFD97706),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.patientName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${log.village} • ${context.tr("doc_asha_label")} ${log.ashaName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: isVisited
                              ? const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12)
                              : const Color(0xFFD97706).withValues(alpha: isDark ? 0.3 : 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isVisited
                              ? context.tr('doc_visited_fmt', params: {'score': '${log.score}'})
                              : (log.skipReason == 'unwell'
                                  ? context.tr('skip_reason_unwell')
                                  : (log.skipReason == 'flood_inaccessible'
                                      ? context.tr('skip_reason_flood')
                                      : (log.skipReason == 'not_home'
                                          ? context.tr('skip_reason_festival')
                                          : (log.skipReason == 'refused'
                                              ? context.tr('skip_reason_refused')
                                              : (log.skipReason ?? context.tr('skip_reason_unwell')))))),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isVisited
                                ? (isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B))
                                : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  // 4. Critical Cases Card (with Village Dropdown & Call Guardian button)
  Widget _buildCriticalCasesCard(PhcRepository repo, List<PhcPatientModel> criticalList) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF281313) : const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
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
                        color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.3 : 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        context.tr('doc_critical_cases'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Village Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3B1818) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isDense: true,
                    dropdownColor: isDark ? const Color(0xFF281313) : Colors.white,
                    value: ['All Villages', ...repo.availableVillages].contains(_criticalVillageFilter)
                        ? _criticalVillageFilter
                        : 'All Villages',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                    ),
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                    ),
                    items: {'All Villages', ...repo.availableVillages}.map((v) {
                      return DropdownMenuItem(value: v, child: Text(v));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _criticalVillageFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (criticalList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.verified_user_rounded, size: 32, color: isDark ? Colors.white24 : Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text(
                      context.tr('doc_no_critical_cases'),
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...criticalList.map((p) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF331717) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${p.name} (${p.age}y / ${p.gender})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${context.tr("doc_score_fmt")}: ${p.latestScore}/10',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.village} • ${p.houseNo}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '“${p.notes}”',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: isDark ? Colors.white70 : const Color(0xFF334155),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Action Row with Call Guardian Button!
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${context.tr("guardian_prefix")}: ${p.guardianName}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _callGuardian(context, p),
                          icon: const Icon(Icons.phone_rounded, size: 14),
                          label: Text(context.tr('doc_call_guardian'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // 5. Bottom Dynamic Inspirational / Clinical Wisdom Quote
  Widget _buildClinicalQuoteCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162522) : const Color(0xFFE8F5ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF243D37) : const Color(0xFFC8E6C9),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.format_quote_rounded, color: Color(0xFF00796B), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('doc_clinical_wisdom_title').toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  DoctorClinicalThoughts.thought,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.white70 : const Color(0xFF004D40),
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

  // =============================================================
  // TAB 2: CARE TEAM TAB
  // =============================================================
  Widget _buildCareTeamTab() {
    final repo = PhcRepository();
    final allAshas = repo.allAshaWorkers;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter patients
    var patientList = repo.patients;
    if (_careTeamVillageFilter != 'All Villages') {
      patientList = patientList.where((p) => p.village == _careTeamVillageFilter).toList();
    }
    if (_careTeamSearchQuery.isNotEmpty) {
      patientList = patientList.where((p) => p.name.toLowerCase().contains(_careTeamSearchQuery.toLowerCase())).toList();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Illustrated Hero Section with Animated Landscape & Botanical Leaf
          _buildCareTeamHeroSection(repo, allAshas, repo.patients),
          const SizedBox(height: 16),

          // 2. Modern Segmented Tab Switcher (ASHA vs Patients)
          _buildCareTeamSubTabSwitcher(allAshas.length, repo.patients.length, isDark),
          const SizedBox(height: 16),

          // 3. Sub-Tab Content
          _careTeamSubTabIndex == 0
              ? _buildAshaWorkersList(allAshas)
              : _buildPatientsList(patientList, repo.availableVillages),
        ],
      ),
    );
  }

  // 1. Care Team Hero Section with Animated Landscape, Leaves & Healthcare Accents
  Widget _buildCareTeamHeroSection(PhcRepository repo, List<PhcAshaModel> ashas, List<PhcPatientModel> patients) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final approvedCount = ashas.where((a) => a.isApproved).length;
    final pendingCount = ashas.where((a) => !a.isApproved).length;
    final villagesCount = repo.availableVillages.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E27) : const Color(0xFFE8F5ED),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFC8E6C9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Meditative Animated Landscape Background
            Positioned.fill(
              child: AnimatedNerLandscape(
                isDark: isDark,
                duration: const Duration(seconds: 14),
              ),
            ),
            // Healthcare Theme Accent Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _DoctorHealthcareDecorPainter(isDark: isDark),
              ),
            ),
            // Botanical Leaf Illustration (Right-Bottom Corner)
            Positioned(
              right: -10,
              bottom: -15,
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.28 : 0.45,
                  child: Image.asset(
                    'assets/images/notifications_leaf_bg.png',
                    width: 130,
                    height: 155,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const SizedBox(),
                  ),
                ),
              ),
            ),
            // Hero Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Sprout Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco_rounded, size: 14, color: Color(0xFF00796B)),
                            const SizedBox(width: 5),
                            Text(
                              context.tr('doc_care_team_badge'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (pendingCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: isDark ? 0.3 : 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade400, width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.pending_actions_rounded, size: 12, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('doc_pending_badge', params: {'count': '$pendingCount'}),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('doc_rural_care_team'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      context.tr('doc_rural_care_team_sub', params: {'count': '$villagesCount'}),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark ? Colors.white70 : const Color(0xFF47655E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // KPI Summary Badges in Wrap for responsiveness
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCareHeroChip(
                        icon: Icons.badge_rounded,
                        label: context.tr('doc_active_asha_chip', params: {'count': '$approvedCount'}),
                        isDark: isDark,
                        color: const Color(0xFF00796B),
                      ),
                      _buildCareHeroChip(
                        icon: Icons.elderly_rounded,
                        label: context.tr('doc_monitored_elders_chip', params: {'count': '${patients.length}'}),
                        isDark: isDark,
                        color: const Color(0xFF2E7D32),
                      ),
                      _buildCareHeroChip(
                        icon: Icons.holiday_village_rounded,
                        label: context.tr('doc_villages_chip', params: {'count': '$villagesCount'}),
                        isDark: isDark,
                        color: const Color(0xFF0288D1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareHeroChip({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF162422).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  // 2. Sub-Tab Switcher (ASHA vs Patients)
  Widget _buildCareTeamSubTabSwitcher(int ashaCount, int patientCount, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModernTabPill(
              icon: Icons.badge_rounded,
              label: context.tr('doc_asha_workers_tab', params: {'count': '$ashaCount'}),
              isSelected: _careTeamSubTabIndex == 0,
              isDark: isDark,
              onTap: () => setState(() => _careTeamSubTabIndex = 0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModernTabPill(
              icon: Icons.elderly_rounded,
              label: context.tr('doc_patients_tab', params: {'count': '$patientCount'}),
              isSelected: _careTeamSubTabIndex == 1,
              isDark: isDark,
              onTap: () => setState(() => _careTeamSubTabIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernTabPill({
    required IconData icon,
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00796B)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00796B).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. ASHA Workers List (Responsive Grid / Stack)
  Widget _buildAshaWorkersList(List<PhcAshaModel> ashas) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (ashas.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2827) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded, size: 42, color: Color(0xFF00796B)),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('doc_no_asha_connected'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('doc_no_asha_sub', params: {'code': PhcRepository().doctor.facilityCode}),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 650;
        final count = ashas.length;

        if (isWide) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 185,
            ),
            itemCount: count,
            itemBuilder: (context, i) => _buildAshaCard(ashas[i], isDark),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _buildAshaCard(ashas[i], isDark),
        );
      },
    );
  }

  Widget _buildAshaCard(PhcAshaModel asha, bool isDark) {
    final repo = PhcRepository();
    final initial = asha.name.trim().isNotEmpty ? asha.name.trim()[0].toUpperCase() : 'A';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: asha.isApproved
              ? (isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8))
              : (isDark ? const Color(0xFF6B4519) : const Color(0xFFFFCC80)),
          width: asha.isApproved ? 1.2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: asha.isApproved
                ? const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.04)
                : Colors.orange.withValues(alpha: isDark ? 0.15 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Avatar, Name, Cluster, Badge
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: asha.isApproved
                        ? [const Color(0xFF00796B), const Color(0xFF004D40)]
                        : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (asha.isApproved ? const Color(0xFF00796B) : Colors.orange).withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asha.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF00796B)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            asha.villageCluster.isNotEmpty ? asha.villageCluster : "Unassigned Village",
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: asha.isApproved
                      ? const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12)
                      : Colors.orange.withValues(alpha: isDark ? 0.3 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: asha.isApproved
                        ? const Color(0xFF00796B).withValues(alpha: isDark ? 0.6 : 0.3)
                        : Colors.orange.withValues(alpha: isDark ? 0.6 : 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      asha.isApproved ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 11,
                      color: asha.isApproved ? const Color(0xFF00796B) : Colors.orange.shade800,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      asha.isApproved ? context.tr('status_approved') : context.tr('status_pending'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: asha.isApproved
                            ? (isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B))
                            : (isDark ? Colors.orange.shade300 : Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8)),
          const SizedBox(height: 10),

          if (!asha.isApproved) ...[
            // Pending Action Row
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('doc_awaiting_verification'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.orange.shade300 : Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await repo.deleteAshaWorker(asha.id);
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: Colors.red.shade700,
                          content: Text('Declined & removed "${asha.name}".'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                  label: Text(context.tr('doc_reject_btn'), style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade300),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    await repo.approveAshaWorker(asha.id);
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: Color(0xFF00796B),
                          content: Text('ASHA approved successfully! 🩺'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 14),
                  label: Text(context.tr('doc_approve_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Approved Metrics Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildStatItem(context.tr('doc_target_label'), context.tr('doc_elders_count', params: {'count': '${asha.targetElders}'}))),
                Expanded(child: _buildStatItem(context.tr('doc_completed_screenings'), context.tr('doc_visits_count', params: {'count': '${asha.visitedCount}'}))),
                Expanded(child: _buildStatItem(context.tr('doc_skipped_refused'), context.tr('doc_visits_count', params: {'count': '${asha.skippedCount}'}))),
                IconButton(
                  tooltip: 'Call ASHA ${asha.name}',
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.phone_rounded, color: Color(0xFF00796B), size: 16),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Calling ASHA ${asha.name} (${asha.phone})...')),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 4. Patients List (Responsive Search, Filter, and Grid)
  Widget _buildPatientsList(List<PhcPatientModel> patients, List<String> villages) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search & Filter Bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2827) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.12 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: context.tr('doc_search_patient_hint'),
                    hintStyle: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white38 : Colors.grey.shade500,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF00796B)),
                    suffixIcon: _careTeamSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _careTeamSearchQuery = ''),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.5),
                    ),
                  ),
                  onChanged: (v) => setState(() => _careTeamSearchQuery = v),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.4 : 0.25),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: ['All Villages', ...villages].contains(_careTeamVillageFilter)
                        ? _careTeamVillageFilter
                        : 'All Villages',
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF00796B)),
                    dropdownColor: isDark ? const Color(0xFF1E2827) : Colors.white,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                    items: {'All Villages', ...villages}.map((v) => DropdownMenuItem(
                      value: v,
                      child: Text(v == 'All Villages' ? context.tr('all_villages') : v),
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _careTeamVillageFilter = val);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Patient Cards List or Empty State
        if (patients.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2827) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.elderly_rounded, size: 40, color: Color(0xFF00796B)),
                ),
                const SizedBox(height: 16),
                Text(
                  context.tr('doc_no_elders_found'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('doc_no_elders_sub'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 650;
              final count = patients.length;

              if (isWide) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 140,
                  ),
                  itemCount: count,
                  itemBuilder: (context, i) => _buildPatientCard(patients[i], isDark),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: count,
                separatorBuilder: (c, i) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _buildPatientCard(patients[i], isDark),
              );
            },
          ),
      ],
    );
  }

  Widget _buildPatientCard(PhcPatientModel p, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Neutral Elder Avatar
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/neutral_elder_avatar.png',
                  width: 38,
                  height: 38,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.elderly_rounded, size: 22, color: Color(0xFF00796B)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${p.name} (${p.age}y / ${p.gender})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildRiskBadge(p.riskLevel),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.home_outlined, size: 12, color: Color(0xFF00796B)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${p.village} • ${context.tr('doc_house_fmt', params: {'house': p.houseNo})}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Assigned ASHA & Score row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.18),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_pin_circle_rounded, size: 15, color: Color(0xFF00796B)),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white70 : const Color(0xFF1E293B),
                      ),
                      children: [
                        TextSpan(
                          text: '${context.tr('doc_asha_label')}: ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                          ),
                        ),
                        TextSpan(
                          text: p.assignedAshaName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.4 : 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${context.tr('doc_score_fmt')}: ${p.latestScore}/10',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
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

  // =============================================================
  // TAB 3: INSIGHTS TAB
  // =============================================================
  Widget _buildInsightsTab() {
    final repo = PhcRepository();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Illustrated Hero Section with Botanical Leaf & Healthcare Painter
          _buildInsightsHeroSection(repo, isDark),
          const SizedBox(height: 16),

          // 2. Modern Segmented Tab Switcher
          _buildInsightsSubTabSwitcher(isDark),
          const SizedBox(height: 16),

          // 3. Analytics Content
          _insightsSubTabIndex == 0
              ? _buildPatientInsightsContent(repo)
              : _buildAshaInsightsContent(repo),
        ],
      ),
    );
  }

  Widget _buildInsightsHeroSection(PhcRepository repo, bool isDark) {
    final totalPatients = repo.patients.length;
    final criticalCount = repo.criticalAlertPatients.length;
    final villages = repo.availableVillages.length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E27) : const Color(0xFFE8F5ED),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFC8E6C9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Meditative Landscape
            Positioned.fill(
              child: AnimatedNerLandscape(
                isDark: isDark,
                duration: const Duration(seconds: 14),
              ),
            ),
            // Healthcare Theme Accent Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _DoctorHealthcareDecorPainter(isDark: isDark),
              ),
            ),
            // Botanical Leaf Illustration (Right-Bottom Corner)
            Positioned(
              right: -10,
              bottom: -15,
              child: IgnorePointer(
                child: Opacity(
                  opacity: isDark ? 0.26 : 0.42,
                  child: Image.asset(
                    'assets/images/greeting_botanical_accent.png',
                    height: 130,
                    fit: BoxFit.contain,
                    errorBuilder: (c, e, s) => const SizedBox(),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sprout Pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.eco_rounded, size: 14, color: Color(0xFF00796B)),
                            const SizedBox(width: 5),
                            Text(
                              context.tr('doc_insights_badge'),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, size: 12, color: Color(0xFF00796B)),
                            const SizedBox(width: 4),
                            Text(
                              context.tr('doc_live_telemetry'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    context.tr('doc_epidemiological_insights'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      context.tr('doc_insights_hero_sub'),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: isDark ? Colors.white70 : const Color(0xFF47655E),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // KPI Summary Badges in Wrap
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCareHeroChip(
                        icon: Icons.psychology_rounded,
                        label: context.tr('doc_screened_chip', params: {'count': '$totalPatients'}),
                        isDark: isDark,
                        color: const Color(0xFF00796B),
                      ),
                      _buildCareHeroChip(
                        icon: Icons.warning_amber_rounded,
                        label: context.tr('doc_critical_alerts_chip', params: {'count': '$criticalCount'}),
                        isDark: isDark,
                        color: criticalCount > 0 ? Colors.red : const Color(0xFF2E7D32),
                      ),
                      _buildCareHeroChip(
                        icon: Icons.holiday_village_rounded,
                        label: context.tr('doc_villages_chip', params: {'count': '$villages'}),
                        isDark: isDark,
                        color: const Color(0xFF0288D1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSubTabSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildModernTabPill(
              icon: Icons.psychology_rounded,
              label: context.tr('doc_patient_insights_tab'),
              isSelected: _insightsSubTabIndex == 0,
              isDark: isDark,
              onTap: () => setState(() => _insightsSubTabIndex = 0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildModernTabPill(
              icon: Icons.analytics_rounded,
              label: context.tr('doc_asha_insights_tab'),
              isSelected: _insightsSubTabIndex == 1,
              isDark: isDark,
              onTap: () => setState(() => _insightsSubTabIndex = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientInsightsContent(PhcRepository repo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = repo.patients.length;
    final normal = repo.patients.where((p) => p.riskLevel == 'normal').length;
    final mci = repo.patients.where((p) => p.riskLevel == 'mci_warning').length;
    final severe = repo.patients.where((p) => p.riskLevel == 'severe_decline').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Cognitive Distribution Card with Brain Art
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2827) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/insights_brain_art.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.psychology_rounded, color: Color(0xFF00796B), size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('doc_cognitive_distribution'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('doc_cognitive_distribution_sub'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildModernProgressBar(
                label: context.tr('doc_normal_trajectory'),
                count: normal,
                total: total,
                color: const Color(0xFF00796B),
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildModernProgressBar(
                label: context.tr('doc_mci_warning_trajectory'),
                count: mci,
                total: total,
                color: Colors.amber.shade700,
                isDark: isDark,
              ),
              const SizedBox(height: 14),
              _buildModernProgressBar(
                label: context.tr('doc_severe_decline_trajectory'),
                count: severe,
                total: total,
                color: Colors.red.shade600,
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Village-wise Dementia Burden Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2827) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.holiday_village_rounded, color: Color(0xFF00796B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('doc_village_burden'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (repo.availableVillages.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No village clusters registered yet.',
                    style: TextStyle(color: isDark ? Colors.white60 : Colors.grey, fontSize: 12),
                  ),
                )
              else
                ...repo.availableVillages.map((v) {
                  final pList = repo.getPatientsByVillage(v);
                  final criticalCount = pList.where((p) => p.isCriticalDecline).length;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14221F) : const Color(0xFFF8FAF9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF243633) : const Color(0xFFE2ECE8),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF00796B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                context.tr('doc_elders_monitored_sub', params: {'count': '${pList.length}'}),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: criticalCount > 0
                                ? Colors.red.withValues(alpha: isDark ? 0.3 : 0.12)
                                : const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: criticalCount > 0
                                  ? Colors.red.withValues(alpha: isDark ? 0.6 : 0.3)
                                  : const Color(0xFF00796B).withValues(alpha: isDark ? 0.6 : 0.3),
                            ),
                          ),
                          child: Text(
                            context.tr('doc_critical_count_badge', params: {'count': '$criticalCount'}),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: criticalCount > 0
                                  ? (isDark ? Colors.red.shade300 : Colors.red.shade900)
                                  : (isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModernProgressBar({
    required String label,
    required int count,
    required int total,
    required Color color,
    required bool isDark,
  }) {
    final percent = total > 0 ? (count / total) : 0.0;
    final percentText = (percent * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count ($percentText%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 9,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14221F) : const Color(0xFFE2ECE8),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.8), color],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAshaInsightsContent(PhcRepository repo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visitLogs = repo.visitLogs;
    final totalVisits = visitLogs.where((v) => v.status == 'visited').length;
    final totalSkips = visitLogs.where((v) => v.status == 'skipped').length;
    final totalAttempts = totalVisits + totalSkips;
    final completionPct = totalAttempts > 0 ? ((totalVisits / totalAttempts) * 100).round() : 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. ASHA Visit Efficiency Overview Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2827) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Color(0xFF00796B), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('doc_field_perf_title'),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('doc_field_perf_sub'),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Dual Metric Cards Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.4 : 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 14, color: Color(0xFF00796B)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.tr('doc_completed_screenings'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('doc_done_count', params: {'count': '$totalVisits'}),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF004D40),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: isDark ? 0.22 : 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: isDark ? 0.4 : 0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.pause_circle_rounded, size: 14, color: Colors.amber),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  context.tr('doc_skipped_refused'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.amber.shade300 : Colors.brown.shade800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr('doc_skipped_count', params: {'count': '$totalSkips'}),
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : Colors.brown.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Overall Efficiency Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('doc_overall_completion'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                    ),
                  ),
                  Text(
                    '$completionPct%',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00796B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: completionPct / 100.0,
                  backgroundColor: isDark ? const Color(0xFF14221F) : const Color(0xFFE2ECE8),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Skip Reasons Breakdown Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2827) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 10,
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: isDark ? 0.25 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.pie_chart_rounded, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('doc_skip_reasons'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (totalSkips == 0)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14221F) : const Color(0xFFF8FAF9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/insights_empty_history_art.png',
                          width: 48,
                          height: 48,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(Icons.verified_rounded, color: Color(0xFF00796B), size: 36),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('doc_flawless_coverage'),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('doc_flawless_coverage_sub'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _SkipReasonBar(
                  label: context.tr('skip_reason_unwell'),
                  percent: ((visitLogs.where((v) => v.status == 'skipped' && v.skipReason == 'unwell').length / totalSkips) * 100).round(),
                  color: Colors.orange,
                ),
                const SizedBox(height: 10),
                _SkipReasonBar(
                  label: context.tr('skip_reason_flood'),
                  percent: ((visitLogs.where((v) => v.status == 'skipped' && v.skipReason == 'flood_inaccessible').length / totalSkips) * 100).round(),
                  color: Colors.blue,
                ),
                const SizedBox(height: 10),
                _SkipReasonBar(
                  label: context.tr('skip_reason_festival'),
                  percent: ((visitLogs.where((v) => v.status == 'skipped' && v.skipReason == 'not_home').length / totalSkips) * 100).round(),
                  color: Colors.purple,
                ),
                const SizedBox(height: 10),
                _SkipReasonBar(
                  label: context.tr('skip_reason_refused'),
                  percent: ((visitLogs.where((v) => v.status == 'skipped' && v.skipReason == 'refused').length / totalSkips) * 100).round(),
                  color: Colors.red,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // =============================================================
  // TAB 4: PROFILE & REPORT GENERATION TAB
  // =============================================================
  // =============================================================
  // TAB 4: PROFILE & REPORT GENERATION TAB
  // =============================================================
  Widget _buildProfileTab() {
    final repo = PhcRepository();
    final doc = repo.doctor;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Doctor Profile Hero Card
          _buildDoctorProfileHeroCard(doc),
          const SizedBox(height: 16),

          // 2. Permanent PHC Govt Facility Card
          _buildPhcFacilityCard(doc),
          const SizedBox(height: 16),

          // 3. Medical Officer Clinical Credentials Card
          _buildDoctorCredentialsCard(doc),
          const SizedBox(height: 16),

          // 4. PHC Clinical Reports Generator Card
          _buildClinicalReportsCard(repo),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 1. Doctor Profile Hero Card (Caregiver/ASHA Standard)
  Widget _buildDoctorProfileHeroCard(PhcDoctorModel doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2E27) : const Color(0xFFE8F5ED),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFC8E6C9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Background NER Landscape
            Positioned.fill(
              child: AnimatedNerLandscape(
                isDark: isDark,
                duration: const Duration(seconds: 14),
              ),
            ),
            // Healthcare Theme Accent Painter
            Positioned.fill(
              child: CustomPaint(
                painter: _DoctorHealthcareDecorPainter(isDark: isDark),
              ),
            ),
            // Profile Card Content
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Circle with Verified Ring
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF004D40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00796B).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            doc.name.trim().isNotEmpty
                                ? (doc.name.startsWith('Dr.') ? 'Dr' : doc.name[0].toUpperCase())
                                : 'Dr',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1B2E27) : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name, Designation, Email & Reg No
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                doc.name,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: Color(0xFF00796B),
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          doc.designation,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 13,
                              color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                doc.email,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            doc.doctorRegNo.isNotEmpty ? 'Reg: ${doc.doctorRegNo}' : context.tr('doc_duty_officer'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00796B),
                              letterSpacing: 0.3,
                            ),
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
    );
  }

  // 2. Permanent PHC Govt Facility Card
  Widget _buildPhcFacilityCard(PhcDoctorModel doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
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
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_rounded, color: Color(0xFF00796B), size: 14),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.tr('doc_permanent_facility').toUpperCase(),
                          style: const TextStyle(color: Color(0xFF00796B), fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: doc.facilityCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF00796B),
                      content: Text(context.tr('doc_facility_code_copied')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.5 : 0.3),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_rounded, size: 14, color: Color(0xFF00796B)),
                      const SizedBox(width: 6),
                      Text(
                        doc.facilityCode,
                        style: const TextStyle(
                          color: Color(0xFF00796B),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF00796B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            doc.hospitalName,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Block Health Jurisdiction • District Jorhat, Assam (NER)',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14221F) : const Color(0xFFF1F5F3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF243633) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFF00796B), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PHC Centre & Facility Code remain permanent; Medical Officers rotate on duty.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      fontStyle: FontStyle.italic,
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

  // 3. Medical Officer Clinical Credentials Card
  Widget _buildDoctorCredentialsCard(PhcDoctorModel doc) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.medical_information_rounded, color: Color(0xFF00796B), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('doc_duty_officer'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      doc.designation,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _showEditDoctorDialog(context),
                icon: const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                label: Text(context.tr('doc_edit_credentials'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00796B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8)),
          const SizedBox(height: 8),
          _buildDetailRow(context.tr('doc_name_label'), doc.name),
          _buildDetailRow(context.tr('doc_designation_label'), doc.designation),
          _buildDetailRow(context.tr('doc_reg_no_label'), doc.doctorRegNo),
          _buildDetailRow(context.tr('doc_contact_label'), doc.phone),
          _buildDetailRow(context.tr('doc_email_label'), doc.email),
        ],
      ),
    );
  }

  // 4. PHC Clinical Reports Generator Card
  Widget _buildClinicalReportsCard(PhcRepository repo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF00796B), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('doc_reports_generator'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('doc_reports_generator_sub'),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),

          // 1. Report Period Toggle (Daily vs Monthly)
          Text(
            context.tr('doc_select_timeframe').toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(context.tr('doc_timeframe_daily'), _reportPeriod == 'daily', () => setState(() => _reportPeriod = 'daily')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceChip(context.tr('doc_timeframe_monthly'), _reportPeriod == 'monthly', () => setState(() => _reportPeriod = 'monthly')),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Report Type (Patient Clinical vs ASHA Supervision)
          Text(
            context.tr('doc_select_scope').toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(context.tr('doc_report_patient_roster'), _reportType == 'patient', () => setState(() => _reportType = 'patient')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceChip(context.tr('doc_report_asha_field'), _reportType == 'asha', () => setState(() => _reportType = 'asha')),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Generate Button
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
                  color: const Color(0xFF00796B).withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                final reportData = repo.generateReportData(
                  reportType: _reportType,
                  period: _reportPeriod,
                );
                DoctorReportPreviewDialog.show(context, reportData);
              },
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
              label: Text(
                context.tr('doc_generate_preview_btn'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // DIALOGS & HELPER WIDGETS
  // -------------------------------------------------------------
  void _showPendingAshasDialog(BuildContext context) {
    final repo = PhcRepository();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final pending = repo.pendingAshaWorkers;

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Gradient Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF004D40), Color(0xFF00695C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.people_outline_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${context.tr('doc_pending_ashas')} (${pending.length})',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const Text(
                                'Synced from Firebase Cloud & Local Network',
                                style: TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // Notice Banner
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade800, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Unapproved accounts from testing or field registrations. Approve or permanently remove them.',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content Area
                  Flexible(
                    child: pending.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF004D40).withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF004D40), size: 36),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  context.tr('doc_all_approved'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'There are no pending unverified staff in the network.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: pending.map((asha) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.teal.shade50,
                                            child: const Icon(Icons.person, color: Color(0xFF004D40), size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  asha.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                                ),
                                                Text(
                                                  'Village: ${asha.villageCluster.isNotEmpty ? asha.villageCluster : "Unassigned"} • ${asha.phone.isNotEmpty ? asha.phone : "No phone"}',
                                                  style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          // Decline & Permanently Remove
                                          OutlinedButton.icon(
                                            onPressed: () async {
                                              await repo.deleteAshaWorker(asha.id);
                                              setDialogState(() {});
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    backgroundColor: Colors.red.shade700,
                                                    content: Text('Declined & removed "${asha.name}".'),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.close, size: 14, color: Colors.red),
                                            label: Text(context.tr('doc_reject_btn'), style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.red.shade300),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Approve Button
                                          ElevatedButton.icon(
                                            onPressed: () async {
                                              await repo.approveAshaWorker(asha.id);
                                              setDialogState(() {});
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    backgroundColor: AppColors.primary,
                                                    content: Text('ASHA ${asha.name} approved successfully! 🩺'),
                                                  ),
                                                );
                                              }
                                            },
                                            icon: const Icon(Icons.check_circle_rounded, size: 14),
                                            label: Text(context.tr('doc_approve_btn'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ),

                  // Bottom Action
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(context.tr('close')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDoctorDialog(BuildContext context) {
    final repo = PhcRepository();
    final doc = repo.doctor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameController = TextEditingController(text: doc.name);
    final regNoController = TextEditingController(text: doc.doctorRegNo);
    final designationController = TextEditingController(text: doc.designation);
    final phoneController = TextEditingController(text: doc.phone);
    final emailController = TextEditingController(text: doc.email);

    Widget buildInput({
      required TextEditingController controller,
      required String label,
      required String hint,
      required IconData icon,
      TextInputType keyboardType = TextInputType.text,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF00796B), size: 18),
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF141F1D) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 490),
          color: isDark ? const Color(0xFF1E2827) : Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Premium Gradient Header with Assam Leaves & Healthcare Decor
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: const Icon(Icons.badge_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr('doc_credentials_title'),
                                  style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.tr('doc_credentials_sub'),
                                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20, color: Colors.white70),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Form Body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Permanent PHC Badge Notice (Clinical Glass Banner)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF162522) : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF264039) : const Color(0xFFA5D6A7),
                            width: 1.1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.15),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Icon(Icons.account_balance_rounded, color: Color(0xFF00796B), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.hospitalName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: isDark ? Colors.white : const Color(0xFF004D40),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Jurisdiction Code: ${doc.facilityCode} • Non-Transferable PHC Facility',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      buildInput(
                        controller: nameController,
                        label: '${context.tr('doc_name_label')} *',
                        hint: 'e.g. Dr. Alok Singh',
                        icon: Icons.person_outline_rounded,
                      ),
                      buildInput(
                        controller: designationController,
                        label: '${context.tr('doc_designation_label')} *',
                        hint: 'e.g. Medical Officer In-Charge',
                        icon: Icons.medical_services_outlined,
                      ),
                      buildInput(
                        controller: regNoController,
                        label: '${context.tr('doc_reg_no_label')} *',
                        hint: 'e.g. NMC-AS-2018-9410',
                        icon: Icons.assignment_ind_outlined,
                      ),
                      buildInput(
                        controller: phoneController,
                        label: context.tr('doc_contact_label'),
                        hint: '+91 98765-XXXXX',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      buildInput(
                        controller: emailController,
                        label: context.tr('doc_email_label'),
                        hint: 'doctor@assamhealth.gov.in',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions Row
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF172220) : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF2E403D) : const Color(0xFFCBD5E1),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(context.tr('btn_cancel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
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
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final enteredName = nameController.text.trim();
                            if (enteredName.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Colors.red,
                                  content: Text('Doctor ka naam bharna anivarya hai!'),
                                ),
                              );
                              return;
                            }

                            await repo.updateDoctorProfile(
                              name: enteredName,
                              designation: designationController.text.trim(),
                              doctorRegNo: regNoController.text.trim(),
                              phone: phoneController.text.trim(),
                              email: emailController.text.trim(),
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: AppColors.primary,
                                  content: Text('Duty Doctor profile updated: ${repo.doctor.name} 🩺'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                          label: Text(
                            context.tr('doc_save_profile'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
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
      ),
    );
  }

  void _callGuardian(BuildContext context, PhcPatientModel p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 10),
            Text(context.tr('doc_contact_guardian'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.name} (${context.tr('doc_score_fmt')}: ${p.latestScore}/10)'),
            const SizedBox(height: 10),
            Text('${context.tr('guardian_prefix')}: ${p.guardianName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${context.tr('doc_contact_label')}: ${p.guardianPhone}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 15)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('btn_cancel'))),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.primary,
                  content: Text('Dialing ${p.guardianPhone} (${p.guardianName})... 📞'),
                ),
              );
            },
            icon: const Icon(Icons.call, size: 16),
            label: Text(context.tr('doc_call_now')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTabButton(String label, int index, int current, Function(int) onTap) {
    final isSelected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.primaryDark : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }


  Widget _buildChoiceChip(String label, bool isSelected, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12)
              : (isDark ? const Color(0xFF1B2E27) : const Color(0xFFF1F5F3)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF00796B)
                : (isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B))
                : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          val,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10.5, color: isDark ? Colors.white54 : Colors.grey)),
      ],
    );
  }

  Widget _buildDetailRow(String label, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              val.isEmpty ? '-' : val,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(String risk) {
    Color bg;
    Color fg;
    String text;
    if (risk == 'severe_decline') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
      text = context.tr('risk_severe_decline');
    } else if (risk == 'mci_warning') {
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
      text = context.tr('risk_mci_warning');
    } else {
      bg = Colors.teal.shade100;
      fg = Colors.teal.shade900;
      text = context.tr('risk_normal');
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  String _getMonthName(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[(month - 1).clamp(0, 11)];
  }

  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162422) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        backgroundColor: isDark ? const Color(0xFF162422) : Colors.white,
        elevation: 0,
        currentIndex: _currentNavIndex,
        onTap: (i) => setState(() => _currentNavIndex = i),
        selectedItemColor: const Color(0xFF00796B),
        unselectedItemColor: isDark ? Colors.white54 : Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home_rounded),
            label: context.tr('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline_rounded),
            activeIcon: const Icon(Icons.people_rounded),
            label: context.tr('tab_care_team'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.analytics_outlined),
            activeIcon: const Icon(Icons.analytics_rounded),
            label: context.tr('tab_insights'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline_rounded),
            activeIcon: const Icon(Icons.person_rounded),
            label: context.tr('nav_profile'),
          ),
        ],
      ),
    );
  }
}

class _SkipReasonBar extends StatelessWidget {
  final String label;
  final int percent;
  final Color color;

  const _SkipReasonBar({required this.label, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.black87)),
            Text('$percent%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent / 100,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

/// Subtle authentic healthcare-themed decorative painter
/// Draws soft organic leaves, medical cross icons, and ECG heartbeat lines
class _DoctorHealthcareDecorPainter extends CustomPainter {
  final bool isDark;

  const _DoctorHealthcareDecorPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Translucent theme-aware colors
    final leafColor = (isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B)).withValues(alpha: isDark ? 0.08 : 0.07);
    final crossColor = (isDark ? Colors.white : const Color(0xFF004D40)).withValues(alpha: isDark ? 0.07 : 0.06);
    final pulseColor = (isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B)).withValues(alpha: isDark ? 0.09 : 0.08);

    final leafPaint = Paint()
      ..color = leafColor
      ..style = PaintingStyle.fill;

    // Leaf 1 (Top right corner)
    final leaf1 = Path()
      ..moveTo(w * 0.88, h * 0.06)
      ..quadraticBezierTo(w * 0.96, h * 0.12, w * 0.94, h * 0.24)
      ..quadraticBezierTo(w * 0.84, h * 0.20, w * 0.88, h * 0.06)
      ..close();
    canvas.drawPath(leaf1, leafPaint);

    // Leaf 2 (Paired small leaf)
    final leaf2 = Path()
      ..moveTo(w * 0.91, h * 0.15)
      ..quadraticBezierTo(w * 0.99, h * 0.18, w * 0.97, h * 0.28)
      ..quadraticBezierTo(w * 0.89, h * 0.25, w * 0.91, h * 0.15)
      ..close();
    canvas.drawPath(leaf2, leafPaint);

    // Leaf 3 (Bottom left corner)
    final leaf3 = Path()
      ..moveTo(w * 0.08, h * 0.78)
      ..quadraticBezierTo(w * 0.02, h * 0.86, w * 0.05, h * 0.96)
      ..quadraticBezierTo(w * 0.14, h * 0.90, w * 0.08, h * 0.78)
      ..close();
    canvas.drawPath(leaf3, leafPaint);

    // Medical Cross (+) Top-Center-Left
    _drawMedicalCross(canvas, Offset(w * 0.38, h * 0.22), 12, crossColor);

    // Medical Cross (+) Bottom-Center-Right
    _drawMedicalCross(canvas, Offset(w * 0.74, h * 0.78), 10, crossColor);

    // Subtle ECG Pulse Line across bottom
    final pulsePaint = Paint()
      ..color = pulseColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    final pulsePath = Path()
      ..moveTo(w * 0.52, h * 0.90)
      ..lineTo(w * 0.62, h * 0.90)
      ..lineTo(w * 0.65, h * 0.84)
      ..lineTo(w * 0.68, h * 0.95)
      ..lineTo(w * 0.71, h * 0.81)
      ..lineTo(w * 0.74, h * 0.92)
      ..lineTo(w * 0.77, h * 0.90)
      ..lineTo(w * 0.86, h * 0.90);
    canvas.drawPath(pulsePath, pulsePaint);
  }

  void _drawMedicalCross(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final thick = size / 3;

    // Horizontal bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: size, height: thick),
        Radius.circular(thick / 2),
      ),
      paint,
    );
    // Vertical bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: thick, height: size),
        Radius.circular(thick / 2),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DoctorHealthcareDecorPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

