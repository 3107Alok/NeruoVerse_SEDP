import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../data/phc_repository.dart';
import '../../models/phc_patient_model.dart';
import '../../models/phc_asha_model.dart';
import '../../models/phc_doctor_model.dart';
import 'asha_skip_bottom_sheet.dart';
import 'asha_register_patient_dialog.dart';
import 'asha_patient_games_screen.dart';
import 'asha_sync_screen.dart';
import 'asha_patients_tab.dart';
import 'asha_insights_tab.dart';
import 'asha_profile_tab.dart';
import 'asha_settings_screen.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../patient/games/common/ner_illustrations.dart';
import 'caregiver_illustration_painter.dart';

class AshaDashboardScreen extends StatefulWidget {
  const AshaDashboardScreen({super.key});

  @override
  State<AshaDashboardScreen> createState() => _AshaDashboardScreenState();
}

class _AshaDashboardScreenState extends State<AshaDashboardScreen> {
  int _currentIndex = 0;
  String _selectedVillage = 'All Villages';
  String _searchQuery = '';
  String _filter = 'all'; // 'all', 'due', 'high_risk', 'screened'
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: PhcRepository(),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: _buildTopAppBar(),
          body: _buildCurrentTab(),
          bottomNavigationBar: _buildBottomNav(),
          floatingActionButton: _currentIndex == 0 ? _buildFab() : null,
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TOP APP BAR (Caregiver & Patient Design Standard)
  // -------------------------------------------------------------
  PreferredSizeWidget _buildTopAppBar() {
    final repo = PhcRepository();
    final pendingCount = repo.pendingSyncCount;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      titleSpacing: 16,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/images/app_icon.jpg',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF00796B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.psychology_rounded, size: 20, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NeuroVerse',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Care Together. Grow Together.',
                  style: TextStyle(
                    fontSize: 9.8,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.grey.shade600,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: theme.cardColor,
      elevation: 0,
      foregroundColor: isDark ? Colors.white : Colors.black87,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
          height: 1,
        ),
      ),
      actions: [
        // Sync Button with Pending Badge in circular container
        IconButton(
          tooltip: context.tr('asha_sync_cloud'),
          icon: Container(
            padding: EdgeInsets.all(isSmall ? 4.5 : 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF122822) : const Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.sync_rounded,
                  size: isSmall ? 20 : 22,
                  color: const Color(0xFF00796B),
                ),
                if (pendingCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF9800),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AshaSyncScreen()),
            );
          },
        ),
        // Dedicated ASHA Settings Page
        IconButton(
          tooltip: context.tr('settings'),
          icon: Container(
            padding: EdgeInsets.all(isSmall ? 5 : 7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFE0F2F1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.settings_outlined,
              color: const Color(0xFF00796B),
              size: isSmall ? 18 : 20,
            ),
          ),
          onPressed: () {
            AshaSettingsScreen.show(
              context,
              onNavigateToProfile: () {
                if (mounted) {
                  setState(() => _currentIndex = 3);
                }
              },
            );
          },
        ),
        SizedBox(width: isSmall ? 4 : 8),
      ],
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const AshaPatientsTab();
      case 2:
        return const AshaInsightsTab();
      case 3:
      default:
        return const AshaProfileTab();
    }
  }

  // -------------------------------------------------------------
  // TAB 1: HOME TAB
  // -------------------------------------------------------------
  Widget _buildHomeTab() {
    final repo = PhcRepository();
    final asha = repo.currentAsha;
    final doctor = repo.doctor;
    final villages = repo.availableVillages;
    final villageOptions = {'All Villages', ...villages}.toList();
    if (!villageOptions.contains(_selectedVillage)) {
      _selectedVillage = 'All Villages';
    }

    final scheduledVisits = repo.getScheduledVisits(_selectedVillage);
    final completedVisits = repo.getScheduledCompleted(_selectedVillage);

    final villagePatients = repo.getPatientsByVillage(_selectedVillage);
    final filtered = villagePatients.where((p) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final match = p.name.toLowerCase().contains(query) || p.houseNo.toLowerCase().contains(query);
        if (!match) return false;
      }
      if (_filter == 'due') return p.status == 'due';
      if (_filter == 'high_risk') return p.isCriticalDecline || p.riskLevel == 'severe_decline';
      if (_filter == 'screened') return p.status == 'visited_today';
      return true;
    }).toList();

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

    return RefreshIndicator(
      color: const Color(0xFF00796B),
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          isSmall ? 12.0 : 16.0,
          12.0,
          isSmall ? 12.0 : 16.0,
          88.0,
        ),
        children: [
          // 0. Pending Approval Alert Banner
          if (!asha.isApproved) ...[
            _buildApprovalAlertBanner(asha),
          ],

          // 1. Welcome Greeting & Doctor Scheduled Visits Hero Card (Signature Animated Landscape)
          _buildWelcomeScheduledCard(asha, doctor, scheduledVisits, completedVisits),
          const SizedBox(height: 16),

          // 2. Aesthetic Village Dropdown Selector (Doctor/PHC Provided)
          _buildAestheticVillageSelector(repo),
          const SizedBox(height: 16),

          // 3. Search & Filter Bar
          _buildSearchAndFilters(villagePatients),
          const SizedBox(height: 14),

          // 4. Compact Patient Cards List
          if (filtered.isEmpty)
            _buildEmptyState()
          else
            ...filtered.map((patient) => _buildCompactPatientCard(patient)),
        ],
      ),
    );
  }

  // Pending Approval Alert Banner (Warm Amber Layered Surface)
  Widget _buildApprovalAlertBanner(PhcAshaModel asha) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2E1F12), const Color(0xFF24170D)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
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
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.pending_actions_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        context.tr('asha_mo_verification_pending'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: isDark ? 0.35 : 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFD97706).withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        context.tr('status_pending').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFD97706),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('asha_mo_verification_desc', params: {
                    'facility': asha.facilityCode.isNotEmpty ? asha.facilityCode : context.tr('not_set'),
                  }),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : const Color(0xFF78350F),
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

  // Welcome Hero Card with Animated Meditative Landscape (Caregiver/Patient Standard)
  Widget _buildWelcomeScheduledCard(PhcAshaModel asha, PhcDoctorModel doctor, int scheduled, int completed) {
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

    final progress = scheduled > 0 ? (completed / scheduled).clamp(0.0, 1.0) : 0.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

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
            Positioned.fill(
              child: AnimatedNerLandscape(
                isDark: isDark,
                duration: const Duration(seconds: 14),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isSmall ? 14.0 : 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Greeting & Identity Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  greetingEmoji,
                                  style: const TextStyle(fontSize: 14),
                                ),
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
                              asha.name,
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                fontSize: isSmall ? 19 : 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFF00796B).withValues(alpha: 0.25),
                                  width: 0.9,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.people_alt_rounded, size: 12, color: Color(0xFF00796B)),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      context.tr('asha_frontline_worker', params: {
                                        'facility': asha.facilityCode.isNotEmpty ? asha.facilityCode : context.tr('not_set'),
                                      }),
                                      style: const TextStyle(
                                        color: Color(0xFF00796B),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
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
                      const SizedBox(width: 8),
                      // Existing Elder + Caretaker vector illustration from Caregiver Home
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: SizedBox(
                          width: (screenWidth * 0.22).clamp(62.0, 84.0),
                          height: (screenWidth * 0.16).clamp(46.0, 62.0),
                          child: const CustomPaint(
                            painter: CaregiverIllustrationPainter(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Nested Frosted Glass Doctor Scheduled Visits Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF162421).withValues(alpha: 0.88)
                          : Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E4C3E) : const Color(0xFFCCE8DD),
                        width: 1.1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
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
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.event_note_rounded,
                                      size: 15,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      context.tr('asha_scheduled_doctor_visits'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                context.tr('asha_scheduled_done_fmt', params: {
                                  'completed': '$completed',
                                  'total': '$scheduled',
                                }),
                                style: const TextStyle(
                                  color: Color(0xFF00796B),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          context.tr('asha_scheduled_note_fmt', params: {
                            'doctor': doctor.name,
                            'count': '$scheduled',
                            'village': context.localizeVillage(_selectedVillage),
                          }),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : const Color(0xFF334155),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 7,
                            backgroundColor: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00796B)),
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

  // Aesthetic Village Selector Dropdown (Caregiver Card Style)
  Widget _buildAestheticVillageSelector(PhcRepository repo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final villages = {'All Villages', ...repo.availableVillages}.toList();
    final effectiveValue = villages.contains(_selectedVillage) ? _selectedVillage : 'All Villages';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                  color: const Color(0xFF00796B).withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF004D40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00796B).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('asha_current_village').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                    letterSpacing: 0.8,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectiveValue,
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
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                    ),
                    selectedItemBuilder: (BuildContext ctx) {
                      return villages.map<Widget>((String v) {
                        final count = repo.getPatientsByVillage(v).length;
                        final displayName = ctx.localizeVillage(v);
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count ${ctx.tr('elders_count_suffix')}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00796B),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                    items: villages.map((v) {
                      final count = repo.getPatientsByVillage(v).length;
                      final displayName = context.localizeVillage(v);
                      return DropdownMenuItem(
                        value: v,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$count ${context.tr('elders_count_suffix')}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00796B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedVillage = val);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Search and Filter Bar (Caregiver Modern Component)
  Widget _buildSearchAndFilters(List<PhcPatientModel> villagePatients) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dueCount = villagePatients.where((p) => p.status == 'due').length;
    final screenedCount = villagePatients.where((p) => p.status == 'visited_today').length;
    final criticalCount = villagePatients.where((p) => p.isCriticalDecline || p.riskLevel == 'severe_decline').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : const Color(0xFF1B3B36),
            ),
            decoration: InputDecoration(
              hintText: context.tr('search_elder_hint'),
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.grey.shade400,
              ),
              prefixIcon: Container(
                padding: const EdgeInsets.all(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.22 : 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF00796B),
                  ),
                ),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18, color: isDark ? Colors.white60 : Colors.grey.shade600),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildFilterChip(context.tr('asha_all_filter', params: {'count': '${villagePatients.length}'}), 'all', Icons.people_alt_rounded),
              const SizedBox(width: 8),
              _buildFilterChip('${context.tr("filter_due")} ($dueCount)', 'due', Icons.schedule_rounded),
              const SizedBox(width: 8),
              _buildFilterChip('${context.tr("filter_critical")} ($criticalCount)', 'high_risk', Icons.warning_amber_rounded),
              const SizedBox(width: 8),
              _buildFilterChip('${context.tr("filter_screened")} ($screenedCount)', 'screened', Icons.check_circle_outline_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _filter == value;
    const primaryColor = Color(0xFF00796B);

    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark ? const Color(0xFF1E2827) : Colors.white),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8)),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : (isDark
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF00796B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Individual Elder Visit Card (Caregiver Patient Card Standard)
  Widget _buildCompactPatientCard(PhcPatientModel p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCritical = p.isCriticalDecline || p.riskLevel == 'severe_decline';
    final isVisited = p.status == 'visited_today';

    // Status dot color on avatar (mirrors Caregiver patient card)
    final statusDotColor = isCritical
        ? const Color(0xFFDC2626)
        : (isVisited ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCritical
              ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
              : (isVisited
                  ? (isDark ? const Color(0xFF166534) : const Color(0xFF86EFAC))
                  : (isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8))),
          width: isCritical ? 1.5 : 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: isCritical
                      ? const Color(0xFFDC2626).withValues(alpha: 0.06)
                      : const Color(0xFF00796B).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar with Status Dot, Elder Name, Age/Gender, House, Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF004D40), const Color(0xFF00332C)]
                            : [const Color(0xFFE0F2F1), const Color(0xFFB2DFDB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF00796B) : Colors.white,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.name.isNotEmpty ? p.name[0].toUpperCase() : 'E',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF004D40),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: statusDotColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E2827) : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: statusDotColor.withValues(alpha: 0.5),
                            blurRadius: 3,
                          ),
                        ],
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${p.age} ${context.tr('field_age_yrs')} • ${p.gender.toLowerCase() == 'male' ? context.tr('gender_male') : (p.gender.toLowerCase() == 'female' ? context.tr('gender_female') : context.tr('gender_other'))}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00796B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.home_outlined,
                          size: 13,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${p.houseNo} • ${context.localizeVillage(p.village)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
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
              const SizedBox(width: 8),
              _buildCompactStatusBadge(p),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Bottom Actions (Skip on left, Play on right)
          Row(
            children: [
              // Left: Skip Button
              OutlinedButton.icon(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AshaSkipBottomSheet(patient: p),
                  );
                },
                icon: const Icon(Icons.fast_forward_rounded, size: 14),
                label: Text(context.tr('btn_skip'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 10),

              // Right: Play Button
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF004D40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00796B).withValues(alpha: 0.30),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AshaPatientGamesScreen(patient: p),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 19, color: Colors.white),
                    label: Text(
                      isVisited ? context.tr('btn_play_again') : context.tr('btn_khel_shuru'),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStatusBadge(PhcPatientModel p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (p.isCriticalDecline || p.riskLevel == 'severe_decline') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3B1212) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 12, color: Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Text(
              context.tr('status_high_risk'),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
            ),
          ],
        ),
      );
    }
    if (p.status == 'visited_today') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
            const SizedBox(width: 4),
            Text(
              context.tr('status_screened'),
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF332508) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFFD97706)),
          const SizedBox(width: 4),
          Text(
            context.tr('status_due'),
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20, horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2827) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
          width: 1.2,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF00796B).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Existing Elder + Caregiver vector illustration reused from Caregiver UI
          const SizedBox(
            width: 100,
            height: 72,
            child: CustomPaint(
              painter: CaregiverIllustrationPainter(),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('asha_no_patients_found'),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr('asha_no_patients_sub', params: {
              'village': context.localizeVillage(_selectedVillage),
            }),
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

  Widget _buildFab() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00897B), Color(0xFF004D40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00796B).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AshaRegisterPatientDialog(
              defaultVillage: _selectedVillage == 'All Villages' ? '' : _selectedVillage,
            ),
          );
        },
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.person_add_rounded, size: 20),
        label: Text(
          context.tr('add_elder_patient'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // BOTTOM NAVIGATION BAR (Exact Caregiver Design System)
  // -------------------------------------------------------------
  Widget _buildBottomNav() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
            width: 1,
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: isSmall ? 56 : 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: context.tr('nav_home'),
                  index: 0,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.people_alt_outlined,
                  activeIcon: Icons.people_alt_rounded,
                  label: context.tr('tab_care_team'),
                  index: 1,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights_rounded,
                  label: context.tr('tab_insights'),
                  index: 2,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: context.tr('nav_profile'),
                  index: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 360;
    const primaryColor = Color(0xFF00796B);
    final unselectedColor = isDark ? Colors.white54 : Colors.grey.shade600;

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 6 : (screenWidth < 380 ? 10 : 14),
                vertical: isSmall ? 2 : 3.5,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? primaryColor : unselectedColor,
                size: isSmall ? 19 : 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? primaryColor : unselectedColor,
                fontSize: isSmall ? 9.5 : (screenWidth < 380 ? 10.5 : 11),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
