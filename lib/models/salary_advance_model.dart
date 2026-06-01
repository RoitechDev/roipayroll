import 'package:cloud_firestore/cloud_firestore.dart';

enum SalaryAdvanceStatus { pending, approved, rejected, recovered, cancelled }

class SalaryAdvance {
  final String id;
  final String employeeId;
  final String employeeName;
  final double amount;
  final double maxAllowed;
  final DateTime requestDate;
  final SalaryAdvanceStatus status;
  final String reason;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? rejectedAt;
  final String? rejectedBy;
  final String? rejectedByName;
  final String? rejectionReason;
  final String? payrollId;
  final int? payrollMonth;
  final int? payrollYear;
  final DateTime? recoveredAt;
  final int version;

  const SalaryAdvance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.maxAllowed,
    required this.requestDate,
    this.status = SalaryAdvanceStatus.pending,
    required this.reason,
    this.approvedAt,
    this.approvedBy,
    this.approvedByName,
    this.rejectedAt,
    this.rejectedBy,
    this.rejectedByName,
    this.rejectionReason,
    this.payrollId,
    this.payrollMonth,
    this.payrollYear,
    this.recoveredAt,
    this.version = 1,
  });

  bool get isPending => status == SalaryAdvanceStatus.pending;
  bool get isApproved => status == SalaryAdvanceStatus.approved;
  bool get isRejected => status == SalaryAdvanceStatus.rejected;
  bool get isRecovered => status == SalaryAdvanceStatus.recovered;
  bool get isCancelled => status == SalaryAdvanceStatus.cancelled;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'amount': amount,
      'maxAllowed': maxAllowed,
      'requestDate': Timestamp.fromDate(requestDate),
      'status': status.name,
      'reason': reason,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'rejectedAt': rejectedAt != null ? Timestamp.fromDate(rejectedAt!) : null,
      'rejectedBy': rejectedBy,
      'rejectedByName': rejectedByName,
      'rejectionReason': rejectionReason,
      'payrollId': payrollId,
      'payrollMonth': payrollMonth,
      'payrollYear': payrollYear,
      'recoveredAt': recoveredAt != null
          ? Timestamp.fromDate(recoveredAt!)
          : null,
      'version': version,
    };
  }

  factory SalaryAdvance.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    int? parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    return SalaryAdvance(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      amount: (json['amount'] ?? 0).toDouble(),
      maxAllowed: (json['maxAllowed'] ?? 0).toDouble(),
      requestDate: parseDate(json['requestDate']),
      status: SalaryAdvanceStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => SalaryAdvanceStatus.pending,
      ),
      reason: (json['reason'] ?? '').toString(),
      approvedAt: parseNullableDate(json['approvedAt']),
      approvedBy: json['approvedBy']?.toString(),
      approvedByName: json['approvedByName']?.toString(),
      rejectedAt: parseNullableDate(json['rejectedAt']),
      rejectedBy: json['rejectedBy']?.toString(),
      rejectedByName: json['rejectedByName']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      payrollId: json['payrollId']?.toString(),
      payrollMonth: parseNullableInt(json['payrollMonth']),
      payrollYear: parseNullableInt(json['payrollYear']),
      recoveredAt: parseNullableDate(json['recoveredAt']),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  SalaryAdvance copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    double? amount,
    double? maxAllowed,
    DateTime? requestDate,
    SalaryAdvanceStatus? status,
    String? reason,
    DateTime? approvedAt,
    String? approvedBy,
    String? approvedByName,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectedByName,
    String? rejectionReason,
    String? payrollId,
    int? payrollMonth,
    int? payrollYear,
    DateTime? recoveredAt,
    int? version,
  }) {
    return SalaryAdvance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      amount: amount ?? this.amount,
      maxAllowed: maxAllowed ?? this.maxAllowed,
      requestDate: requestDate ?? this.requestDate,
      status: status ?? this.status,
      reason: reason ?? this.reason,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedByName: rejectedByName ?? this.rejectedByName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      payrollId: payrollId ?? this.payrollId,
      payrollMonth: payrollMonth ?? this.payrollMonth,
      payrollYear: payrollYear ?? this.payrollYear,
      recoveredAt: recoveredAt ?? this.recoveredAt,
      version: version ?? this.version,
    );
  }
}
