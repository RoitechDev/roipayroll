import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_payout_model.dart';
import 'package:roipayroll/models/payment_batch_model.dart';

enum PaymentOrchestrationStatus {
  pending,
  salaryProcessing,
  salaryCompleted,
  deductionProcessing,
  deductionCompleted,
  zohoSyncing,
  completed,
  partiallyCompleted,
  failed,
}

enum ExternalSyncStatus { notStarted, skipped, processing, completed, failed }

DateTime _readOrchestrationDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime.now();
}

DateTime? _readNullableOrchestrationDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

class PaymentOrchestrationRun {
  final String id;
  final String payrollRunId;
  final int month;
  final int year;
  final String currency;
  final PaymentOrchestrationStatus status;
  final String? salaryBatchId;
  final PaymentBatchStatus? salaryBatchStatus;
  final String? deductionBatchId;
  final DeductionPayoutBatchStatus? deductionBatchStatus;
  final ExternalSyncStatus zohoSyncStatus;
  final String? zohoJournalId;
  final String? zohoJournalNumber;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final Map<String, dynamic>? metadata;

  const PaymentOrchestrationRun({
    required this.id,
    required this.payrollRunId,
    required this.month,
    required this.year,
    required this.currency,
    required this.status,
    required this.zohoSyncStatus,
    required this.createdAt,
    required this.updatedAt,
    this.salaryBatchId,
    this.salaryBatchStatus,
    this.deductionBatchId,
    this.deductionBatchStatus,
    this.zohoJournalId,
    this.zohoJournalNumber,
    this.failureReason,
    this.completedAt,
    this.metadata,
  });

  factory PaymentOrchestrationRun.fromJson(Map<String, dynamic> json) {
    return PaymentOrchestrationRun(
      id: (json['id'] ?? '').toString(),
      payrollRunId: (json['payrollRunId'] ?? '').toString(),
      month: (json['month'] as num? ?? 0).toInt(),
      year: (json['year'] as num? ?? 0).toInt(),
      currency: (json['currency'] ?? 'NGN').toString(),
      status: PaymentOrchestrationStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => PaymentOrchestrationStatus.pending,
      ),
      salaryBatchId: json['salaryBatchId']?.toString(),
      salaryBatchStatus: json['salaryBatchStatus'] == null
          ? null
          : PaymentBatchStatus.values.firstWhere(
              (value) => value.name == json['salaryBatchStatus'],
              orElse: () => PaymentBatchStatus.pending,
            ),
      deductionBatchId: json['deductionBatchId']?.toString(),
      deductionBatchStatus: json['deductionBatchStatus'] == null
          ? null
          : DeductionPayoutBatchStatus.values.firstWhere(
              (value) => value.name == json['deductionBatchStatus'],
              orElse: () => DeductionPayoutBatchStatus.pending,
            ),
      zohoSyncStatus: ExternalSyncStatus.values.firstWhere(
        (value) => value.name == json['zohoSyncStatus'],
        orElse: () => ExternalSyncStatus.notStarted,
      ),
      zohoJournalId: json['zohoJournalId']?.toString(),
      zohoJournalNumber: json['zohoJournalNumber']?.toString(),
      failureReason: json['failureReason']?.toString(),
      createdAt: _readOrchestrationDate(json['createdAt']),
      updatedAt: _readOrchestrationDate(json['updatedAt']),
      completedAt: _readNullableOrchestrationDate(json['completedAt']),
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
      'status': status.name,
      'salaryBatchId': salaryBatchId,
      'salaryBatchStatus': salaryBatchStatus?.name,
      'deductionBatchId': deductionBatchId,
      'deductionBatchStatus': deductionBatchStatus?.name,
      'zohoSyncStatus': zohoSyncStatus.name,
      'zohoJournalId': zohoJournalId,
      'zohoJournalNumber': zohoJournalNumber,
      'failureReason': failureReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'metadata': metadata,
    };
  }

  PaymentOrchestrationRun copyWith({
    String? id,
    String? payrollRunId,
    int? month,
    int? year,
    String? currency,
    PaymentOrchestrationStatus? status,
    String? salaryBatchId,
    PaymentBatchStatus? salaryBatchStatus,
    String? deductionBatchId,
    DeductionPayoutBatchStatus? deductionBatchStatus,
    ExternalSyncStatus? zohoSyncStatus,
    String? zohoJournalId,
    String? zohoJournalNumber,
    String? failureReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
    Map<String, dynamic>? metadata,
  }) {
    return PaymentOrchestrationRun(
      id: id ?? this.id,
      payrollRunId: payrollRunId ?? this.payrollRunId,
      month: month ?? this.month,
      year: year ?? this.year,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      salaryBatchId: salaryBatchId ?? this.salaryBatchId,
      salaryBatchStatus: salaryBatchStatus ?? this.salaryBatchStatus,
      deductionBatchId: deductionBatchId ?? this.deductionBatchId,
      deductionBatchStatus: deductionBatchStatus ?? this.deductionBatchStatus,
      zohoSyncStatus: zohoSyncStatus ?? this.zohoSyncStatus,
      zohoJournalId: zohoJournalId ?? this.zohoJournalId,
      zohoJournalNumber: zohoJournalNumber ?? this.zohoJournalNumber,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}
