import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/services/encryption_service.dart';

enum InvitationStatus {
  notInvited,
  inviteSent,
  inviteFailed,
  passwordChanged,
  active,
}

enum EmploymentType { permanent, contract, probation }

class Employee {
  static const List<String> sensitiveFields = [
    'phone',
    'bankName',
    'accountNumber',
  ];

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String department;
  final String position;
  final double basicSalary;
  final String payoutCurrency;
  final DateTime hireDate;
  final String status;
  final EmploymentType employmentType;
  final DateTime? probationEndDate;
  final DateTime? contractEndDate;
  final bool isProbationConfirmed;
  final String? bankName;
  final String? accountNumber;
  final bool hasLogin;
  final String? userId;
  final InvitationStatus invitationStatus;
  final DateTime? invitedAt;
  final DateTime? lastInviteSentAt;
  final DateTime? passwordChangedAt;
  final DateTime? lastLoginAt;
  final int inviteAttempts;
  final String? inviteError;
  final String? companyId;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? deletedBy;
  final String? deletionReason;

  Employee({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.department,
    required this.position,
    required this.basicSalary,
    this.payoutCurrency = 'NGN',
    required this.hireDate,
    this.status = 'active',
    this.employmentType = EmploymentType.permanent,
    this.probationEndDate,
    this.contractEndDate,
    this.isProbationConfirmed = false,
    this.bankName,
    this.accountNumber,
    this.hasLogin = false,
    this.userId,
    this.invitationStatus = InvitationStatus.notInvited,
    this.invitedAt,
    this.lastInviteSentAt,
    this.passwordChangedAt,
    this.lastLoginAt,
    this.inviteAttempts = 0,
    this.inviteError,
    this.companyId,
    this.isDeleted = false,
    this.deletedAt,
    this.deletedBy,
    this.deletionReason,
  });

  String get fullName => '$firstName $lastName';

  bool get canInvite =>
      !hasLogin || invitationStatus == InvitationStatus.inviteFailed;

  bool get needsPasswordChange =>
      hasLogin && invitationStatus == InvitationStatus.inviteSent;

  bool get isFullyOnboarded => invitationStatus == InvitationStatus.active;

  String get statusLabel {
    switch (invitationStatus) {
      case InvitationStatus.notInvited:
        return 'Not Invited';
      case InvitationStatus.inviteSent:
        return 'Pending';
      case InvitationStatus.inviteFailed:
        return 'Failed';
      case InvitationStatus.passwordChanged:
        return 'Password Set';
      case InvitationStatus.active:
        return 'Active';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phone': phone,
      'department': department,
      'position': position,
      'basicSalary': basicSalary,
      'payoutCurrency': payoutCurrency,
      'hireDate': Timestamp.fromDate(hireDate),
      'status': status,
      'employmentType': employmentType.name,
      'probationEndDate': probationEndDate != null
          ? Timestamp.fromDate(probationEndDate!)
          : null,
      'contractEndDate': contractEndDate != null
          ? Timestamp.fromDate(contractEndDate!)
          : null,
      'isProbationConfirmed': isProbationConfirmed,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'hasLogin': hasLogin,
      'userId': userId,
      'invitationStatus': invitationStatus.name,
      'invitedAt': invitedAt != null ? Timestamp.fromDate(invitedAt!) : null,
      'lastInviteSentAt': lastInviteSentAt != null
          ? Timestamp.fromDate(lastInviteSentAt!)
          : null,
      'passwordChangedAt': passwordChangedAt != null
          ? Timestamp.fromDate(passwordChangedAt!)
          : null,
      'lastLoginAt': lastLoginAt != null
          ? Timestamp.fromDate(lastLoginAt!)
          : null,
      'inviteAttempts': inviteAttempts,
      'inviteError': inviteError,
      'companyId': companyId,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'deletedBy': deletedBy,
      'deletionReason': deletionReason,
    };
  }

  Future<Map<String, dynamic>> toJsonEncrypted() async {
    return EncryptionService.encryptFields(toJson(), sensitiveFields);
  }

  Future<Map<String, dynamic>> toAuditJson() async {
    final json = await toJsonEncrypted();
    json['phone'] = _maskValue(phone, visibleEnd: 2);
    json['bankName'] = bankName == null || bankName!.trim().isEmpty
        ? bankName
        : '[redacted]';
    json['accountNumber'] = _maskValue(accountNumber, visibleEnd: 4);
    json['basicSalary'] = '[redacted]';
    return json;
  }

