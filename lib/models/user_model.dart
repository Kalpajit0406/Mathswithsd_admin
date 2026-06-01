// User model matching the backend API response
class AppUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? role;
  final int? classNo;
  final bool? verified;
  final bool? isRejected;
  final bool? isBlacklisted;
  final bool? isJoint;
  final String token;

  AppUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.role,
    this.classNo,
    this.verified,
    this.isRejected,
    this.isBlacklisted,
    this.isJoint,
    required this.token,
  });

  String get fullName => '$firstName $lastName';

  factory AppUser.fromJson(Map<String, dynamic> json, String token) {
    return AppUser(
      id: json['id'] ?? json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['studentPhone'] ?? json['studentMobile'],
      role: json['role'],
      classNo: json['classNo'] != null ? int.tryParse(json['classNo'].toString()) : null,
      verified: json['verified'],
      isRejected: json['isRejected'] ?? false,
      isBlacklisted: json['isBlacklisted'] ?? false,
      isJoint: json['isJoint'] ?? false,
      token: token,
    );
  }
}

class StudentUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final int? classNo;
  final bool? verified;
  final bool? isRejected;
  final bool? isJoint;
  final String? fatherName;
  final String? motherName;
  final String? dateOfBirth;
  final String? language;
  final Map<String, dynamic>? pendingProfileEdit;

  StudentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.classNo,
    this.verified,
    this.isRejected,
    this.isJoint,
    this.fatherName,
    this.motherName,
    this.dateOfBirth,
    this.language,
    this.pendingProfileEdit,
  });

  String get fullName => '$firstName $lastName';

  factory StudentUser.fromJson(Map<String, dynamic> json) {
    return StudentUser(
      id: json['id'] ?? json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['studentPhone'] ?? json['studentMobile'],
      classNo: json['classNo'] != null ? int.tryParse(json['classNo'].toString()) : null,
      verified: json['verified'],
      isRejected: json['isRejected'] ?? false,
      isJoint: json['isJoint'] ?? false,
      fatherName: json['fatherName'],
      motherName: json['motherName'],
      dateOfBirth: json['dateOfBirth'],
      language: json['language'],
      pendingProfileEdit: json['pendingProfileEdit'],
    );
  }
}
