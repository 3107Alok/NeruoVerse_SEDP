import 'package:flutter/material.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/role_selection/role_selection_screen.dart';
import '../../features/phc_network/presentation/phc_role_selection_screen.dart';
import '../../features/phc_network/presentation/asha/asha_dashboard_screen.dart';
import '../../features/phc_network/presentation/doctor/doctor_dashboard_screen.dart';
import '../../features/patient/home/patient_main_screen.dart';
import '../../features/caregiver/overview/caregiver_main_screen.dart';
import '../../features/admin/dashboard/admin_main_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String auth = '/auth';
  static const String roleSelection = '/roles';
  static const String phcRoleSelection = '/phc_roles';
  static const String ashaDashboard = '/asha';
  static const String doctorDashboard = '/doctor';
  static const String patientMain = '/patient';
  static const String caregiverMain = '/caregiver';
  static const String adminMain = '/admin';

  static Map<String, WidgetBuilder> get routes {
    return {
      auth: (context) => const AuthScreen(),
      roleSelection: (context) => const RoleSelectionScreen(),
      phcRoleSelection: (context) => const PhcRoleSelectionScreen(),
      ashaDashboard: (context) => const AshaDashboardScreen(),
      doctorDashboard: (context) => const DoctorDashboardScreen(),
      patientMain: (context) => const PatientMainScreen(),
      caregiverMain: (context) => const CaregiverMainScreen(),
      adminMain: (context) => const AdminMainScreen(),
    };
  }
}
