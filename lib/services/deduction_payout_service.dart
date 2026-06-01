import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_payout_model.dart';
import 'package:roipayroll/models/deduction_transaction_model.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/ledger_account_model.dart';
import 'package:roipayroll/models/payment_batch_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/payroll_transaction_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/deduction_transaction_service.dart';
import 'package:roipayroll/services/payment_gateway_service.dart';
import 'package:roipayroll/services/payroll_transaction_service.dart';
import 'package:roipayroll/services/paystack_gateway_service.dart';
import 'package:roipayroll/services/transaction_service.dart';
import 'package:uuid/uuid.dart';

class DeductionPayoutService extends BaseService {
  static const String _recipientCollection = 'payment_recipients';
  static const String _batchCollection = 'deduction_payout_batches';
  static const String _itemCollection = 'deduction_payout_items';

  final PaymentGatewayService _gateway;
  final DeductionTransactionService _deductionTransactionService =
      DeductionTransactionService();
  final TransactionService _transactionService = TransactionService();

  DeductionPayoutService({
    String? paystackSecretKey,
    PaymentGatewayService? gateway,
  }) : _gateway =
           gateway ??
           PaystackGatewayService(secretKey: paystackSecretKey ?? '');

  Future<void> saveRecipientConfig(PayoutRecipientConfig recipient) async {
    final ref = await companyCollection(_recipientCollection);
    await ref.doc(recipient.id).set(recipient.toJson());
  }

  Future<List<PayoutRecipientConfig>> getRecipientConfigs({
    bool activeOnly = false,
  }) async {
    final ref = await companyCollection(_recipientCollection);
    final query = activeOnly ? ref.where('isActive', isEqualTo: true) : ref;
    final snapshot = await query.get();
    final recipients = snapshot.docs
        .map((doc) => PayoutRecipientConfig.fromJson(docData(doc)))
        .toList();
    recipients.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return recipients;
  }

  Future<List<PayoutRecipientConfig>> getActiveRecipientConfigs() {
    return getRecipientConfigs(activeOnly: true);
  }

