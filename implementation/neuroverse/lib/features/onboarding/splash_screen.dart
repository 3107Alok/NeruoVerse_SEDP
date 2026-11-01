import 'package:flutter/material.dart';
import '../../core/services/emergency_sos_service.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/local/hive_service.dart';
import '../../core/services/sync_service.dart';
import '../../providers/app_provider.dart';
import '../patient/home/patient_main_screen.dart';
import '../caregiver/overview/caregiver_main_screen.dart';
import '../admin/dashboard/admin_main_screen.dart';
import '../auth/auth_screen.dart';
import '../role_selection/role_selection_screen.dart';
import '../phc_network/presentation/asha/asha_dashboard_screen.dart';
import '../phc_network/presentation/doctor/doctor_dashboard_screen.dart';
import '../phc_network/data/phc_repository.dart';
import 'dart:math';
import 'setup_profile_screen.dart';
import 'caregiver_setup_profile_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Show splash screen for at least 2.5 seconds
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Not logged in -> go to AuthScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
      return;
    }

    // Verify email for password-based accounts before allowing into the app
    final isPasswordProvider = user.providerData.any((p) => p.providerId == 'password');
    if (isPasswordProvider) {
      try {
        await user.reload();
      } catch (_) {}
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser != null && !refreshedUser.emailVerified) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please verify your email before logging in. Check your inbox!')),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
        return;
      }
    }
    if (!mounted) return;

    final hive = context.read<HiveService>();
    final appProvider = context.read<AppProvider>();

    // Fetch user document from Firestore
    DocumentSnapshot<Map<String, dynamic>>? userDoc;
    bool isNetworkError = false;
    try {
      userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      isNetworkError = true;
    }

    if (!mounted) return;

    // 1. If doc exists in Firestore, check suspension and profile completion
    if (userDoc != null && userDoc.exists && userDoc.data() != null) {
      final data = userDoc.data()!;

      // Suspension Check
      final isSuspended = data['isSuspended'] == true;
      if (isSuspended) {
        await FirebaseAuth.instance.signOut();
        await hive.saveUserProfile({});
        appProvider.clearUserProfile();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.red,
              content: Text('Your account has been suspended by the administrator.'),
              duration: Duration(seconds: 5),
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
        return;
      }

      final firestoreRole = data['role']?.toString();
      final firestoreName = data['name']?.toString();
      final firestoreCaregiverId = data['linkedCaregiverId']?.toString();

      // Case A: Role is Admin
      if (firestoreRole == 'admin') {
        appProvider.setRole('admin');
        await hive.saveUserProfile({
          'uid': user.uid,
          'role': 'admin',
          'name': firestoreName ?? 'Admin',
          'email': user.email ?? '',
        });
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminMainScreen()),
          );
        }
        return;
      }

      // Case B: Role is Caregiver
      if (firestoreRole == 'caregiver') {
        if (firestoreName == null || firestoreName.trim().isEmpty) {
          // Profile incomplete -> route to setup
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const CaregiverSetupProfileScreen()),
            );
          }
          return;
        }

        appProvider.setRole('caregiver');
        appProvider.setUserProfile(
          firestoreName,
          data['age']?.toString() ?? '',
          data['gender']?.toString() ?? '',
          'English',
        );
        final cgPhone = (data['phone']?.toString().trim() ?? '').isNotEmpty
            ? data['phone'].toString().trim()
            : (hive.getUserProfile()?['phone']?.toString().trim() ?? '');

        await hive.saveUserProfile({
          'uid': user.uid,
          'role': 'caregiver',
          'name': firestoreName,
          'email': user.email ?? '',
          'age': data['age']?.toString() ?? '',
          'gender': data['gender']?.toString() ?? '',
          'phone': cgPhone,
        });
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const CaregiverMainScreen()),
          );
        }
        return;
      }

      // Case C: Role is Patient
      if (firestoreRole == 'patient') {
        if (firestoreName == null || firestoreName.trim().isEmpty) {
          // Profile incomplete -> route to setup
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SetupProfileScreen()),
            );
          }
          return;
        }

        // Ensure shareCode is NEVER empty or '---'
        var shareCode = data['shareCode']?.toString() ?? data['connectCode']?.toString() ?? '';
        if (shareCode.isEmpty || shareCode == '---') {
          const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
          final rand = Random();
          shareCode = String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rand.nextInt(chars.length))));
          try {
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'shareCode': shareCode,
              'connectCode': shareCode,
            }, SetOptions(merge: true));
          } catch (_) {}
        }

        String? caretakerName = data['caretakerName']?.toString();
        if (firestoreCaregiverId != null && firestoreCaregiverId.isNotEmpty && caretakerName == null) {
          try {
            final cgDoc = await FirebaseFirestore.instance.collection('users').doc(firestoreCaregiverId).get();
            caretakerName = cgDoc.data()?['name']?.toString();
          } catch (_) {}
        }

        final lang = data['language']?.toString() ?? 'English';
        final vLang = data['voiceLanguage']?.toString() ?? lang;

        appProvider.setRole('patient');
        appProvider.setUserProfile(
          firestoreName,
          data['age']?.toString() ?? '',
          data['gender']?.toString() ?? '',
          lang,
          voiceLanguage: vLang,
          caretakerName: caretakerName,
        );

        final ptPhone = (data['phone']?.toString().trim() ?? '').isNotEmpty
            ? data['phone'].toString().trim()
            : (hive.getUserProfile()?['phone']?.toString().trim() ?? '');

        final ptCaregiverPhone = (data['caregiverPhone'] ?? data['guardianPhone'] ?? '').toString().trim();

        await hive.saveUserProfile({
          'uid': user.uid,
          'role': 'patient',
          'name': firestoreName,
          'email': user.email ?? '',
          'age': data['age']?.toString() ?? '',
          'gender': data['gender']?.toString() ?? '',
          'language': lang,
          'voiceLanguage': vLang,
          'shareCode': shareCode,
          'connectCode': shareCode,
          'caretakerName': caretakerName,
          'phone': ptPhone,
          if (ptCaregiverPhone.isNotEmpty) 'caregiverPhone': ptCaregiverPhone,
          if (ptCaregiverPhone.isNotEmpty) 'guardianPhone': ptCaregiverPhone,
        });

        if (ptCaregiverPhone.isNotEmpty) {
          try {
            await EmergencySosService().addEmergencyContact(ptCaregiverPhone);
          } catch (_) {}
        }

        // Restore game sessions from cloud into local Hive
        try {
          await SyncService(hive).restoreDataFromCloud(user.uid);
          if (mounted) {
            appProvider.loadProgress();
            appProvider.setSyncStatus(true);
          }
        } catch (_) {}

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PatientMainScreen()),
          );
        }
        return;
      }

      // Case D: Role is ASHA Worker
      if (firestoreRole == 'asha') {
        String ashaName = '';
        if (firestoreName != null && firestoreName.trim().isNotEmpty) {
          ashaName = firestoreName.trim();
        } else if (data['name'] != null && data['name'].toString().trim().isNotEmpty) {
          ashaName = data['name'].toString().trim();
        } else if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          ashaName = user.displayName!.trim();
        } else if (hive.getUserProfile()?['name'] != null && hive.getUserProfile()!['name'].toString().trim().isNotEmpty) {
          ashaName = hive.getUserProfile()!['name'].toString().trim();
        } else if (user.email != null && user.email!.contains('@')) {
          final uname = user.email!.split('@').first;
          ashaName = uname.isNotEmpty ? (uname[0].toUpperCase() + uname.substring(1)) : 'ASHA Worker';
        } else {
          ashaName = 'ASHA Worker';
        }

        final village = data['village']?.toString() ?? 'Bihpuria Gaon';
        final facilityCode = data['facilityCode']?.toString() ?? 'PHC-JHT-108';
        final ashaLang = data['language']?.toString() ?? 'English';
        final int ashaAge = int.tryParse(data['age']?.toString() ?? '32') ?? 32;
        final String ashaPhone = data['phone']?.toString() ?? user.phoneNumber ?? '+91 98640-33129';

        PhcRepository().updateAshaProfile(
          name: ashaName,
          phone: ashaPhone,
          age: ashaAge,
          villageCluster: village,
        );

        appProvider.setRole('asha');
        appProvider.setUserProfile(
          ashaName,
          data['age']?.toString() ?? '32',
          data['gender']?.toString() ?? 'Female',
          ashaLang,
        );

        await hive.saveUserProfile({
          'uid': user.uid,
          'role': 'asha',
          'name': ashaName,
          'email': user.email ?? '',
          'phone': ashaPhone,
          'age': ashaAge.toString(),
          'gender': data['gender']?.toString() ?? 'Female',
          'village': village,
          'facilityCode': facilityCode,
          'language': ashaLang,
        });

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AshaDashboardScreen()),
          );
        }
        return;
      }

      // Case E: Role is Medical Officer / Doctor
      if (firestoreRole == 'doctor') {
        String docName = '';
        if (firestoreName != null && firestoreName.trim().isNotEmpty) {
          docName = firestoreName.trim();
        } else if (data['doctorName'] != null && data['doctorName'].toString().trim().isNotEmpty) {
          docName = data['doctorName'].toString().trim();
        } else if (data['name'] != null && data['name'].toString().trim().isNotEmpty) {
          docName = data['name'].toString().trim();
        } else if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          docName = user.displayName!.trim();
        } else if (hive.getUserProfile()?['doctorName'] != null && hive.getUserProfile()!['doctorName'].toString().trim().isNotEmpty) {
          docName = hive.getUserProfile()!['doctorName'].toString().trim();
        } else if (hive.getUserProfile()?['name'] != null && hive.getUserProfile()!['name'].toString().trim().isNotEmpty) {
          docName = hive.getUserProfile()!['name'].toString().trim();
        } else if (user.email != null && user.email!.contains('@')) {
          final uname = user.email!.split('@').first;
          docName = uname.isNotEmpty ? (uname[0].toUpperCase() + uname.substring(1)) : 'Medical Officer';
        } else {
          docName = 'Medical Officer';
        }

        if (!docName.toLowerCase().startsWith('dr.')) {
          docName = 'Dr. $docName';
        }

        final hospitalName = data['hospitalName']?.toString() ?? 'Jorhat Rural Primary Health Centre';
        final facilityCode = data['facilityCode']?.toString() ?? 'PHC-JHT-108';
        final docLang = data['language']?.toString() ?? 'English';
        final doctorRegNo = data['doctorRegNo']?.toString() ?? 'NMC-AS-2018-9410';
        final docPhone = data['phone']?.toString() ?? user.phoneNumber ?? '+91 94350-12847';
        final docEmail = user.email ?? data['email']?.toString() ?? 'cmo.jorhat@assamhealth.gov.in';
        final designation = data['designation']?.toString() ?? 'Medical Officer In-Charge';

        await PhcRepository().updateDoctorProfile(
          name: docName,
          doctorRegNo: doctorRegNo,
          phone: docPhone,
          email: docEmail,
          designation: designation,
        );

        appProvider.setRole('doctor');
        appProvider.setUserProfile(
          docName,
          data['age']?.toString() ?? '45',
          data['gender']?.toString() ?? 'Male',
          docLang,
        );

        await hive.saveUserProfile({
          'uid': user.uid,
          'role': 'doctor',
          'name': docName,
          'doctorName': docName,
          'doctorRegNo': doctorRegNo,
          'phone': docPhone,
          'email': docEmail,
          'designation': designation,
          'hospitalName': hospitalName,
          'facilityCode': facilityCode,
          'language': docLang,
        });

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DoctorDashboardScreen()),
          );
        }
        return;
      }
    }

    // 2. Offline Fallback: Only trust local Hive profile if it strictly belongs to THIS user.uid
    if (isNetworkError) {
      final localProfile = hive.getUserProfile();
      if (localProfile != null && localProfile['uid'] == user.uid && localProfile['role'] != null) {
        final role = localProfile['role'].toString();
        appProvider.setRole(role);
        appProvider.setUserProfile(
          localProfile['name']?.toString() ?? '',
          localProfile['age']?.toString() ?? '',
          localProfile['gender']?.toString() ?? '',
          localProfile['language']?.toString() ?? 'English',
          voiceLanguage: localProfile['voiceLanguage']?.toString(),
          caretakerName: localProfile['caretakerName']?.toString(),
        );
        if (role == 'caregiver') {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const CaregiverMainScreen()));
        } else if (role == 'admin') {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AdminMainScreen()));
        } else if (role == 'asha') {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AshaDashboardScreen()));
        } else if (role == 'doctor') {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const DoctorDashboardScreen()));
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PatientMainScreen()));
        }
        return;
      }
    }

    // 3. User has NO role in Firestore (New user or incomplete profile)
    // Clear any stale local cache and route directly to RoleSelectionScreen!
    await hive.saveUserProfile({});
    appProvider.clearUserProfile();
    appProvider.clearProgress();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00221E),
      body: Stack(
        children: [
          // Emerald Neural Network Background Wallpaper
          Positioned.fill(
            child: Image.asset(
              'assets/images/splash_bg.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF002824), Color(0xFF004D40), Color(0xFF001E1A)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          
          // Subtle Dark Gradient Overlay for optimal contrast
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF001B17).withValues(alpha: 0.5),
                    Colors.transparent,
                    const Color(0xFF001B17).withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // Content Overlay
          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 70),

                  // Glowing Emerald Brain App Logo
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00BFA5).withValues(alpha: 0.35),
                          blurRadius: 30,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/app_icon.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: const Color(0xFF00695C),
                          child: const Icon(Icons.psychology_rounded, size: 60, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // App Title
                  const Text(
                    'NEUROVERSE',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Color(0xFF004D40),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Care Together. Grow Together.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF80CBC4),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const Spacer(),

                  // Loading Text
                  AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _glowAnimation.value.clamp(0.4, 1.0),
                        child: child,
                      );
                    },
                    child: const Text(
                      'Getting neuroverse ready',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 13.5,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Aesthetic Glowing Capsule Progress Bar
                  AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return Container(
                        width: 140,
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.white.withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF26A69A).withValues(alpha: _glowAnimation.value * 0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Stack(
                            children: [
                              Positioned(
                                left: -40 + (_animController.value * 160),
                                width: 50,
                                height: 4,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Color(0xFF80CBC4),
                                        Color(0xFF26A69A),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 52),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
