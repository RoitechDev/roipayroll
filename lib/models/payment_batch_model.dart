import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentBatchStatus {
  pending,
  processing,
  completed,
  failed,
  partiallyCompleted,
}

enum PaymentStatus { pending, processing, completed, failed, reversed }

class PaymentBatch {
  final String id;
  final String payrollRunId;
  final int month;
  final int year;
  final int totalEmployees;
  final double totalAmount;
  final String currency;
  final PaymentBatchStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? gatewayReference;
  final String? gatewayProvider;
  final Map<String, dynamic>? metadata;

  const PaymentBatch({
    required this.id,
    required this.payrollRunId,
    required this.month,
    required this.year,
    required this.totalEmployees,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.gatewayReference,
    this.gatewayProvider,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payrollRunId': payrollRunId,
      'month': month,
      'year': year,
      'totalEmployees': totalEmployees,
      'totalAmount': totalAmount,
      'currency': currency,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt == null
          ? null
          : Timestamp.fromDate(processedAt!),
      'gatewayReference': gatewayReference,
      'gatewayProvider': gatewayProvider,
      'metadata': metadata,
    };
  }

  factory PaymentBatch.fromJson(Map<String, dynamic> json) {
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

    return PaymentBatch(
      id: (json['id'] ?? '').toString(),
      payrollRunId: (json['payrollRunId'] ?? '').toString(),
      month: (json['month'] as num? ?? 0).toInt(),
      year: (json['year'] as num? ?? 0).toInt(),
      totalEmployees: (json['totalEmployees'] as num? ?? 0).toInt(),
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'NGN').toString(),
      status: PaymentBatchStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => PaymentBatchStatus.pending,
      ),
      createdAt: parseDate(json['createdAt']),
      processedAt: parseNullableDate(json['processedAt']),
      gatewayReference: json['gatewayReference']?.toString(),
      gatewayProvider: json['gatewayProvider']?.toString(),
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  PaymentBatch copyWith({
    String? id,
    String? payrollRunId,
    int? month,
    int? year,
    int? totalEmployees,
    double? totalAmount,
    String? currency,
    PaymentBatchStatus? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? gatewayReference,
    String? gatewayProvider,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentBatch(
      id: id ?? this.id,
      payrollRunId: payrollRunId ?? this.payrollRunId,
      month: month ?? this.month,
      year: year ?? this.year,
      totalEmployees: totalEmployees ?? this.totalEmployees,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      gatewayReference: gatewayReference ?? this.gatewayReference,
      gatewayProvider: gatewayProvider ?? this.gatewayProvider,
      metadata: metadata ?? this.metadata,
    );
  }
}

class EmployeePayment {
  final String id;
  final String paymentBatchId;
  final String payrollId;
  final String employeeId;
  final String employeeName;
  final double amount;
  final String currency;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? gatewayReference;
  final String? failureReason;

  const EmployeePayment({
    required this.id,
    required this.paymentBatchId,
    required this.payrollId,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.currency,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.gatewayReference,
    this.failureReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentBatchId': paymentBatchId,
      'payrollId': payrollId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'amount': amount,
      'currency': currency,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'gatewayReference': gatewayReference,
      'failureReason': failureReason,
    };
  }

  factory EmployeePayment.fromJson(Map<String, dynamic> json) {
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

    return EmployeePayment(
      id: (json['id'] ?? '').toString(),
      paymentBatchId: (json['paymentBatchId'] ?? '').toString(),
      payrollId: (json['payrollId'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'NGN').toString(),
      bankName: (json['bankName'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      accountName: (json['accountName'] ?? '').toString(),
      status: PaymentStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      createdAt: parseDate(json['createdAt']),
      completedAt: parseNullableDate(json['completedAt']),
      gatewayReference: json['gatewayReference']?.toString(),
      failureReason: json['failureReason']?.toString(),
    );
  }

  EmployeePayment copyWith({
    String? id,
    String? paymentBatchId,
    String? payrollId,
    String? employeeId,
    String? employeeName,
    double? amount,
    String? currency,
    String? bankName,
    String? accountNumber,
    String? accountName,
    PaymentStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? gatewayReference,
    String? failureReason,
  }) {
    return EmployeePayment(
      id: id ?? this.id,
      paymentBatchId: paymentBatchId ?? this.paymentBatchId,
      payrollId: payrollId ?? this.payrollId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      gatewayReference: gatewayReference ?? this.gatewayReference,
      failureReason: failureReason ?? this.failureReason,
    );
  }
}
