import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../data/local/hive_service.dart';
import '../models/phc_patient_model.dart';
import '../models/phc_visit_model.dart';
import '../models/phc_asha_model.dart';
import '../models/phc_doctor_model.dart';

class PhcScheduledDrive {
  final String id;
  final String village;
  final DateTime date;
  final List<String> ashaIds;
  final List<String> ashaNames;
  final int totalAssignedPatients;
  final bool isDividedEqually;

  PhcScheduledDrive({
    required this.id,
    required this.village,
    required this.date,
    required this.ashaIds,
    required this.ashaNames,
    required this.totalAssignedPatients,
    required this.isDividedEqually,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'village': village,
    'date': date.toIso8601String(),
    'ashaIds': ashaIds,
    'ashaNames': ashaNames,
    'totalAssignedPatients': totalAssignedPatients,
    'isDividedEqually': isDividedEqually,
  };

  factory PhcScheduledDrive.fromJson(Map<String, dynamic> json) => PhcScheduledDrive(
    id: json['id'] as String? ?? 'DRIVE_${DateTime.now().millisecondsSinceEpoch}',
    village: json['village'] as String? ?? '',
    date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
    ashaIds: List<String>.from(json['ashaIds'] as List? ?? []),
    ashaNames: List<String>.from(json['ashaNames'] as List? ?? []),
    totalAssignedPatients: (json['totalAssignedPatients'] as num?)?.toInt() ?? 0,
    isDividedEqually: json['isDividedEqually'] as bool? ?? false,
  );
}

class PhcRepository extends ChangeNotifier {
  static final PhcRepository _instance = PhcRepository._internal();
  factory PhcRepository() => _instance;

  PhcRepository._internal() {
    _loadPersistedData();
  }

  // Active Doctor Information (PHC Centre is permanent; Doctor rotates)
  PhcDoctorModel _doctor = PhcDoctorModel(
    id: FirebaseAuth.instance.currentUser?.uid ?? 'PHC_DUTY_DOCTOR',
    name: 'Dr. Duty Medical Officer',
    facilityCode: 'PHC-JHT-108',
    hospitalName: 'Jorhat Rural Primary Health Centre',
    doctorRegNo: '',
    phone: '',
    email: FirebaseAuth.instance.currentUser?.email ?? '',
    designation: 'Medical Officer In-Charge',
  );

  // Active ASHA Worker Information (Current logged in field worker)
  PhcAshaModel _currentAsha = PhcAshaModel(
    id: FirebaseAuth.instance.currentUser?.uid ?? '',
    name: 'ASHA Worker',
    phone: '',
    email: FirebaseAuth.instance.currentUser?.email ?? '',
    villageCluster: '',
    facilityCode: 'PHC-JHT-108',
    isApproved: false,
    targetElders: 0,
    visitedCount: 0,
    skippedCount: 0,
  );

  // Dynamic real data lists (NO DUMMY HARDECODED DATA)
  final List<PhcAshaModel> _allAshaWorkers = [];
  final List<PhcPatientModel> _patients = [];
  final List<PhcVisitModel> _visitLogs = [];
  final Map<String, int> _scheduledVisits = {};
  final List<Map<String, dynamic>> _doctorReferrals = [];
  final List<PhcScheduledDrive> _scheduledDrives = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ashaSubscription;

  // -------------------------------------------------------------
  // PERSISTENCE & INITIALIZATION
  // -------------------------------------------------------------

