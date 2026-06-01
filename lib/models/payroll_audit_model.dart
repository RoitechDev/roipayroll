import 'package:cloud_firestore/cloud_firestore.dart';

enum PayrollAuditAction {
  salaryUpdated,
  allowanceAdded,
  allowanceRemoved,
  deductionAdded,
  deductionRemoved,
  bonusAdded,
  payrollProcessed,
  payrollApproved,
  payrollRejected,
  overtimeAdded,
  loanDeducted,
  advanceDeducted,
}

/// Payroll Audit Trail for Compliance
class PayrollAuditLog {
  final String id;
  final String employeeId;
  final String employeeName;
  
  // Action Details
  final PayrollAuditAction action;
  final String description;
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  
  // User Info
  final String performedBy;
  final String performedByName;
  final String performedByRole;
  
  // Metadata
  final DateTime performedAt;
  final String? reason;
  final String? ipAddress;
  final String? deviceInfo;

  PayrollAuditLog({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.action,
    required this.description,
    required this.oldValues,
    required this.newValues,
    required this.performedBy,
    required this.performedByName,
    required this.performedByRole,
    DateTime? performedAt,
    this.reason,
    this.ipAddress,
    this.deviceInfo,
  }) : performedAt = performedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'action': action.name,
      'description': description,
      'oldValues': oldValues,
      'newValues': newValues,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'performedByRole': performedByRole,
      'performedAt': Timestamp.fromDate(performedAt),
      'reason': reason,
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
    };
  }

  factory PayrollAuditLog.fromJson(Map<String, dynamic> json) {
    return PayrollAuditLog(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      action: PayrollAuditAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => PayrollAuditAction.salaryUpdated,
      ),
      description: json['description'],
      oldValues: Map<String, dynamic>.from(json['oldValues'] ?? {}),
      newValues: Map<String, dynamic>.from(json['newValues'] ?? {}),
      performedBy: json['performedBy'],
      performedByName: json['performedByName'],
      performedByRole: json['performedByRole'],
      performedAt: (json['performedAt'] as Timestamp).toDate(),
      reason: json['reason'],
      ipAddress: json['ipAddress'],
      deviceInfo: json['deviceInfo'],
    );
  }
}

/// Payroll Approval Workflow for Compliance
enum PayrollApprovalStatus {
  pending,
  approved,
  rejected,
}

class PayrollApprovalRecord {
  final String id;
  final String payrollBatchId;
  final int month;
  final int year;
  
  // Approval Details
  final PayrollApprovalStatus status;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? rejectionReason;
  
  // Batch Summary
  final int totalEmployees;
  final double totalGrossPay;
  final double totalDeductions;
  final double totalNetPay;
  
  // Compliance Checks
  final bool taxCompliant;
  final bool laborLawCompliant;
  final bool minimumWageCompliant;
  final List<String> complianceViolations;
  
  // Metadata
  final DateTime createdAt;

  PayrollApprovalRecord({
    required this.id,
    required this.payrollBatchId,
    required this.month,
    required this.year,
    this.status = PayrollApprovalStatus.pending,
    this.approvedBy,
    this.approvedByName,
    this.approvedAt,
    this.rejectionReason,
    required this.totalEmployees,
    required this.totalGrossPay,
    required this.totalDeductions,
    required this.totalNetPay,
    this.taxCompliant = true,
    this.laborLawCompliant = true,
    this.minimumWageCompliant = true,
    this.complianceViolations = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompliant => complianceViolations.isEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payrollBatchId': payrollBatchId,
      'month': month,
      'year': year,
      'status': status.name,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'totalEmployees': totalEmployees,
      'totalGrossPay': totalGrossPay,
      'totalDeductions': totalDeductions,
      'totalNetPay': totalNetPay,
      'taxCompliant': taxCompliant,
      'laborLawCompliant': laborLawCompliant,
      'minimumWageCompliant': minimumWageCompliant,
      'complianceViolations': complianceViolations,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PayrollApprovalRecord.fromJson(Map<String, dynamic> json) {
    return PayrollApprovalRecord(
      id: json['id'],
      payrollBatchId: json['payrollBatchId'],
      month: json['month'],
      year: json['year'],
      status: PayrollApprovalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PayrollApprovalStatus.pending,
      ),
      approvedBy: json['approvedBy'],
      approvedByName: json['approvedByName'],
      approvedAt: json['approvedAt'] != null ? (json['approvedAt'] as Timestamp).toDate() : null,
      rejectionReason: json['rejectionReason'],
      totalEmployees: json['totalEmployees'],
      totalGrossPay: (json['totalGrossPay'] ?? 0).toDouble(),
      totalDeductions: (json['totalDeductions'] ?? 0).toDouble(),
      totalNetPay: (json['totalNetPay'] ?? 0).toDouble(),
      taxCompliant: json['taxCompliant'] ?? true,
      laborLawCompliant: json['laborLawCompliant'] ?? true,
      minimumWageCompliant: json['minimumWageCompliant'] ?? true,
      complianceViolations: List<String>.from(json['complianceViolations'] ?? []),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }
}
