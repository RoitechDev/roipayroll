import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/payment_batch_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/payment_gateway_service.dart';
import 'package:roipayroll/services/payroll_service.dart';
import 'package:roipayroll/services/payroll_transaction_service.dart';
import 'package:roipayroll/services/paystack_gateway_service.dart';
import 'package:roipayroll/services/transaction_service.dart';
import 'package:uuid/uuid.dart';

class PaymentProcessingService extends BaseService {
  static const String _batchCollection = 'payment_batches';
  static const String _paymentCollection = 'employee_payments';

  final PaymentGatewayService _gateway;
  final EmployeeService _employeeService = EmployeeService();
  final PayrollService _payrollService = PayrollService();
  final PayrollTransactionService _payrollTransactionService =
      PayrollTransactionService();
  final TransactionService _transactionService = TransactionService();

  PaymentProcessingService({
    String? paystackSecretKey,
    PaymentGatewayService? gateway,
  }) : _gateway =
           gateway ??
           PaystackGatewayService(secretKey: paystackSecretKey ?? '');

  Future<PaymentBatch> createPaymentBatch({
    required List<Payroll> payrolls,
    required String payrollRunId,
  }) async {
    if (payrolls.isEmpty) {
      throw Exception('At least one payroll is required to create a batch.');
    }

    final first = payrolls.first;
    final mixedPeriods = payrolls.any(
      (payroll) => payroll.month != first.month || payroll.year != first.year,
    );
    if (mixedPeriods) {
      throw Exception(
        'Payment batch must contain payrolls from the same period.',
      );
    }

    final mixedCurrencies = payrolls.any(
      (payroll) =>
          payroll.currency.trim().toUpperCase() !=
          first.currency.trim().toUpperCase(),
    );
    if (mixedCurrencies) {
      throw Exception(
        'Payment batch must contain payrolls in the same currency.',
      );
    }

    final companyId = await getCompanyId();
    final existing = await _getBatchByPayrollRunId(payrollRunId);
    if (existing != null) {
      return existing;
    }

    final totalAmount = payrolls.fold<double>(
      0.0,
      (runningTotal, payroll) => runningTotal + payroll.netSalary,
    );
    final batch = PaymentBatch(
      id: const Uuid().v4(),
      payrollRunId: payrollRunId,
      month: first.month,
      year: first.year,
      totalEmployees: payrolls.length,
      totalAmount: totalAmount,
      currency: first.currency,
      status: PaymentBatchStatus.pending,
      createdAt: DateTime.now(),
    );

    final employeePayments = <EmployeePayment>[];
    for (final payroll in payrolls) {
      final employee = await _employeeService.getEmployeeById(
        payroll.employeeId,
      );
      if (employee == null) {
        throw Exception('Employee not found for payroll ${payroll.id}.');
      }

      employeePayments.add(
        EmployeePayment(
          id: const Uuid().v4(),
          paymentBatchId: batch.id,
          payrollId: payroll.id,
          employeeId: payroll.employeeId,
          employeeName: payroll.employeeName,
          amount: payroll.netSalary,
          currency: payroll.currency,
          bankName: employee.bankName?.trim() ?? '',
          accountNumber: employee.accountNumber?.trim() ?? '',
          accountName: employee.fullName,
          status: PaymentStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
    }

    final batchRef = companyCollectionRef(companyId, _batchCollection);
    final paymentRef = companyCollectionRef(companyId, _paymentCollection);
    final writeBatch = firestore.batch();
    writeBatch.set(batchRef.doc(batch.id), batch.toJson());
    for (final employeePayment in employeePayments) {
      writeBatch.set(
        paymentRef.doc(employeePayment.id),
        employeePayment.toJson(),
      );
    }
    await writeBatch.commit();

    return batch;
  }

  Future<BatchPaymentResult> processPaymentBatch({
    required String batchId,
  }) async {
    final batch = await getPaymentBatchById(batchId);
    if (batch == null) {
      throw Exception('Payment batch not found.');
    }

    final employeePayments = await getEmployeePayments(batchId);
    if (employeePayments.isEmpty) {
      throw Exception('No employee payments found for this batch.');
    }

    if (batch.status == PaymentBatchStatus.completed) {
      return _buildBatchSummary(employeePayments);
    }

    final payrollById = await _loadPayrollsForBatch(employeePayments);
    _assertPayrollsReadyForPayment(employeePayments, payrollById);

    final companyId = await getCompanyId();
    final batchRef = companyCollectionRef(
      companyId,
      _batchCollection,
    ).doc(batchId);
    final lockKey = await _beginBatchProcessing(
      companyId: companyId,
      batchId: batchId,
    );
    final bankCodeMap = await _loadBankCodeMap();
    final results = <PaymentResult>[];
    var completedCount = 0;
    var processingCount = 0;
    var failedCount = 0;

    try {
      for (final employeePayment in employeePayments) {
        final reference = _paymentReferenceFor(employeePayment);
        if (employeePayment.status == PaymentStatus.completed) {
          results.add(
            PaymentResult(
              success: true,
              status: PaymentStatus.completed,
              reference: reference,
              gatewayReference: employeePayment.gatewayReference,
              message: 'Payment already completed.',
            ),
          );
          completedCount++;
          continue;
        }

        if (employeePayment.status == PaymentStatus.processing) {
          final reconciled = await _reconcileProcessingPayment(
            companyId: companyId,
            batch: batch,
            employeePayment: employeePayment,
            payroll: payrollById[employeePayment.payrollId]!,
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

        final failure = _validatePaymentReadiness(employeePayment);
        if (failure != null) {
          await _updateEmployeePayment(
            employeePayment.id,
            status: PaymentStatus.failed,
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

        final bankCode =
            bankCodeMap[_normalizeBankName(employeePayment.bankName)];
        if (bankCode == null || bankCode.isEmpty) {
          final failureReason =
              'Unsupported or unmapped bank: ${employeePayment.bankName}';
          await _updateEmployeePayment(
            employeePayment.id,
            status: PaymentStatus.failed,
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

        await _updateEmployeePayment(
          employeePayment.id,
          status: PaymentStatus.processing,
          failureReason: null,
        );

        final result = await _gateway.processPayment(
          reference: reference,
          accountNumber: employeePayment.accountNumber,
          bankCode: bankCode,
          amount: employeePayment.amount,
          currency: employeePayment.currency,
          narration:
              'Salary ${batch.month.toString().padLeft(2, '0')}/${batch.year} - ${employeePayment.employeeName}',
        );

        if (result.status == PaymentStatus.completed) {
          try {
            await _finalizeCompletedPayment(
              companyId: companyId,
              batch: batch,
              employeePayment: employeePayment,
              payroll: payrollById[employeePayment.payrollId]!,
              gatewayReference: result.gatewayReference,
              settledAt: DateTime.now(),
            );
            results.add(result);
            completedCount++;
          } catch (error) {
            final recoveryMessage =
                'Gateway transfer completed, but local settlement sync is pending: $error';
            await _updateEmployeePayment(
              employeePayment.id,
              status: PaymentStatus.processing,
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
          await _updateEmployeePayment(
            employeePayment.id,
            status: result.status,
            gatewayReference: result.gatewayReference,
            failureReason: null,
          );
          results.add(result);
          processingCount++;
          continue;
        }

        await _updateEmployeePayment(
          employeePayment.id,
          status: PaymentStatus.failed,
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
      totalCount: employeePayments.length,
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
      totalCount: employeePayments.length,
      successCount: completedCount + processingCount,
      failedCount: failedCount,
      results: results,
    );
  }

  Future<PaymentBatch?> getPaymentBatchById(String batchId) async {
    final ref = await companyCollection(_batchCollection);
    final doc = await ref.doc(batchId).get();
    final data = docDataNullable(doc);
    if (data == null) {
      return null;
    }
    return PaymentBatch.fromJson(data);
  }

  Future<List<PaymentBatch>> getPaymentBatchesForPeriod({
    required int month,
    required int year,
  }) async {
    final ref = await companyCollection(_batchCollection);
    final snapshot = await ref
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();
    final batches = snapshot.docs
        .map((doc) => PaymentBatch.fromJson(docData(doc)))
        .toList();
    batches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return batches;
  }

  Future<PaymentBatch?> getPaymentBatchByPayrollRunId(String payrollRunId) {
    return _getBatchByPayrollRunId(payrollRunId);
  }

  Future<List<EmployeePayment>> getEmployeePayments(String batchId) async {
    final ref = await companyCollection(_paymentCollection);
    final snapshot = await ref
        .where('paymentBatchId', isEqualTo: batchId)
        .orderBy('createdAt')
        .get();
    return snapshot.docs
        .map((doc) => EmployeePayment.fromJson(docData(doc)))
        .toList();
  }

  Future<PaymentBatch?> _getBatchByPayrollRunId(String payrollRunId) async {
    final ref = await companyCollection(_batchCollection);
    final snapshot = await ref
        .where('payrollRunId', isEqualTo: payrollRunId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return PaymentBatch.fromJson(docData(snapshot.docs.first));
  }

  Future<String> _beginBatchProcessing({
    required String companyId,
    required String batchId,
  }) async {
    final lockKey = 'payment_batch_process_$batchId';
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
            metadata: {'batchId': batchId, 'operation': 'processPaymentBatch'},
          );
      if (!shouldProceed) {
        throw Exception('Payment batch is already being processed.');
      }

      final batchDoc = await transaction.get(batchRef);
      final batchData = docDataNullable(batchDoc);
      if (batchData == null) {
        throw Exception('Payment batch not found.');
      }

      transaction.update(batchRef, {
        'status': PaymentBatchStatus.processing.name,
        'gatewayProvider': _gatewayProviderName,
      });
    });

    return lockKey;
  }

  Future<Map<String, Payroll>> _loadPayrollsForBatch(
    List<EmployeePayment> employeePayments,
  ) async {
    final payrollIds = employeePayments
        .map((payment) => payment.payrollId)
        .toSet();
    final payrollEntries = await Future.wait(
      payrollIds.map((payrollId) async {
        final payroll = await _payrollService.getPayrollById(payrollId);
        return MapEntry(payrollId, payroll);
      }),
    );

    return {
      for (final entry in payrollEntries)
        if (entry.value != null) entry.key: entry.value!,
    };
  }

  void _assertPayrollsReadyForPayment(
    List<EmployeePayment> employeePayments,
    Map<String, Payroll> payrollById,
  ) {
    final issues = <String>[];
    for (final payment in employeePayments) {
      if (payment.status == PaymentStatus.completed) {
        continue;
      }

      final payroll = payrollById[payment.payrollId];
      if (payroll == null) {
        issues.add('${payment.employeeName}: payroll record not found.');
        continue;
      }
      if (payroll.isReversal ||
          payroll.isReversed ||
          payroll.status == 'reversed') {
        issues.add('${payment.employeeName}: payroll is reversed.');
      }
      if (payroll.status == 'paid') {
        issues.add(
          '${payment.employeeName}: payroll is already marked as paid and needs reconciliation.',
        );
      }
      if (payroll.approvalStatus != PayrollApprovalStatus.approved) {
        issues.add('${payment.employeeName}: payroll is not fully approved.');
      }
    }

    if (issues.isNotEmpty) {
      throw Exception(
        'Payment batch cannot be processed until payroll approval issues are resolved: ${issues.join(' ')}',
      );
    }
  }

  Future<PaymentResult?> _reconcileProcessingPayment({
    required String companyId,
    required PaymentBatch batch,
    required EmployeePayment employeePayment,
    required Payroll payroll,
  }) async {
    final reference = _paymentReferenceFor(employeePayment);
    try {
      final statusResponse = await _gateway.checkPaymentStatus(reference);
      final gatewayReference =
          statusResponse.data?['transfer_code']?.toString() ??
          statusResponse.data?['reference']?.toString() ??
          employeePayment.gatewayReference;

      if (statusResponse.status == PaymentStatus.completed) {
        try {
          await _finalizeCompletedPayment(
            companyId: companyId,
            batch: batch,
            employeePayment: employeePayment,
            payroll: payroll,
            gatewayReference: gatewayReference,
            settledAt: DateTime.now(),
          );
          return PaymentResult(
            success: true,
            status: PaymentStatus.completed,
            reference: reference,
            gatewayReference: gatewayReference,
            message:
                'Recovered previously completed payment from gateway status.',
            data: statusResponse.data,
          );
        } catch (error) {
          final recoveryMessage =
              'Gateway transfer completed, but local settlement sync is pending: $error';
          await _updateEmployeePayment(
            employeePayment.id,
            status: PaymentStatus.processing,
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
        await _updateEmployeePayment(
          employeePayment.id,
          status: PaymentStatus.processing,
          gatewayReference: gatewayReference,
          failureReason: null,
        );
        return PaymentResult(
          success: true,
          status: PaymentStatus.processing,
          reference: reference,
          gatewayReference: gatewayReference,
          message: 'Payment is still processing on the gateway.',
          data: statusResponse.data,
        );
      }
    } catch (error) {
      return PaymentResult(
        success: true,
        status: PaymentStatus.processing,
        reference: reference,
        gatewayReference: employeePayment.gatewayReference,
        message:
            'Payment is already marked processing and could not be re-verified yet: $error',
      );
    }

    return null;
  }

  Future<void> _finalizeCompletedPayment({
    required String companyId,
    required PaymentBatch batch,
    required EmployeePayment employeePayment,
    required Payroll payroll,
    required DateTime settledAt,
    String? gatewayReference,
  }) async {
    final paymentRef = companyCollectionRef(
      companyId,
      _paymentCollection,
    ).doc(employeePayment.id);
    final payrollRef = companyCollectionRef(
      companyId,
      'payrolls',
    ).doc(payroll.id);
    final transactionsRef = companyCollectionRef(
      companyId,
      PayrollTransactionService.collectionName,
    );
    final settlement = _payrollTransactionService
        .buildSalarySettlementTransaction(
          payroll: payroll,
          payrollRunId: batch.payrollRunId,
          paymentId: employeePayment.id,
          amount: employeePayment.amount,
          settledAt: settledAt,
          gatewayReference: gatewayReference,
        );
    final settlementRef = transactionsRef.doc(settlement.id);

    await _transactionService.runTransaction<void>((transaction) async {
      final payrollDoc = await transaction.get(payrollRef);
      final payrollData = docDataNullable(payrollDoc);
      if (payrollData == null) {
        throw Exception('Payroll not found for payment ${employeePayment.id}.');
      }

      final latestPayroll = Payroll.fromJson(payrollData);
      if (latestPayroll.approvalStatus != PayrollApprovalStatus.approved &&
          latestPayroll.status != 'paid') {
        throw Exception(
          'Payroll ${latestPayroll.id} is no longer approved for payment.',
        );
      }
      if (latestPayroll.isLocked) {
        throw Exception('Payroll ${latestPayroll.id} is locked.');
      }

      final settlementDoc = await transaction.get(settlementRef);
      if (!settlementDoc.exists) {
        transaction.set(settlementRef, settlement.toJson());
      }

      transaction.update(paymentRef, {
        'status': PaymentStatus.completed.name,
        'gatewayReference': gatewayReference,
        'failureReason': null,
        'completedAt': Timestamp.fromDate(settledAt),
      });
      transaction.update(payrollRef, {
        'status': 'paid',
        'approvalStatus': PayrollApprovalStatus.processed.name,
      });
    });
  }

  BatchPaymentResult _buildBatchSummary(
    List<EmployeePayment> employeePayments,
  ) {
    final results = <PaymentResult>[];
    var successCount = 0;
    var failedCount = 0;

    for (final payment in employeePayments) {
      final success =
          payment.status != PaymentStatus.failed &&
          payment.status != PaymentStatus.reversed;
      if (success) {
        successCount++;
      } else {
        failedCount++;
      }

      results.add(
        PaymentResult(
          success: success,
          status: payment.status,
          reference: _paymentReferenceFor(payment),
          gatewayReference: payment.gatewayReference,
          message:
              payment.failureReason ?? _summaryMessageForStatus(payment.status),
        ),
      );
    }

    return BatchPaymentResult(
      totalCount: employeePayments.length,
      successCount: successCount,
      failedCount: failedCount,
      results: results,
    );
  }

  Future<void> _updateEmployeePayment(
    String paymentId, {
    required PaymentStatus status,
    String? gatewayReference,
    String? failureReason,
    DateTime? completedAt,
  }) async {
    final ref = await companyCollection(_paymentCollection);
    await ref.doc(paymentId).update({
      'status': status.name,
      'gatewayReference': gatewayReference,
      'failureReason': failureReason,
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt),
    });
  }

  PaymentBatchStatus _resolveBatchStatus({
    required int totalCount,
    required int completedCount,
    required int processingCount,
    required int failedCount,
  }) {
    if (completedCount == totalCount) {
      return PaymentBatchStatus.completed;
    }
    if (failedCount == totalCount) {
      return PaymentBatchStatus.failed;
    }
    if (processingCount > 0 && completedCount == 0 && failedCount == 0) {
      return PaymentBatchStatus.processing;
    }
    return PaymentBatchStatus.partiallyCompleted;
  }

  Future<Map<String, String>> _loadBankCodeMap() async {
    final resolved = <String, String>{..._fallbackBankCodes};
    try {
      final banks = await _gateway.getSupportedBanks();
      for (final bank in banks) {
        final normalized = _normalizeBankName(bank.name);
        if (normalized.isNotEmpty && bank.code.trim().isNotEmpty) {
          resolved[normalized] = bank.code.trim();
        }
      }
    } catch (_) {}
    return resolved;
  }

  String? _validatePaymentReadiness(EmployeePayment payment) {
    if (payment.amount <= 0) {
      return 'Payment amount must be greater than zero.';
    }
    if (payment.accountNumber.trim().isEmpty) {
      return 'Missing employee account number.';
    }
    if (payment.bankName.trim().isEmpty) {
      return 'Missing employee bank name.';
    }
    return null;
  }

  String _paymentReferenceFor(EmployeePayment payment) {
    return 'PAY-${payment.payrollId}';
  }

  String _summaryMessageForStatus(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.completed:
        return 'Payment completed.';
      case PaymentStatus.processing:
        return 'Payment is processing.';
      case PaymentStatus.pending:
        return 'Payment is pending.';
      case PaymentStatus.failed:
        return 'Payment failed.';
      case PaymentStatus.reversed:
        return 'Payment was reversed.';
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

  String _normalizeBankName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  }

  String get _gatewayProviderName {
    if (_gateway is PaystackGatewayService) {
      return 'paystack';
    }
    return 'custom';
  }

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