  Future<void> _loadPersistedData() async {
    try {
      final hive = HiveService();
      final profile = hive.getUserProfile();
      final authUser = FirebaseAuth.instance.currentUser;

      // 1. Resolve Doctor details dynamically from Auth or Hive
      if (authUser != null) {
        _doctor = _doctor.copyWith(
          id: authUser.uid,
          email: authUser.email ?? _doctor.email,
        );
      }

      if (profile != null) {
        final role = profile['role']?.toString();
        final docName = profile['doctorName']?.toString() ?? (role == 'doctor' ? profile['name']?.toString() : null);
        if (docName != null && docName.trim().isNotEmpty) {
          final cleanDoc = docName.trim().startsWith('Dr.') ? docName.trim() : 'Dr. ${docName.trim()}';
          _doctor = _doctor.copyWith(
            name: cleanDoc,
            doctorRegNo: profile['doctorRegNo']?.toString() ?? '',
            phone: profile['phone']?.toString() ?? '',
            email: profile['email']?.toString() ?? _doctor.email,
            designation: profile['designation']?.toString() ?? 'Medical Officer In-Charge',
          );
        } else if (authUser?.displayName != null && authUser!.displayName!.trim().isNotEmpty) {
          final name = authUser.displayName!.trim();
          final cleanDoc = name.startsWith('Dr.') ? name : 'Dr. $name';
          _doctor = _doctor.copyWith(name: cleanDoc);
        }

        if (role == 'asha') {
          final ashaName = profile['name']?.toString() ?? authUser?.displayName;
          if (ashaName != null && ashaName.trim().isNotEmpty) {
            _currentAsha = _currentAsha.copyWith(
              id: authUser?.uid ?? _currentAsha.id,
              name: ashaName.trim(),
              phone: profile['phone']?.toString() ?? '',
              email: authUser?.email ?? profile['email']?.toString() ?? _currentAsha.email,
              villageCluster: profile['village']?.toString() ?? '',
            );
          }
        }
      } else if (authUser != null && authUser.displayName != null && authUser.displayName!.trim().isNotEmpty) {
        final name = authUser.displayName!.trim();
        final cleanDoc = name.startsWith('Dr.') ? name : 'Dr. $name';
        _doctor = _doctor.copyWith(name: cleanDoc);
      }

      // 2. Load Patients from Hive Box
      final box = Hive.box(HiveService.profileBoxName);
      final rawPatients = box.get('phc_patients');
      if (rawPatients != null && rawPatients is List && rawPatients.isNotEmpty) {
        _patients.clear();
        for (var item in rawPatients) {
          try {
            _patients.add(PhcPatientModel.fromJson(Map<String, dynamic>.from(item as Map)));
          } catch (_) {}
        }
      }

      // 3. Load ASHA Workers from Hive Box
      final rawAshas = box.get('phc_ashas');
      if (rawAshas != null && rawAshas is List && rawAshas.isNotEmpty) {
        _allAshaWorkers.clear();
        for (var item in rawAshas) {
          try {
            _allAshaWorkers.add(PhcAshaModel.fromJson(Map<String, dynamic>.from(item as Map)));
          } catch (_) {}
        }
      }

      // 4. Load Visit Logs from Hive Box
      final rawVisits = box.get('phc_visits');
      if (rawVisits != null && rawVisits is List && rawVisits.isNotEmpty) {
        _visitLogs.clear();
        for (var item in rawVisits) {
          try {
            _visitLogs.add(PhcVisitModel.fromJson(Map<String, dynamic>.from(item as Map)));
          } catch (_) {}
        }
      }

      // 5. Load Scheduled Drives from Hive Box
      final rawDrives = box.get('phc_drives');
      if (rawDrives != null && rawDrives is List && rawDrives.isNotEmpty) {
        _scheduledDrives.clear();
        for (var item in rawDrives) {
          try {
            _scheduledDrives.add(PhcScheduledDrive.fromJson(Map<String, dynamic>.from(item as Map)));
          } catch (_) {}
        }
      }

      notifyListeners();

      // Cloud Fetch (asynchronous background sync with Cloud Firestore)
      _fetchCloudData();

      // Live Firestore listener for incoming ASHA registrations & status
      _listenToAshaWorkers();
    } catch (_) {}
  }

  Future<void> _fetchCloudData() async {
    try {
      final firestore = FirebaseFirestore.instance;

      // A. Fetch Patients from Firestore
      final pSnap = await firestore.collection('phc_patients').get();
      if (pSnap.docs.isNotEmpty) {
        for (var doc in pSnap.docs) {
          try {
            final p = PhcPatientModel.fromJson(doc.data());
            final idx = _patients.indexWhere((existing) => existing.id == p.id);
            if (idx != -1) {
              _patients[idx] = p;
            } else {
              _patients.add(p);
            }
          } catch (_) {}
        }
        await _savePatientsToHive();
      }

      // B. Fetch ASHA Workers from Firestore (users collection with role == 'asha')
      final ashaSnap = await firestore.collection('users').where('role', isEqualTo: 'asha').get();
      if (ashaSnap.docs.isNotEmpty) {
        for (var doc in ashaSnap.docs) {
          final data = doc.data();
          final id = doc.id;
          if (data['rejected'] == true || data['isDeleted'] == true) {
            _allAshaWorkers.removeWhere((a) => a.id == id);
            continue;
          }
          final name = data['name']?.toString().trim() ?? '';
          final phone = data['phone']?.toString().trim() ?? '';
          final village = data['village']?.toString().trim() ?? '';
          final aFacility = data['facilityCode']?.toString().trim().toUpperCase() ?? '';

          // Filter out dummy/empty test accounts with no details
          if (name.isEmpty || (name == 'ASHA Worker' && phone.isEmpty && village.isEmpty)) {
            _allAshaWorkers.removeWhere((a) => a.id == id);
            continue;
          }

          // If ASHA specified a facilityCode, ensure it matches this doctor's PHC or is unassigned
          if (aFacility.isNotEmpty && aFacility != _doctor.facilityCode.trim().toUpperCase()) {
            _allAshaWorkers.removeWhere((a) => a.id == id);
            continue;
          }

          final idx = _allAshaWorkers.indexWhere((a) => a.id == id);
          final asha = PhcAshaModel(
            id: id,
            name: name,
            phone: phone,
            villageCluster: village,
            facilityCode: aFacility.isNotEmpty ? aFacility : _doctor.facilityCode,
            isApproved: data['isApproved'] as bool? ?? false,
            targetElders: (data['targetElders'] as num?)?.toInt() ?? 0,
            visitedCount: (data['visitedCount'] as num?)?.toInt() ?? 0,
            skippedCount: (data['skippedCount'] as num?)?.toInt() ?? 0,
          );
          if (idx != -1) {
            _allAshaWorkers[idx] = asha;
          } else {
            _allAshaWorkers.add(asha);
          }
        }
        await _saveAshasToHive();
      }

      // C. Fetch Scheduled Drives
      final driveSnap = await firestore.collection('phc_drives').get();
      if (driveSnap.docs.isNotEmpty) {
        for (var doc in driveSnap.docs) {
          try {
            final drive = PhcScheduledDrive.fromJson(doc.data());
            if (!_scheduledDrives.any((d) => d.id == drive.id)) {
              _scheduledDrives.add(drive);
            }
          } catch (_) {}
        }
        await _saveDrivesToHive();
      }

      // D. Fetch Visit Logs
      final visitSnap = await firestore.collection('phc_visits').get();
      if (visitSnap.docs.isNotEmpty) {
        for (var doc in visitSnap.docs) {
          try {
            final visit = PhcVisitModel.fromJson(doc.data());
            if (!_visitLogs.any((v) => v.id == visit.id)) {
              _visitLogs.add(visit);
            }
          } catch (_) {}
        }
        await _saveVisitsToHive();
      }

      notifyListeners();
    } catch (_) {}
  }