  Future<void> setRecipientActive({
    required String recipientId,
    required bool isActive,
  }) async {
    final ref = await companyCollection(_recipientCollection);
    await ref.doc(recipientId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DeductionPayoutBatch?> createPayoutBatch({
    required List<Payroll> payrolls,
    required String payrollRunId,
    List<DeductionPayoutType>? deductionTypes,
  }) async {
    if (payrolls.isEmpty) {
      throw Exception(
        'At least one payroll is required to create a deduction payout batch.',
      );
    }

    final first = payrolls.first;
    final mixedPeriods = payrolls.any(
      (payroll) => payroll.month != first.month || payroll.year != first.year,
    );
    if (mixedPeriods) {
      throw Exception(
        'Deduction payout batch must contain payrolls from the same period.',
      );
    }

    final mixedCurrencies = payrolls.any(
      (payroll) =>
          payroll.currency.trim().toUpperCase() !=
          first.currency.trim().toUpperCase(),
    );
    if (mixedCurrencies) {
      throw Exception(
        'Deduction payout batch must contain payrolls in the same currency.',
      );
    }

    final existing = await _getBatchByPayrollRunId(payrollRunId);
    if (existing != null) {
      return existing;
    }

    final recipientLookup = _buildRecipientLookup(
      await getActiveRecipientConfigs(),
    );
    final groups = <String, _GroupedPayout>{};

    for (final payroll in payrolls) {
      final transactions = await _deductionTransactionService
          .getPayrollTransactions(payroll.id);
      for (final transaction in transactions) {
        if (_isZero(transaction.amount)) {
          continue;
        }

        final recipient = _findRecipientForTransaction(
          transaction,
          recipientLookup,
        );
        final payoutType = _payoutTypeForTransaction(transaction);
        if (deductionTypes != null && !deductionTypes.contains(payoutType)) {
          continue;
        }
        final groupKey = recipient?.id ?? _fallbackGroupKey(transaction);
        final localAmount = _localAmountForTransaction(transaction, payroll);
        final group = groups.putIfAbsent(
          groupKey,
          () => _GroupedPayout(
            payoutKey: groupKey,
            payoutType: payoutType,
            category: transaction.category,
            currency: payroll.currency,
            recipient: recipient,
          ),
        );
        group.amount += localAmount;
        group.allocations.add(
          _PayoutAllocation(
            deductionTransactionId: transaction.id,
            payrollId: transaction.payrollId,
            employeeId: transaction.employeeId,
            employeeName: transaction.employeeName,
            amount: localAmount,
            amountBase: transaction.amount,
            deductionTypeId: transaction.deductionTypeId,
            deductionTypeName: transaction.deductionTypeName,
            category: transaction.category,
          ),
        );
      }
    }

    if (groups.isEmpty) {
      return null;
    }

    final batch = DeductionPayoutBatch(
      id: const Uuid().v4(),
      payrollRunId: payrollRunId,
      month: first.month,
      year: first.year,
      currency: first.currency,
      totalPayouts: groups.length,
      totalAmount: groups.values.fold<double>(
        0.0,
        (runningTotal, group) => runningTotal + group.amount,
      ),
      status: DeductionPayoutBatchStatus.pending,
      createdAt: DateTime.now(),
      metadata: {
        'payrollIds': payrolls.map((payroll) => payroll.id).toList(),
        'unresolvedPayoutKeys': groups.values
            .where((group) => group.recipient == null)
            .map((group) => group.payoutKey)
            .toList(),
      },
    );

    final items = groups.values
        .map(
          (group) => DeductionPayoutItem(
            id: const Uuid().v4(),
            batchId: batch.id,
            payrollRunId: payrollRunId,
            payoutKey: group.payoutKey,
            recipientId: group.recipient?.id,
            recipientName: group.recipient?.name ?? group.displayName,
            bankName: group.recipient?.bankName ?? '',
            accountNumber: group.recipient?.accountNumber ?? '',
            accountName: group.recipient?.accountName ?? '',
            bankCode: group.recipient?.bankCode,
            payoutType: group.payoutType,
            category: group.category,
            amount: group.amount,
            currency: group.currency,
            sourceCount: group.allocations.length,
            status: DeductionPayoutItemStatus.pending,
            createdAt: DateTime.now(),
            metadata: {
              'allocations': group.allocations
                  .map((allocation) => allocation.toJson())
                  .toList(),
              'recipientConfigured': group.recipient != null,
              if (group.recipient == null)
                'configurationHint':
                    'Create a payment recipient using one of the keys: ${_candidateRecipientKeysFromAllocation(group.allocations.first).join(', ')}',
            },
          ),
        )
        .toList();

    final companyId = await getCompanyId();
    final batchRef = companyCollectionRef(companyId, _batchCollection);
    final itemRef = companyCollectionRef(companyId, _itemCollection);
    final writeBatch = firestore.batch();
    writeBatch.set(batchRef.doc(batch.id), batch.toJson());
    for (final item in items) {
      writeBatch.set(itemRef.doc(item.id), item.toJson());
    }
    await writeBatch.commit();

    return batch;
  }

  Future<BatchPaymentResult> processPayoutBatch({
    required String batchId,
  }) async {
    final batch = await getPayoutBatchById(batchId);
    if (batch == null) {
      throw Exception('Deduction payout batch not found.');
    }

    final items = await getPayoutItems(batchId);
    if (items.isEmpty) {
      throw Exception('No deduction payout items found for this batch.');
    }

    if (batch.status == DeductionPayoutBatchStatus.completed) {
      return _buildBatchSummary(items);
    }

    final companyId = await getCompanyId();
    final lockKey = await _beginBatchProcessing(
      companyId: companyId,
      batchId: batchId,
    );
    final batchRef = companyCollectionRef(
      companyId,
      _batchCollection,
    ).doc(batchId);
    final bankCodeMap = await _loadBankCodeMap();
    final results = <PaymentResult>[];
    var completedCount = 0;
    var processingCount = 0;
    var failedCount = 0;

    try {
      for (final item in items) {
        final reference = _paymentReferenceFor(item);
        if (item.status == DeductionPayoutItemStatus.completed) {
          results.add(
            PaymentResult(
              success: true,
              status: PaymentStatus.completed,
              reference: reference,
              gatewayReference: item.gatewayReference,
              message: 'Payout already completed.',
            ),
          );
          completedCount++;
          continue;
        }

        if (item.status == DeductionPayoutItemStatus.processing) {
          final reconciled = await _reconcileProcessingPayout(
            companyId: companyId,
            item: item,
          );
          if (reconciled != null) {
            results.add(reconciled);
            switch (reconciled.status) {
              case PaymentStatus.completed:
                completedCount++;
                break;
              case PaymentStatus.processing:
              case PaymentStatus.pending:
                processingCount++;
                break;
              case PaymentStatus.failed:
              case PaymentStatus.reversed:
                failedCount++;
                break;
            }
            continue;
          }
        }

        final failure = _validatePayoutReadiness(item);
        if (failure != null) {
          await _updatePayoutItem(
            item.id,
            status: DeductionPayoutItemStatus.failed,
            failureReason: failure,
          );
          results.add(
            PaymentResult(
              success: false,
              status: PaymentStatus.failed,
              reference: reference,
              message: failure,
            ),
          );
          failedCount++;
          continue;
        }

        final bankCode = item.bankCode?.trim().isNotEmpty == true
            ? item.bankCode!.trim()
            : bankCodeMap[_normalizeKey(item.bankName)];
        if (bankCode == null || bankCode.isEmpty) {
          final failureReason =
              'Unsupported or unmapped recipient bank: ${item.bankName}';
          await _updatePayoutItem(
            item.id,
            status: DeductionPayoutItemStatus.failed,
            failureReason: failureReason,
          );
          results.add(
            PaymentResult(
              success: false,
              status: PaymentStatus.failed,
              reference: reference,
              message: failureReason,
            ),
          );
          failedCount++;
          continue;
        }

        await _updatePayoutItem(
          item.id,
          status: DeductionPayoutItemStatus.processing,
          failureReason: null,
        );

        final result = await _gateway.processPayment(
          reference: reference,
          accountNumber: item.accountNumber,
          bankCode: bankCode,
          amount: item.amount,
          currency: item.currency,
          narration:
              '${_labelForPayoutType(item.payoutType)} remittance ${batch.month.toString().padLeft(2, '0')}/${batch.year} - ${item.recipientName}',
        );

        if (result.status == PaymentStatus.completed) {
          try {
            await _finalizeCompletedPayout(
              companyId: companyId,
              item: item,
              settledAt: DateTime.now(),
              gatewayReference: result.gatewayReference,
            );
            results.add(result);
            completedCount++;
          } catch (error) {
            final recoveryMessage =
                'Gateway payout completed, but local settlement sync is pending: $error';
            await _updatePayoutItem(
              item.id,
              status: DeductionPayoutItemStatus.processing,
              gatewayReference: result.gatewayReference,
              failureReason: recoveryMessage,
            );
            results.add(
              PaymentResult(
                success: true,
                status: PaymentStatus.processing,
                reference: reference,
                gatewayReference: result.gatewayReference,
                message: recoveryMessage,
                data: result.data,
              ),
            );
            processingCount++;
          }
          continue;
        }

        if (result.success) {
          await _updatePayoutItem(
            item.id,
            status: DeductionPayoutItemStatus.processing,
            gatewayReference: result.gatewayReference,
            failureReason: null,
          );
          results.add(result);
          processingCount++;
          continue;
        }

        await _updatePayoutItem(
          item.id,
          status: DeductionPayoutItemStatus.failed,
          gatewayReference: result.gatewayReference,
          failureReason: result.message,
        );
        results.add(result);
        failedCount++;
      }
    } finally {
      try {
        await _transactionService.removeIdempotencyLock(companyId, lockKey);
      } catch (_) {}
    }

    final batchStatus = _resolveBatchStatus(
      totalCount: items.length,
      completedCount: completedCount,
      processingCount: processingCount,
      failedCount: failedCount,
    );
    await batchRef.update({
      'status': batchStatus.name,
      'processedAt': FieldValue.serverTimestamp(),
      'gatewayProvider': _gatewayProviderName,
      'gatewayReference': _selectBatchGatewayReference(results),
    });

    return BatchPaymentResult(
      totalCount: items.length,
      successCount: completedCount + processingCount,
      failedCount: failedCount,
      results: results,
    );
  }

  Future<DeductionPayoutBatch?> getPayoutBatchById(String batchId) async {
    final ref = await companyCollection(_batchCollection);
    final doc = await ref.doc(batchId).get();
    final data = docDataNullable(doc);
    return data == null ? null : DeductionPayoutBatch.fromJson(data);
  }

  Future<List<DeductionPayoutBatch>> getPayoutBatchesForPeriod({
    required int month,
    required int year,
  }) async {
    final ref = await companyCollection(_batchCollection);
    final snapshot = await ref
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();
    final batches = snapshot.docs
        .map((doc) => DeductionPayoutBatch.fromJson(docData(doc)))
        .toList();
    batches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return batches;
  }

  Future<List<DeductionPayoutBatch>> getAllBatches() async {
    final ref = await companyCollection(_batchCollection);
    final snapshot = await ref.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => DeductionPayoutBatch.fromJson(docData(doc)))
        .toList();
  }

  Future<DeductionPayoutBatch?> getPayoutBatchByPayrollRunId(
    String payrollRunId,
  ) {
    return _getBatchByPayrollRunId(payrollRunId);
  }

  Future<List<DeductionPayoutItem>> getPayoutItems(String batchId) async {
    final ref = await companyCollection(_itemCollection);
    final snapshot = await ref
        .where('batchId', isEqualTo: batchId)
        .orderBy('createdAt')
        .get();
    return snapshot.docs
        .map((doc) => DeductionPayoutItem.fromJson(docData(doc)))
        .toList();
  }

  Future<List<DeductionPayout>> getPayouts(String batchId) async {
    final items = await getPayoutItems(batchId);
    return items.map(DeductionPayout.fromItem).toList();
  }

  Future<void> savePayeeConfig(DeductionPayeeConfig config) async {
    final existingRecipient = await _findRecipientConfigForType(config.type);
    final now = DateTime.now();
    final recipient = PayoutRecipientConfig(
      id: existingRecipient?.id ?? _recipientIdForType(config.type),
      key: _recipientKeyForType(config.type),
      name: config.payeeName,
      bankName: config.bankName,
      accountNumber: config.accountNumber,
      accountName: config.payeeName,
      bankCode: config.bankCode.trim().isEmpty ? null : config.bankCode.trim(),
      aliases: _recipientAliasesForType(config.type),
      isActive: config.isActive,
      metadata: {
        ...?existingRecipient?.metadata,
        ...?config.metadata,
        'deductionPayoutType': config.type.name,
        'compatPayeeConfig': true,
      },
      createdAt: existingRecipient?.createdAt ?? now,
      updatedAt: now,
    );
    await saveRecipientConfig(recipient);
  }

  Future<List<DeductionPayeeConfig>> getPayeeConfigs() async {
    final configs = <DeductionPayeeConfig>[];
    for (final type in DeductionPayoutType.values) {
      final recipient = await _findRecipientConfigForType(type);
      if (recipient != null) {
        configs.add(DeductionPayeeConfig.fromRecipient(recipient));
      }
    }
    return configs;
  }

  Future<DeductionPayeeConfig?> getPayeeConfig(DeductionPayoutType type) async {
    final recipient = await _findRecipientConfigForType(type);
    return recipient == null
        ? null
        : DeductionPayeeConfig.fromRecipient(recipient);
  }

  Future<DeductionPayoutBatch?> _getBatchByPayrollRunId(
    String payrollRunId,
  ) async {
    final ref = await companyCollection(_batchCollection);
    final snapshot = await ref
        .where('payrollRunId', isEqualTo: payrollRunId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return DeductionPayoutBatch.fromJson(docData(snapshot.docs.first));
  }

  Future<String> _beginBatchProcessing({
    required String companyId,
    required String batchId,
  }) async {
    final lockKey = 'deduction_payout_batch_process_$batchId';
    final batchRef = companyCollectionRef(
      companyId,
      _batchCollection,
    ).doc(batchId);
    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'batchId': batchId,
              'operation': 'processDeductionPayoutBatch',
            },
          );
      if (!shouldProceed) {
        throw Exception('Deduction payout batch is already being processed.');
      }

      final batchDoc = await transaction.get(batchRef);
      final batchData = docDataNullable(batchDoc);
      if (batchData == null) {
        throw Exception('Deduction payout batch not found.');
      }

      transaction.update(batchRef, {
        'status': DeductionPayoutBatchStatus.processing.name,
        'gatewayProvider': _gatewayProviderName,
      });
    });
    return lockKey;
  }

  Future<PaymentResult?> _reconcileProcessingPayout({
    required String companyId,
    required DeductionPayoutItem item,
  }) async {
    final reference = _paymentReferenceFor(item);
    try {
      final statusResponse = await _gateway.checkPaymentStatus(reference);
      final gatewayReference =
          statusResponse.data?['transfer_code']?.toString() ??
          statusResponse.data?['reference']?.toString() ??
          item.gatewayReference;

      if (statusResponse.status == PaymentStatus.completed) {
        try {
          await _finalizeCompletedPayout(
            companyId: companyId,
            item: item,
            settledAt: DateTime.now(),
            gatewayReference: gatewayReference,
          );
          return PaymentResult(
            success: true,
            status: PaymentStatus.completed,
            reference: reference,
            gatewayReference: gatewayReference,
            message:
                'Recovered completed deduction payout from gateway status.',
            data: statusResponse.data,
          );
        } catch (error) {
          final recoveryMessage =
              'Gateway payout completed, but local settlement sync is pending: $error';
          await _updatePayoutItem(
            item.id,
            status: DeductionPayoutItemStatus.processing,
            gatewayReference: gatewayReference,
            failureReason: recoveryMessage,
          );
          return PaymentResult(
            success: true,
            status: PaymentStatus.processing,
            reference: reference,
            gatewayReference: gatewayReference,
            message: recoveryMessage,
            data: statusResponse.data,
          );
        }
      }

      if (statusResponse.status == PaymentStatus.processing ||
          statusResponse.status == PaymentStatus.pending) {
        await _updatePayoutItem(
          item.id,
          status: DeductionPayoutItemStatus.processing,
          gatewayReference: gatewayReference,
          failureReason: null,
        );
        return PaymentResult(
          success: true,
          status: PaymentStatus.processing,
          reference: reference,
          gatewayReference: gatewayReference,
          message: 'Deduction payout is still processing on the gateway.',
          data: statusResponse.data,
        );
      }
    } catch (error) {
      return PaymentResult(
        success: true,
        status: PaymentStatus.processing,
        reference: reference,
        gatewayReference: item.gatewayReference,
        message:
            'Deduction payout is already marked processing and could not be re-verified yet: $error',
      );
    }

    return null;
  }

  Future<void> _finalizeCompletedPayout({
    required String companyId,
    required DeductionPayoutItem item,
    required DateTime settledAt,
    String? gatewayReference,
  }) async {
    final itemRef = companyCollectionRef(
      companyId,
      _itemCollection,
    ).doc(item.id);
    final transactionsRef = companyCollectionRef(
      companyId,
      PayrollTransactionService.collectionName,
    );
    final allocations =
        (item.metadata?['allocations'] as List<dynamic>? ?? const <dynamic>[])
            .whereType<Map>()
            .map(
              (raw) =>
                  _PayoutAllocation.fromJson(Map<String, dynamic>.from(raw)),
            )
            .toList();
    if (allocations.isEmpty) {
      throw Exception('Deduction payout item ${item.id} has no allocations.');
    }

    await _transactionService.runTransaction<void>((transaction) async {
      for (final allocation in allocations) {
        final payrollRef = companyCollectionRef(
          companyId,
          'payrolls',
        ).doc(allocation.payrollId);
        final payrollDoc = await transaction.get(payrollRef);
        final payrollData = docDataNullable(payrollDoc);
        if (payrollData == null) {
          throw Exception(
            'Payroll not found for deduction payout allocation ${allocation.deductionTransactionId}.',
          );
        }
        final payroll = Payroll.fromJson(payrollData);
        final settlementId =
            'deduction_settlement_${item.id}_${allocation.deductionTransactionId}';
        final settlementRef = transactionsRef.doc(settlementId);
        final settlementDoc = await transaction.get(settlementRef);
        if (!settlementDoc.exists) {
          final settlement = _buildDeductionSettlementTransaction(
            settlementId: settlementId,
            payroll: payroll,
            item: item,
            allocation: allocation,
            settledAt: settledAt,
            gatewayReference: gatewayReference,
          );
          transaction.set(settlementRef, settlement.toJson());
        }
      }

      transaction.update(itemRef, {
        'status': DeductionPayoutItemStatus.completed.name,
        'gatewayReference': gatewayReference,
        'failureReason': null,
        'completedAt': Timestamp.fromDate(settledAt),
      });
    });
  }

  PayrollTransaction _buildDeductionSettlementTransaction({
    required String settlementId,
    required Payroll payroll,
    required DeductionPayoutItem item,
    required _PayoutAllocation allocation,
    required DateTime settledAt,
    String? gatewayReference,
  }) {
    final debitAccount = _debitAccountForPayout(item.payoutType, item.category);
    return PayrollTransaction(
      id: settlementId,
      payrollId: allocation.payrollId,
      payrollRunId: item.payrollRunId,
      employeeId: allocation.employeeId,
      employeeName: allocation.employeeName,
      type: TransactionType.deductionPayment,
      description:
          '${_labelForPayoutType(item.payoutType)} remittance settlement',
      debitAccount: debitAccount.code,
      debitAccountName: debitAccount.name,
      creditAccount: PayrollLedgerChartOfAccounts.bankAccount.code,
      creditAccountName: PayrollLedgerChartOfAccounts.bankAccount.name,
      amount: allocation.amount.abs(),
      currency: payroll.currency,
      exchangeRate: payroll.exchangeRateToBase <= 0
          ? 1.0
          : payroll.exchangeRateToBase,
      amountBase: allocation.amountBase.abs(),
      transactionMonth: settledAt.month,
      transactionYear: settledAt.year,
      transactionDate: settledAt,
      createdAt: settledAt,
      isReversal: payroll.isReversal,
      metadata: {
        'deductionPayoutItemId': item.id,
        'deductionTransactionId': allocation.deductionTransactionId,
        'deductionTypeId': allocation.deductionTypeId,
        'deductionTypeName': allocation.deductionTypeName,
        'payoutType': item.payoutType.name,
        'payoutKey': item.payoutKey,
        'recipientName': item.recipientName,
        if (gatewayReference != null && gatewayReference.trim().isNotEmpty)
          'gatewayReference': gatewayReference.trim(),
      },
    );
  }

  BatchPaymentResult _buildBatchSummary(List<DeductionPayoutItem> items) {
    final results = <PaymentResult>[];
    var successCount = 0;
    var failedCount = 0;

    for (final item in items) {
      final success =
          item.status != DeductionPayoutItemStatus.failed &&
          item.status != DeductionPayoutItemStatus.reversed;
      if (success) {
        successCount++;
      } else {
        failedCount++;
      }

      results.add(
        PaymentResult(
          success: success,
          status: _paymentStatusForItem(item.status),
          reference: _paymentReferenceFor(item),
          gatewayReference: item.gatewayReference,
          message: item.failureReason ?? _summaryMessageForStatus(item.status),
        ),
      );
    }

    return BatchPaymentResult(
      totalCount: items.length,
      successCount: successCount,
      failedCount: failedCount,
      results: results,
    );
  }

  Future<void> _updatePayoutItem(
    String itemId, {
    required DeductionPayoutItemStatus status,
    String? gatewayReference,
    String? failureReason,
    DateTime? completedAt,
  }) async {
    final ref = await companyCollection(_itemCollection);
    await ref.doc(itemId).update({
      'status': status.name,
      'gatewayReference': gatewayReference,
      'failureReason': failureReason,
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt),
    });
  }

  PaymentStatus _paymentStatusForItem(DeductionPayoutItemStatus status) {
    switch (status) {
      case DeductionPayoutItemStatus.pending:
        return PaymentStatus.pending;
      case DeductionPayoutItemStatus.processing:
        return PaymentStatus.processing;
      case DeductionPayoutItemStatus.completed:
        return PaymentStatus.completed;
      case DeductionPayoutItemStatus.failed:
        return PaymentStatus.failed;
      case DeductionPayoutItemStatus.reversed:
        return PaymentStatus.reversed;
    }
  }

  DeductionPayoutBatchStatus _resolveBatchStatus({
    required int totalCount,
    required int completedCount,
    required int processingCount,
    required int failedCount,
  }) {
    if (completedCount == totalCount) {
      return DeductionPayoutBatchStatus.completed;
    }
    if (failedCount == totalCount) {
      return DeductionPayoutBatchStatus.failed;
    }
    if (processingCount > 0 && completedCount == 0 && failedCount == 0) {
      return DeductionPayoutBatchStatus.processing;
    }
    return DeductionPayoutBatchStatus.partiallyCompleted;
  }

  String? _validatePayoutReadiness(DeductionPayoutItem item) {
    if (item.amount <= 0) {
      return 'Payout amount must be greater than zero.';
    }
    if (item.accountNumber.trim().isEmpty) {
      return 'No payout recipient configured for ${item.recipientName}.';
    }
    if (item.bankName.trim().isEmpty) {
      return 'Missing payout recipient bank name for ${item.recipientName}.';
    }
    return null;
  }

  Map<String, PayoutRecipientConfig> _buildRecipientLookup(
    List<PayoutRecipientConfig> recipients,
  ) {
    final lookup = <String, PayoutRecipientConfig>{};
    for (final recipient in recipients) {
      lookup[_normalizeKey(recipient.key)] = recipient;
      for (final alias in recipient.aliases) {
        final normalized = _normalizeKey(alias);
        if (normalized.isNotEmpty) {
          lookup[normalized] = recipient;
        }
      }
    }
    return lookup;
  }

  PayoutRecipientConfig? _findRecipientForTransaction(
    DeductionTransaction transaction,
    Map<String, PayoutRecipientConfig> recipientLookup,
  ) {
    for (final key in _candidateRecipientKeys(transaction)) {
      final resolved = recipientLookup[_normalizeKey(key)];
      if (resolved != null && resolved.isActive) {
        return resolved;
      }
    }
    return null;
  }

  List<String> _candidateRecipientKeys(DeductionTransaction transaction) {
    final keys = <String>[
      transaction.deductionTypeId,
      transaction.deductionTypeName,
      'category:${transaction.category.name}',
    ];
    final referenceNumber =
        transaction.metadata?['referenceNumber']?.toString().trim() ?? '';
    if (referenceNumber.isNotEmpty) {
      keys.add(referenceNumber);
      keys.add('${transaction.category.name}:$referenceNumber');
      keys.add('ref:$referenceNumber');
    }

    final normalizedName = _normalizeKey(transaction.deductionTypeName);
    if (transaction.isStatutory || normalizedName == 'paye') {
      keys.add('statutory_paye');
    }
    if (normalizedName == 'pension') {
      keys.add('statutory_pension');
    }
    if (normalizedName == 'nhf') {
      keys.add('statutory_nhf');
    }

    return keys.where((key) => key.trim().isNotEmpty).toList();
  }

  List<String> _candidateRecipientKeysFromAllocation(
    _PayoutAllocation allocation,
  ) {
    return <String>[
      allocation.deductionTypeId,
      allocation.deductionTypeName,
      'category:${allocation.category.name}',
    ].where((key) => key.trim().isNotEmpty).toList();
  }

  String _fallbackGroupKey(DeductionTransaction transaction) {
    final referenceNumber =
        transaction.metadata?['referenceNumber']?.toString().trim() ?? '';
    if (referenceNumber.isNotEmpty) {
      return _normalizeKey('${transaction.category.name}:$referenceNumber');
    }
    return _normalizeKey(transaction.deductionTypeId);
  }

  double _localAmountForTransaction(
    DeductionTransaction transaction,
    Payroll payroll,
  ) {
    final exchangeRate = payroll.exchangeRateToBase <= 0
        ? 1.0
        : payroll.exchangeRateToBase;
    return transaction.amount / exchangeRate;
  }

  DeductionPayoutType _payoutTypeForTransaction(
    DeductionTransaction transaction,
  ) {
    final normalizedName = _normalizeKey(transaction.deductionTypeName);
    if (transaction.deductionTypeId == 'statutory_paye' ||
        normalizedName == 'paye') {
      return DeductionPayoutType.paye;
    }
    if (transaction.deductionTypeId == 'statutory_pension' ||
        normalizedName == 'pension') {
      return DeductionPayoutType.pension;
    }
    if (transaction.deductionTypeId == 'statutory_nhf' ||
        normalizedName == 'nhf') {
      return DeductionPayoutType.nhf;
    }
    switch (transaction.category) {
      case DeductionCategory.loan:
        return DeductionPayoutType.loan;
      case DeductionCategory.advance:
        return DeductionPayoutType.advance;
      case DeductionCategory.statutory:
      case DeductionCategory.garnishment:
      case DeductionCategory.insurance:
      case DeductionCategory.union:
      case DeductionCategory.other:
        return DeductionPayoutType.other;
    }
  }

  LedgerAccount _debitAccountForPayout(
    DeductionPayoutType payoutType,
    DeductionCategory category,
  ) {
    switch (payoutType) {
      case DeductionPayoutType.paye:
        return PayrollLedgerChartOfAccounts.payePayable;
      case DeductionPayoutType.pension:
        return PayrollLedgerChartOfAccounts.pensionPayable;
      case DeductionPayoutType.nhf:
        return PayrollLedgerChartOfAccounts.nhfPayable;
      case DeductionPayoutType.loan:
        return PayrollLedgerChartOfAccounts.loanReceivable;
      case DeductionPayoutType.advance:
        return PayrollLedgerChartOfAccounts.advanceReceivable;
      case DeductionPayoutType.other:
        switch (category) {
          case DeductionCategory.loan:
            return PayrollLedgerChartOfAccounts.loanReceivable;
          case DeductionCategory.advance:
            return PayrollLedgerChartOfAccounts.advanceReceivable;
          case DeductionCategory.statutory:
          case DeductionCategory.garnishment:
          case DeductionCategory.insurance:
          case DeductionCategory.union:
          case DeductionCategory.other:
            return PayrollLedgerChartOfAccounts.otherDeductionsPayable;
        }
    }
  }

  String _labelForPayoutType(DeductionPayoutType payoutType) {
    switch (payoutType) {
      case DeductionPayoutType.paye:
        return 'PAYE';
      case DeductionPayoutType.pension:
        return 'Pension';
      case DeductionPayoutType.nhf:
        return 'NHF';
      case DeductionPayoutType.loan:
        return 'Loan';
      case DeductionPayoutType.advance:
        return 'Advance';
      case DeductionPayoutType.other:
        return 'Deduction';
    }
  }

  String _paymentReferenceFor(DeductionPayoutItem item) {
    return 'DED-${item.id}';
  }

  String _summaryMessageForStatus(DeductionPayoutItemStatus status) {
    switch (status) {
      case DeductionPayoutItemStatus.pending:
        return 'Payout is pending.';
      case DeductionPayoutItemStatus.processing:
        return 'Payout is processing.';
      case DeductionPayoutItemStatus.completed:
        return 'Payout completed.';
      case DeductionPayoutItemStatus.failed:
        return 'Payout failed.';
      case DeductionPayoutItemStatus.reversed:
        return 'Payout was reversed.';
    }
  }

  String _normalizeKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  }

  bool _recipientMatchesType(
    PayoutRecipientConfig recipient,
    DeductionPayoutType type,
  ) {
    final key = _normalizeKey(recipient.key);
    if (key == _normalizeKey(_recipientKeyForType(type))) {
      return true;
    }
    for (final alias in recipient.aliases) {
      if (_normalizeKey(alias) == _normalizeKey(_recipientKeyForType(type))) {
        return true;
      }
      if (_normalizeKey(alias) == _normalizeKey(type.name)) {
        return true;
      }
    }
    return false;
  }

  Future<PayoutRecipientConfig?> _findRecipientConfigForType(
    DeductionPayoutType type,
  ) async {
    final recipients = await getRecipientConfigs();
    for (final recipient in recipients) {
      if (_recipientMatchesType(recipient, type)) {
        return recipient;
      }
    }
    return null;
  }

  String _recipientIdForType(DeductionPayoutType type) {
    return 'deduction_payee_${type.name}';
  }

  String _recipientKeyForType(DeductionPayoutType type) {
    switch (type) {
      case DeductionPayoutType.paye:
        return 'statutory_paye';
      case DeductionPayoutType.pension:
        return 'statutory_pension';
      case DeductionPayoutType.nhf:
        return 'statutory_nhf';
      case DeductionPayoutType.loan:
        return 'category:loan';
      case DeductionPayoutType.advance:
        return 'category:advance';
      case DeductionPayoutType.other:
        return 'category:other';
    }
  }

  List<String> _recipientAliasesForType(DeductionPayoutType type) {
    switch (type) {
      case DeductionPayoutType.paye:
        return ['paye', 'tax', 'category:statutory'];
      case DeductionPayoutType.pension:
        return ['pension'];
      case DeductionPayoutType.nhf:
        return ['nhf'];
      case DeductionPayoutType.loan:
        return ['loan'];
      case DeductionPayoutType.advance:
        return ['advance'];
      case DeductionPayoutType.other:
        return ['other', 'deduction'];
    }
  }

  String? _selectBatchGatewayReference(List<PaymentResult> results) {
    for (final result in results) {
      final gatewayReference = result.gatewayReference?.trim();
      if (gatewayReference != null && gatewayReference.isNotEmpty) {
        return gatewayReference;
      }
    }
    return null;
  }

  Future<Map<String, String>> _loadBankCodeMap() async {
    final resolved = <String, String>{..._fallbackBankCodes};
    try {
      final banks = await _gateway.getSupportedBanks();
      for (final bank in banks) {
        final normalized = _normalizeKey(bank.name);
        if (normalized.isNotEmpty && bank.code.trim().isNotEmpty) {
          resolved[normalized] = bank.code.trim();
        }
      }
    } catch (_) {}
    return resolved;
  }

  String get _gatewayProviderName {
    if (_gateway is PaystackGatewayService) {
      return 'paystack';
    }
    return 'custom';
  }

  bool _isZero(double value) => value.abs() < 0.01;

  static const Map<String, String> _fallbackBankCodes = {
    'access bank': '044',
    'citibank': '023',
    'ecobank': '050',
    'fidelity bank': '070',
    'first bank': '011',
    'first city monument bank': '214',
    'fcmb': '214',
    'globus bank': '00103',
    'guaranty trust bank': '058',
    'gtbank': '058',
    'heritage bank': '030',
    'keystone bank': '082',
    'opay': '999992',
    'palmpay': '100033',
    'polaris bank': '076',
    'providus bank': '101',
    'stanbic ibtc bank': '221',
    'standard chartered bank': '068',
    'sterling bank': '232',
    'suntrust bank': '100',
    'taj bank': '302',
    'union bank': '032',
    'uba': '033',
    'united bank for africa': '033',
    'unity bank': '215',
    'wema bank': '035',
    'zenith bank': '057',
  };
}

