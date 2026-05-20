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
      classNo: json['classNo'],
      verified: json['verified'],
      isRejected: json['isRejected'] ?? false,
      isBlacklisted: json['isBlacklisted'] ?? false,
      token: token,
    );
  }
}

// For manage students screen
class StudentUser {
  final String id;
  final String firstName;
  final String lastName;
  final String? phone;
  final int? classNo;
  final bool? verified;
  final bool? isRejected;

  StudentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.classNo,
    this.verified,
    this.isRejected,
  });

  String get fullName => '$firstName $lastName';

  factory StudentUser.fromJson(Map<String, dynamic> json) {
    return StudentUser(
      id: json['id'] ?? json['_id'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['studentPhone'] ?? json['studentMobile'],
      classNo: json['classNo'],
      verified: json['verified'],
      isRejected: json['isRejected'] ?? false,
    );
  }
}
