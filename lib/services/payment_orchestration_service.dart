import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/models/deduction_payout_model.dart';
import 'package:roipayroll/models/payment_batch_model.dart';
import 'package:roipayroll/models/payment_orchestration_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/zoho_sync_config_model.dart';
import 'package:roipayroll/services/accounting_integration_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/deduction_payout_service.dart';
import 'package:roipayroll/services/payment_processing_service.dart';
import 'package:roipayroll/services/transaction_service.dart';
import 'package:roipayroll/services/zoho_books_service.dart';
import 'package:uuid/uuid.dart';

class PaymentOrchestrationService extends BaseService {
  static const String _collection = 'payment_orchestrations';
  static const String _settingsCollection = 'settings';
  static const String _zohoSettingsDoc = 'zoho_books';

  final PaymentProcessingService _paymentProcessingService;
  final DeductionPayoutService _deductionPayoutService;
  final AccountingIntegrationService _accountingIntegrationService =
      AccountingIntegrationService();
  final TransactionService _transactionService = TransactionService();

  PaymentOrchestrationService({
    PaymentProcessingService? paymentProcessingService,
    DeductionPayoutService? deductionPayoutService,
  }) : _paymentProcessingService =
           paymentProcessingService ?? PaymentProcessingService(),
       _deductionPayoutService =
           deductionPayoutService ?? DeductionPayoutService();

