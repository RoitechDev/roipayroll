import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/services/encryption_service.dart';

enum UserRole { admin, hr, accountant, employee }

class AppUser {
  static const List<String> sensitiveFields = ['phoneNumber'];

  final String id;
  final String email;
  final String name;
  final UserRole role;
  final String companyId;
  final String? employeeId;
  final DateTime createdAt;
  final bool isActive;
  final DateTime? invitationSentAt;
  final bool requirePasswordChange;
  final DateTime? passwordChangedAt;
  final DateTime? lastLoginAt;
  final String? phoneNumber;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.companyId,
    this.employeeId,
    required this.createdAt,
    this.isActive = true,
    this.invitationSentAt,
    this.requirePasswordChange = false,
    this.passwordChangedAt,
    this.lastLoginAt,
    this.phoneNumber,
  });

  String getRoleName() {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.hr:
        return 'HR';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.employee:
        return 'Employee';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'companyId': companyId,
      'employeeId': employeeId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'invitationSentAt': invitationSentAt == null
          ? null
          : Timestamp.fromDate(invitationSentAt!),
      'requirePasswordChange': requirePasswordChange,
      'mustChangePassword': requirePasswordChange,
      'passwordChangedAt': passwordChangedAt == null
          ? null
          : Timestamp.fromDate(passwordChangedAt!),
      'lastLoginAt': lastLoginAt == null
          ? null
          : Timestamp.fromDate(lastLoginAt!),
      'phoneNumber': phoneNumber,
    };
  }

  Future<Map<String, dynamic>> toJsonEncrypted() async {
    return EncryptionService.encryptFields(toJson(), sensitiveFields);
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return AppUser(
      id: json['id'],
      email: json['email'],
      name: json['name'],
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.employee,
      ),
      companyId: json['companyId'] ?? 'original_company',
      employeeId: json['employeeId'],
      createdAt: readDate(json['createdAt']) ?? DateTime.now(),
      isActive: json['isActive'] ?? true,
      invitationSentAt: readDate(json['invitationSentAt']),
      requirePasswordChange:
          json['requirePasswordChange'] == true ||
          json['mustChangePassword'] == true,
      passwordChangedAt: readDate(json['passwordChangedAt']),
      lastLoginAt: readDate(json['lastLoginAt']),
      phoneNumber: json['phoneNumber'] as String?,
    );
  }

  static Future<AppUser> fromJsonEncrypted(Map<String, dynamic> json) async {
    final decrypted = await EncryptionService.decryptFields(
      json,
      sensitiveFields,
    );
    return AppUser.fromJson(decrypted);
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? companyId,
    String? employeeId,
    DateTime? createdAt,
    bool? isActive,
    DateTime? invitationSentAt,
    bool? requirePasswordChange,
    DateTime? passwordChangedAt,
    DateTime? lastLoginAt,
    String? phoneNumber,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      companyId: companyId ?? this.companyId,
      employeeId: employeeId ?? this.employeeId,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      invitationSentAt: invitationSentAt ?? this.invitationSentAt,
      requirePasswordChange:
          requirePasswordChange ?? this.requirePasswordChange,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      phoneNumber: phoneNumber ?? this.phoneNumber,
    );
  }
}
