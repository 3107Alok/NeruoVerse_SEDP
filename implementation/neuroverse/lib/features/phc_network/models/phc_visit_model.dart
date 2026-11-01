class PhcVisitModel {
  final String id;
  final String patientId;
  final String patientName;
  final String village;
  final String ashaId;
  final String ashaName;
  final String facilityCode;
  final DateTime timestamp;
  final String status; // 'visited' or 'skipped'
  final String? skipReason; // 'not_home', 'unwell', 'flood_inaccessible', 'refused'
  final int? score;
  final int? durationSeconds;
  bool isSynced;

  PhcVisitModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.village,
    required this.ashaId,
    required this.ashaName,
    required this.facilityCode,
    required this.timestamp,
    required this.status,
    this.skipReason,
    this.score,
    this.durationSeconds,
    this.isSynced = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'village': village,
      'ashaId': ashaId,
      'ashaName': ashaName,
      'facilityCode': facilityCode,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'skipReason': skipReason,
      'score': score,
      'durationSeconds': durationSeconds,
      'isSynced': isSynced,
    };
  }

  factory PhcVisitModel.fromJson(Map<String, dynamic> json) {
    return PhcVisitModel(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      patientName: json['patientName'] as String? ?? 'Elder',
      village: json['village'] as String? ?? '',
      ashaId: json['ashaId'] as String? ?? '',
      ashaName: json['ashaName'] as String? ?? 'ASHA Worker',
      facilityCode: json['facilityCode'] as String? ?? 'PHC-JHT-108',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'visited',
      skipReason: json['skipReason'] as String?,
      score: (json['score'] as num?)?.toInt(),
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      isSynced: json['isSynced'] as bool? ?? false,
    );
  }
}
