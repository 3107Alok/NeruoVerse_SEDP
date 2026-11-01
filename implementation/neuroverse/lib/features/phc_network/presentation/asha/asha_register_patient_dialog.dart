import 'package:flutter/material.dart';
import '../../../../core/localization/app_translations.dart';
import '../../data/phc_repository.dart';
import 'caregiver_illustration_painter.dart';

class AshaRegisterPatientDialog extends StatefulWidget {
  final String defaultVillage;

  const AshaRegisterPatientDialog({super.key, required this.defaultVillage});

  @override
  State<AshaRegisterPatientDialog> createState() => _AshaRegisterPatientDialogState();
}

class _AshaRegisterPatientDialogState extends State<AshaRegisterPatientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _houseController = TextEditingController();
  final _guardianController = TextEditingController();
  final _phoneController = TextEditingController();
  final _abhaController = TextEditingController();
  final _notesController = TextEditingController();

  String _gender = 'Male';
  late String _village;

  @override
  void initState() {
    super.initState();
    final villages = PhcRepository().availableVillages;
    final fallback = villages.isNotEmpty ? villages.first : 'Majuli Cluster 1';
    if (widget.defaultVillage.isNotEmpty &&
        widget.defaultVillage != 'All Villages' &&
        villages.contains(widget.defaultVillage)) {
      _village = widget.defaultVillage;
    } else {
      _village = fallback;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _houseController.dispose();
    _guardianController.dispose();
    _phoneController.dispose();
    _abhaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final rawVillages = PhcRepository().availableVillages;
    final villages = rawVillages.isNotEmpty
        ? rawVillages
        : const ['Majuli Cluster 1', 'Majuli Cluster 2', 'Jorhat North', 'Jorhat South', 'Teok East', 'Titabor South'];
    final effectiveVillage = villages.contains(_village) ? _village : villages.first;
    final effectiveGender = const ['Male', 'Female', 'Other'].contains(_gender) ? _gender : 'Male';

    final fieldFillColor = isDark ? const Color(0xFF1E2827) : const Color(0xFFF8FAFC);
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
        width: 1.2,
      ),
    );
    final fieldFocusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
    );
    final fieldLabelStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white70 : const Color(0xFF475569),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 530, maxHeight: 700),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF162422) : theme.cardColor,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Column(
              children: [
                // 1. AESTHETIC HEADER BANNER (Caregiver Style with Reused Vector Art)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF00897B), Color(0xFF004D40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('add_elder_patient'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('register_elder_subtitle'),
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Existing Elder + Caregiver vector artwork from Caregiver UI
                      const SizedBox(
                        width: 58,
                        height: 44,
                        child: CustomPaint(
                          painter: CaregiverIllustrationPainter(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          padding: const EdgeInsets.all(7),
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(context),
                          tooltip: context.tr('close'),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. FORM BODY
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Caregiver Tip Banner
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1B2E27) : const Color(0xFFE8F5ED),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2E4540) : const Color(0xFFC8E6C9),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFF00796B)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    context.tr('register_elder_tip'),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: isDark ? Colors.white70 : const Color(0xFF004D40),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Section 1: Basic Info
                          _buildSectionHeader(context.tr('sec_basic_elder_details'), Icons.person_outline_rounded),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36), fontSize: 14.5),
                            decoration: InputDecoration(
                              labelText: context.tr('field_elder_name'),
                              labelStyle: fieldLabelStyle,
                              hintText: 'e.g. Bhaben Saikia',
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF00796B)),
                              filled: true,
                              fillColor: fieldFillColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              border: fieldBorder,
                              enabledBorder: fieldBorder,
                              focusedBorder: fieldFocusedBorder,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? context.tr('field_enter_name_val') : null,
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36), fontSize: 14.5),
                                  decoration: InputDecoration(
                                    labelText: context.tr('field_age_req'),
                                    labelStyle: fieldLabelStyle,
                                    hintText: '72',
                                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF00796B)),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                    border: fieldBorder,
                                    enabledBorder: fieldBorder,
                                    focusedBorder: fieldFocusedBorder,
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return context.tr('field_enter_age_val');
                                    final val = int.tryParse(v);
                                    if (val == null || val < 40) return context.tr('field_valid_age_val');
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: effectiveGender,
                                  dropdownColor: isDark ? const Color(0xFF1E2827) : theme.cardColor,
                                  style: TextStyle(fontSize: 14.5, color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                                  decoration: InputDecoration(
                                    labelText: context.tr('field_gender'),
                                    labelStyle: fieldLabelStyle,
                                    filled: true,
                                    fillColor: fieldFillColor,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                                    border: fieldBorder,
                                    enabledBorder: fieldBorder,
                                    focusedBorder: fieldFocusedBorder,
                                  ),
                                  items: [
                                    DropdownMenuItem(value: 'Male', child: Text(context.tr('gender_male'))),
                                    DropdownMenuItem(value: 'Female', child: Text(context.tr('gender_female'))),
                                    DropdownMenuItem(value: 'Other', child: Text(context.tr('gender_other'))),
                                  ],
                                  onChanged: (v) => setState(() => _gender = v ?? 'Male'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Section 2: Location
                          _buildSectionHeader(context.tr('sec_location_household'), Icons.location_on_outlined),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: effectiveVillage,
                            dropdownColor: isDark ? const Color(0xFF1E2827) : theme.cardColor,
                            style: TextStyle(fontSize: 14.5, color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                            decoration: InputDecoration(
                              labelText: context.tr('field_village_cluster'),
                              labelStyle: fieldLabelStyle,
                              prefixIcon: const Icon(Icons.holiday_village_outlined, size: 20, color: Color(0xFF00796B)),
                              filled: true,
                              fillColor: fieldFillColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              border: fieldBorder,
                              enabledBorder: fieldBorder,
                              focusedBorder: fieldFocusedBorder,
                            ),
                            selectedItemBuilder: (BuildContext ctx) {
                              return villages.map<Widget>((String v) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    ctx.localizeVillage(v),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            items: villages.map((v) => DropdownMenuItem(value: v, child: Text(context.localizeVillage(v)))).toList(),
                            onChanged: (v) => setState(() => _village = v ?? effectiveVillage),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _houseController,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36), fontSize: 14.5),
                            decoration: InputDecoration(
                              labelText: context.tr('field_house_ward'),
                              labelStyle: fieldLabelStyle,
                              hintText: 'e.g. Ward 3, House #14',
                              prefixIcon: const Icon(Icons.home_outlined, size: 20, color: Color(0xFF00796B)),
                              filled: true,
                              fillColor: fieldFillColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              border: fieldBorder,
                              enabledBorder: fieldBorder,
                              focusedBorder: fieldFocusedBorder,
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Section 3: Guardian
                          _buildSectionHeader(context.tr('sec_guardian_contact'), Icons.family_restroom_rounded),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _guardianController,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36), fontSize: 14.5),
                                  decoration: InputDecoration(
                                    labelText: context.tr('field_guardian_name'),
                                    labelStyle: fieldLabelStyle,
                                    hintText: context.tr('field_guardian_relation_hint'),
                                    prefixIcon: const Icon(Icons.people_outline_rounded, size: 18, color: Color(0xFF00796B)),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                                    border: fieldBorder,
                                    enabledBorder: fieldBorder,
                                    focusedBorder: fieldFocusedBorder,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36), fontSize: 14.5),
                                  decoration: InputDecoration(
                                    labelText: context.tr('field_phone'),
                                    labelStyle: fieldLabelStyle,
                                    hintText: '+91 987...',
                                    prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF00796B)),
                                    filled: true,
                                    fillColor: fieldFillColor,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                                    border: fieldBorder,
                                    enabledBorder: fieldBorder,
                                    focusedBorder: fieldFocusedBorder,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),

                          // Section 4: Health ID & Notes
                          _buildSectionHeader(context.tr('sec_abha_observations'), Icons.health_and_safety_outlined),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _abhaController,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36), fontSize: 14.5),
                            decoration: InputDecoration(
                              labelText: context.tr('field_abha_optional'),
                              labelStyle: fieldLabelStyle,
                              hintText: '14-digit ID (e.g. 14-8841-9204-1182)',
                              prefixIcon: const Icon(Icons.credit_card_outlined, size: 20, color: Color(0xFF00796B)),
                              filled: true,
                              fillColor: fieldFillColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              border: fieldBorder,
                              enabledBorder: fieldBorder,
                              focusedBorder: fieldFocusedBorder,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36), fontSize: 14.5),
                            decoration: InputDecoration(
                              labelText: context.tr('field_asha_observations'),
                              labelStyle: fieldLabelStyle,
                              hintText: context.tr('field_asha_obs_hint'),
                              prefixIcon: const Icon(Icons.note_alt_outlined, size: 20, color: Color(0xFF00796B)),
                              filled: true,
                              fillColor: fieldFillColor,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                              border: fieldBorder,
                              enabledBorder: fieldBorder,
                              focusedBorder: fieldFocusedBorder,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. BOTTOM BUTTON BAR (Caregiver Style)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF162422) : theme.cardColor,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: Text(context.tr('btn_cancel'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(),
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
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              final safeAge = int.tryParse(_ageController.text.trim()) ?? 60;
                              PhcRepository().registerPatient(
                                name: _nameController.text.trim(),
                                age: safeAge,
                                gender: effectiveGender,
                                village: effectiveVillage,
                                houseNo: _houseController.text.trim(),
                                guardianName: _guardianController.text.trim(),
                                guardianPhone: _phoneController.text.trim(),
                                abhaId: _abhaController.text.trim(),
                                notes: _notesController.text.trim(),
                              );
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFF00796B),
                                  content: Text(context.tr('elder_registered_success', params: {'name': _nameController.text.trim()})),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          label: Text(
                            context.tr('add_elder_patient'),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF00796B)),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF00796B),
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}