  /// Live Firestore stream listener for real-time incoming ASHA registrations & approval status updates
  void _listenToAshaWorkers() {
    _ashaSubscription?.cancel();
    try {
      _ashaSubscription = FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'asha')
          .snapshots()
          .listen((snap) {
        bool changed = false;
        for (var doc in snap.docs) {
          final data = doc.data();
          final id = doc.id;
          if (data['rejected'] == true || data['isDeleted'] == true) {
            final before = _allAshaWorkers.length;
            _allAshaWorkers.removeWhere((a) => a.id == id);
            if (before != _allAshaWorkers.length) changed = true;
            if (_currentAsha.id == id) {
              _currentAsha = _currentAsha.copyWith(isApproved: false);
              changed = true;
            }
            continue;
          }
          final name = data['name']?.toString().trim() ?? '';
          final phone = data['phone']?.toString().trim() ?? '';
          final village = data['village']?.toString().trim() ?? '';
          final aFacility = data['facilityCode']?.toString().trim().toUpperCase() ?? '';

          if (name.isEmpty || (name == 'ASHA Worker' && phone.isEmpty && village.isEmpty)) {
            continue;
          }

          // If ASHA specified a facilityCode, ensure it matches this doctor's PHC or is unassigned
          if (aFacility.isNotEmpty && aFacility != _doctor.facilityCode.trim().toUpperCase()) {
            final before = _allAshaWorkers.length;
            _allAshaWorkers.removeWhere((a) => a.id == id);
            if (before != _allAshaWorkers.length) changed = true;
            continue;
          }

          final isApproved = data['isApproved'] as bool? ?? false;
          final age = int.tryParse(data['age']?.toString() ?? '32') ?? 32;

          final idx = _allAshaWorkers.indexWhere((a) => a.id == id);
          final updatedAsha = PhcAshaModel(
            id: id,
            name: name,
            phone: phone,
            villageCluster: village,
            facilityCode: aFacility.isNotEmpty ? aFacility : _doctor.facilityCode,
            isApproved: isApproved,
            age: age,
            targetElders: (data['targetElders'] as num?)?.toInt() ?? 0,
            visitedCount: (data['visitedCount'] as num?)?.toInt() ?? 0,
            skippedCount: (data['skippedCount'] as num?)?.toInt() ?? 0,
          );

          if (idx != -1) {
            _allAshaWorkers[idx] = updatedAsha;
          } else {
            _allAshaWorkers.add(updatedAsha);
          }
          changed = true;

          if (_currentAsha.id == id) {
            _currentAsha = updatedAsha;
          }
        }
        if (changed) {
          _saveAshasToHive();
          notifyListeners();
        }
      }, onError: (_) {});
    } catch (_) {}
  }

  Future<void> _savePatientsToHive() async {
    try {
      final box = Hive.box(HiveService.profileBoxName);
      await box.put('phc_patients', _patients.map((p) => p.toJson()).toList());
    } catch (_) {}
  }

  Future<void> _saveAshasToHive() async {
    try {
      final box = Hive.box(HiveService.profileBoxName);
      await box.put('phc_ashas', _allAshaWorkers.map((a) => a.toJson()).toList());
    } catch (_) {}
  }

  Future<void> _saveVisitsToHive() async {
    try {
      final box = Hive.box(HiveService.profileBoxName);
      await box.put('phc_visits', _visitLogs.map((v) => v.toJson()).toList());
    } catch (_) {}
  }

