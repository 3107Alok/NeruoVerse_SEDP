class PhcPatientModel {
  final String id;
  final String name;
  final int age;
  final String gender;
  final String village;
  final String houseNo;
  final String guardianName;
  final String guardianPhone;
  final String abhaId;
  int baselineScore;
  int latestScore;
  int previousScore;
  DateTime lastScreenedDate;
  String status; // 'visited_today', 'due', 'skipped_today'
  String? skipReason;
  String riskLevel; // 'normal', 'mci_warning', 'severe_decline'
  final String notes;
  String assignedAshaId;
  String assignedAshaName;

  PhcPatientModel({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.village,
    required this.houseNo,
    required this.guardianName,
    required this.guardianPhone,
    this.abhaId = '',
    required this.baselineScore,
    required this.latestScore,
    required this.previousScore,
    required this.lastScreenedDate,
    required this.status,
    this.skipReason,
    required this.riskLevel,
    this.notes = '',
    this.assignedAshaId = '',
    this.assignedAshaName = 'Unassigned',
  });

  bool get isCriticalDecline {
    if (previousScore == 0) return false;
    final drop = ((previousScore - latestScore) / previousScore) * 100;
    return drop >= 30 || latestScore <= 4;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'gender': gender,
      'village': village,
      'houseNo': houseNo,
      'guardianName': guardianName,
      'guardianPhone': guardianPhone,
      'abhaId': abhaId,
      'baselineScore': baselineScore,
      'latestScore': latestScore,
      'previousScore': previousScore,
      'lastScreenedDate': lastScreenedDate.toIso8601String(),
      'status': status,
      'skipReason': skipReason,
      'riskLevel': riskLevel,
      'notes': notes,
      'assignedAshaId': assignedAshaId,
      'assignedAshaName': assignedAshaName,
    };
  }

  factory PhcPatientModel.fromJson(Map<String, dynamic> json) {
    return PhcPatientModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Elder',
      age: (json['age'] as num?)?.toInt() ?? 60,
      gender: json['gender'] as String? ?? 'Female',
      village: json['village'] as String? ?? '',
      houseNo: json['houseNo'] as String? ?? '',
      guardianName: json['guardianName'] as String? ?? '',
      guardianPhone: json['guardianPhone'] as String? ?? '',
      abhaId: json['abhaId'] as String? ?? '',
      baselineScore: (json['baselineScore'] as num?)?.toInt() ?? 0,
      latestScore: (json['latestScore'] as num?)?.toInt() ?? 0,
      previousScore: (json['previousScore'] as num?)?.toInt() ?? 0,
      lastScreenedDate: DateTime.tryParse(json['lastScreenedDate'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'due',
      skipReason: json['skipReason'] as String?,
      riskLevel: json['riskLevel'] as String? ?? 'normal',
      notes: json['notes'] as String? ?? '',
      assignedAshaId: json['assignedAshaId'] as String? ?? '',
      assignedAshaName: json['assignedAshaName'] as String? ?? 'Unassigned',
    );
  }
}
