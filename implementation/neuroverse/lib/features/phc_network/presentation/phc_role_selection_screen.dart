import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/local/hive_service.dart';
import '../../../providers/app_provider.dart';
import 'asha/asha_dashboard_screen.dart';
import 'doctor/doctor_dashboard_screen.dart';
import '../data/phc_repository.dart';
import '../../../core/localization/app_translations.dart';

class PhcRoleSelectionScreen extends StatefulWidget {
  const PhcRoleSelectionScreen({super.key});

  @override
  State<PhcRoleSelectionScreen> createState() => _PhcRoleSelectionScreenState();
}

class _PhcRoleSelectionScreenState extends State<PhcRoleSelectionScreen> {
  bool _isLoading = false;

  void _onSelectAsha() {
    final hive = context.read<HiveService>();
    final profile = hive.getUserProfile();
    final pName = profile?['name']?.toString().trim();
    final pVillage = profile?['village']?.toString().trim();

    // If already properly registered with a real name, proceed (village is optional)
    if (pName != null && pName.isNotEmpty && pName != 'ASHA Worker') {
      _executeAshaLogin(
        name: pName,
        phone: profile?['phone']?.toString() ?? '',
        village: pVillage ?? '',
        age: int.tryParse(profile?['age']?.toString() ?? '32') ?? 32,
        facilityCode: profile?['facilityCode']?.toString() ?? 'PHC-JHT-108',
      );
    } else {
      _showAshaRegistrationModal();
    }
  }

  void _onSelectDoctor() {
    final hive = context.read<HiveService>();
    final profile = hive.getUserProfile();
    final pName = profile?['doctorName']?.toString().trim() ?? profile?['name']?.toString().trim();
    final pReg = profile?['doctorRegNo']?.toString().trim();

    // If already properly registered with doctor name and registration number, proceed
    if (pName != null && pName.isNotEmpty && pName != 'Medical Officer' && pReg != null && pReg.isNotEmpty) {
      _executeDoctorLogin(
        name: pName,
        regNo: pReg,
        designation: profile?['designation']?.toString() ?? 'Medical Officer In-Charge',
        phone: profile?['phone']?.toString() ?? '',
        email: profile?['email']?.toString() ?? '',
        facilityCode: profile?['facilityCode']?.toString() ?? 'PHC-JHT-108',
        hospitalName: profile?['hospitalName']?.toString() ?? 'Jorhat Rural Primary Health Centre',
      );
    } else {
      _showDoctorRegistrationModal();
    }
  }

