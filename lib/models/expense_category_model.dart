import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseCategory {
  final String id;
  final String name;
  final String description;
  final double? maxLimitPerClaim;
  final double? monthlyLimit;
  final bool requiresReceipt;
  final double? receiptThreshold;
  final bool requiresFinanceApproval;
  final double? financeApprovalThreshold;
  final bool isTaxable;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.description,
    this.maxLimitPerClaim,
    this.monthlyLimit,
    this.requiresReceipt = true,
    this.receiptThreshold,
    this.requiresFinanceApproval = false,
    this.financeApprovalThreshold,
    this.isTaxable = false,
    this.isActive = true,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'maxLimitPerClaim': maxLimitPerClaim,
      'monthlyLimit': monthlyLimit,
      'requiresReceipt': requiresReceipt,
      'receiptThreshold': receiptThreshold,
      'requiresFinanceApproval': requiresFinanceApproval,
      'financeApprovalThreshold': financeApprovalThreshold,
      'isTaxable': isTaxable,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      maxLimitPerClaim: json['maxLimitPerClaim']?.toDouble(),
      monthlyLimit: json['monthlyLimit']?.toDouble(),
      requiresReceipt: json['requiresReceipt'] ?? true,
      receiptThreshold: json['receiptThreshold']?.toDouble(),
      requiresFinanceApproval: json['requiresFinanceApproval'] ?? false,
      financeApprovalThreshold:
          json['financeApprovalThreshold']?.toDouble(),
      isTaxable: json['isTaxable'] ?? false,
      isActive: json['isActive'] ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] ?? '',
    );
  }
}