  factory Employee.fromJson(Map<String, dynamic> json) {
    try {
      DateTime? readDate(dynamic value) {
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        if (value is String) return DateTime.tryParse(value);
        return null;
      }

      final hasLinkedUser =
          (json['userId']?.toString().trim().isNotEmpty ?? false);
      final hasLogin = json['hasLogin'] == true || hasLinkedUser;

      final parsedStatus = InvitationStatus.values.firstWhere(
        (value) => value.name == json['invitationStatus'],
        orElse: () =>
            hasLogin ? InvitationStatus.active : InvitationStatus.notInvited,
      );

      return Employee(
        id: json['id'] ?? '',
        firstName: json['firstName'] ?? 'Unknown',
        lastName: json['lastName'] ?? '',
        email: json['email'] ?? '',
        phone: json['phone'] ?? '',
        department: json['department'] ?? 'Not Assigned',
        position: json['position'] ?? 'Not Assigned',
        basicSalary: (json['basicSalary'] ?? 0).toDouble(),
        payoutCurrency: _normalizeCurrencyCode(
          json['payoutCurrency']?.toString(),
        ),
        hireDate: readDate(json['hireDate']) ?? DateTime.now(),
        status: json['status'] ?? 'active',
        employmentType: EmploymentType.values.firstWhere(
          (value) => value.name == json['employmentType'],
          orElse: () => EmploymentType.permanent,
        ),
        probationEndDate: readDate(json['probationEndDate']),
        contractEndDate: readDate(json['contractEndDate']),
        isProbationConfirmed: json['isProbationConfirmed'] == true,
        bankName: json['bankName'],
        accountNumber: json['accountNumber'],
        hasLogin: hasLogin,
        userId: json['userId'],
        invitationStatus: parsedStatus,
        invitedAt: readDate(json['invitedAt']),
        lastInviteSentAt: readDate(json['lastInviteSentAt']),
        passwordChangedAt: readDate(json['passwordChangedAt']),
        lastLoginAt: readDate(json['lastLoginAt']),
        inviteAttempts: (json['inviteAttempts'] ?? 0) as int,
        inviteError: json['inviteError'],
        companyId: json['companyId'],
        isDeleted: json['isDeleted'] == true,
        deletedAt: readDate(json['deletedAt']),
        deletedBy: json['deletedBy'],
        deletionReason: json['deletionReason'],
      );
    } catch (e) {
      print('ERROR parsing employee: $e');
      print('JSON data: $json');
      rethrow;
    }
  }

  static Future<Employee> fromJsonEncrypted(Map<String, dynamic> json) async {
    final decrypted = await EncryptionService.decryptFields(
      json,
      sensitiveFields,
    );
    return Employee.fromJson(decrypted);
  }

  Employee copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? department,
    String? position,
    double? basicSalary,
    String? payoutCurrency,
    DateTime? hireDate,
    String? status,
    EmploymentType? employmentType,
    DateTime? probationEndDate,
    DateTime? contractEndDate,
    bool? isProbationConfirmed,
    String? bankName,
    String? accountNumber,
    bool? hasLogin,
    String? userId,
    InvitationStatus? invitationStatus,
    DateTime? invitedAt,
    DateTime? lastInviteSentAt,
    DateTime? passwordChangedAt,
    DateTime? lastLoginAt,
    int? inviteAttempts,
    String? inviteError,
    String? companyId,
    bool? isDeleted,
    DateTime? deletedAt,
    String? deletedBy,
    String? deletionReason,
  }) {
    return Employee(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      department: department ?? this.department,
      position: position ?? this.position,
      basicSalary: basicSalary ?? this.basicSalary,
      payoutCurrency: _normalizeCurrencyCode(
        payoutCurrency ?? this.payoutCurrency,
      ),
      hireDate: hireDate ?? this.hireDate,
      status: status ?? this.status,
      employmentType: employmentType ?? this.employmentType,
      probationEndDate: probationEndDate ?? this.probationEndDate,
      contractEndDate: contractEndDate ?? this.contractEndDate,
      isProbationConfirmed: isProbationConfirmed ?? this.isProbationConfirmed,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      hasLogin: hasLogin ?? this.hasLogin,
      userId: userId ?? this.userId,
      invitationStatus: invitationStatus ?? this.invitationStatus,
      invitedAt: invitedAt ?? this.invitedAt,
      lastInviteSentAt: lastInviteSentAt ?? this.lastInviteSentAt,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      inviteAttempts: inviteAttempts ?? this.inviteAttempts,
      inviteError: inviteError ?? this.inviteError,
      companyId: companyId ?? this.companyId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      deletionReason: deletionReason ?? this.deletionReason,
    );
  }

  static String _normalizeCurrencyCode(String? value) {
    final normalized = (value ?? 'NGN').trim().toUpperCase();
    switch (normalized) {
      case 'USD':
      case 'EUR':
      case 'GBP':
      case 'NGN':
        return normalized;
      default:
        return 'NGN';
    }
  }

  static String? _maskValue(
    String? value, {
    int visibleStart = 0,
    int visibleEnd = 0,
  }) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return value;
    if (normalized.length <= visibleStart + visibleEnd) {
      return '*' * normalized.length;
    }
    final start = visibleStart > 0 ? normalized.substring(0, visibleStart) : '';
    final end = visibleEnd > 0
        ? normalized.substring(normalized.length - visibleEnd)
        : '';
    final maskedLength = normalized.length - visibleStart - visibleEnd;
    return '$start${'*' * maskedLength}$end';
  }
}
