import 'package:cloud_firestore/cloud_firestore.dart';

enum EmployeeDocumentType {
  // Employment Documents
  contract,
  contractRenewal,
  probationEvaluation,
  promotionLetter,
  transferLetter,
  terminationLetter,
  offerLetter,
  joiningReport,

  // Personal Documents
  idCard,
  passport,
  driverLicense,
  birthCertificate,

  // Financial Documents
  bankDetails,
  taxForm,
  pensionForm,

  // Payroll Generated Documents
  payslip,
  payrollReport,
  bonusLetter,
  salaryAdjustmentLetter,

  // Qualification Documents
  resume,
  certificate,
  degree,
  transcript,

  // Compliance Documents
  workPermit,
  visa,
  healthInsurance,
  backgroundCheck,
  referenceLetter,

  // Exit Documents
  resignationLetter,
  exitClearance,

  // Other
  license,
  compliance,
  other,
}

enum DocumentVisibility {
  public,
  employeeOnly,
  hrOnly,
  accountantOnly,
  adminOnly,
}

class EmployeeDocument {
  final String id;
  final String employeeId;
  final String employeeName;
  final String title;
  final EmployeeDocumentType type;
  final String? fileUrl;
  final String? fileName;
  final DateTime? issuedDate;
  final DateTime? expiryDate;
  final DateTime uploadedAt;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime? lastReminderSentAt;
  final DocumentVisibility visibility;
  final bool isSystemGenerated;
  final String? relatedRecordId;
  final String? relatedRecordType;

  const EmployeeDocument({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.title,
    required this.type,
    this.fileUrl,
    this.fileName,
    this.issuedDate,
    this.expiryDate,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.uploadedByName,
    this.lastReminderSentAt,
    this.visibility = DocumentVisibility.public,
    this.isSystemGenerated = false,
    this.relatedRecordId,
    this.relatedRecordType,
  });

  bool get hasExpiry => expiryDate != null;

  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return expiryDate!.isBefore(endOfDay);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'title': title,
      'type': type.name,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'issuedDate': issuedDate != null ? Timestamp.fromDate(issuedDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'lastReminderSentAt': lastReminderSentAt != null
          ? Timestamp.fromDate(lastReminderSentAt!)
          : null,
      'visibility': visibility.name,
      'isSystemGenerated': isSystemGenerated,
      'relatedRecordId': relatedRecordId,
      'relatedRecordType': relatedRecordType,
    };
  }

  factory EmployeeDocument.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return EmployeeDocument(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      type: EmployeeDocumentType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => EmployeeDocumentType.other,
      ),
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      issuedDate: parseNullableDate(json['issuedDate']),
      expiryDate: parseNullableDate(json['expiryDate']),
      uploadedAt: parseDate(json['uploadedAt']),
      uploadedBy: (json['uploadedBy'] ?? '').toString(),
      uploadedByName: (json['uploadedByName'] ?? '').toString(),
      lastReminderSentAt: parseNullableDate(json['lastReminderSentAt']),
      visibility: DocumentVisibility.values.firstWhere(
        (v) => v.name == json['visibility'],
        orElse: () => DocumentVisibility.public,
      ),
      isSystemGenerated: json['isSystemGenerated'] ?? false,
      relatedRecordId: json['relatedRecordId']?.toString(),
      relatedRecordType: json['relatedRecordType']?.toString(),
    );
  }
}