  void _showDoctorRegistrationModal() {
    final authUser = FirebaseAuth.instance.currentUser;
    final repo = PhcRepository();
    final initialName = authUser?.displayName != null && authUser!.displayName!.isNotEmpty
        ? (authUser.displayName!.startsWith('Dr.') ? authUser.displayName! : 'Dr. ${authUser.displayName!}')
        : (repo.doctor.name.isNotEmpty && repo.doctor.name != 'Dr. Duty Medical Officer' ? repo.doctor.name : 'Dr. ');

    final nameController = TextEditingController(text: initialName);
    final regNoController = TextEditingController(text: repo.doctor.doctorRegNo);
    final designationController = TextEditingController(text: repo.doctor.designation);
    final phoneController = TextEditingController(text: authUser?.phoneNumber ?? repo.doctor.phone);
    final emailController = TextEditingController(text: authUser?.email ?? repo.doctor.email);
    final hospitalController = TextEditingController(text: repo.doctor.hospitalName);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.badge_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Medical Officer Registration',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Enter official PHC clinical duty credentials',
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

              // Form
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: nameController,
                        label: 'Medical Officer / Doctor Full Name *',
                        hint: 'e.g. Dr. Alok Singh',
                        icon: Icons.person_outline_rounded,
                      ),
                      _buildTextField(
                        controller: regNoController,
                        label: 'Medical Council Reg No. *',
                        hint: 'e.g. NMC-AS-2024-9102',
                        icon: Icons.assignment_ind_outlined,
                      ),
                      _buildTextField(
                        controller: designationController,
                        label: 'Designation / Specialization *',
                        hint: 'e.g. Medical Officer In-Charge',
                        icon: Icons.medical_services_outlined,
                      ),
                      _buildTextField(
                        controller: hospitalController,
                        label: 'PHC Centre Name',
                        hint: 'e.g. Jorhat Rural PHC',
                        icon: Icons.account_balance_outlined,
                      ),
                      // Auto-allocated Government Facility Code card
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF004D40).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF004D40).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF004D40),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Official PHC Facility Code',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.teal.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'AUTO-ALLOCATED',
                                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal.shade900),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    repo.doctor.facilityCode.trim().isNotEmpty
                                        ? repo.doctor.facilityCode.trim().toUpperCase()
                                        : 'PHC-JHT-108',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF004D40),
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Government auto-allocated code. Frontline ASHA workers use this to link to your centre.',
                                    style: TextStyle(fontSize: 10.5, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildTextField(
                        controller: phoneController,
                        label: 'Official Contact Phone',
                        hint: '+91 98765-XXXXX',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      _buildTextField(
                        controller: emailController,
                        label: 'Govt / OPD Email',
                        hint: 'doctor@assamhealth.gov.in',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final reg = regNoController.text.trim();
                          if (name.isEmpty || name == 'Dr.' || reg.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: Colors.red,
                                content: Text('Kripya Doctor ka naam aur Registration No. bharein!'),
                              ),
                            );
                            return;
                          }
                          final allocatedCode = repo.doctor.facilityCode.trim().isNotEmpty
                              ? repo.doctor.facilityCode.trim().toUpperCase()
                              : 'PHC-JHT-108';
                          Navigator.pop(ctx);
                          _executeDoctorLogin(
                            name: name.startsWith('Dr.') ? name : 'Dr. $name',
                            regNo: reg,
                            designation: designationController.text.trim().isNotEmpty ? designationController.text.trim() : 'Medical Officer In-Charge',
                            phone: phoneController.text.trim(),
                            email: emailController.text.trim(),
                            facilityCode: allocatedCode,
                            hospitalName: hospitalController.text.trim().isNotEmpty ? hospitalController.text.trim() : 'Jorhat Rural Primary Health Centre',
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: const Text('Complete Registration & Enter Portal', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  }

  void _showAshaRegistrationModal() {
    final authUser = FirebaseAuth.instance.currentUser;
    final repo = PhcRepository();
    final nameController = TextEditingController(
      text: (authUser?.displayName != null && authUser!.displayName!.isNotEmpty) ? authUser.displayName! : '',
    );
    final phoneController = TextEditingController(text: authUser?.phoneNumber ?? repo.currentAsha.phone);
    final villageController = TextEditingController(text: repo.currentAsha.villageCluster);
    final ageController = TextEditingController(text: repo.currentAsha.age > 0 ? repo.currentAsha.age.toString() : '32');
    final facilityController = TextEditingController(text: repo.currentAsha.facilityCode.isNotEmpty ? repo.currentAsha.facilityCode : 'PHC-JHT-108');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('asha_registration_title'),
                            style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            context.tr('asha_registration_sub'),
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
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

              // Form
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: nameController,
                        label: context.tr('field_full_name'),
                        hint: 'e.g. Sunita Das',
                        icon: Icons.person_outline_rounded,
                      ),
                      _buildTextField(
                        controller: phoneController,
                        label: context.tr('field_phone'),
                        hint: '+91 98765-XXXXX',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: ageController,
                              label: context.tr('field_age'),
                              hint: '32',
                              icon: Icons.calendar_today_outlined,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: _buildTextField(
                              controller: villageController,
                              label: '${context.tr('field_village_cluster')} (${context.tr('optional')})',
                              hint: 'e.g. Majuli North, Teok',
                              icon: Icons.location_on_outlined,
                            ),
                          ),
                        ],
                      ),
                      _buildTextField(
                        controller: facilityController,
                        label: context.tr('asha_phc_code_input'),
                        hint: 'e.g. PHC-JHT-108',
                        icon: Icons.pin_outlined,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF004D40), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('asha_facility_approval_notice'),
                                style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          final name = nameController.text.trim();
                          final phone = phoneController.text.trim();
                          final village = villageController.text.trim();
                          if (name.isEmpty || phone.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(context.tr('asha_fill_required_fields')),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          _executeAshaLogin(
                            name: name,
                            phone: phone,
                            village: village,
                            age: int.tryParse(ageController.text.trim()) ?? 32,
                            facilityCode: facilityController.text.trim().isNotEmpty ? facilityController.text.trim().toUpperCase() : 'PHC-JHT-108',
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text(context.tr('btn_complete_registration'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 12.5, color: Colors.grey.shade400),
              prefixIcon: Icon(icon, color: const Color(0xFF004D40), size: 19),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF004D40), width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeAshaLogin({
    required String name,
    required String phone,
    required String village,
    required int age,
    required String facilityCode,
  }) async {
    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final hive = context.read<HiveService>();
    final authUser = FirebaseAuth.instance.currentUser;
    final repo = PhcRepository();

    // Register ASHA with facility code and dispatch verification request to Medical Officer
    await repo.registerAshaWithFacilityCode(
      name: name,
      phone: phone,
      villageCluster: village,
      age: age,
      facilityCode: facilityCode,
    );

    appProvider.setRole('asha');
    appProvider.setUserProfile(
      name,
      age.toString(),
      'Female',
      appProvider.userLanguage ?? 'English',
    );

    await hive.saveUserProfile({
      if (authUser != null) 'uid': authUser.uid,
      'role': 'asha',
      'name': name,
      'email': authUser?.email ?? '',
      'phone': phone,
      'age': age.toString(),
      'gender': 'Female',
      'village': village,
      'facilityCode': facilityCode,
      'isApproved': false,
      'language': appProvider.userLanguage ?? 'English',
    });

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text(
            context.tr('asha_reg_submitted_snack_fmt', params: {'facilityCode': facilityCode}),
          ),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AshaDashboardScreen()),
      );
    }
  }

  Future<void> _executeDoctorLogin({
    required String name,
    required String regNo,
    required String designation,
    required String phone,
    required String email,
    required String facilityCode,
    required String hospitalName,
  }) async {
    setState(() => _isLoading = true);
    final appProvider = context.read<AppProvider>();
    final hive = context.read<HiveService>();
    final authUser = FirebaseAuth.instance.currentUser;
    final repo = PhcRepository();

    await repo.updateDoctorProfile(
      name: name,
      phone: phone,
      email: email,
      doctorRegNo: regNo,
      designation: designation,
      facilityCode: facilityCode,
      hospitalName: hospitalName,
    );

    appProvider.setRole('doctor');
    appProvider.setUserProfile(
      name,
      '45',
      'Male',
      appProvider.userLanguage ?? 'English',
    );

    await hive.saveUserProfile({
      if (authUser != null) 'uid': authUser.uid,
      'role': 'doctor',
      'name': name,
      'doctorName': name,
      'email': email,
      'phone': phone,
      'doctorRegNo': regNo,
      'designation': designation,
      'facilityCode': facilityCode,
      'hospitalName': hospitalName,
      'language': appProvider.userLanguage ?? 'English',
    });

    if (authUser != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(authUser.uid).set({
          'role': 'doctor',
          'name': name,
          'doctorName': name,
          'doctorRegNo': regNo,
          'designation': designation,
          'phone': phone,
          'email': email,
          'facilityCode': facilityCode,
          'hospitalName': hospitalName,
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoctorDashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
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
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.tr('phc_choose_role'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Option 1: ASHA / Healthcare Worker
                  _buildRoleCard(
                    icon: '🩺',
                    title: context.tr('role_asha_title'),
                    onTap: _isLoading ? () {} : _onSelectAsha,
                  ),
                  const SizedBox(height: 18),

                  // Option 2: Medical Officer
                  _buildRoleCard(
                    icon: '👨‍⚕️',
                    title: context.tr('role_doctor_title'),
                    onTap: _isLoading ? () {} : _onSelectDoctor,
                  ),

                  if (_isLoading) ...[
                    const SizedBox(height: 28),
                    const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.5,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
