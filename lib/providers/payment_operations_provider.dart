import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/deduction_payout_model.dart';
import 'package:roipayroll/models/payment_batch_model.dart';
import 'package:roipayroll/models/payment_orchestration_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/payroll_transaction_model.dart';
import 'package:roipayroll/models/zoho_sync_config_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/payroll_provider.dart';
import 'package:roipayroll/services/deduction_payout_service.dart';
import 'package:roipayroll/services/payment_orchestration_service.dart';
import 'package:roipayroll/services/payment_processing_service.dart';
import 'package:roipayroll/services/payroll_service.dart';
import 'package:roipayroll/services/payroll_transaction_service.dart';

class PaymentRunCandidate {
  final String payrollRunId;
  final List<Payroll> payrolls;
  final double totalNetAmount;
  final int eligiblePayrollCount;
  final int paidPayrollCount;

  const PaymentRunCandidate({
    required this.payrollRunId,
    required this.payrolls,
    required this.totalNetAmount,
    required this.eligiblePayrollCount,
    required this.paidPayrollCount,
  });

  bool get hasEligiblePayrolls => eligiblePayrollCount > 0;
}

class PaymentOperationsSummary {
  final List<PaymentRunCandidate> runCandidates;
  final List<PaymentBatch> salaryBatches;
  final List<DeductionPayoutBatch> deductionBatches;
  final List<PaymentOrchestrationRun> orchestrationRuns;
  final List<PayoutRecipientConfig> recipients;
  final ZohoSyncConfig? zohoConfig;
  final List<PaymentReconciliationRow> reconciliationRows;

  const PaymentOperationsSummary({
    required this.runCandidates,
    required this.salaryBatches,
    required this.deductionBatches,
    required this.orchestrationRuns,
    required this.recipients,
    required this.zohoConfig,
    required this.reconciliationRows,
  });
}

class PaymentReconciliationRow {
  final String payrollRunId;
  final int payrollCount;
  final double totalNetAmount;
  final int accrualTransactionCount;
  final int salarySettlementCount;
  final int expectedSalarySettlementCount;
  final int deductionSettlementCount;
  final int expectedDeductionSettlementCount;
  final double deductionLiabilityAmountBase;
  final PaymentBatchStatus? salaryBatchStatus;
  final DeductionPayoutBatchStatus? deductionBatchStatus;
  final ExternalSyncStatus zohoSyncStatus;
  final String? zohoJournalReference;
  final List<String> issues;

  const PaymentReconciliationRow({
    required this.payrollRunId,
    required this.payrollCount,
    required this.totalNetAmount,
    required this.accrualTransactionCount,
    required this.salarySettlementCount,
    required this.expectedSalarySettlementCount,
    required this.deductionSettlementCount,
    required this.expectedDeductionSettlementCount,
    required this.deductionLiabilityAmountBase,
    required this.salaryBatchStatus,
    required this.deductionBatchStatus,
    required this.zohoSyncStatus,
    required this.zohoJournalReference,
    required this.issues,
  });

  bool get isFullyReconciled => issues.isEmpty;
}

