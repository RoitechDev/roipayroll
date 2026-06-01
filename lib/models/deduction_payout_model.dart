import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_type_model.dart';

enum DeductionPayoutBatchStatus {
  pending,
  processing,
  completed,
  failed,
  partiallyCompleted,
}

enum DeductionPayoutStatus {
  pending,
  processing,
  completed,
  failed,
  partiallyCompleted,
}

enum DeductionPayoutItemStatus {
  pending,
  processing,
  completed,
  failed,
  reversed,
}

enum DeductionPayoutType { paye, pension, nhf, loan, advance, other }

DateTime _readDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

DateTime? _readNullableDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class PayoutRecipientConfig {
  final String id;
  final String key;
  final String name;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String? bankCode;
  final List<String> aliases;
  final bool isActive;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PayoutRecipientConfig({
    required this.id,
    required this.key,
    required this.name,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.bankCode,
    this.aliases = const <String>[],
    this.isActive = true,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PayoutRecipientConfig.fromJson(Map<String, dynamic> json) {
    return PayoutRecipientConfig(
      id: (json['id'] ?? '').toString(),
      key: (json['key'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      bankName: (json['bankName'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      accountName: (json['accountName'] ?? '').toString(),
      bankCode: json['bankCode']?.toString(),
      aliases: (json['aliases'] as List<dynamic>? ?? const <dynamic>[])
          .map((alias) => alias.toString())
          .toList(),
      isActive: json['isActive'] != false,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
      createdAt: _readDate(json['createdAt']),
      updatedAt: _readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'name': name,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'bankCode': bankCode,
      'aliases': aliases,
      'isActive': isActive,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  PayoutRecipientConfig copyWith({
    String? id,
    String? key,
    String? name,
    String? bankName,
    String? accountNumber,
    String? accountName,
    String? bankCode,
    List<String>? aliases,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PayoutRecipientConfig(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountName: accountName ?? this.accountName,
      bankCode: bankCode ?? this.bankCode,
      aliases: aliases ?? this.aliases,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class DeductionPayoutBatch {
  final String id;
  final String payrollRunId;
  final int month;
  final int year;
  final String currency;
  final int totalPayouts;
  final double totalAmount;
  final DeductionPayoutBatchStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? gatewayProvider;
  final String? gatewayReference;
  final Map<String, dynamic>? metadata;

  const DeductionPayoutBatch({
    required this.id,
    required this.payrollRunId,
    required this.month,
    required this.year,
    required this.currency,
    required this.totalPayouts,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.gatewayProvider,
    this.gatewayReference,
    this.metadata,
  });

  factory DeductionPayoutBatch.fromJson(Map<String, dynamic> json) {
    return DeductionPayoutBatch(
      id: (json['id'] ?? '').toString(),
      payrollRunId: (json['payrollRunId'] ?? '').toString(),
      month: (json['month'] as num? ?? 0).toInt(),
      year: (json['year'] as num? ?? 0).toInt(),
      currency: (json['currency'] ?? 'NGN').toString(),
      totalPayouts: (json['totalPayouts'] as num? ?? 0).toInt(),
      totalAmount: (json['totalAmount'] as num? ?? 0).toDouble(),
      status: DeductionPayoutBatchStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => DeductionPayoutBatchStatus.pending,
      ),
      createdAt: _readDate(json['createdAt']),
      processedAt: _readNullableDate(json['processedAt']),
      gatewayProvider: json['gatewayProvider']?.toString(),
      gatewayReference: json['gatewayReference']?.toString(),
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payrollRunId': payrollRunId,
      'month': month,
      'year': year,
      'currency': currency,
      'totalPayouts': totalPayouts,
      'totalAmount': totalAmount,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'processedAt': processedAt == null
          ? null
          : Timestamp.fromDate(processedAt!),
      'gatewayProvider': gatewayProvider,
      'gatewayReference': gatewayReference,
      'metadata': metadata,
    };
  }
}

class DeductionPayout {
  final String id;
  final String payoutBatchId;
  final String payrollRunId;
  final DeductionPayoutType type;
  final String payeeName;
  final String payeeAccountNumber;
  final String payeeBankCode;
  final String payeeBankName;
  final double amount;
  final String currency;
  final DeductionPayoutStatus status;
  final String? gatewayReference;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  const DeductionPayout({
    required this.id,
    required this.payoutBatchId,
    required this.payrollRunId,
    required this.type,
    required this.payeeName,
    required this.payeeAccountNumber,
    required this.payeeBankCode,
    required this.payeeBankName,
    required this.amount,
    required this.currency,
    required this.status,
    this.gatewayReference,
    this.failureReason,
    required this.createdAt,
    this.completedAt,
    this.metadata,
  });

  factory DeductionPayout.fromJson(Map<String, dynamic> json) {
    return DeductionPayout(
      id: (json['id'] ?? '').toString(),
      payoutBatchId: (json['payoutBatchId'] ?? '').toString(),
      payrollRunId: (json['payrollRunId'] ?? '').toString(),
      type: DeductionPayoutType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => DeductionPayoutType.other,
      ),
      payeeName: (json['payeeName'] ?? '').toString(),
      payeeAccountNumber: (json['payeeAccountNumber'] ?? '').toString(),
      payeeBankCode: (json['payeeBankCode'] ?? '').toString(),
      payeeBankName: (json['payeeBankName'] ?? '').toString(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'NGN').toString(),
      status: DeductionPayoutStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => DeductionPayoutStatus.pending,
      ),
      gatewayReference: json['gatewayReference']?.toString(),
      failureReason: json['failureReason']?.toString(),
      createdAt: _readDate(json['createdAt']),
      completedAt: _readNullableDate(json['completedAt']),
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  factory DeductionPayout.fromItem(DeductionPayoutItem item) {
    return DeductionPayout(
      id: item.id,
      payoutBatchId: item.batchId,
      payrollRunId: item.payrollRunId,
      type: item.payoutType,
      payeeName: item.recipientName,
      payeeAccountNumber: item.accountNumber,
      payeeBankCode: item.bankCode ?? '',
      payeeBankName: item.bankName,
      amount: item.amount,
      currency: item.currency,
      status: _compatStatusFromItemStatus(item.status),
      gatewayReference: item.gatewayReference,
      failureReason: item.failureReason,
      createdAt: item.createdAt,
      completedAt: item.completedAt,
      metadata: item.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'payoutBatchId': payoutBatchId,
      'payrollRunId': payrollRunId,
      'type': type.name,
      'payeeName': payeeName,
      'payeeAccountNumber': payeeAccountNumber,
      'payeeBankCode': payeeBankCode,
      'payeeBankName': payeeBankName,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'gatewayReference': gatewayReference,
      'failureReason': failureReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'metadata': metadata,
    };
  }
}

class DeductionPayoutItem {
  final String id;
  final String batchId;
  final String payrollRunId;
  final String payoutKey;
  final String? recipientId;
  final String recipientName;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String? bankCode;
  final DeductionPayoutType payoutType;
  final DeductionCategory category;
  final double amount;
  final String currency;
  final int sourceCount;
  final DeductionPayoutItemStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? gatewayReference;
  final String? failureReason;
  final Map<String, dynamic>? metadata;

  const DeductionPayoutItem({
    required this.id,
    required this.batchId,
    required this.payrollRunId,
    required this.payoutKey,
    required this.recipientName,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.payoutType,
    required this.category,
    required this.amount,
    required this.currency,
    required this.sourceCount,
    required this.status,
    required this.createdAt,
    this.recipientId,
    this.bankCode,
    this.completedAt,
    this.gatewayReference,
    this.failureReason,
    this.metadata,
  });

  factory DeductionPayoutItem.fromJson(Map<String, dynamic> json) {
    return DeductionPayoutItem(
      id: (json['id'] ?? '').toString(),
      batchId: (json['batchId'] ?? '').toString(),
      payrollRunId: (json['payrollRunId'] ?? '').toString(),
      payoutKey: (json['payoutKey'] ?? '').toString(),
      recipientId: json['recipientId']?.toString(),
      recipientName: (json['recipientName'] ?? '').toString(),
      bankName: (json['bankName'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      accountName: (json['accountName'] ?? '').toString(),
      bankCode: json['bankCode']?.toString(),
      payoutType: DeductionPayoutType.values.firstWhere(
        (value) => value.name == json['payoutType'],
        orElse: () => DeductionPayoutType.other,
      ),
      category: DeductionCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => DeductionCategory.other,
      ),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: (json['currency'] ?? 'NGN').toString(),
      sourceCount: (json['sourceCount'] as num? ?? 0).toInt(),
      status: DeductionPayoutItemStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => DeductionPayoutItemStatus.pending,
      ),
      createdAt: _readDate(json['createdAt']),
      completedAt: _readNullableDate(json['completedAt']),
      gatewayReference: json['gatewayReference']?.toString(),
      failureReason: json['failureReason']?.toString(),
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batchId': batchId,
      'payrollRunId': payrollRunId,
      'payoutKey': payoutKey,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'bankCode': bankCode,
      'payoutType': payoutType.name,
      'category': category.name,
      'amount': amount,
      'currency': currency,
      'sourceCount': sourceCount,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'gatewayReference': gatewayReference,
      'failureReason': failureReason,
      'metadata': metadata,
    };
  }
}

class DeductionPayeeConfig {
  final DeductionPayoutType type;
  final String payeeName;
  final String accountNumber;
  final String bankCode;
  final String bankName;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const DeductionPayeeConfig({
    required this.type,
    required this.payeeName,
    required this.accountNumber,
    required this.bankCode,
    required this.bankName,
    this.isActive = true,
    this.metadata,
  });

  factory DeductionPayeeConfig.fromJson(Map<String, dynamic> json) {
    return DeductionPayeeConfig(
      type: DeductionPayoutType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => DeductionPayoutType.other,
      ),
      payeeName: (json['payeeName'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      bankCode: (json['bankCode'] ?? '').toString(),
      bankName: (json['bankName'] ?? '').toString(),
      isActive: json['isActive'] != false,
      metadata: json['metadata'] == null
          ? null
          : Map<String, dynamic>.from(json['metadata'] as Map),
    );
  }

  factory DeductionPayeeConfig.fromRecipient(PayoutRecipientConfig recipient) {
    final type = _compatTypeFromRecipient(recipient);
    return DeductionPayeeConfig(
      type: type,
      payeeName: recipient.name,
      accountNumber: recipient.accountNumber,
      bankCode: recipient.bankCode ?? '',
      bankName: recipient.bankName,
      isActive: recipient.isActive,
      metadata: recipient.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'payeeName': payeeName,
      'accountNumber': accountNumber,
      'bankCode': bankCode,
      'bankName': bankName,
      'isActive': isActive,
      'metadata': metadata,
    };
  }
}

DeductionPayoutStatus _compatStatusFromItemStatus(
  DeductionPayoutItemStatus status,
) {
  switch (status) {
    case DeductionPayoutItemStatus.pending:
      return DeductionPayoutStatus.pending;
    case DeductionPayoutItemStatus.processing:
      return DeductionPayoutStatus.processing;
    case DeductionPayoutItemStatus.completed:
      return DeductionPayoutStatus.completed;
    case DeductionPayoutItemStatus.failed:
    case DeductionPayoutItemStatus.reversed:
      return DeductionPayoutStatus.failed;
  }
}

DeductionPayoutType _compatTypeFromRecipient(PayoutRecipientConfig recipient) {
  final normalized = recipient.key.trim().toLowerCase();
  if (normalized == 'statutory_paye') {
    return DeductionPayoutType.paye;
  }
  if (normalized == 'statutory_pension') {
    return DeductionPayoutType.pension;
  }
  if (normalized == 'statutory_nhf') {
    return DeductionPayoutType.nhf;
  }
  if (normalized == 'category:loan') {
    return DeductionPayoutType.loan;
  }
  if (normalized == 'category:advance') {
    return DeductionPayoutType.advance;
  }
  return DeductionPayoutType.other;
}