class _GroupedPayout {
  final String payoutKey;
  final DeductionPayoutType payoutType;
  final DeductionCategory category;
  final String currency;
  final PayoutRecipientConfig? recipient;
  final List<_PayoutAllocation> allocations = <_PayoutAllocation>[];
  double amount = 0.0;

  _GroupedPayout({
    required this.payoutKey,
    required this.payoutType,
    required this.category,
    required this.currency,
    required this.recipient,
  });

  String get displayName {
    if (recipient != null) {
      return recipient!.name;
    }
    return payoutKey.trim().isEmpty
        ? 'Unconfigured deduction payout'
        : payoutKey;
  }
}

class _PayoutAllocation {
  final String deductionTransactionId;
  final String payrollId;
  final String employeeId;
  final String employeeName;
  final double amount;
  final double amountBase;
  final String deductionTypeId;
  final String deductionTypeName;
  final DeductionCategory category;

  const _PayoutAllocation({
    required this.deductionTransactionId,
    required this.payrollId,
    required this.employeeId,
    required this.employeeName,
    required this.amount,
    required this.amountBase,
    required this.deductionTypeId,
    required this.deductionTypeName,
    required this.category,
  });

  factory _PayoutAllocation.fromJson(Map<String, dynamic> json) {
    return _PayoutAllocation(
      deductionTransactionId: (json['deductionTransactionId'] ?? '').toString(),
      payrollId: (json['payrollId'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      amountBase: (json['amountBase'] as num? ?? 0).toDouble(),
      deductionTypeId: (json['deductionTypeId'] ?? '').toString(),
      deductionTypeName: (json['deductionTypeName'] ?? '').toString(),
      category: DeductionCategory.values.firstWhere(
        (value) => value.name == json['category'],
        orElse: () => DeductionCategory.other,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deductionTransactionId': deductionTransactionId,
      'payrollId': payrollId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'amount': amount,
      'amountBase': amountBase,
      'deductionTypeId': deductionTypeId,
      'deductionTypeName': deductionTypeName,
      'category': category.name,
    };
  }
}
