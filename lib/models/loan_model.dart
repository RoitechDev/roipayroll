import 'package:cloud_firestore/cloud_firestore.dart';

enum LoanStatus { pending, approved, rejected, active, completed }

enum LoanRiskLevel { low, medium, high }

class LoanRiskAssessment {
  final LoanRiskLevel level;
  final String label;
  final String reason;
  final double salaryRatio;
  final int activeLoanCount;

  const LoanRiskAssessment({
    required this.level,
    required this.label,
    required this.reason,
    required this.salaryRatio,
    required this.activeLoanCount,
  });
}

class Loan {
  final String id;
  final String employeeId;
  final String employeeName;
  final double amount;
  final int durationMonths;
  final double monthlyDeduction;
  final double totalRepaid;
  final LoanStatus status;
  final String reason;
  final DateTime requestDate;
  final DateTime? approvalDate;
  final String? approvedBy;
  final String? rejectionReason;
  final int version;

  Loan({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.durationMonths,
    required this.monthlyDeduction,
    this.totalRepaid = 0,
    required this.status,
    required this.reason,
    required this.requestDate,
    this.approvalDate,
    this.approvedBy,
    this.rejectionReason,
    this.version = 1,
  });

  double get remainingBalance => amount - totalRepaid;
  bool get isFullyPaid => totalRepaid >= amount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'amount': amount,
      'durationMonths': durationMonths,
      'monthlyDeduction': monthlyDeduction,
      'totalRepaid': totalRepaid,
      'status': status.name,
      'reason': reason,
      'requestDate': Timestamp.fromDate(requestDate),
      'approvalDate': approvalDate != null
          ? Timestamp.fromDate(approvalDate!)
          : null,
      'approvedBy': approvedBy,
      'rejectionReason': rejectionReason,
      'version': version,
    };
  }

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      amount: (json['amount'] ?? 0).toDouble(),
      durationMonths: json['durationMonths'] ?? 0,
      monthlyDeduction: (json['monthlyDeduction'] ?? 0).toDouble(),
      totalRepaid: (json['totalRepaid'] ?? 0).toDouble(),
      status: LoanStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LoanStatus.pending,
      ),
      reason: json['reason'] ?? '',
      requestDate: (json['requestDate'] as Timestamp).toDate(),
      approvalDate: json['approvalDate'] != null
          ? (json['approvalDate'] as Timestamp).toDate()
          : null,
      approvedBy: json['approvedBy'],
      rejectionReason: json['rejectionReason'],
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }

  Loan copyWith({
    double? totalRepaid,
    LoanStatus? status,
    DateTime? approvalDate,
    String? approvedBy,
    String? rejectionReason,
    int? version,
  }) {
    return Loan(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      amount: amount,
      durationMonths: durationMonths,
      monthlyDeduction: monthlyDeduction,
      totalRepaid: totalRepaid ?? this.totalRepaid,
      status: status ?? this.status,
      reason: reason,
      requestDate: requestDate,
      approvalDate: approvalDate ?? this.approvalDate,
      approvedBy: approvedBy ?? this.approvedBy,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      version: version ?? this.version,
    );
  }
}
