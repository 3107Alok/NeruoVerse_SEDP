import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/phc_repository.dart';
import 'doctor_healthcare_decor_painter.dart';

class DoctorScheduleVisitDialog extends StatefulWidget {
  const DoctorScheduleVisitDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const DoctorScheduleVisitDialog(),
    );
  }

  @override
  State<DoctorScheduleVisitDialog> createState() => _DoctorScheduleVisitDialogState();
}

class _DoctorScheduleVisitDialogState extends State<DoctorScheduleVisitDialog> {
  String _selectedVillage = '';
  final TextEditingController _customVillageController = TextEditingController();
  bool _isCustomVillage = false;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  final Set<String> _selectedAshaIds = {};
  bool _dividePatientsEqually = true;

  @override
  void initState() {
    super.initState();
    final repo = PhcRepository();
    final villages = repo.availableVillages;
    if (villages.isNotEmpty) {
      _selectedVillage = villages.first;
    } else {
      _isCustomVillage = true;
    }

    // Default select first approved ASHA
    if (repo.approvedAshaWorkers.isNotEmpty) {
      _selectedAshaIds.add(repo.approvedAshaWorkers.first.id);
    }
  }

  @override
  void dispose() {
    _customVillageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00796B),
              onPrimary: Colors.white,
              onSurface: Color(0xFF004D40),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = PhcRepository();
    final approvedAshas = repo.approvedAshaWorkers;
    final villages = repo.availableVillages;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeVillageName = _isCustomVillage
        ? _customVillageController.text.trim()
        : _selectedVillage;
    final villagePatients = repo.getPatientsByVillage(activeVillageName);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 720),
        color: isDark ? const Color(0xFF1B2826) : Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Illustrated Assam Leaves Header
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
                        leafColor: Colors.white.withValues(alpha: 0.15),
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Schedule Field Drive',
                                style: TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Assign Village & Distribute Elderly Care',
                                style: TextStyle(fontSize: 11.5, color: Colors.white70),
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

            // 2. Scrollable Body
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Step 1: Village Cluster
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF00796B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '1. TARGET VILLAGE CLUSTER',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        if (villages.isNotEmpty)
                          InkWell(
                            onTap: () => setState(() => _isCustomVillage = !_isCustomVillage),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _isCustomVillage ? 'Choose Existing' : '+ Enter New',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isCustomVillage || villages.isEmpty) ...[
                      TextField(
                        controller: _customVillageController,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter village cluster name...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.white38 : Colors.grey.shade400,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(Icons.location_city_rounded, size: 20, color: Color(0xFF00796B)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF141F1D) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFF00796B), width: 1.8),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141F1D) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: villages.contains(_selectedVillage) ? _selectedVillage : villages.first,
                            isExpanded: true,
                            dropdownColor: isDark ? const Color(0xFF1E2827) : Colors.white,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF00796B)),
                            items: villages.map((v) {
                              final count = repo.getPatientsByVillage(v).length;
                              return DropdownMenuItem(
                                value: v,
                                child: Text(
                                  '$v ($count Elders)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
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
                    const SizedBox(height: 16),

                    // Step 2: Drive Date Picker
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.event_note_rounded, size: 12, color: Color(0xFF00796B)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '2. SCHEDULE DRIVE DATE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141F1D) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.event_available_rounded, color: Color(0xFF00796B), size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  Text(
                                    'Next Field Screening Session',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Change Date',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF00796B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Step 3: Assign ASHA Workers
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.group_add_rounded, size: 12, color: Color(0xFF00796B)),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '3. ASSIGN ASHA WORKERS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_selectedAshaIds.length} Selected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (approvedAshas.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF281C10) : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF78350F) : Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: Colors.orange.shade800, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No approved ASHA workers found. Approve pending ASHA workers in Care Team tab first.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? Colors.orange.shade200 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141F1D) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: approvedAshas.map((asha) {
                            final isChecked = _selectedAshaIds.contains(asha.id);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isChecked) {
                                    if (_selectedAshaIds.length > 1) {
                                      _selectedAshaIds.remove(asha.id);
                                    }
                                  } else {
                                    _selectedAshaIds.add(asha.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: isChecked
                                      ? const Color(0xFF00796B).withValues(alpha: isDark ? 0.2 : 0.08)
                                      : Colors.transparent,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark ? const Color(0xFF263835) : const Color(0xFFEEF2F6),
                                      width: 0.8,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      color: isChecked
                                          ? const Color(0xFF00796B)
                                          : (isDark ? Colors.white38 : Colors.grey.shade400),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.person_rounded, size: 14, color: Color(0xFF00796B)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            asha.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${asha.villageCluster.isNotEmpty ? asha.villageCluster : "Assigned"} • ${asha.phone}',
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
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Step 4: Equal Patient Distribution Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF142420) : const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF264039) : const Color(0xFFA5D6A7),
                          width: 1.1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.35 : 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.splitscreen_rounded, color: Color(0xFF00796B), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Divide Patients Equally (Split)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF004D40),
                                  ),
                                ),
                              ),
                              Switch.adaptive(
                                value: _dividePatientsEqually,
                                activeThumbColor: const Color(0xFF00796B),
                                onChanged: (val) => setState(() => _dividePatientsEqually = val),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedAshaIds.length > 1 && _dividePatientsEqually
                                ? 'Total ${villagePatients.length} elders in $activeVillageName will be distributed equally among ${_selectedAshaIds.length} selected ASHA workers.'
                                : 'All assigned patients in $activeVillageName will report under the selected field worker.',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF2E7D32),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Confirm Button Bottom Bar
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
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF2E403D) : const Color(0xFFCBD5E1),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
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
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00796B).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final targetVillage = _isCustomVillage
                              ? _customVillageController.text.trim()
                              : _selectedVillage.trim();

                          if (targetVillage.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter or select a village!')),
                            );
                            return;
                          }

                          if (_selectedAshaIds.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please select at least 1 ASHA worker!')),
                            );
                            return;
                          }

                          repo.scheduleVillageDrive(
                            village: targetVillage,
                            date: _selectedDate,
                            ashaIds: _selectedAshaIds.toList(),
                            divideEqually: _dividePatientsEqually,
                          );

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.primary,
                              content: Text('Drive scheduled for $targetVillage on ${_selectedDate.day}/${_selectedDate.month}! Patients assigned. 🩺'),
                            ),
                          );
                        },
                        icon: const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Confirm & Assign Field Drive',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
}