  Future<void> _saveDrivesToHive() async {
    try {
      final box = Hive.box(HiveService.profileBoxName);
      await box.put('phc_drives', _scheduledDrives.map((d) => d.toJson()).toList());
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // GETTERS
  // -------------------------------------------------------------

  PhcDoctorModel get doctor => _doctor;
  PhcAshaModel get currentAsha => _currentAsha;
  List<PhcAshaModel> get allAshaWorkers => List.unmodifiable(_allAshaWorkers);
  List<PhcAshaModel> get approvedAshaWorkers =>
      _allAshaWorkers.where((a) => a.isApproved).toList();
  List<PhcAshaModel> get pendingAshaWorkers => _allAshaWorkers.where((a) =>
      !a.isApproved &&
      a.name.trim().isNotEmpty &&
      !(a.name == 'ASHA Worker' && a.phone.isEmpty && a.villageCluster.isEmpty)).toList();
  List<PhcPatientModel> get patients => List.unmodifiable(_patients);
  List<PhcVisitModel> get visitLogs => List.unmodifiable(_visitLogs);
  List<PhcScheduledDrive> get scheduledDrives => List.unmodifiable(_scheduledDrives);
  List<Map<String, dynamic>> get doctorReferrals => List.unmodifiable(_doctorReferrals);

  /// Dynamically aggregates village names from registered patients, ASHA clusters, and drives
  List<String> get availableVillages {
    final set = <String>{};
    if (_currentAsha.villageCluster.trim().isNotEmpty) {
      set.add(_currentAsha.villageCluster.trim());
    }
    for (var p in _patients) {
      if (p.village.trim().isNotEmpty) set.add(p.village.trim());
    }
    for (var a in _allAshaWorkers) {
      if (a.villageCluster.trim().isNotEmpty) set.add(a.villageCluster.trim());
    }
    for (var d in _scheduledDrives) {
      if (d.village.trim().isNotEmpty) set.add(d.village.trim());
    }
    if (set.isEmpty) {
      set.addAll(const [
        'Majuli Cluster 1',
        'Majuli Cluster 2',
        'Jorhat North',
        'Jorhat South',
        'Teok East',
        'Titabor South',
      ]);
    }
    return set.toList();
  }

  int getScheduledVisits(String village) {
    if (_scheduledVisits.containsKey(village)) {
      return _scheduledVisits[village]!;
    }
    return _patients.where((p) => p.village == village).length;
  }

  int getScheduledCompleted(String village) {
    return _patients
        .where((p) => p.village == village && p.status == 'visited_today')
        .length;
  }

  // Filter Patients by Village
  List<PhcPatientModel> getPatientsByVillage(String village) {
    if (village == 'All Villages' || village.isEmpty) {
      return _patients;
    }
    return _patients.where((p) => p.village == village).toList();
  }

  // Filter Visit Logs by Village (or all)
  List<PhcVisitModel> getVisitLogsByVillage(String village) {
    if (village == 'All Villages' || village.isEmpty) {
      return _visitLogs;
    }
    return _visitLogs.where((v) => v.village == village).toList();
  }

  // Filter High Risk Patients (Red Alerts for Doctor Triage)
  List<PhcPatientModel> get criticalAlertPatients {
    return _patients.where((p) => p.isCriticalDecline || p.riskLevel == 'severe_decline').toList();
  }

  int get pendingSyncCount {
    return _visitLogs.where((v) => !v.isSynced).length;
  }

  // -------------------------------------------------------------
  // DOCTOR ACTIONS
  // -------------------------------------------------------------

  /// Doctor schedules a village field drive and optionally divides patients equally among multiple ASHAs
  Future<void> scheduleVillageDrive({
    required String village,
    required DateTime date,
    required List<String> ashaIds,
    required bool divideEqually,
  }) async {
    final ashas = _allAshaWorkers.where((a) => ashaIds.contains(a.id)).toList();
    final ashaNames = ashas.map((a) => a.name).toList();
    final villagePatients = _patients.where((p) => p.village == village).toList();

    if (divideEqually && ashas.length > 1) {
      for (int i = 0; i < villagePatients.length; i++) {
        final assignedAsha = ashas[i % ashas.length];
        villagePatients[i].assignedAshaId = assignedAsha.id;
        villagePatients[i].assignedAshaName = assignedAsha.name;
        villagePatients[i].status = 'scheduled';
      }
    } else if (ashas.isNotEmpty) {
      for (var p in villagePatients) {
        p.assignedAshaId = ashas.first.id;
        p.assignedAshaName = ashas.first.name;
        p.status = 'scheduled';
      }
    }

    final newDrive = PhcScheduledDrive(
      id: 'DRIVE_${DateTime.now().millisecondsSinceEpoch}',
      village: village,
      date: date,
      ashaIds: ashaIds,
      ashaNames: ashaNames,
      totalAssignedPatients: villagePatients.length,
      isDividedEqually: divideEqually,
    );

    _scheduledDrives.insert(0, newDrive);
    _scheduledVisits[village] = (_scheduledVisits[village] ?? 0) + villagePatients.length;

    await _saveDrivesToHive();
    await _savePatientsToHive();

    try {
      await FirebaseFirestore.instance
          .collection('phc_drives')
          .doc(newDrive.id)
          .set(newDrive.toJson());
      for (var p in villagePatients) {
        await FirebaseFirestore.instance
            .collection('phc_patients')
            .doc(p.id)
            .set(p.toJson(), SetOptions(merge: true));
      }
    } catch (_) {}

    notifyListeners();
  }

  /// Generates structured clinical / ASHA supervision report data for Daily or Monthly view
  Map<String, dynamic> generateReportData({
    required String reportType, // 'patient' or 'asha'
    required String period,     // 'daily' or 'monthly'
  }) {
    final now = DateTime.now();
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final currentMonthName = months[(now.month - 1).clamp(0, 11)];
    final periodStr = period == 'daily'
        ? '${now.day}/${now.month}/${now.year} (Daily Roster)'
        : '$currentMonthName ${now.year} (Monthly Clinical Summary)';

    if (reportType == 'patient') {
      final total = _patients.length;
      final normal = _patients.where((p) => p.riskLevel == 'normal').length;
      final mci = _patients.where((p) => p.riskLevel == 'mci_warning').length;
      final severe = _patients.where((p) => p.riskLevel == 'severe_decline').length;
      final critical = _patients.where((p) => p.isCriticalDecline).length;

      final rows = _patients.map((p) => {
        'name': p.name,
        'age': '${p.age} / ${p.gender.isNotEmpty ? p.gender[0] : "U"}',
        'village': p.village,
        'baseline': '${p.baselineScore}/10',
        'latest': '${p.latestScore}/10',
        'assignedAsha': p.assignedAshaName,
        'risk': p.riskLevel == 'severe_decline'
            ? 'SEVERE'
            : p.riskLevel == 'mci_warning'
                ? 'MCI'
                : 'NORMAL',
      }).toList();

      return {
        'title': 'GERIATRIC DEMENTIA CLINICAL PROGRESSION REPORT',
        'subtitle': 'Primary Health Centre Community Screening Roster',
        'facilityCode': _doctor.facilityCode,
        'hospital': _doctor.hospitalName,
        'cmo': _doctor.name,
        'period': periodStr,
        'metrics': {
          'Total Elders Screened': total,
          'Stable / Normal (>=8)': normal,
          'Mild Cognitive Impairment (5-7)': mci,
          'Severe Decline (<=4)': severe,
          'Active Red Alerts': critical,
        },
        'headers': ['Elder Name', 'Age/G', 'Village Cluster', 'Baseline', 'Latest', 'Under ASHA', 'Clinical Risk'],
        'rows': rows,
      };
    } else {
      final totalAshas = _allAshaWorkers.length;
      final approvedAshas = approvedAshaWorkers.length;
      final totalVisits = _visitLogs.where((v) => v.status == 'visited').length;
      final totalSkipped = _visitLogs.where((v) => v.status == 'skipped').length;
      final totalDrives = _scheduledDrives.length;

      final rows = _allAshaWorkers.map((a) {
        final aVisits = _visitLogs.where((v) => v.ashaId == a.id && v.status == 'visited').length;
        final aSkips = _visitLogs.where((v) => v.ashaId == a.id && v.status == 'skipped').length;
        final totalP = _patients.where((p) => p.assignedAshaId == a.id).length;
        return {
          'name': a.name,
          'phone': a.phone.isNotEmpty ? a.phone : 'Not Registered',
          'village': a.villageCluster.isNotEmpty ? a.villageCluster : 'Unassigned',
          'status': a.isApproved ? 'Approved' : 'Pending',
          'assignedElders': totalP,
          'visited': aVisits > 0 ? aVisits : a.visitedCount,
          'skipped': aSkips > 0 ? aSkips : a.skippedCount,
        };
      }).toList();

      return {
        'title': 'ASHA / ANM FIELD SCREENING & SUPERVISION REPORT',
        'subtitle': 'National Health Mission & Frontline Telemetry',
        'facilityCode': _doctor.facilityCode,
        'hospital': _doctor.hospitalName,
        'cmo': _doctor.name,
        'period': periodStr,
        'metrics': {
          'Total Field Workers': totalAshas,
          'Active Approved ASHAs': approvedAshas,
          'Completed Field Visits': totalVisits,
          'Skipped Visits Logged': totalSkipped,
          'Scheduled Village Drives': totalDrives,
        },
        'headers': ['ASHA Name', 'Phone', 'Village Cluster', 'Status', 'Assigned Elders', 'Completed Visits', 'Skipped'],
        'rows': rows,
      };
    }
  }

  /// Doctor approves a pending ASHA worker connection request
  Future<void> approveAshaWorker(String ashaId) async {
    final index = _allAshaWorkers.indexWhere((a) => a.id == ashaId);
    if (index != -1) {
      _allAshaWorkers[index].isApproved = true;
      if (_currentAsha.id == ashaId) {
        _currentAsha = _currentAsha.copyWith(isApproved: true);
      }
      await _saveAshasToHive();
      try {
        await FirebaseFirestore.instance.collection('users').doc(ashaId).set({
          'isApproved': true,
          'status': 'approved',
          'approvedBy': _doctor.name,
          'approvedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Doctor rejects or removes an ASHA worker
  Future<void> rejectAshaWorker(String ashaId) async {
    _allAshaWorkers.removeWhere((a) => a.id == ashaId);
    if (_currentAsha.id == ashaId) {
      _currentAsha = _currentAsha.copyWith(isApproved: false);
    }
    await _saveAshasToHive();
    try {
      await FirebaseFirestore.instance.collection('users').doc(ashaId).set({
        'isApproved': false,
        'rejected': true,
        'isDeleted': true,
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
    notifyListeners();
  }

  /// Doctor permanently removes/purges an ASHA registration from Firebase & Hive
  Future<void> deleteAshaWorker(String ashaId) async {
    _allAshaWorkers.removeWhere((a) => a.id == ashaId);
    if (_currentAsha.id == ashaId) {
      _currentAsha = _currentAsha.copyWith(isApproved: false);
    }
    await _saveAshasToHive();
    try {
      await FirebaseFirestore.instance.collection('users').doc(ashaId).delete();
    } catch (_) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(ashaId).set({
          'isApproved': false,
          'rejected': true,
          'isDeleted': true,
          'status': 'declined',
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    notifyListeners();
  }

  /// Doctor issues a specialized PHC OPD Referral / Token for high risk elder
  void issueOpdReferral({
    required String patientId,
    required String patientName,
    required String doctorNotes,
  }) {
    _doctorReferrals.add({
      'referralId': 'REF_${DateTime.now().millisecondsSinceEpoch}',
      'patientId': patientId,
      'patientName': patientName,
      'doctorName': _doctor.name,
      'facilityCode': _doctor.facilityCode,
      'date': DateTime.now(),
      'notes': doctorNotes,
      'status': 'OPD Token Generated',
    });
    notifyListeners();
  }

  // -------------------------------------------------------------
  // ASHA ACTIONS
  // -------------------------------------------------------------

  /// ASHA registers with a PHC Facility Code, creating an approval request for the Medical Officer
  Future<void> registerAshaWithFacilityCode({
    required String name,
    required String phone,
    required String villageCluster,
    required int age,
    required String facilityCode,
  }) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final cleanCode = facilityCode.trim().toUpperCase();
    final cleanVillage = villageCluster.trim();
    final ashaId = authUser?.uid ??
        (_currentAsha.id.isNotEmpty && !_currentAsha.id.startsWith('ASHA_')
            ? _currentAsha.id
            : 'ASHA_${DateTime.now().millisecondsSinceEpoch}');

    final newAsha = PhcAshaModel(
      id: ashaId,
      name: name.trim(),
      phone: phone.trim(),
      age: age,
      villageCluster: cleanVillage,
      facilityCode: cleanCode,
      isApproved: false, // Sent for Medical Officer approval!
      targetElders: 0,
      visitedCount: 0,
      skippedCount: 0,
    );

    _currentAsha = newAsha;

    final idx = _allAshaWorkers.indexWhere((a) => a.id == ashaId);
    if (idx != -1) {
      _allAshaWorkers[idx] = newAsha;
    } else {
      _allAshaWorkers.add(newAsha);
    }

    await _saveAshasToHive();

    // Persist to user profile
    try {
      final hive = HiveService();
      final p = hive.getUserProfile() ?? {};
      p['role'] = 'asha';
      p['name'] = newAsha.name;
      p['phone'] = newAsha.phone;
      p['age'] = age.toString();
      p['village'] = cleanVillage;
      p['facilityCode'] = cleanCode;
      p['isApproved'] = false;
      await hive.saveUserProfile(p);
    } catch (_) {}

    // Persist to Firebase Firestore for the Medical Officer to see in real-time
    try {
      await FirebaseFirestore.instance.collection('users').doc(ashaId).set({
        'role': 'asha',
        'name': newAsha.name,
        'phone': newAsha.phone,
        'age': newAsha.age.toString(),
        'village': newAsha.villageCluster,
        'facilityCode': newAsha.facilityCode,
        'isApproved': false,
        'status': 'pending_approval',
        'requestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}

    notifyListeners();
  }

  /// ASHA connects to a Doctor using Facility Code
  bool connectToDoctorWithCode(
    String code, {
    required String ashaName,
    required String phone,
    required String village,
  }) {
    if (code.trim().toUpperCase() != _doctor.facilityCode) {
      return false; // Invalid code
    }

    final authUser = FirebaseAuth.instance.currentUser;
    final newAsha = PhcAshaModel(
      id: authUser?.uid ?? 'ASHA_${DateTime.now().millisecondsSinceEpoch}',
      name: ashaName,
      phone: phone,
      email: authUser?.email ?? '',
      villageCluster: village,
      facilityCode: code.trim().toUpperCase(),
      isApproved: false, // Needs doctor's approval
      targetElders: 0,
    );

    final idx = _allAshaWorkers.indexWhere((a) => a.id == newAsha.id);
    if (idx != -1) {
      _allAshaWorkers[idx] = newAsha;
    } else {
      _allAshaWorkers.add(newAsha);
    }
    _currentAsha = newAsha;

    _saveAshasToHive();

    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(newAsha.id)
          .set({
        'role': 'asha',
        'name': ashaName,
        'phone': phone,
        'village': village,
        'facilityCode': _doctor.facilityCode,
        'isApproved': false,
        'targetElders': 0,
      }, SetOptions(merge: true));
    } catch (_) {}

    notifyListeners();
    return true;
  }

  /// ASHA creates / registers a new elderly patient in her village
  Future<void> registerPatient({
    required String name,
    required int age,
    required String gender,
    required String village,
    required String houseNo,
    required String guardianName,
    required String guardianPhone,
    String abhaId = '',
    String notes = '',
  }) async {
    final newPatient = PhcPatientModel(
      id: 'PAT_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      age: age,
      gender: gender,
      village: village,
      houseNo: houseNo,
      guardianName: guardianName,
      guardianPhone: guardianPhone,
      abhaId: abhaId.trim(),
      baselineScore: 0,
      latestScore: 0,
      previousScore: 0,
      lastScreenedDate: DateTime.now(),
      status: 'due',
      riskLevel: 'normal',
      notes: notes,
      assignedAshaId: _currentAsha.id,
      assignedAshaName: _currentAsha.name.isNotEmpty ? _currentAsha.name : 'Unassigned',
    );

    _patients.insert(0, newPatient);
    await _savePatientsToHive();

    try {
      await FirebaseFirestore.instance
          .collection('phc_patients')
          .doc(newPatient.id)
          .set(newPatient.toJson())
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    notifyListeners();
  }

  /// ASHA records a completed screening game session
  Future<void> recordScreeningResult({
    required String patientId,
    required int score, // 0 to 10
    required int durationSeconds,
  }) async {
    final patientIndex = _patients.indexWhere((p) => p.id == patientId);
    if (patientIndex == -1) return;

    final patient = _patients[patientIndex];
    if (patient.baselineScore == 0) {
      patient.latestScore = score;
    }
    patient.previousScore = patient.latestScore;
    patient.latestScore = score;
    patient.lastScreenedDate = DateTime.now();
    patient.status = 'visited_today';
    patient.skipReason = null;

    if (score >= 8) {
      patient.riskLevel = 'normal';
    } else if (score >= 5) {
      patient.riskLevel = 'mci_warning';
    } else {
      patient.riskLevel = 'severe_decline';
    }

    _currentAsha.visitedCount++;

    final visit = PhcVisitModel(
      id: 'VIS_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patient.id,
      patientName: patient.name,
      village: patient.village,
      ashaId: _currentAsha.id,
      ashaName: _currentAsha.name,
      facilityCode: _doctor.facilityCode,
      timestamp: DateTime.now(),
      status: 'visited',
      score: score,
      durationSeconds: durationSeconds,
      isSynced: false,
    );
    _visitLogs.insert(0, visit);

    await _savePatientsToHive();
    await _saveVisitsToHive();

    try {
      await FirebaseFirestore.instance
          .collection('phc_patients')
          .doc(patient.id)
          .set(patient.toJson(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 2));
      await FirebaseFirestore.instance
          .collection('phc_visits')
          .doc(visit.id)
          .set(visit.toJson())
          .timeout(const Duration(seconds: 2));
    } catch (_) {}

    notifyListeners();
  }

  /// ASHA records a skipped visit with reason
  Future<void> recordSkippedVisit({
    required String patientId,
    required String skipReason, // 'not_home', 'unwell', 'flood_inaccessible', 'refused'
  }) async {
    final patientIndex = _patients.indexWhere((p) => p.id == patientId);
    if (patientIndex == -1) return;

    final patient = _patients[patientIndex];
    patient.status = 'skipped_today';
    patient.skipReason = skipReason;

    _currentAsha.skippedCount++;

    final visit = PhcVisitModel(
      id: 'VIS_${DateTime.now().millisecondsSinceEpoch}',
      patientId: patient.id,
      patientName: patient.name,
      village: patient.village,
      ashaId: _currentAsha.id,
      ashaName: _currentAsha.name,
      facilityCode: _doctor.facilityCode,
      timestamp: DateTime.now(),
      status: 'skipped',
      skipReason: skipReason,
      durationSeconds: 0,
      isSynced: false,
    );
    _visitLogs.insert(0, visit);

    await _savePatientsToHive();
    await _saveVisitsToHive();

    try {
      await FirebaseFirestore.instance
          .collection('phc_patients')
          .doc(patient.id)
          .set(patient.toJson(), SetOptions(merge: true));
      await FirebaseFirestore.instance
          .collection('phc_visits')
          .doc(visit.id)
          .set(visit.toJson());
    } catch (_) {}

    notifyListeners();
  }

  /// ASHA syncs all offline records to PHC cloud
  Future<void> syncAllOfflineWithCloud() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final firestore = FirebaseFirestore.instance;

    for (var log in _visitLogs) {
      if (!log.isSynced) {
        log.isSynced = true;
        try {
          await firestore.collection('phc_visits').doc(log.id).set(log.toJson());
        } catch (_) {}
      }
    }
    _currentAsha.lastSyncTime = DateTime.now();

    await _saveVisitsToHive();
    notifyListeners();
  }

  // Switch ASHA for testing if multiple exist
  void switchAsha(String ashaId) {
    final asha = _allAshaWorkers.firstWhere((a) => a.id == ashaId, orElse: () => _currentAsha);
    _currentAsha = asha;
    notifyListeners();
  }

  /// Update an existing patient's details
  Future<void> updatePatient(PhcPatientModel updated) async {
    final index = _patients.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _patients[index] = updated;
      await _savePatientsToHive();
      try {
        await FirebaseFirestore.instance
            .collection('phc_patients')
            .doc(updated.id)
            .set(updated.toJson(), SetOptions(merge: true));
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Delete a patient from the roster
  Future<void> deletePatient(String patientId) async {
    _patients.removeWhere((p) => p.id == patientId);
    await _savePatientsToHive();
    try {
      await FirebaseFirestore.instance.collection('phc_patients').doc(patientId).delete();
    } catch (_) {}
    notifyListeners();
  }

  /// Update ASHA personal details while keeping facilityCode non-editable!
  Future<void> updateAshaProfile({
    required String name,
    required String phone,
    required int age,
    required String villageCluster,
  }) async {
    _currentAsha.name = name;
    _currentAsha.phone = phone;
    _currentAsha.age = age;
    _currentAsha.villageCluster = villageCluster;

    final index = _allAshaWorkers.indexWhere((a) => a.id == _currentAsha.id);
    if (index != -1) {
      _allAshaWorkers[index].name = name;
      _allAshaWorkers[index].phone = phone;
      _allAshaWorkers[index].age = age;
      _allAshaWorkers[index].villageCluster = villageCluster;
    }
    await _saveAshasToHive();

    // Persist to user profile
    try {
      final hive = HiveService();
      final p = hive.getUserProfile() ?? {};
      p['name'] = name;
      p['phone'] = phone;
      p['age'] = age.toString();
      p['village'] = villageCluster;
      await hive.saveUserProfile(p);
    } catch (_) {}

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(authUser.uid).set({
          'name': name,
          'phone': phone,
          'age': age.toString(),
          'village': villageCluster,
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    notifyListeners();
  }

  /// ASHA updates her assigned PHC Facility Code and Village Cluster (e.g. if transferred or re-assigned)
  Future<void> updateAshaPhcFacility({
    required String facilityCode,
    required String villageCluster,
  }) async {
    final cleanCode = facilityCode.trim().toUpperCase();
    final cleanVillage = villageCluster.trim();

    _currentAsha = _currentAsha.copyWith(
      facilityCode: cleanCode,
      villageCluster: cleanVillage.isNotEmpty ? cleanVillage : _currentAsha.villageCluster,
      isApproved: false, // Reset to pending approval under new facility code
    );

    final index = _allAshaWorkers.indexWhere((a) => a.id == _currentAsha.id);
    if (index != -1) {
      _allAshaWorkers[index].facilityCode = cleanCode;
      _allAshaWorkers[index].isApproved = false;
      if (cleanVillage.isNotEmpty) {
        _allAshaWorkers[index].villageCluster = cleanVillage;
      }
    } else {
      _allAshaWorkers.add(_currentAsha);
    }
    await _saveAshasToHive();

    try {
      final hive = HiveService();
      final p = hive.getUserProfile() ?? {};
      p['facilityCode'] = cleanCode;
      p['isApproved'] = false;
      if (cleanVillage.isNotEmpty) p['village'] = cleanVillage;
      await hive.saveUserProfile(p);
    } catch (_) {}

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      final uid = authUser?.uid ?? _currentAsha.id;
      if (uid.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'facilityCode': cleanCode,
          'isApproved': false,
          'status': 'pending_approval',
          'requestedAt': FieldValue.serverTimestamp(),
          if (cleanVillage.isNotEmpty) 'village': cleanVillage,
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    notifyListeners();
  }

  /// Update active doctor information (Doctors rotate/change, PHC centre stays permanent)
  Future<void> updateDoctorProfile({
    required String name,
    String? doctorRegNo,
    String? phone,
    String? email,
    String? designation,
    String? facilityCode,
    String? hospitalName,
  }) async {
    final cleanName = name.trim().startsWith('Dr.') ? name.trim() : 'Dr. ${name.trim()}';
    _doctor = _doctor.copyWith(
      name: cleanName,
      doctorRegNo: doctorRegNo?.trim().isNotEmpty == true ? doctorRegNo!.trim() : _doctor.doctorRegNo,
      phone: phone?.trim().isNotEmpty == true ? phone!.trim() : _doctor.phone,
      email: email?.trim().isNotEmpty == true ? email!.trim() : _doctor.email,
      designation: designation?.trim().isNotEmpty == true ? designation!.trim() : _doctor.designation,
      facilityCode: facilityCode?.trim().isNotEmpty == true ? facilityCode!.trim().toUpperCase() : _doctor.facilityCode,
      hospitalName: hospitalName?.trim().isNotEmpty == true ? hospitalName!.trim() : _doctor.hospitalName,
    );

    // Persist to Hive local storage
    try {
      final hive = HiveService();
      final currentProfile = hive.getUserProfile() ?? {};
      currentProfile['role'] = 'doctor';
      currentProfile['name'] = cleanName;
      currentProfile['doctorName'] = cleanName;
      currentProfile['doctorRegNo'] = _doctor.doctorRegNo;
      currentProfile['phone'] = _doctor.phone;
      currentProfile['email'] = _doctor.email;
      currentProfile['designation'] = _doctor.designation;
      currentProfile['hospitalName'] = _doctor.hospitalName;
      currentProfile['facilityCode'] = _doctor.facilityCode;
      await hive.saveUserProfile(currentProfile);
    } catch (_) {}

    // Persist to Firebase Firestore if online
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser != null) {
        await FirebaseFirestore.instance.collection('users').doc(authUser.uid).set({
          'role': 'doctor',
          'name': cleanName,
          'doctorName': cleanName,
          'doctorRegNo': _doctor.doctorRegNo,
          'phone': _doctor.phone,
          'email': _doctor.email,
          'designation': _doctor.designation,
          'hospitalName': _doctor.hospitalName,
          'facilityCode': _doctor.facilityCode,
        }, SetOptions(merge: true));
      }
    } catch (_) {}

    notifyListeners();
  }
}