final paymentOperationsProvider =
    FutureProvider.family<PaymentOperationsSummary, PayrollPeriod>((
      ref,
      period,
    ) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);

      final payrollService = PayrollService();
      final transactionService = PayrollTransactionService();
      final paymentProcessingService = PaymentProcessingService();
      final deductionPayoutService = DeductionPayoutService();
      final orchestrationService = PaymentOrchestrationService();

      final results = await Future.wait<dynamic>([
        payrollService.getPayrollsByMonth(period.month, period.year),
        transactionService.getTransactionsForPeriod(
          month: period.month,
          year: period.year,
        ),
        paymentProcessingService.getPaymentBatchesForPeriod(
          month: period.month,
          year: period.year,
        ),
        deductionPayoutService.getPayoutBatchesForPeriod(
          month: period.month,
          year: period.year,
        ),
        orchestrationService.getRunsForPeriod(
          month: period.month,
          year: period.year,
        ),
        deductionPayoutService.getRecipientConfigs(),
        orchestrationService.getZohoSyncConfig(),
      ]);

      final payrolls = results[0] as List<Payroll>;
      final transactions = results[1] as List<PayrollTransaction>;
      final salaryBatches = results[2] as List<PaymentBatch>;
      final deductionBatches = results[3] as List<DeductionPayoutBatch>;
      final orchestrationRuns = results[4] as List<PaymentOrchestrationRun>;
      final recipients = results[5] as List<PayoutRecipientConfig>;
      final zohoConfig = results[6] as ZohoSyncConfig?;

      final runIdByPayrollId = <String, String>{};
      for (final transaction in transactions) {
        if (transaction.payrollId.trim().isEmpty ||
            transaction.payrollRunId.trim().isEmpty) {
          continue;
        }
        runIdByPayrollId.putIfAbsent(
          transaction.payrollId,
          () => transaction.payrollRunId,
        );
      }

      final payrollsByRunId = <String, List<Payroll>>{};
      for (final payroll in payrolls) {
        final runId =
            runIdByPayrollId[payroll.id] ??
            'manual-${payroll.year}${payroll.month.toString().padLeft(2, '0')}-${payroll.id.substring(0, payroll.id.length > 8 ? 8 : payroll.id.length)}';
        payrollsByRunId.putIfAbsent(runId, () => <Payroll>[]).add(payroll);
      }

      final runCandidates = payrollsByRunId.entries.map((entry) {
        final runPayrolls = entry.value
          ..sort(
            (a, b) => a.employeeName.toLowerCase().compareTo(
              b.employeeName.toLowerCase(),
            ),
          );
        final eligiblePayrolls = runPayrolls.where((payroll) {
          if (payroll.isReversal || payroll.isReversed) return false;
          if (payroll.status == 'reversed' || payroll.status == 'paid') {
            return false;
          }
          return payroll.approvalStatus == PayrollApprovalStatus.approved;
        }).toList();
        final paidCount = runPayrolls
            .where((payroll) => payroll.status == 'paid')
            .length;
        return PaymentRunCandidate(
          payrollRunId: entry.key,
          payrolls: runPayrolls,
          totalNetAmount: runPayrolls.fold<double>(
            0.0,
            (sum, payroll) => sum + payroll.netSalary,
          ),
          eligiblePayrollCount: eligiblePayrolls.length,
          paidPayrollCount: paidCount,
        );
      }).toList()..sort((a, b) => b.payrollRunId.compareTo(a.payrollRunId));

      final salaryBatchByRunId = {
        for (final batch in salaryBatches) batch.payrollRunId: batch,
      };
      final deductionBatchByRunId = {
        for (final batch in deductionBatches) batch.payrollRunId: batch,
      };
      final orchestrationByRunId = {
        for (final run in orchestrationRuns) run.payrollRunId: run,
      };
      final transactionsByRunId = <String, List<PayrollTransaction>>{};
      for (final transaction in transactions) {
        final runId = transaction.payrollRunId.trim();
        if (runId.isEmpty) {
          continue;
        }
        transactionsByRunId
            .putIfAbsent(runId, () => <PayrollTransaction>[])
            .add(transaction);
      }

      final reconciliationRows =
          runCandidates.map((candidate) {
            final runTransactions =
                transactionsByRunId[candidate.payrollRunId] ??
                const <PayrollTransaction>[];
            final salaryBatch = salaryBatchByRunId[candidate.payrollRunId];
            final deductionBatch =
                deductionBatchByRunId[candidate.payrollRunId];
            final orchestration = orchestrationByRunId[candidate.payrollRunId];

            final accrualTransactions = runTransactions.where((transaction) {
              switch (transaction.type) {
                case TransactionType.salary:
                case TransactionType.reimbursement:
                case TransactionType.incentive:
                case TransactionType.paye:
                case TransactionType.pension:
                case TransactionType.nhf:
                case TransactionType.loan:
                case TransactionType.advance:
                case TransactionType.deduction:
                  return true;
                case TransactionType.salaryPayment:
                case TransactionType.deductionPayment:
                  return false;
              }
            }).toList();

            final salarySettlementCount = runTransactions
                .where(
                  (transaction) =>
                      transaction.type == TransactionType.salaryPayment,
                )
                .length;
            final deductionSettlementCount = runTransactions
                .where(
                  (transaction) =>
                      transaction.type == TransactionType.deductionPayment,
                )
                .length;
            final deductionLiabilityAmountBase = runTransactions
                .where((transaction) {
                  switch (transaction.type) {
                    case TransactionType.paye:
                    case TransactionType.pension:
                    case TransactionType.nhf:
                    case TransactionType.loan:
                    case TransactionType.advance:
                    case TransactionType.deduction:
                      return transaction.amountBase.abs() > 0.009;
                    case TransactionType.salary:
                    case TransactionType.salaryPayment:
                    case TransactionType.deductionPayment:
                    case TransactionType.reimbursement:
                    case TransactionType.incentive:
                      return false;
                  }
                })
                .fold<double>(
                  0.0,
                  (sum, transaction) => sum + transaction.amountBase,
                );

            final expectedSalarySettlements =
                salaryBatch?.totalEmployees ?? candidate.paidPayrollCount;
            final expectedDeductionSettlements =
                deductionBatch?.totalPayouts ?? 0;
            final issues = <String>[];

            if (salaryBatch == null && candidate.paidPayrollCount > 0) {
              issues.add('Salary paid but no salary batch record found');
            }
            if (salaryBatch != null &&
                salaryBatch.status != PaymentBatchStatus.completed) {
              issues.add('Salary batch is ${salaryBatch.status.name}');
            }
            if (expectedSalarySettlements > 0 &&
                salarySettlementCount < expectedSalarySettlements) {
              issues.add(
                'Salary settlements missing ($salarySettlementCount/$expectedSalarySettlements)',
              );
            }

            if (deductionLiabilityAmountBase > 0.009) {
              if (deductionBatch == null) {
                issues.add(
                  'Deduction liabilities exist but no remittance batch found',
                );
              } else if (deductionBatch.status !=
                  DeductionPayoutBatchStatus.completed) {
                issues.add('Deduction batch is ${deductionBatch.status.name}');
              }
              if (expectedDeductionSettlements > 0 &&
                  deductionSettlementCount < expectedDeductionSettlements) {
                issues.add(
                  'Deduction settlements missing ($deductionSettlementCount/$expectedDeductionSettlements)',
                );
              }
            }

            final zohoSyncStatus =
                orchestration?.zohoSyncStatus ?? ExternalSyncStatus.notStarted;
            final zohoReference =
                orchestration?.zohoJournalNumber?.trim().isNotEmpty == true
                ? orchestration!.zohoJournalNumber
                : orchestration?.zohoJournalId;

            if (zohoSyncStatus != ExternalSyncStatus.completed) {
              issues.add('Zoho sync is ${zohoSyncStatus.name}');
            }

            return PaymentReconciliationRow(
              payrollRunId: candidate.payrollRunId,
              payrollCount: candidate.payrolls.length,
              totalNetAmount: candidate.totalNetAmount,
              accrualTransactionCount: accrualTransactions.length,
              salarySettlementCount: salarySettlementCount,
              expectedSalarySettlementCount: expectedSalarySettlements,
              deductionSettlementCount: deductionSettlementCount,
              expectedDeductionSettlementCount: expectedDeductionSettlements,
              deductionLiabilityAmountBase: deductionLiabilityAmountBase,
              salaryBatchStatus: salaryBatch?.status,
              deductionBatchStatus: deductionBatch?.status,
              zohoSyncStatus: zohoSyncStatus,
              zohoJournalReference: zohoReference,
              issues: issues,
            );
          }).toList()..sort((a, b) {
            if (a.isFullyReconciled == b.isFullyReconciled) {
              return b.payrollRunId.compareTo(a.payrollRunId);
            }
            return a.isFullyReconciled ? 1 : -1;
          });

      return PaymentOperationsSummary(
        runCandidates: runCandidates,
        salaryBatches: salaryBatches,
        deductionBatches: deductionBatches,
        orchestrationRuns: orchestrationRuns,
        recipients: recipients,
        zohoConfig: zohoConfig,
        reconciliationRows: reconciliationRows,
      );
    });
