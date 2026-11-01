import 'package:flutter/material.dart';
import '../../data/phc_repository.dart';
import '../../models/phc_patient_model.dart';
import 'patient_detail_screen.dart';
import 'asha_register_patient_dialog.dart';
import 'caregiver_illustration_painter.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/localization/app_translations.dart';

class AshaPatientsTab extends StatefulWidget {
  const AshaPatientsTab({super.key});

  @override
  State<AshaPatientsTab> createState() => _AshaPatientsTabState();
}

class _AshaPatientsTabState extends State<AshaPatientsTab> {
  String _selectedVillage = 'All Villages';
  String _searchQuery = '';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final repo = PhcRepository();
    final villages = repo.availableVillages;
    final villageOptions = {'All Villages', ...villages}.toList();
    if (!villageOptions.contains(_selectedVillage)) {
      _selectedVillage = 'All Villages';
    }

    // Filter patients by selected village and search query
    final villagePatients = repo.getPatientsByVillage(_selectedVillage);
    final filtered = villagePatients.where((p) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(query) ||
          p.houseNo.toLowerCase().contains(query) ||
          p.guardianName.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // Integrated Top Hero Header with Subtle Countryside Background
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
                // Subtle countryside illustration integrated as right-side backdrop
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 170,
                  child: Opacity(
                    opacity: isDark ? 0.40 : 0.82,
                    child: Image.asset(
                      'assets/images/care_team_banner_art.png',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
                ),
                // Decorative botanical leaf accent from Patient UI
                Positioned(
                  right: 125,
                  bottom: -8,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: isDark ? 0.25 : 0.45,
                      child: Image.asset(
                        'assets/images/greeting_botanical_accent.png',
                        height: 82,
                        fit: BoxFit.contain,
                        errorBuilder: (c, e, s) => const SizedBox(),
                      ),
                    ),
                  ),
                ),
                // Smooth gradient overlay ensuring high contrast & readability across languages
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                const Color(0xFF142421),
                                const Color(0xFF142421).withValues(alpha: 0.94),
                                const Color(0xFF142421).withValues(alpha: 0.15),
                              ]
                            : [
                                const Color(0xFFEDF7F2),
                                const Color(0xFFEDF7F2).withValues(alpha: 0.93),
                                const Color(0xFFEDF7F2).withValues(alpha: 0.05),
                              ],
                        stops: const [0.0, 0.58, 1.0],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),
                // Hero Content
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
                        context.tr('tab_care_team'),
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
                          'Track and support the elders in your village community.',
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
          const SizedBox(height: 10),

          // Village Selector and Search Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // CURRENT VISITING VILLAGE Card
                Container(
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
                      // Location Pin Icon Badge
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00796B), Color(0xFF004D40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00796B).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.location_on_rounded, color: Colors.white, size: 21),
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
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                                letterSpacing: 0.8,
                              ),
                            ),
                            DropdownButtonHideUnderline(
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
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                ),
                                selectedItemBuilder: (BuildContext ctx) {
                                  return villageOptions.map<Widget>((String v) {
                                    final count = repo.getPatientsByVillage(v).length;
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ctx.localizeVillage(v),
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFFF59E0B)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$count ${ctx.tr('elders_count_suffix')}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF00796B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                                items: villageOptions.map((v) {
                                  final count = repo.getPatientsByVillage(v).length;
                                  return DropdownMenuItem(
                                    value: v,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            context.localizeVillage(v),
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
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFFF59E0B)),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$count ${context.tr('elders_count_suffix')}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF00796B),
                                                ),
                                              ),
                                            ],
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
                ),
                const SizedBox(height: 10),

                // Search Field with Filter icon
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
                    onChanged: (val) => setState(() => _searchQuery = val),
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
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 21,
                        color: Color(0xFF00796B),
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear_rounded, size: 18, color: isDark ? Colors.white60 : Colors.grey.shade600),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : const Icon(
                              Icons.tune_rounded,
                              size: 20,
                              color: Color(0xFF00796B),
                            ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Patients List Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.groups_rounded,
                      size: 20,
                      color: Color(0xFF00796B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('registered_elders_count', params: {'count': filtered.length.toString()}).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white70 : const Color(0xFF00796B),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.localizeVillage(_selectedVillage),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00796B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Patients List
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 650;
                      if (isWide) {
                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 92),
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 105,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildPatientListItem(filtered[index]);
                          },
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 92),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _buildPatientListItem(filtered[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00796B), Color(0xFF004D40)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: const Icon(Icons.person_add_rounded, size: 20),
          label: Text(
            context.tr('add_elder_patient'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientListItem(PhcPatientModel p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCritical = p.isCriticalDecline || p.riskLevel == 'severe_decline';
    final isVisited = p.status == 'visited_today';

    // Status dot color on avatar (mirrors Caregiver patient card)
    final statusDotColor = isCritical
        ? const Color(0xFFDC2626)
        : (isVisited ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                      ? const Color(0xFFDC2626).withValues(alpha: 0.05)
                      : const Color(0xFF00796B).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: p)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with Initial and Status Dot
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

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${p.name} (${p.age} ${context.tr('field_age_yrs')}, ${p.gender.toLowerCase() == 'male' ? context.tr('gender_male') : (p.gender.toLowerCase() == 'female' ? context.tr('gender_female') : context.tr('gender_other'))})',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildStatusChip(p),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 14,
                            color: isDark ? Colors.white54 : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${p.houseNo} • ${p.village.isNotEmpty ? "${context.localizeVillage(p.village)} • " : ""}${context.tr('guardian_prefix')}: ${p.guardianName.isNotEmpty ? p.guardianName : context.tr('status_pending')}',
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
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isCritical
                                  ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                                  : const Color(0xFF00796B).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${context.tr('score_label')}: ${p.latestScore}/10',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isCritical ? const Color(0xFFDC2626) : const Color(0xFF00796B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '${context.tr('abha_health_id')}: ${p.abhaId.isNotEmpty ? p.abhaId : context.tr('not_set')}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white38 : Colors.grey.shade500,
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
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFE0F2F1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF00796B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(PhcPatientModel p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (p.isCriticalDecline || p.riskLevel == 'severe_decline') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF3B1212) : const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFFDC2626)),
            const SizedBox(width: 3.5),
            Text(
              context.tr('status_high_risk'),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
            ),
          ],
        ),
      );
    }
    if (p.status == 'visited_today') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF86EFAC), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF16A34A)),
            const SizedBox(width: 3.5),
            Text(
              context.tr('status_screened'),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF332508) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFD97706)),
          const SizedBox(width: 3.5),
          Text(
            context.tr('status_due'),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
                  'village': context.localizeVillage(_selectedVillage)
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
        ),
      ),
    );
  }
}