  Future<PaymentOrchestrationRun> orchestratePayrollRun({
    required List<Payroll> payrolls,
    required String payrollRunId,
    bool includeDeductionPayouts = true,
    bool syncToZoho = false,
    ZohoBooksService? zohoBooksService,
  }) async {
    if (payrolls.isEmpty) {
      throw Exception('At least one payroll is required for orchestration.');
    }

    final first = payrolls.first;
    final companyId = await getCompanyId();
    final orchestration = await _ensureOrchestrationRun(
      payrollRunId: payrollRunId,
      month: first.month,
      year: first.year,
      currency: first.currency,
    );
    final lockKey = 'payment_orchestration_$payrollRunId';

    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'payrollRunId': payrollRunId,
              'operation': 'orchestratePayrollRun',
            },
          );
      if (!shouldProceed) {
        throw Exception('Payroll run orchestration is already in progress.');
      }
    });

    PaymentBatch? salaryBatch;
    DeductionPayoutBatch? deductionBatch;
    ZohoJournalEntryResponse? zohoResponse;

    try {
      await _updateOrchestration(
        orchestration.id,
        status: PaymentOrchestrationStatus.salaryProcessing,
        failureReason: null,
      );

      salaryBatch = await _paymentProcessingService.createPaymentBatch(
        payrolls: payrolls,
        payrollRunId: payrollRunId,
      );
      await _paymentProcessingService.processPaymentBatch(
        batchId: salaryBatch.id,
      );
      salaryBatch = await _paymentProcessingService.getPaymentBatchById(
        salaryBatch.id,
      );

      await _updateOrchestration(
        orchestration.id,
        status: PaymentOrchestrationStatus.salaryCompleted,
        salaryBatchId: salaryBatch?.id,
        salaryBatchStatus: salaryBatch?.status,
      );

      if (includeDeductionPayouts) {
        await _updateOrchestration(
          orchestration.id,
          status: PaymentOrchestrationStatus.deductionProcessing,
        );
        deductionBatch = await _deductionPayoutService.createPayoutBatch(
          payrolls: payrolls,
          payrollRunId: payrollRunId,
        );
        if (deductionBatch != null) {
          await _deductionPayoutService.processPayoutBatch(
            batchId: deductionBatch.id,
          );
          deductionBatch = await _deductionPayoutService.getPayoutBatchById(
            deductionBatch.id,
          );
        }

        await _updateOrchestration(
          orchestration.id,
          status: PaymentOrchestrationStatus.deductionCompleted,
          deductionBatchId: deductionBatch?.id,
          deductionBatchStatus: deductionBatch?.status,
        );
      }

      if (syncToZoho) {
        zohoBooksService ??= await _loadZohoBooksService();

        await _updateOrchestration(
          orchestration.id,
          status: PaymentOrchestrationStatus.zohoSyncing,
          zohoSyncStatus: ExternalSyncStatus.processing,
        );
        zohoResponse = await _accountingIntegrationService.syncPayrollRunToZoho(
          payrollRunId: payrollRunId,
          zohoBooksService: zohoBooksService,
        );
      }

      final finalStatus = _resolveFinalStatus(
        salaryBatchStatus: salaryBatch?.status,
        deductionBatchStatus: deductionBatch?.status,
        zohoSyncStatus: syncToZoho
            ? (zohoResponse?.success == true
                  ? ExternalSyncStatus.completed
                  : ExternalSyncStatus.failed)
            : ExternalSyncStatus.skipped,
      );

      await _updateOrchestration(
        orchestration.id,
        status: finalStatus,
        salaryBatchId: salaryBatch?.id,
        salaryBatchStatus: salaryBatch?.status,
        deductionBatchId: deductionBatch?.id,
        deductionBatchStatus: deductionBatch?.status,
        zohoSyncStatus: syncToZoho
            ? (zohoResponse?.success == true
                  ? ExternalSyncStatus.completed
                  : ExternalSyncStatus.failed)
            : ExternalSyncStatus.skipped,
        zohoJournalId: zohoResponse?.journalId,
        zohoJournalNumber: zohoResponse?.journalNumber,
        failureReason: zohoResponse?.success == false
            ? zohoResponse?.error
            : null,
        completedAt: DateTime.now(),
      );
    } catch (error) {
      await _updateOrchestration(
        orchestration.id,
        status: PaymentOrchestrationStatus.failed,
        failureReason: error.toString(),
      );
      rethrow;
    } finally {
      try {
        await _transactionService.removeIdempotencyLock(companyId, lockKey);
      } catch (_) {}
    }

    final refreshed = await getById(orchestration.id);
    if (refreshed == null) {
      throw Exception('Payment orchestration run could not be reloaded.');
    }
    return refreshed;
  }

  Future<ZohoSyncConfig?> getZohoSyncConfig() async {
    final ref = await companyCollection(_settingsCollection);
    final doc = await ref.doc(_zohoSettingsDoc).get();
    final data = docDataNullable(doc);
    if (data == null) {
      return null;
    }
    return ZohoSyncConfig.fromJsonEncrypted(data);
  }

  Future<void> saveZohoSyncConfig(ZohoSyncConfig config) async {
    final validationError = config.validateConfiguration();
    if (validationError != null) {
      throw Exception(validationError);
    }

    final ref = await companyCollection(_settingsCollection);
    await ref.doc(_zohoSettingsDoc).set(await config.toJsonEncrypted());
  }

  Future<void> clearZohoSyncConfig() async {
    final ref = await companyCollection(_settingsCollection);
    await ref.doc(_zohoSettingsDoc).delete();
  }

  Future<PaymentOrchestrationRun> syncRunToZoho({
    required PaymentOrchestrationRun orchestration,
    ZohoBooksService? zohoBooksService,
  }) async {
    zohoBooksService ??= await _loadZohoBooksService();

    try {
      await _updateOrchestration(
        orchestration.id,
        status: PaymentOrchestrationStatus.zohoSyncing,
        zohoSyncStatus: ExternalSyncStatus.processing,
        failureReason: null,
      );

      final response = await _accountingIntegrationService.syncPayrollRunToZoho(
        payrollRunId: orchestration.payrollRunId,
        zohoBooksService: zohoBooksService,
      );
      final syncStatus = response.success
          ? ExternalSyncStatus.completed
          : ExternalSyncStatus.failed;
      final finalStatus = _resolveFinalStatus(
        salaryBatchStatus: orchestration.salaryBatchStatus,
        deductionBatchStatus: orchestration.deductionBatchStatus,
        zohoSyncStatus: syncStatus,
      );

      await _updateOrchestration(
        orchestration.id,
        status: finalStatus,
        zohoSyncStatus: syncStatus,
        zohoJournalId: response.journalId,
        zohoJournalNumber: response.journalNumber,
        failureReason: response.success ? null : response.error,
        completedAt: response.success ? DateTime.now() : null,
      );
    } catch (error) {
      final failedStatus = _resolveFinalStatus(
        salaryBatchStatus: orchestration.salaryBatchStatus,
        deductionBatchStatus: orchestration.deductionBatchStatus,
        zohoSyncStatus: ExternalSyncStatus.failed,
      );
      await _updateOrchestration(
        orchestration.id,
        status: failedStatus,
        zohoSyncStatus: ExternalSyncStatus.failed,
        failureReason: error.toString(),
      );
      rethrow;
    }

    final refreshed = await getById(orchestration.id);
    if (refreshed == null) {
      throw Exception('Payment orchestration run could not be reloaded.');
    }
    return refreshed;
  }

  Future<PaymentOrchestrationRun?> getById(String orchestrationId) async {
    final ref = await companyCollection(_collection);
    final doc = await ref.doc(orchestrationId).get();
    final data = docDataNullable(doc);
    return data == null ? null : PaymentOrchestrationRun.fromJson(data);
  }

  Future<PaymentOrchestrationRun?> getByPayrollRunId(
    String payrollRunId,
  ) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('payrollRunId', isEqualTo: payrollRunId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return null;
    }
    return PaymentOrchestrationRun.fromJson(docData(snapshot.docs.first));
  }

  Future<PaymentOrchestrationRun> ensureRunRecord({
    required List<Payroll> payrolls,
    required String payrollRunId,
  }) async {
    if (payrolls.isEmpty) {
      throw Exception('At least one payroll is required for orchestration.');
    }
    final first = payrolls.first;
    return _ensureOrchestrationRun(
      payrollRunId: payrollRunId,
      month: first.month,
      year: first.year,
      currency: first.currency,
    );
  }

  Future<PaymentOrchestrationRun> recordSalaryBatchResult({
    required List<Payroll> payrolls,
    required String payrollRunId,
    required PaymentBatch batch,
  }) async {
    final orchestration = await ensureRunRecord(
      payrolls: payrolls,
      payrollRunId: payrollRunId,
    );
    final status = switch (batch.status) {
      PaymentBatchStatus.completed =>
        PaymentOrchestrationStatus.salaryCompleted,
      PaymentBatchStatus.processing =>
        PaymentOrchestrationStatus.salaryProcessing,
      PaymentBatchStatus.pending => PaymentOrchestrationStatus.pending,
      PaymentBatchStatus.failed => PaymentOrchestrationStatus.failed,
      PaymentBatchStatus.partiallyCompleted =>
        PaymentOrchestrationStatus.partiallyCompleted,
    };

    await _updateOrchestration(
      orchestration.id,
      status: status,
      salaryBatchId: batch.id,
      salaryBatchStatus: batch.status,
      failureReason: batch.status == PaymentBatchStatus.failed
          ? 'Salary batch failed.'
          : null,
      completedAt: batch.status == PaymentBatchStatus.completed
          ? DateTime.now()
          : null,
    );

    final refreshed = await getById(orchestration.id);
    if (refreshed == null) {
      throw Exception('Payment orchestration run could not be reloaded.');
    }
    return refreshed;
  }

  Future<PaymentOrchestrationRun> recordDeductionBatchResult({
    required List<Payroll> payrolls,
    required String payrollRunId,
    required DeductionPayoutBatch batch,
  }) async {
    final orchestration = await ensureRunRecord(
      payrolls: payrolls,
      payrollRunId: payrollRunId,
    );
    final status = switch (batch.status) {
      DeductionPayoutBatchStatus.completed =>
        PaymentOrchestrationStatus.deductionCompleted,
      DeductionPayoutBatchStatus.processing =>
        PaymentOrchestrationStatus.deductionProcessing,
      DeductionPayoutBatchStatus.pending => PaymentOrchestrationStatus.pending,
      DeductionPayoutBatchStatus.failed => PaymentOrchestrationStatus.failed,
      DeductionPayoutBatchStatus.partiallyCompleted =>
        PaymentOrchestrationStatus.partiallyCompleted,
    };

    await _updateOrchestration(
      orchestration.id,
      status: status,
      deductionBatchId: batch.id,
      deductionBatchStatus: batch.status,
      failureReason: batch.status == DeductionPayoutBatchStatus.failed
          ? 'Deduction batch failed.'
          : null,
      completedAt: batch.status == DeductionPayoutBatchStatus.completed
          ? DateTime.now()
          : null,
    );

    final refreshed = await getById(orchestration.id);
    if (refreshed == null) {
      throw Exception('Payment orchestration run could not be reloaded.');
    }
    return refreshed;
  }

  Future<PaymentOrchestrationRun> syncPayrollRunToZoho({
    required List<Payroll> payrolls,
    required String payrollRunId,
    ZohoBooksService? zohoBooksService,
  }) async {
    final orchestration = await ensureRunRecord(
      payrolls: payrolls,
      payrollRunId: payrollRunId,
    );
    return syncRunToZoho(
      orchestration: orchestration,
      zohoBooksService: zohoBooksService,
    );
  }

  Future<List<PaymentOrchestrationRun>> getRunsForPeriod({
    required int month,
    required int year,
  }) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();
    final runs = snapshot.docs
        .map((doc) => PaymentOrchestrationRun.fromJson(docData(doc)))
        .toList();
    runs.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return runs;
  }

  Future<PaymentOrchestrationRun> _ensureOrchestrationRun({
    required String payrollRunId,
    required int month,
    required int year,
    required String currency,
  }) async {
    final existing = await getByPayrollRunId(payrollRunId);
    if (existing != null) {
      return existing;
    }

    final run = PaymentOrchestrationRun(
      id: const Uuid().v4(),
      payrollRunId: payrollRunId,
      month: month,
      year: year,
      currency: currency,
      status: PaymentOrchestrationStatus.pending,
      zohoSyncStatus: ExternalSyncStatus.notStarted,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final ref = await companyCollection(_collection);
    await ref.doc(run.id).set(run.toJson());
    return run;
  }

  Future<ZohoBooksService> _loadZohoBooksService() async {
    try {
      final companyId = await getCompanyId();
      final settingsRef = companyCollectionRef(companyId, _settingsCollection);
      final doc = await settingsRef.doc(_zohoSettingsDoc).get();
      if (!doc.exists) {
        throw Exception(
          'Zoho Books is not configured. Open Payment Operations and add your organization credentials first.',
        );
      }

      final config = await ZohoSyncConfig.fromJsonEncrypted(docData(doc));
      final validationError = config.validateConfiguration();
      if (validationError != null) {
        throw Exception(
          'Zoho Books configuration is invalid: $validationError',
        );
      }

      if (!config.isConfigured) {
        throw Exception(
          'Zoho Books credentials are incomplete. Please reconnect the integration.',
        );
      }

      return ZohoBooksService(
        organizationId: config.organizationId,
        authToken: config.authToken,
        refreshToken: config.refreshToken,
        tokenExpiresAt: config.tokenExpiresAt,
        baseUrl: config.baseUrl,
        accountMapping: config.accountMapping,
        onTokenRefreshed: (newToken, expiresAt) async {
          await _updateZohoToken(
            companyId: companyId,
            newToken: newToken,
            expiresAt: expiresAt,
          );
        },
      );
    } catch (error) {
      debugPrint('Failed to load Zoho Books service: $error');
      rethrow;
    }
  }

  Future<void> _updateZohoToken({
    required String companyId,
    required String newToken,
    required DateTime expiresAt,
  }) async {
    try {
      final settingsRef = companyCollectionRef(companyId, _settingsCollection);
      final doc = await settingsRef.doc(_zohoSettingsDoc).get();
      if (!doc.exists) {
        return;
      }

      final config = await ZohoSyncConfig.fromJsonEncrypted(docData(doc));
      final updatedConfig = config.copyWith(
        authToken: newToken,
        tokenExpiresAt: expiresAt,
        updatedAt: DateTime.now(),
      );
      await settingsRef
          .doc(_zohoSettingsDoc)
          .set(await updatedConfig.toJsonEncrypted());
      debugPrint('Zoho token updated successfully.');
    } catch (error) {
      debugPrint('Failed to persist refreshed Zoho token: $error');
    }
  }

  Future<void> _updateOrchestration(
    String orchestrationId, {
    PaymentOrchestrationStatus? status,
    String? salaryBatchId,
    PaymentBatchStatus? salaryBatchStatus,
    String? deductionBatchId,
    DeductionPayoutBatchStatus? deductionBatchStatus,
    ExternalSyncStatus? zohoSyncStatus,
    String? zohoJournalId,
    String? zohoJournalNumber,
    String? failureReason,
    DateTime? completedAt,
  }) async {
    final ref = await companyCollection(_collection);
    await ref.doc(orchestrationId).update({
      ...?status == null ? null : {'status': status.name},
      ...?salaryBatchId == null ? null : {'salaryBatchId': salaryBatchId},
      ...?salaryBatchStatus == null
          ? null
          : {'salaryBatchStatus': salaryBatchStatus.name},
      ...?deductionBatchId == null
          ? null
          : {'deductionBatchId': deductionBatchId},
      ...?deductionBatchStatus == null
          ? null
          : {'deductionBatchStatus': deductionBatchStatus.name},
      ...?zohoSyncStatus == null
          ? null
          : {'zohoSyncStatus': zohoSyncStatus.name},
      ...?zohoJournalId == null ? null : {'zohoJournalId': zohoJournalId},
      ...?zohoJournalNumber == null
          ? null
          : {'zohoJournalNumber': zohoJournalNumber},
      'failureReason': failureReason,
      'updatedAt': FieldValue.serverTimestamp(),
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt),
    });
  }

  PaymentOrchestrationStatus _resolveFinalStatus({
    required PaymentBatchStatus? salaryBatchStatus,
    required DeductionPayoutBatchStatus? deductionBatchStatus,
    required ExternalSyncStatus zohoSyncStatus,
  }) {
    final hasSalaryFailure = salaryBatchStatus == PaymentBatchStatus.failed;
    final hasSalaryPartial =
        salaryBatchStatus == PaymentBatchStatus.partiallyCompleted ||
        salaryBatchStatus == PaymentBatchStatus.processing;
    final hasDeductionFailure =
        deductionBatchStatus == DeductionPayoutBatchStatus.failed;
    final hasDeductionPartial =
        deductionBatchStatus == DeductionPayoutBatchStatus.partiallyCompleted ||
        deductionBatchStatus == DeductionPayoutBatchStatus.processing;
    final hasZohoFailure = zohoSyncStatus == ExternalSyncStatus.failed;

    if (hasSalaryFailure &&
        deductionBatchStatus == null &&
        (zohoSyncStatus == ExternalSyncStatus.skipped ||
            zohoSyncStatus == ExternalSyncStatus.notStarted)) {
      return PaymentOrchestrationStatus.failed;
    }

    if (hasSalaryFailure || hasDeductionFailure || hasZohoFailure) {
      return PaymentOrchestrationStatus.partiallyCompleted;
    }

    if (hasSalaryPartial || hasDeductionPartial) {
      return PaymentOrchestrationStatus.partiallyCompleted;
    }

    return PaymentOrchestrationStatus.completed;
  }
}
