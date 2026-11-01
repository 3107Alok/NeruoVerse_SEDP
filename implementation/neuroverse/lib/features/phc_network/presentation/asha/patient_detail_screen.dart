import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../providers/app_provider.dart';
import '../../models/phc_patient_model.dart';
import '../../data/phc_repository.dart';
import 'asha_patient_games_screen.dart';
import 'asha_skip_bottom_sheet.dart';
import '../../../../core/localization/app_translations.dart';

class PatientDetailScreen extends StatefulWidget {
  final PhcPatientModel patient;

  const PatientDetailScreen({super.key, required this.patient});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  late PhcPatientModel _patient;

  @override
  void initState() {
    super.initState();
    _patient = widget.patient;
  }

  void _showEditPatientDialog() {
    final nameController = TextEditingController(text: _patient.name);
    final ageController = TextEditingController(text: _patient.age.toString());
    final houseController = TextEditingController(text: _patient.houseNo);
    final guardianController = TextEditingController(text: _patient.guardianName);
    final phoneController = TextEditingController(text: _patient.guardianPhone);
    final abhaController = TextEditingController(text: _patient.abhaId);
    final notesController = TextEditingController(text: _patient.notes);
    String gender = _patient.gender;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('edit_elder_details'),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: context.tr('field_elder_name'),
                            prefixIcon: const Icon(Icons.person_outline, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: ageController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: context.tr('field_age'),
                                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: gender,
                                decoration: InputDecoration(
                                  labelText: context.tr('field_gender'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: [
                                  DropdownMenuItem(value: 'Male', child: Text(context.tr('gender_male'))),
                                  DropdownMenuItem(value: 'Female', child: Text(context.tr('gender_female'))),
                                  DropdownMenuItem(value: 'Other', child: Text(context.tr('gender_other'))),
                                ],
                                onChanged: (v) => setDialogState(() => gender = v ?? 'Male'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: houseController,
                          decoration: InputDecoration(
                            labelText: context.tr('field_house_ward'),
                            prefixIcon: const Icon(Icons.home_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: guardianController,
                          decoration: InputDecoration(
                            labelText: '${context.tr('field_guardian_name')} (${context.tr('field_guardian_relation_hint')})',
                            prefixIcon: const Icon(Icons.family_restroom, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: context.tr('field_phone'),
                            prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: abhaController,
                          decoration: InputDecoration(
                            labelText: context.tr('field_abha_optional'),
                            prefixIcon: const Icon(Icons.health_and_safety_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: context.tr('field_asha_observations'),
                            prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton(
                  onPressed: () {
                    final updated = PhcPatientModel(
                      id: _patient.id,
                      name: nameController.text.trim(),
                      age: int.tryParse(ageController.text.trim()) ?? _patient.age,
                      gender: gender,
                      village: _patient.village,
                      houseNo: houseController.text.trim(),
                      guardianName: guardianController.text.trim(),
                      guardianPhone: phoneController.text.trim(),
                      abhaId: abhaController.text.trim(),
                      baselineScore: _patient.baselineScore,
                      latestScore: _patient.latestScore,
                      previousScore: _patient.previousScore,
                      lastScreenedDate: _patient.lastScreenedDate,
                      status: _patient.status,
                      skipReason: _patient.skipReason,
                      riskLevel: _patient.riskLevel,
                      notes: notesController.text.trim(),
                    );

                    PhcRepository().updatePatient(updated);
                    setState(() => _patient = updated);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.primary,
                        content: Text(context.tr('elder_updated_success', params: {'name': _patient.name})),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(context.tr('btn_save_changes'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final isCritical = _patient.isCriticalDecline || _patient.riskLevel == 'severe_decline';
    final isVisited = _patient.status == 'visited_today';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(context.tr('patient_details_title')),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            tooltip: context.tr('edit_details'),
            onPressed: _showEditPatientDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Hero Profile Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isCritical ? Colors.red.shade300 : Colors.grey.shade200,
                  width: isCritical ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          _patient.name.isNotEmpty ? _patient.name[0] : 'P',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _patient.name,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_patient.age} ${context.tr('field_age_yrs')} • ${_patient.gender == 'Male' ? context.tr('gender_male') : (_patient.gender == 'Female' ? context.tr('gender_female') : context.tr('gender_other'))} • ${context.localizeVillage(_patient.village)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _patient.houseNo,
                              style: const TextStyle(fontSize: 11, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Score Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCritical
                          ? Colors.red.shade50
                          : (isVisited ? Colors.green.shade50 : AppColors.primary.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricCol(context.tr('latest_score_label'), '${_patient.latestScore} / 10',
                            isCritical ? Colors.red : AppColors.primary),
                        _buildMetricCol(context.tr('baseline_score_label'), '${_patient.baselineScore} / 10', Colors.black87),
                        _buildMetricCol(
                          context.tr('status_label'),
                          isCritical
                              ? '🔴 ${context.tr('status_high_risk')}'
                              : (_patient.riskLevel == 'mci_warning' ? '🟡 ${context.tr('status_mci_watch')}' : '🟢 ${context.tr('status_stable')}'),
                          isCritical ? Colors.red : Colors.green.shade800,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Guardian & Contact Details Card
            _buildSectionCard(
              title: context.tr('family_guardian_contact'),
              icon: Icons.family_restroom,
              children: [
                _buildInfoRow(context.tr('field_village_cluster'), context.localizeVillage(_patient.village)),
                _buildInfoRow(context.tr('field_guardian_name'), _patient.guardianName.isNotEmpty ? _patient.guardianName : context.tr('not_added')),
                _buildInfoRow(context.tr('contact_number'), _patient.guardianPhone.isNotEmpty ? _patient.guardianPhone : context.tr('not_added')),
                _buildInfoRow(context.tr('abha_health_id'), _patient.abhaId.isNotEmpty ? _patient.abhaId : context.tr('status_pending')),
              ],
            ),
            const SizedBox(height: 14),

            // Clinical & Field Notes Card
            _buildSectionCard(
              title: context.tr('asha_field_observations_history'),
              icon: Icons.medical_information_outlined,
              children: [
                _buildInfoRow(
                  context.tr('last_screened_date'),
                  '${_patient.lastScreenedDate.day}/${_patient.lastScreenedDate.month}/${_patient.lastScreenedDate.year}',
                ),
                _buildInfoRow(
                  context.tr('visit_status_today'),
                  _patient.status == 'visited_today'
                      ? context.tr('visited_and_screened')
                      : (_patient.status == 'skipped_today'
                          ? context.tr('skipped_with_reason_fmt', params: {'reason': _localizedSkipReason(context, _patient.skipReason)})
                          : context.tr('status_due')),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('observation_notes_label'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    _patient.notes.isNotEmpty
                        ? _patient.notes
                        : context.tr('default_stable_note'),
                    style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Bottom Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => AshaSkipBottomSheet(patient: _patient),
                      ).then((_) {
                        setState(() {
                          _patient = PhcRepository().patients.firstWhere(
                                (p) => p.id == _patient.id,
                                orElse: () => _patient,
                              );
                        });
                      });
                    },
                    icon: const Icon(Icons.fast_forward_rounded, size: 16),
                    label: Text(context.tr('btn_skip')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AshaPatientGamesScreen(patient: _patient),
                        ),
                      ).then((_) {
                        setState(() {
                          _patient = PhcRepository().patients.firstWhere(
                                (p) => p.id == _patient.id,
                                orElse: () => _patient,
                              );
                        });
                      });
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                    label: Text(isVisited ? context.tr('btn_play_again') : context.tr('btn_khel_shuru')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCol(String label, String val, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            val,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  String _localizedSkipReason(BuildContext context, String? reason) {
    switch (reason) {
      case 'not_home':
        return context.tr('skip_reason_not_home_short');
      case 'unwell':
        return context.tr('skip_reason_unwell_short');
      case 'flood_inaccessible':
      case 'inaccessible':
        return context.tr('skip_reason_flood_short');
      case 'refused':
        return context.tr('skip_reason_refused_short');
      default:
        return reason ?? context.tr('status_logged');
    }
  }
}
