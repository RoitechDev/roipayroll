import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseCategory { fuel, meals, travel, accommodation, utilities, other }

enum ExpenseStatus { pending, approved, rejected, paid }

class ExpenseClaim {
  final String id;
  final String employeeId;
  final String employeeName;
  final ExpenseCategory category;
  final double amount;
  final String description;
  final String? receiptUrl;
  final String? receiptName;
  final DateTime expenseDate;
  final DateTime submittedAt;
  final ExpenseStatus status;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approvedByName;
  final String? rejectionReason;
  final String? payrollId;
  final int? payrollMonth;
  final int? payrollYear;
  final DateTime? paidAt;
  final bool isTaxable;
  final String? categoryId;

  const ExpenseClaim({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.category,
    required this.amount,
    required this.description,
    this.receiptUrl,
    this.receiptName,
    required this.expenseDate,
    required this.submittedAt,
    this.status = ExpenseStatus.pending,
    this.approvedAt,
    this.approvedBy,
    this.approvedByName,
    this.rejectionReason,
    this.payrollId,
    this.payrollMonth,
    this.payrollYear,
    this.paidAt,
    this.isTaxable = false,
    this.categoryId,
  });

  bool get isPending => status == ExpenseStatus.pending;
  bool get isApproved => status == ExpenseStatus.approved;
  bool get isRejected => status == ExpenseStatus.rejected;
  bool get isPaid => status == ExpenseStatus.paid;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'category': category.name,
      'amount': amount,
      'description': description,
      'receiptUrl': receiptUrl,
      'receiptName': receiptName,
      'expenseDate': Timestamp.fromDate(expenseDate),
      'submittedAt': Timestamp.fromDate(submittedAt),
      'status': status.name,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'rejectionReason': rejectionReason,
      'payrollId': payrollId,
      'payrollMonth': payrollMonth,
      'payrollYear': payrollYear,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'isTaxable': isTaxable,
      'categoryId': categoryId,
    };
  }

  factory ExpenseClaim.fromJson(Map<String, dynamic> json) {
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

    return ExpenseClaim(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ExpenseCategory.other,
      ),
      amount: (json['amount'] ?? 0).toDouble(),
      description: (json['description'] ?? '').toString(),
      receiptUrl: json['receiptUrl']?.toString(),
      receiptName: json['receiptName']?.toString(),
      expenseDate: parseDate(json['expenseDate']),
      submittedAt: parseDate(json['submittedAt']),
      status: ExpenseStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExpenseStatus.pending,
      ),
      approvedAt: parseNullableDate(json['approvedAt']),
      approvedBy: json['approvedBy']?.toString(),
      approvedByName: json['approvedByName']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      payrollId: json['payrollId']?.toString(),
      payrollMonth: parseNullableInt(json['payrollMonth']),
      payrollYear: parseNullableInt(json['payrollYear']),
      paidAt: parseNullableDate(json['paidAt']),
      isTaxable: json['isTaxable'] ?? false,
      categoryId: json['categoryId']?.toString(),
    );
  }

  ExpenseClaim copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    ExpenseCategory? category,
    double? amount,
    String? description,
    String? receiptUrl,
    String? receiptName,
    DateTime? expenseDate,
    DateTime? submittedAt,
    ExpenseStatus? status,
    DateTime? approvedAt,
    String? approvedBy,
    String? approvedByName,
    String? rejectionReason,
    String? payrollId,
    int? payrollMonth,
    int? payrollYear,
    DateTime? paidAt,
    bool? isTaxable,
    String? categoryId,
  }) {
    return ExpenseClaim(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      receiptName: receiptName ?? this.receiptName,
      expenseDate: expenseDate ?? this.expenseDate,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      payrollId: payrollId ?? this.payrollId,
      payrollMonth: payrollMonth ?? this.payrollMonth,
      payrollYear: payrollYear ?? this.payrollYear,
      paidAt: paidAt ?? this.paidAt,
      isTaxable: isTaxable ?? this.isTaxable,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
