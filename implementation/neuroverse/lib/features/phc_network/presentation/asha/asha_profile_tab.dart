import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../data/local/hive_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../data/phc_repository.dart';
import '../../models/phc_asha_model.dart';
import 'caregiver_illustration_painter.dart';
import '../../../patient/common/language_selection_sheet.dart';
import '../../../patient/common/logout_confirm_dialog.dart';

class AshaProfileTab extends StatefulWidget {
  final bool isStandalone;
  const AshaProfileTab({super.key, this.isStandalone = false});

  @override
  State<AshaProfileTab> createState() => _AshaProfileTabState();
}

class _AshaProfileTabState extends State<AshaProfileTab> {
  void _showEditProfileDialog(PhcAshaModel asha) {
    final nameController = TextEditingController(text: asha.name);
    final phoneController = TextEditingController(text: asha.phone);
    final ageController = TextEditingController(text: asha.age.toString());
    final clusterController = TextEditingController(text: asha.villageCluster);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final theme = Theme.of(ctx);
        final fieldFill = isDark ? const Color(0xFF1E2827) : const Color(0xFFF8FAFC);
        final fieldBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8)),
        );
        final fieldFocused = OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
        );

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Dialog Header
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('asha_edit_personal_details'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                context.tr('asha_update_worker_records'),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                            padding: const EdgeInsets.all(7),
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Dialog Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Locked PHC Code Notice (Caregiver Style)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2827) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.lock_rounded, color: isDark ? Colors.white60 : const Color(0xFF64748B), size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.tr('asha_phc_code_locked'),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        asha.facilityCode.isNotEmpty ? asha.facilityCode : context.tr('not_set'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    context.tr('asha_non_editable'),
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: nameController,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                            decoration: InputDecoration(
                              labelText: context.tr('field_full_name'),
                              labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF00796B)),
                              filled: true,
                              fillColor: fieldFill,
                              border: fieldBorder,
                              enabledBorder: fieldBorder,
                              focusedBorder: fieldFocused,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: ageController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                                  decoration: InputDecoration(
                                    labelText: context.tr('field_age'),
                                    labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                    prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF00796B)),
                                    filled: true,
                                    fillColor: fieldFill,
                                    border: fieldBorder,
                                    enabledBorder: fieldBorder,
                                    focusedBorder: fieldFocused,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: phoneController,
                                  keyboardType: TextInputType.phone,
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                                  decoration: InputDecoration(
                                    labelText: context.tr('field_phone'),
                                    labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                                    prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF00796B)),
                                    filled: true,
                                    fillColor: fieldFill,
                                    border: fieldBorder,
                                    enabledBorder: fieldBorder,
                                    focusedBorder: fieldFocused,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            controller: clusterController,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                            decoration: InputDecoration(
                              labelText: context.tr('asha_assigned_cluster'),
                              labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                              prefixIcon: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFF00796B)),
                              filled: true,
                              fillColor: fieldFill,
                              border: fieldBorder,
                              enabledBorder: fieldBorder,
                              focusedBorder: fieldFocused,
                            ),
                          ),
                          const SizedBox(height: 20),

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
                                  color: const Color(0xFF00796B).withValues(alpha: 0.30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                final ageVal = int.tryParse(ageController.text.trim()) ?? asha.age;
                                PhcRepository().updateAshaProfile(
                                  name: nameController.text.trim(),
                                  phone: phoneController.text.trim(),
                                  age: ageVal,
                                  villageCluster: clusterController.text.trim(),
                                );
                                Navigator.pop(ctx);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF00796B),
                                    content: Text(context.tr('asha_profile_updated_success')),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: Text(context.tr('btn_save_changes'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUpdatePhcDialog(BuildContext context) {
    final repo = PhcRepository();
    final asha = repo.currentAsha;
    final phcController = TextEditingController(text: asha.facilityCode);
    final villageController = TextEditingController(text: asha.villageCluster);

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final theme = Theme.of(ctx);
        final fieldFill = isDark ? const Color(0xFF1E2827) : const Color(0xFFF8FAFC);
        final fieldBorder = OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8)),
        );
        final fieldFocused = OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00796B), width: 2),
        );

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('asha_update_phc_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                context.tr('asha_update_phc_sub'),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                            padding: const EdgeInsets.all(7),
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: phcController,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                          decoration: InputDecoration(
                            labelText: context.tr('asha_phc_code_input'),
                            labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            hintText: 'e.g. PHC-JHT-108',
                            prefixIcon: const Icon(Icons.pin_outlined, size: 20, color: Color(0xFF00796B)),
                            filled: true,
                            fillColor: fieldFill,
                            border: fieldBorder,
                            enabledBorder: fieldBorder,
                            focusedBorder: fieldFocused,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: villageController,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1B3B36)),
                          decoration: InputDecoration(
                            labelText: context.tr('asha_assigned_cluster'),
                            labelStyle: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                            hintText: 'e.g. Majuli North, Teok',
                            prefixIcon: const Icon(Icons.location_city_outlined, size: 20, color: Color(0xFF00796B)),
                            filled: true,
                            fillColor: fieldFill,
                            border: fieldBorder,
                            enabledBorder: fieldBorder,
                            focusedBorder: fieldFocused,
                          ),
                        ),
                        const SizedBox(height: 20),
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
                                color: const Color(0xFF00796B).withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final newCode = phcController.text.trim();
                              if (newCode.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: Colors.red,
                                    content: Text(context.tr('asha_valid_phc_warning')),
                                  ),
                                );
                                return;
                              }

                              await repo.updateAshaPhcFacility(
                                facilityCode: newCode,
                                villageCluster: villageController.text.trim(),
                              );

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) setState(() {});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF00796B),
                                    content: Text(context.tr('asha_phc_updated_snack', params: {'code': newCode})),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                            label: Text(context.tr('asha_save_phc_btn'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      },
    );
  }

  void _showLanguageDialog() {
    LanguageSelectionSheet.show(context, isVoice: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final repo = PhcRepository();
    final asha = repo.currentAsha;
    final doctor = repo.doctor;
    final currentLang = context.watch<AppProvider>().userLanguage ?? 'English';
    final screenWidth = MediaQuery.of(context).size.width;
    final String ashaEmail = asha.email.isNotEmpty
        ? asha.email
        : (FirebaseAuth.instance.currentUser?.email ??
            context.read<HiveService>().getUserProfile()?['email']?.toString() ??
            'asha.worker@phc.gov.in');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: widget.isStandalone
          ? AppBar(
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              centerTitle: false,
              title: Text(
                context.tr('nav_profile'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF1E2927),
                ),
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: isDark ? Colors.white : const Color(0xFF1E2927),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, widget.isStandalone ? 8 : 14, 18, widget.isStandalone ? 24 : 88),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. TOP PROFILE AVATAR & NAME CARD (Caregiver / Patient Standard)
            Container(
              padding: const EdgeInsets.all(18),
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
                          color: const Color(0xFF00796B).withValues(alpha: 0.05),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar with Verified Ring
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
                              color: const Color(0xFF00796B).withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            asha.name.trim().isNotEmpty ? asha.name.trim()[0].toUpperCase() : 'A',
                            style: const TextStyle(
                              fontSize: 26,
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
                            color: asha.isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E2827) : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            asha.isApproved ? Icons.check_rounded : Icons.hourglass_empty_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Name, Email, ID & Approval Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                asha.name,
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
                            if (asha.isApproved) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF00796B),
                                size: 20,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.email_outlined,
                              size: 13,
                              color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                ashaEmail,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.tr('asha_id_prefix_fmt', params: {'id': asha.id}),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00796B),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (!asha.isApproved) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF332508) : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.hourglass_top_rounded,
                                  size: 12.5,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    context.tr('status_awaiting_approval'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFD97706),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Right: Subtle Elder & Caregiver vector illustration
                  SizedBox(
                    width: (screenWidth * 0.18).clamp(52.0, 68.0),
                    height: (screenWidth * 0.14).clamp(42.0, 54.0),
                    child: const CustomPaint(
                      painter: CaregiverIllustrationPainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. ASSIGNED PHC CENTRE CARD (Interactive Jurisdiction)
            Container(
              padding: const EdgeInsets.all(18),
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
                          blurRadius: 14,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00897B), Color(0xFF004D40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00796B).withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('asha_assigned_phc_center'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B),
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              asha.facilityCode.isNotEmpty ? asha.facilityCode : context.tr('asha_no_phc_id'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              doctor.hospitalName,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _showUpdatePhcDialog(context),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.10),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF00796B).withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_location_alt_rounded, size: 13, color: Color(0xFF00796B)),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('asha_change_btn'),
                                style: const TextStyle(
                                  fontSize: 11.5,
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162422) : const Color(0xFFF4F8F6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00796B).withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF00796B)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('asha_phc_jurisdiction_note'),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white70 : const Color(0xFF334155),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 3. PERSONAL INFORMATION CARD WITH EDIT BUTTON
            Container(
              padding: const EdgeInsets.all(18),
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
                          blurRadius: 14,
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00796B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_outline_rounded, size: 18, color: Color(0xFF00796B)),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            context.tr('personal_information'),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        onPressed: () => _showEditProfileDialog(asha),
                        icon: const Icon(Icons.mode_edit_outline_rounded, size: 14, color: Color(0xFF00796B)),
                        label: Text(
                          context.tr('edit_details'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF00796B)),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF00796B).withValues(alpha: 0.08),
                          side: BorderSide(color: const Color(0xFF00796B).withValues(alpha: 0.22)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Divider(color: isDark ? Colors.white12 : const Color(0xFFE2ECE8), height: 1),
                  const SizedBox(height: 10),
                  _buildProfileRow(context.tr('field_full_name'), asha.name, Icons.badge_outlined),
                  _buildProfileRow(context.tr('field_email'), ashaEmail, Icons.email_outlined),
                  _buildProfileRow(context.tr('field_age'), '${asha.age} ${context.tr('field_age_yrs')}', Icons.cake_outlined),
                  _buildProfileRow(context.tr('field_phone'), asha.phone, Icons.phone_outlined),
                  _buildProfileRow(context.tr('asha_assigned_cluster'), asha.villageCluster.trim().isEmpty ? context.tr('not_assigned') : context.localizeVillage(asha.villageCluster), Icons.location_city_outlined),
                  _buildProfileRow(context.tr('asha_supervising_doctor'), doctor.name, Icons.medical_services_outlined),
                  _buildProfileRow(context.tr('asha_target_elders'), '${asha.targetElders} ${context.tr('elders_count_suffix')}', Icons.groups_outlined),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 4. APP PREFERENCES & LANGUAGE CARD
            Container(
              padding: const EdgeInsets.all(18),
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
                          blurRadius: 14,
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
                          color: const Color(0xFF00796B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF00796B)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.tr('app_preferences'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _showLanguageDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF162422) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2E403D) : const Color(0xFFE2ECE8),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.translate_rounded, color: Color(0xFF00796B), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr('app_display_language'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : const Color(0xFF1B3B36),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    currentLang,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00796B).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                currentLang,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00796B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 5. AESTHETIC LOG OUT BUTTON CARD
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => LogoutConfirmDialog.show(context),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF261414) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF5A2525) : const Color(0xFFFECACA),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: isDark ? 0.08 : 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.logout_rounded,
                          color: Color(0xFFDC2626),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('logout'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('sign_out_device'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFDC2626),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.22 : 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 14, color: const Color(0xFF00796B)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
