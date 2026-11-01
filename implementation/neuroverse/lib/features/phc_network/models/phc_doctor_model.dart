class PhcDoctorModel {
  final String id;
  String name;
  final String facilityCode; // e.g. "PHC-JHT-108" (Permanent)
  final String hospitalName; // e.g. "Jorhat Rural Primary Health Centre" (Permanent)
  String doctorRegNo;
  String phone;
  String email;
  String designation;

  PhcDoctorModel({
    required this.id,
    required this.name,
    required this.facilityCode,
    required this.hospitalName,
    required this.doctorRegNo,
    required this.phone,
    required this.email,
    this.designation = 'Medical Officer In-Charge',
  });

  PhcDoctorModel copyWith({
    String? id,
    String? name,
    String? facilityCode,
    String? hospitalName,
    String? doctorRegNo,
    String? phone,
    String? email,
    String? designation,
  }) {
    return PhcDoctorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      facilityCode: facilityCode ?? this.facilityCode,
      hospitalName: hospitalName ?? this.hospitalName,
      doctorRegNo: doctorRegNo ?? this.doctorRegNo,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      designation: designation ?? this.designation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'facilityCode': facilityCode,
      'hospitalName': hospitalName,
      'doctorRegNo': doctorRegNo,
      'phone': phone,
      'email': email,
      'designation': designation,
    };
  }

  factory PhcDoctorModel.fromJson(Map<String, dynamic> json) {
    return PhcDoctorModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Medical Officer',
      facilityCode: json['facilityCode'] as String? ?? 'PHC-JHT-108',
      hospitalName: json['hospitalName'] as String? ?? 'Jorhat Rural Primary Health Centre',
      doctorRegNo: json['doctorRegNo'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      designation: json['designation'] as String? ?? 'Medical Officer',
    );
  }
}
