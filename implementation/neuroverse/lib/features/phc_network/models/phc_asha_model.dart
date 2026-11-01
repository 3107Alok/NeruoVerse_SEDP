class PhcAshaModel {
  final String id;
  String name;
  String phone;
  String email;
  int age;
  String villageCluster;
  String facilityCode;
  bool isApproved;
  final int targetElders;
  int visitedCount;
  int skippedCount;
  DateTime? lastSyncTime;

  PhcAshaModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.age = 38,
    required this.villageCluster,
    required this.facilityCode,
    this.isApproved = false,
    this.targetElders = 0,
    this.visitedCount = 0,
    this.skippedCount = 0,
    this.lastSyncTime,
  });

  PhcAshaModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    int? age,
    String? villageCluster,
    String? facilityCode,
    bool? isApproved,
    int? targetElders,
    int? visitedCount,
    int? skippedCount,
    DateTime? lastSyncTime,
  }) {
    return PhcAshaModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      age: age ?? this.age,
      villageCluster: villageCluster ?? this.villageCluster,
      facilityCode: facilityCode ?? this.facilityCode,
      isApproved: isApproved ?? this.isApproved,
      targetElders: targetElders ?? this.targetElders,
      visitedCount: visitedCount ?? this.visitedCount,
      skippedCount: skippedCount ?? this.skippedCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'age': age,
      'villageCluster': villageCluster,
      'facilityCode': facilityCode,
      'isApproved': isApproved,
      'targetElders': targetElders,
      'visitedCount': visitedCount,
      'skippedCount': skippedCount,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
    };
  }

  factory PhcAshaModel.fromJson(Map<String, dynamic> json) {
    return PhcAshaModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'ASHA Worker',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      age: json['age'] as int? ?? 30,
      villageCluster: json['villageCluster'] as String? ?? '',
      facilityCode: json['facilityCode'] as String? ?? 'PHC-JHT-108',
      isApproved: json['isApproved'] as bool? ?? false,
      targetElders: json['targetElders'] as int? ?? 0,
      visitedCount: json['visitedCount'] as int? ?? 0,
      skippedCount: json['skippedCount'] as int? ?? 0,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'] as String)
          : null,
    );
  }
}
