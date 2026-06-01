import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_type_model.dart';

class DeductionTransaction {
  final String id;
  final String payrollId;
  final int payrollMonth;
  final int payrollYear;
  final String employeeId;
  final String employeeName;
  final String employeeDeductionId;
  final String deductionTypeId;
  final String deductionTypeName;
  final DeductionCategory category;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final DateTime processedAt;
  final String? processedBy;
  final bool isStatutory;
  final Map<String, dynamic>? metadata;

  DeductionTransaction({
    required this.id,
    required this.payrollId,
    required this.payrollMonth,
    required this.payrollYear,
    required this.employeeId,
    required this.employeeName,
    required this.employeeDeductionId,
    required this.deductionTypeId,
    required this.deductionTypeName,
    required this.category,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.processedAt,
    this.processedBy,
    this.isStatutory = false,
    this.metadata,
  });

  factory DeductionTransaction.fromJson(Map<String, dynamic> json) {
    DateTime readDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.now();
    }

    return DeductionTransaction(
      id: json['id'] ?? '',
      payrollId: json['payrollId'] ?? '',
      payrollMonth: json['payrollMonth'] ?? 0,
      payrollYear: json['payrollYear'] ?? 0,
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      employeeDeductionId: json['employeeDeductionId'] ?? '',
      deductionTypeId: json['deductionTypeId'] ?? '',
      deductionTypeName: json['deductionTypeName'] ?? '',
      category: DeductionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => DeductionCategory.other,
      ),
      amount: (json['amount'] ?? 0).toDouble(),
      balanceBefore: (json['balanceBefore'] ?? 0).toDouble(),
      balanceAfter: (json['balanceAfter'] ?? 0).toDouble(),
      processedAt: readDate(json['processedAt']),
      processedBy: json['processedBy'],
      isStatutory: json['isStatutory'] ?? false,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payrollId': payrollId,
      'payrollMonth': payrollMonth,
      'payrollYear': payrollYear,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeDeductionId': employeeDeductionId,
      'deductionTypeId': deductionTypeId,
      'deductionTypeName': deductionTypeName,
      'category': category.name,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'processedAt': Timestamp.fromDate(processedAt),
      'processedBy': processedBy,
      'isStatutory': isStatutory,
      'metadata': metadata,
    };
  }
}
