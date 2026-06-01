import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_type_model.dart';

enum DeductionStatus { active, completed, suspended, cancelled, pending }

enum DeductionFrequency { oneTime, monthly, biweekly, weekly, custom }

class EmployeeDeduction {
  final String id;
  final String employeeId;
  final String employeeName;
  final String deductionTypeId;
  final String deductionTypeName;
  final DeductionCategory category;
  final DeductionCalculationMethod calculationMethod;
  final DeductionFrequency frequency;
  final DeductionStatus status;
  final double totalAmount;
  final double amountPerPayroll;
  final double totalDeducted;
  final double percentageRate;
  final int? totalInstallments;
  final int installmentsPaid;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextDeductionDate;
  final bool requiresApproval;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? notes;
  final String? referenceNumber;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeDeduction({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.deductionTypeId,
    required this.deductionTypeName,
    required this.category,
    required this.calculationMethod,
    required this.frequency,
    this.status = DeductionStatus.pending,
    required this.totalAmount,
    required this.amountPerPayroll,
    this.totalDeducted = 0,
    this.percentageRate = 0,
    this.totalInstallments,
    this.installmentsPaid = 0,
    required this.startDate,
    this.endDate,
    this.nextDeductionDate,
    this.requiresApproval = false,
    this.approvedBy,
    this.approvedAt,
    this.notes,
    this.referenceNumber,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  double get balance {
    final value = totalAmount - totalDeducted;
    return value < 0 ? 0 : value;
  }

  // Backward-compatibility alias used by service code/legacy docs.
  double get amountDeducted => totalDeducted;

  bool get isCompleted => status == DeductionStatus.completed || balance <= 0;

  factory EmployeeDeduction.fromJson(Map<String, dynamic> json) {
    DateTime? readNullableDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return null;
    }

    DateTime readDate(dynamic raw) {
      return readNullableDate(raw) ?? DateTime.now();
    }

    return EmployeeDeduction(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      employeeName: json['employeeName'] ?? '',
      deductionTypeId: json['deductionTypeId'] ?? '',
      deductionTypeName: json['deductionTypeName'] ?? '',
      category: DeductionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => DeductionCategory.other,
      ),
      calculationMethod: DeductionCalculationMethod.values.firstWhere(
        (e) => e.name == json['calculationMethod'],
        orElse: () => DeductionCalculationMethod.fixedAmount,
      ),
      frequency: DeductionFrequency.values.firstWhere(
        (e) => e.name == json['frequency'],
        orElse: () => DeductionFrequency.monthly,
      ),
      status: DeductionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DeductionStatus.pending,
      ),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      amountPerPayroll: (json['amountPerPayroll'] ?? 0).toDouble(),
      totalDeducted: (json['totalDeducted'] ?? json['amountDeducted'] ?? 0)
          .toDouble(),
      percentageRate: (json['percentageRate'] ?? 0).toDouble(),
      totalInstallments: json['totalInstallments'],
      installmentsPaid: json['installmentsPaid'] ?? 0,
      startDate: readDate(json['startDate']),
      endDate: readNullableDate(json['endDate']),
      nextDeductionDate: readNullableDate(json['nextDeductionDate']),
      requiresApproval: json['requiresApproval'] ?? false,
      approvedBy: json['approvedBy'],
      approvedAt: readNullableDate(json['approvedAt']),
      notes: json['notes'],
      referenceNumber: json['referenceNumber'],
      description: json['description'],
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'deductionTypeId': deductionTypeId,
      'deductionTypeName': deductionTypeName,
      'category': category.name,
      'calculationMethod': calculationMethod.name,
      'frequency': frequency.name,
      'status': status.name,
      'totalAmount': totalAmount,
      'amountPerPayroll': amountPerPayroll,
      'totalDeducted': totalDeducted,
      'amountDeducted': totalDeducted,
      'balance': balance,
      'percentageRate': percentageRate,
      'totalInstallments': totalInstallments,
      'installmentsPaid': installmentsPaid,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'nextDeductionDate': nextDeductionDate != null
          ? Timestamp.fromDate(nextDeductionDate!)
          : null,
      'requiresApproval': requiresApproval,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'notes': notes,
      'referenceNumber': referenceNumber,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  EmployeeDeduction copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? deductionTypeId,
    String? deductionTypeName,
    DeductionCategory? category,
    DeductionCalculationMethod? calculationMethod,
    DeductionFrequency? frequency,
    DeductionStatus? status,
    double? totalAmount,
    double? amountPerPayroll,
    double? totalDeducted,
    double? percentageRate,
    int? totalInstallments,
    int? installmentsPaid,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextDeductionDate,
    bool? requiresApproval,
    String? approvedBy,
    DateTime? approvedAt,
    String? notes,
    String? referenceNumber,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeDeduction(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      deductionTypeId: deductionTypeId ?? this.deductionTypeId,
      deductionTypeName: deductionTypeName ?? this.deductionTypeName,
      category: category ?? this.category,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      frequency: frequency ?? this.frequency,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      amountPerPayroll: amountPerPayroll ?? this.amountPerPayroll,
      totalDeducted: totalDeducted ?? this.totalDeducted,
      percentageRate: percentageRate ?? this.percentageRate,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      installmentsPaid: installmentsPaid ?? this.installmentsPaid,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextDeductionDate: nextDeductionDate ?? this.nextDeductionDate,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      notes: notes ?? this.notes,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
