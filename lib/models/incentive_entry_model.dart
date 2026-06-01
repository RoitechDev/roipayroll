import 'package:cloud_firestore/cloud_firestore.dart';

enum IncentiveType { commission, bonus }

enum IncentiveStatus { pending, approved, rejected, paid }

enum BonusCategory {
  performance,
  project,
  referral,
  retention,
  annual,
  holiday,
  spot,
  signing,
  other,
}

class IncentiveEntry {
  final String id;
  final String employeeId;
  final String employeeName;
  final IncentiveType type;
  final double amount;
  final String description;
  final DateTime incentiveDate;
  final DateTime submittedAt;
  final IncentiveStatus status;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approvedByName;
  final String? rejectionReason;
  final String? payrollId;
  final int? payrollMonth;
  final int? payrollYear;
  final DateTime? paidAt;
  final double? salesAmount;
  final double? commissionRatePercent;
  final String? tierName;
  final String? performancePeriod;
  final BonusCategory? bonusCategory;
  final String? bonusTemplateId;
  final bool isTaxable;

  const IncentiveEntry({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.amount,
    required this.description,
    required this.incentiveDate,
    required this.submittedAt,
    this.status = IncentiveStatus.pending,
    this.approvedAt,
    this.approvedBy,
    this.approvedByName,
    this.rejectionReason,
    this.payrollId,
    this.payrollMonth,
    this.payrollYear,
    this.paidAt,
    this.salesAmount,
    this.commissionRatePercent,
    this.tierName,
    this.performancePeriod,
    this.bonusCategory,
    this.bonusTemplateId,
    this.isTaxable = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'type': type.name,
      'amount': amount,
      'description': description,
      'incentiveDate': Timestamp.fromDate(incentiveDate),
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
      'salesAmount': salesAmount,
      'commissionRatePercent': commissionRatePercent,
      'tierName': tierName,
      'performancePeriod': performancePeriod,
      'bonusCategory': bonusCategory?.name,
      'bonusTemplateId': bonusTemplateId,
      'isTaxable': isTaxable,
    };
  }

  factory IncentiveEntry.fromJson(Map<String, dynamic> json) {
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

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return IncentiveEntry(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      type: IncentiveType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => IncentiveType.bonus,
      ),
      amount: (json['amount'] ?? 0).toDouble(),
      description: (json['description'] ?? '').toString(),
      incentiveDate: parseDate(json['incentiveDate']),
      submittedAt: parseDate(json['submittedAt']),
      status: IncentiveStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => IncentiveStatus.pending,
      ),
      approvedAt: parseNullableDate(json['approvedAt']),
      approvedBy: json['approvedBy']?.toString(),
      approvedByName: json['approvedByName']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      payrollId: json['payrollId']?.toString(),
      payrollMonth: parseNullableInt(json['payrollMonth']),
      payrollYear: parseNullableInt(json['payrollYear']),
      paidAt: parseNullableDate(json['paidAt']),
      salesAmount: parseNullableDouble(json['salesAmount']),
      commissionRatePercent: parseNullableDouble(json['commissionRatePercent']),
      tierName: json['tierName']?.toString(),
      performancePeriod: json['performancePeriod']?.toString(),
      bonusCategory: json['bonusCategory'] != null
          ? BonusCategory.values.firstWhere(
              (e) => e.name == json['bonusCategory'],
              orElse: () => BonusCategory.other,
            )
          : null,
      bonusTemplateId: json['bonusTemplateId']?.toString(),
      isTaxable: json['isTaxable'] ?? true,
    );
  }
}
