import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType {
  salary,
  salaryPayment,
  deductionPayment,
  reimbursement,
  incentive,
  paye,
  pension,
  nhf,
  loan,
  advance,
  deduction,
}

class PayrollTransaction {
  final String id;
  final String payrollId;
  final String payrollRunId;
  final String employeeId;
  final String employeeName;
  final TransactionType type;
  final String description;
  final String debitAccount;
  final String debitAccountName;
  final String creditAccount;
  final String creditAccountName;
  final double amount;
  final String currency;
  final double exchangeRate;
  final double amountBase;
  final int transactionMonth;
  final int transactionYear;
  final DateTime transactionDate;
  final DateTime createdAt;
  final bool isReversal;
  final Map<String, dynamic>? metadata;

  const PayrollTransaction({
    required this.id,
    required this.payrollId,
    required this.payrollRunId,
    required this.employeeId,
    required this.employeeName,
    required this.type,
    required this.description,
    required this.debitAccount,
    required this.debitAccountName,
    required this.creditAccount,
    required this.creditAccountName,
    required this.amount,
    required this.currency,
    required this.exchangeRate,
    required this.amountBase,
    required this.transactionMonth,
    required this.transactionYear,
    required this.transactionDate,
    required this.createdAt,
    this.isReversal = false,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payrollId': payrollId,
      'payrollRunId': payrollRunId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'type': type.name,
      'description': description,
      'debitAccount': debitAccount,
      'debitAccountName': debitAccountName,
      'creditAccount': creditAccount,
      'creditAccountName': creditAccountName,
      'amount': amount,
      'currency': currency,
      'exchangeRate': exchangeRate,
      'amountBase': amountBase,
      'transactionMonth': transactionMonth,
      'transactionYear': transactionYear,
      'transactionDate': Timestamp.fromDate(transactionDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'isReversal': isReversal,
      'metadata': metadata,
    };
  }

  factory PayrollTransaction.fromJson(Map<String, dynamic> json) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return PayrollTransaction(
      id: (json['id'] ?? '').toString(),
      payrollId: (json['payrollId'] ?? '').toString(),
      payrollRunId: (json['payrollRunId'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      type: TransactionType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => TransactionType.deduction,
      ),
      description: (json['description'] ?? '').toString(),
      debitAccount: (json['debitAccount'] ?? '').toString(),
      debitAccountName: (json['debitAccountName'] ?? '').toString(),
      creditAccount: (json['creditAccount'] ?? '').toString(),
      creditAccountName: (json['creditAccountName'] ?? '').toString(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'NGN').toString(),
      exchangeRate: (json['exchangeRate'] as num? ?? 1).toDouble(),
      amountBase: (json['amountBase'] as num? ?? 0).toDouble(),
      transactionMonth: (json['transactionMonth'] as num?)?.toInt() ?? 0,
      transactionYear: (json['transactionYear'] as num?)?.toInt() ?? 0,
      transactionDate: readDate(json['transactionDate']),
      createdAt: readDate(json['createdAt']),
      isReversal: json['isReversal'] == true,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }
}
