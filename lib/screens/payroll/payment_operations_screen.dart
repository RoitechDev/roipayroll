import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/csv_file_helper.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/deduction_payout_model.dart';
import 'package:roipayroll/models/payment_batch_model.dart';
import 'package:roipayroll/models/payment_orchestration_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/payroll_transaction_model.dart';
import 'package:roipayroll/models/zoho_sync_config_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/payment_operations_provider.dart';
import 'package:roipayroll/providers/payroll_provider.dart';
import 'package:roipayroll/services/deduction_payout_service.dart';
import 'package:roipayroll/services/payment_orchestration_service.dart';
import 'package:roipayroll/services/payment_processing_service.dart';
import 'package:roipayroll/services/payroll_transaction_service.dart';
import 'package:roipayroll/services/zoho_books_service.dart';
import 'package:roipayroll/services/zoho_oauth_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

class PaymentOperationsScreen extends ConsumerStatefulWidget {
  const PaymentOperationsScreen({super.key});

  @override
  ConsumerState<PaymentOperationsScreen> createState() =>
      _PaymentOperationsScreenState();
}

class _PaymentOperationsScreenState
    extends ConsumerState<PaymentOperationsScreen> {
  static final DateFormat _dateFormat = DateFormat('MMM d, y h:mm a');

  final _deductionPayoutService = DeductionPayoutService();
  final _orchestrationService = PaymentOrchestrationService();
  final _paymentProcessingService = PaymentProcessingService();
  final _payrollTransactionService = PayrollTransactionService();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String? _busyRunId;
  String? _salaryRunId;
  String? _deductionRunId;
  String? _retryingSalaryBatchId;
  String? _retryingDeductionBatchId;
  String? _syncingZohoRunId;
  String? _togglingRecipientId;
  bool _savingRecipient = false;
  bool _savingZohoConfig = false;

  @override
  Widget build(BuildContext context) {
    final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
    final summaryAsync = ref.watch(paymentOperationsProvider(period));

    return AppScaffold(
      topBar: AppBar(
        title: const Text('Payment Operations'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(paymentOperationsProvider(period)),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            child: summaryAsync.when(
              loading: () => const ModernLoadingState(
                message: 'Loading payment operations...',
              ),
              error: (error, _) => ModernErrorState(
                message: 'Failed to load payment operations',
                subtitle: error.toString(),
                onRetry: () =>
                    ref.invalidate(paymentOperationsProvider(period)),
              ),
              data: (summary) => _buildContent(summary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final monthField = DropdownButtonFormField<int>(
      initialValue: _selectedMonth,
      decoration: const InputDecoration(labelText: 'Month'),
      items: List.generate(12, (i) {
        return DropdownMenuItem(value: i + 1, child: Text(_monthName(i + 1)));
      }),
      onChanged: (value) => setState(() => _selectedMonth = value!),
    );
    final yearField = DropdownButtonFormField<int>(
      initialValue: _selectedYear,
      decoration: const InputDecoration(labelText: 'Year'),
      items: List.generate(5, (i) {
        final year = DateTime.now().year - 2 + i;
        return DropdownMenuItem(value: year, child: Text('$year'));
      }),
      onChanged: (value) => setState(() => _selectedYear = value!),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ResponsiveLayout(
        mobile: Column(
          children: [monthField, const SizedBox(height: 12), yearField],
        ),
        tablet: Row(
          children: [
            Expanded(child: monthField),
            const SizedBox(width: 16),
            Expanded(child: yearField),
          ],
        ),
        desktop: Row(
          children: [
            Expanded(child: monthField),
            const SizedBox(width: 16),
            Expanded(child: yearField),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(PaymentOperationsSummary summary) {
    final runMap = {
      for (final run in summary.orchestrationRuns) run.payrollRunId: run,
    };
    final salaryBatchMap = {
      for (final batch in summary.salaryBatches) batch.id: batch,
    };
    final deductionBatchMap = {
      for (final batch in summary.deductionBatches) batch.id: batch,
    };
    final zohoConfigured = summary.zohoConfig?.isReadyForSync == true;
    final unreconciledCount = summary.reconciliationRows
        .where((row) => !row.isFullyReconciled)
        .length;
    final activeRecipients = summary.recipients
        .where((recipient) => recipient.isActive)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        ModernMetricsGrid(
          metrics: [
            ModernMetricCard(
              title: 'Payroll Runs',
              value: summary.runCandidates.length.toString(),
              icon: Icons.layers_outlined,
              color: AppColors.primary,
            ),
            ModernMetricCard(
              title: 'Salary Batches',
              value: summary.salaryBatches.length.toString(),
              icon: Icons.payments_outlined,
              color: AppColors.success,
            ),
            ModernMetricCard(
              title: 'Deduction Batches',
              value: summary.deductionBatches.length.toString(),
              icon: Icons.account_balance_outlined,
              color: AppColors.warning,
            ),
            ModernMetricCard(
              title: 'Recipients',
              value: '${activeRecipients.length}/${summary.recipients.length}',
              icon: Icons.business_center_outlined,
              color: AppColors.info,
            ),
            ModernMetricCard(
              title: 'Zoho Sync',
              value: zohoConfigured ? 'Ready' : 'Setup',
              icon: Icons.sync_alt_outlined,
              color: zohoConfigured ? AppColors.success : AppColors.warning,
            ),
            ModernMetricCard(
              title: 'Reconcile',
              value: '$unreconciledCount',
              icon: Icons.rule_folder_outlined,
              color: unreconciledCount == 0
                  ? AppColors.success
                  : AppColors.warning,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildZohoSection(summary.zohoConfig),
        const SizedBox(height: 16),
        _buildRecipientSection(summary.recipients),
        const SizedBox(height: 16),
        _buildRunSection(
          summary.runCandidates,
          runMap,
          activeRecipients,
          zohoConfigured,
        ),
        const SizedBox(height: 16),
        _buildReconciliationSection(summary.reconciliationRows),
        const SizedBox(height: 16),
        _buildOrchestrationSection(
          summary.orchestrationRuns,
          salaryBatchMap,
          deductionBatchMap,
          zohoConfigured,
        ),
        const SizedBox(height: 16),
        _buildSalaryBatchSection(summary.salaryBatches),
        const SizedBox(height: 16),
        _buildDeductionBatchSection(summary.deductionBatches),
      ],
    );
  }

  Widget _buildReconciliationSection(List<PaymentReconciliationRow> rows) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Reconciliation',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: rows.isEmpty
                      ? null
                      : () => _exportReconciliationCsv(rows),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'One row per payroll run showing batch status, settlement coverage, and Zoho journal state.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const ModernEmptyState(
                icon: Icons.rule_folder_outlined,
                title: 'No payroll runs available for reconciliation',
              )
            else
              ...rows.map(
                (row) => InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showReconciliationDetails(row),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: row.isFullyReconciled
                            ? AppColors.success.withValues(alpha: 0.35)
                            : AppColors.warning.withValues(alpha: 0.35),
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.payrollRunId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _buildStatusChip(
                              label: row.isFullyReconciled
                                  ? 'reconciled'
                                  : 'attention',
                              color: row.isFullyReconciled
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text('${row.payrollCount} payrolls'),
                            Text(
                              'Net: ${CurrencyFormatter.formatNaira(row.totalNetAmount)}',
                            ),
                            Text('Entries: ${row.accrualTransactionCount}'),
                            Text(
                              'Salary settlements: ${row.salarySettlementCount}/${row.expectedSalarySettlementCount}',
                            ),
                            Text(
                              'Deduction settlements: ${row.deductionSettlementCount}/${row.expectedDeductionSettlementCount}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMiniStateChip(
                              'Salary ${row.salaryBatchStatus?.name ?? 'none'}',
                              row.salaryBatchStatus ==
                                      PaymentBatchStatus.completed
                                  ? AppColors.success
                                  : row.salaryBatchStatus == null
                                  ? AppColors.textSecondary
                                  : AppColors.warning,
                            ),
                            _buildMiniStateChip(
                              'Deductions ${row.deductionBatchStatus?.name ?? 'none'}',
                              row.expectedDeductionSettlementCount == 0 &&
                                      row.deductionLiabilityAmountBase <= 0.009
                                  ? AppColors.textSecondary
                                  : row.deductionBatchStatus ==
                                        DeductionPayoutBatchStatus.completed
                                  ? AppColors.success
                                  : row.deductionBatchStatus == null
                                  ? AppColors.warning
                                  : AppColors.warning,
                            ),
                            _buildMiniStateChip(
                              'Zoho ${row.zohoSyncStatus.name}',
                              row.zohoSyncStatus == ExternalSyncStatus.completed
                                  ? AppColors.success
                                  : row.zohoSyncStatus ==
                                        ExternalSyncStatus.skipped
                                  ? AppColors.textSecondary
                                  : AppColors.warning,
                            ),
                          ],
                        ),
                        if ((row.zohoJournalReference ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Journal: ${row.zohoJournalReference}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (row.issues.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: row.issues
                                .map(
                                  (issue) => _buildMiniStateChip(
                                    issue,
                                    AppColors.warning,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Tap for details',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientSection(List<PayoutRecipientConfig> recipients) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Payout Recipients',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _savingRecipient
                      ? null
                      : () => _openRecipientDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Recipient'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${recipients.where((recipient) => recipient.isActive).length} active of ${recipients.length} configured recipients.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (recipients.isEmpty)
              const ModernEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No payout recipients configured',
                subtitle:
                    'Add at least one recipient before running deduction remittances.',
              )
            else
              ...recipients.map(
                (recipient) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.info.withValues(alpha: 0.12),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: AppColors.info,
                    ),
                  ),
                  title: Text(recipient.name),
                  subtitle: Text(
                    '${recipient.key} | ${recipient.bankName} | ${recipient.accountNumber}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!recipient.isActive)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Text(
                            'Inactive',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Switch.adaptive(
                        value: recipient.isActive,
                        onChanged:
                            _togglingRecipientId != null || _savingRecipient
                            ? null
                            : (value) =>
                                  _toggleRecipientStatus(recipient, value),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed:
                            _savingRecipient || _togglingRecipientId != null
                            ? null
                            : () => _openRecipientDialog(existing: recipient),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZohoSection(ZohoSyncConfig? config) {
    final validationError = config?.validateConfiguration();
    final isConfigured = config?.isReadyForSync == true;
    final activeConfig = config;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Zoho Books Sync',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _savingZohoConfig
                      ? null
                      : () => _openZohoConfigDialog(existing: config),
                  icon: const Icon(Icons.settings_outlined),
                  label: Text(isConfigured ? 'Edit Config' : 'Configure'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isConfigured
                  ? 'Organization ${config!.organizationId} is ready for payroll journal sync.'
                  : validationError != null
                  ? 'Zoho Books is configured but still needs attention before payroll journals can sync.'
                  : 'Add Zoho Books credentials to enable in-app accounting sync and retries.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (activeConfig == null)
              const ModernEmptyState(
                icon: Icons.sync_problem_outlined,
                title: 'Zoho Books is not configured',
                subtitle:
                    'Configure organization credentials, refresh token, and account mappings before enabling sync.',
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isConfigured ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organization ID: ${activeConfig.organizationId}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Token: ${activeConfig.maskedToken}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      activeConfig.canRefreshToken
                          ? 'Refresh token: configured'
                          : 'Refresh token: not configured',
                      style: TextStyle(
                        color: activeConfig.canRefreshToken
                            ? AppColors.textSecondary
                            : AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Endpoint: ${activeConfig.baseUrl}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mapped accounts: ${activeConfig.accountMapping.length}/${ZohoSyncConfig.supportedAccounts.length}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (activeConfig.tokenExpiresAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        activeConfig.isTokenExpired
                            ? 'Access token expired'
                            : 'Access token expires: ${_dateFormat.format(activeConfig.tokenExpiresAt!.toLocal())}',
                        style: TextStyle(
                          color: activeConfig.isTokenExpired
                              ? AppColors.warning
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (activeConfig.lastValidatedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last validated: ${_dateFormat.format(activeConfig.lastValidatedAt!.toLocal())}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    if (activeConfig.lastSyncedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Last synced: ${_dateFormat.format(activeConfig.lastSyncedAt!.toLocal())}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      'Updated: ${_dateFormat.format(activeConfig.updatedAt.toLocal())}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationError,
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunSection(
    List<PaymentRunCandidate> runCandidates,
    Map<String, PaymentOrchestrationRun> runMap,
    List<PayoutRecipientConfig> recipients,
    bool zohoConfigured,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payroll Runs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Run salary payments and deduction remittances per payroll run so operations stay aligned with accounting transactions.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (runCandidates.isEmpty)
              const ModernEmptyState(
                icon: Icons.layers_clear_outlined,
                title: 'No payroll runs found for this period',
              )
            else
              ...runCandidates.map((candidate) {
                final orchestration = runMap[candidate.payrollRunId];
                final recipientsConfigured = recipients.isNotEmpty;
                return _buildRunCard(
                  candidate: candidate,
                  orchestration: orchestration,
                  recipientsConfigured: recipientsConfigured,
                  zohoConfigured: zohoConfigured,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRunCard({
    required PaymentRunCandidate candidate,
    required PaymentOrchestrationRun? orchestration,
    required bool recipientsConfigured,
    required bool zohoConfigured,
  }) {
    final orchestrationStatus = orchestration?.status;
    final isRunning = _busyRunId == candidate.payrollRunId;
    final isSalaryRunning = _salaryRunId == candidate.payrollRunId;
    final isDeductionRunning = _deductionRunId == candidate.payrollRunId;
    final isZohoRunning = _syncingZohoRunId == candidate.payrollRunId;
    final hasAnyStepRunning =
        isRunning || isSalaryRunning || isDeductionRunning || isZohoRunning;
    final canRun = candidate.hasEligiblePayrolls && !hasAnyStepRunning;
    final canRunDeductions =
        (orchestration?.salaryBatchStatus == PaymentBatchStatus.completed ||
            candidate.paidPayrollCount > 0) &&
        !hasAnyStepRunning;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.payrollRunId,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${candidate.payrolls.length} payrolls | ${candidate.eligiblePayrollCount} eligible | ${candidate.paidPayrollCount} already paid',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(
                  label: orchestrationStatus?.name ?? 'not_started',
                  color: _orchestrationColor(orchestrationStatus),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Net: ${CurrencyFormatter.formatNaira(candidate.totalNetAmount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (orchestration?.salaryBatchStatus != null)
                  Text(
                    'Salary: ${orchestration!.salaryBatchStatus!.name}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                if (orchestration?.deductionBatchStatus != null)
                  Text(
                    'Deductions: ${orchestration!.deductionBatchStatus!.name}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
            if (!recipientsConfigured)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Deduction remittances will fail until payout recipients are configured.',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (!zohoConfigured)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Zoho sync is not configured yet, so payroll journals will stay local only.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: hasAnyStepRunning
                      ? null
                      : () => _runSalaryStep(candidate),
                  icon: isSalaryRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.payments_outlined),
                  label: Text(isSalaryRunning ? 'Paying...' : 'Pay Employees'),
                ),
                OutlinedButton.icon(
                  onPressed: !recipientsConfigured || !canRunDeductions
                      ? null
                      : () => _runDeductionStep(candidate),
                  icon: isDeductionRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.account_balance_outlined),
                  label: Text(
                    isDeductionRunning ? 'Paying...' : 'Pay Deductions',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: !zohoConfigured || hasAnyStepRunning
                      ? null
                      : () => _runZohoStep(candidate),
                  icon: isZohoRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: Text(isZohoRunning ? 'Syncing...' : 'Sync Zoho'),
                ),
                ElevatedButton.icon(
                  onPressed: canRun ? () => _runOrchestration(candidate) : null,
                  icon: isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(
                    isRunning ? 'Running...' : _runActionLabel(orchestration),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryBatchSection(List<PaymentBatch> batches) {
    return _buildBatchSection<PaymentBatch>(
      title: 'Salary Batches',
      emptyTitle: 'No salary batches for this period',
      items: batches,
      itemBuilder: _buildSalaryBatchTile,
    );
  }

  Widget _buildDeductionBatchSection(List<DeductionPayoutBatch> batches) {
    return _buildBatchSection<DeductionPayoutBatch>(
      title: 'Deduction Payout Batches',
      emptyTitle: 'No deduction payout batches for this period',
      items: batches,
      itemBuilder: _buildDeductionBatchTile,
    );
  }

  Widget _buildOrchestrationSection(
    List<PaymentOrchestrationRun> runs,
    Map<String, PaymentBatch> salaryBatchMap,
    Map<String, DeductionPayoutBatch> deductionBatchMap,
    bool zohoConfigured,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Orchestration Runs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Track how each payroll run moved through salary settlement, deduction remittance, and accounting sync.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (runs.isEmpty)
              const ModernEmptyState(
                icon: Icons.alt_route_outlined,
                title: 'No orchestration runs recorded for this period',
              )
            else
              ...runs.map((run) {
                final actionRow = _buildOrchestrationActions(
                  run,
                  salaryBatchMap,
                  deductionBatchMap,
                  zohoConfigured,
                );
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                run.payrollRunId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _buildStatusChip(
                              label: run.status.name,
                              color: _orchestrationColor(run.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (run.salaryBatchStatus != null)
                              Text(
                                'Salary: ${run.salaryBatchStatus!.name}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            if (run.deductionBatchStatus != null)
                              Text(
                                'Deductions: ${run.deductionBatchStatus!.name}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            Text(
                              'Zoho: ${run.zohoSyncStatus.name}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'Updated: ${_dateFormat.format(run.updatedAt.toLocal())}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        if ((run.failureReason ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              run.failureReason!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                        if ((run.zohoJournalNumber ?? '').trim().isNotEmpty ||
                            (run.zohoJournalId ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Zoho journal: ${run.zohoJournalNumber ?? run.zohoJournalId}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (actionRow != null) ...[
                          const SizedBox(height: 12),
                          actionRow,
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSalaryBatchTile(PaymentBatch batch) {
    final isRetrying = _retryingSalaryBatchId == batch.id;
    final canRetry =
        batch.status != PaymentBatchStatus.completed && !isRetrying;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    batch.payrollRunId,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _buildStatusChip(
                  label: batch.status.name,
                  color: _paymentBatchColor(batch.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('${batch.totalEmployees} employees'),
                Text(CurrencyFormatter.formatNaira(batch.totalAmount)),
                if ((batch.gatewayProvider ?? '').trim().isNotEmpty)
                  Text(
                    'Gateway: ${batch.gatewayProvider}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                if (batch.processedAt != null)
                  Text(
                    'Processed: ${_dateFormat.format(batch.processedAt!.toLocal())}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showSalaryBatchDetails(batch),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: canRetry ? () => _retrySalaryBatch(batch) : null,
                  icon: isRetrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(isRetrying ? 'Retrying...' : 'Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeductionBatchTile(DeductionPayoutBatch batch) {
    final isRetrying = _retryingDeductionBatchId == batch.id;
    final canRetry =
        batch.status != DeductionPayoutBatchStatus.completed && !isRetrying;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    batch.payrollRunId,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                _buildStatusChip(
                  label: batch.status.name,
                  color: _deductionBatchColor(batch.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text('${batch.totalPayouts} payouts'),
                Text(CurrencyFormatter.formatNaira(batch.totalAmount)),
                if ((batch.gatewayProvider ?? '').trim().isNotEmpty)
                  Text(
                    'Gateway: ${batch.gatewayProvider}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                if (batch.processedAt != null)
                  Text(
                    'Processed: ${_dateFormat.format(batch.processedAt!.toLocal())}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showDeductionBatchDetails(batch),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: canRetry
                      ? () => _retryDeductionBatch(batch)
                      : null,
                  icon: isRetrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(isRetrying ? 'Retrying...' : 'Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchSection<T>({
    required String title,
    required String emptyTitle,
    required List<T> items,
    required Widget Function(T item) itemBuilder,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              ModernEmptyState(icon: Icons.inbox_outlined, title: emptyTitle)
            else
              ...items.map(itemBuilder),
          ],
        ),
      ),
    );
  }

  Future<void> _runOrchestration(PaymentRunCandidate candidate) async {
    final options = await _showRunOptionsDialog();
    if (options == null) {
      return;
    }

    final payrolls = candidate.payrolls.where((payroll) {
      if (payroll.isReversal || payroll.isReversed) return false;
      if (payroll.status == 'reversed' || payroll.status == 'paid') {
        return false;
      }
      return payroll.approvalStatus == PayrollApprovalStatus.approved;
    }).toList();
    if (payrolls.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no approved unpaid payrolls in this run.'),
        ),
      );
      return;
    }

    setState(() => _busyRunId = candidate.payrollRunId);
    try {
      await _orchestrationService.orchestratePayrollRun(
        payrolls: payrolls,
        payrollRunId: candidate.payrollRunId,
        includeDeductionPayouts: options.includeDeductionPayouts,
        syncToZoho: options.syncToZoho,
      );
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment orchestration completed.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment orchestration failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyRunId = null);
      }
    }
  }

  Future<void> _runSalaryStep(PaymentRunCandidate candidate) async {
    final payrolls = candidate.payrolls.where((payroll) {
      if (payroll.isReversal || payroll.isReversed) return false;
      if (payroll.status == 'reversed' || payroll.status == 'paid') {
        return false;
      }
      return payroll.approvalStatus == PayrollApprovalStatus.approved;
    }).toList();
    if (payrolls.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no approved unpaid payrolls to pay.'),
        ),
      );
      return;
    }

    setState(() => _salaryRunId = candidate.payrollRunId);
    try {
      final batch = await _paymentProcessingService.createPaymentBatch(
        payrolls: payrolls,
        payrollRunId: candidate.payrollRunId,
      );
      await _paymentProcessingService.processPaymentBatch(batchId: batch.id);
      final refreshedBatch = await _paymentProcessingService
          .getPaymentBatchById(batch.id);
      if (refreshedBatch != null) {
        await _orchestrationService.recordSalaryBatchResult(
          payrolls: candidate.payrolls,
          payrollRunId: candidate.payrollRunId,
          batch: refreshedBatch,
        );
      }
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Employee payments processed for ${candidate.payrollRunId}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Employee payment failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _salaryRunId = null);
      }
    }
  }

  Future<void> _runDeductionStep(PaymentRunCandidate candidate) async {
    final payrolls = candidate.payrolls.where((payroll) {
      if (payroll.isReversal || payroll.isReversed) return false;
      if (payroll.status == 'reversed') {
        return false;
      }
      return payroll.approvalStatus == PayrollApprovalStatus.approved ||
          payroll.status == 'paid';
    }).toList();
    if (payrolls.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('There are no eligible payrolls for deduction payout.'),
        ),
      );
      return;
    }

    setState(() => _deductionRunId = candidate.payrollRunId);
    try {
      final batch = await _deductionPayoutService.createPayoutBatch(
        payrolls: payrolls,
        payrollRunId: candidate.payrollRunId,
      );
      if (batch == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No deduction liabilities were found for this run.'),
          ),
        );
        return;
      }

      await _deductionPayoutService.processPayoutBatch(batchId: batch.id);
      final refreshedBatch = await _deductionPayoutService.getPayoutBatchById(
        batch.id,
      );
      if (refreshedBatch != null) {
        await _orchestrationService.recordDeductionBatchResult(
          payrolls: candidate.payrolls,
          payrollRunId: candidate.payrollRunId,
          batch: refreshedBatch,
        );
      }
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deduction payouts processed for ${candidate.payrollRunId}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deduction payout failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _deductionRunId = null);
      }
    }
  }

  Future<void> _runZohoStep(PaymentRunCandidate candidate) async {
    setState(() => _syncingZohoRunId = candidate.payrollRunId);
    try {
      await _orchestrationService.syncPayrollRunToZoho(
        payrolls: candidate.payrolls,
        payrollRunId: candidate.payrollRunId,
      );
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zoho sync completed for ${candidate.payrollRunId}.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Zoho sync failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _syncingZohoRunId = null);
      }
    }
  }

  Future<void> _openZohoConfigDialog({ZohoSyncConfig? existing}) async {
    final result = await showDialog<_ZohoConfigDraft>(
      context: context,
      builder: (context) => _ZohoConfigDialog(
        existing: existing,
        onTestConnection: _testZohoConnection,
      ),
    );
    if (result == null) {
      return;
    }

    await _saveZohoConfig(result, existing: existing);
  }

  Future<void> _saveZohoConfig(
    _ZohoConfigDraft draft, {
    ZohoSyncConfig? existing,
  }) async {
    setState(() => _savingZohoConfig = true);
    try {
      final now = DateTime.now();
      final refreshToken = draft.refreshToken.trim();
      final config = ZohoSyncConfig(
        organizationId: draft.organizationId.trim(),
        authToken: draft.authToken.trim(),
        refreshToken: refreshToken.isEmpty ? null : refreshToken,
        tokenExpiresAt: refreshToken.isEmpty
            ? existing?.tokenExpiresAt
            : now.add(const Duration(hours: 1)),
        baseUrl: draft.baseUrl.trim().isEmpty
            ? ZohoSyncConfig.defaultBaseUrl
            : draft.baseUrl.trim(),
        accountMapping: {
          for (final entry in draft.accountMapping.entries)
            entry.key: entry.value.trim(),
        },
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastValidatedAt: draft.validatedAt ?? existing?.lastValidatedAt,
        lastSyncedAt: existing?.lastSyncedAt,
      );

      final validationError = config.validateConfiguration();
      if (validationError != null) {
        _showError('Configuration Invalid', validationError);
        return;
      }

      await _orchestrationService.saveZohoSyncConfig(config);
      _refreshCurrentPeriod();
      _showSuccess('Zoho Books configured successfully.');
    } catch (error) {
      _showError('Save Failed', error.toString());
    } finally {
      if (mounted) {
        setState(() => _savingZohoConfig = false);
      }
    }
  }

  Future<ZohoTestConnectionResponse> _testZohoConnection(
    _ZohoConfigDraft draft,
  ) async {
    final service = ZohoBooksService(
      organizationId: draft.organizationId.trim(),
      authToken: draft.authToken.trim(),
      baseUrl: draft.baseUrl.trim().isEmpty
          ? ZohoSyncConfig.defaultBaseUrl
          : draft.baseUrl.trim(),
    );
    return service.testConnection();
  }

  Future<void> _openRecipientDialog({PayoutRecipientConfig? existing}) async {
    final result = await showDialog<PayoutRecipientConfig>(
      context: context,
      builder: (context) => _RecipientDialog(existing: existing),
    );
    if (result == null) {
      return;
    }

    setState(() => _savingRecipient = true);
    try {
      await _deductionPayoutService.saveRecipientConfig(result);
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? 'Recipient saved.'
                : 'Recipient updated successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save recipient: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _savingRecipient = false);
      }
    }
  }

  Future<void> _toggleRecipientStatus(
    PayoutRecipientConfig recipient,
    bool isActive,
  ) async {
    setState(() => _togglingRecipientId = recipient.id);
    try {
      await _deductionPayoutService.setRecipientActive(
        recipientId: recipient.id,
        isActive: isActive,
      );
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? '${recipient.name} activated for remittances.'
                : '${recipient.name} deactivated for remittances.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update recipient status: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _togglingRecipientId = null);
      }
    }
  }

  Future<_RunOptions?> _showRunOptionsDialog() async {
    var includeDeductionPayouts = true;
    final zohoConfig = await _orchestrationService.getZohoSyncConfig();
    if (!mounted) {
      return null;
    }
    final canSyncZoho = zohoConfig?.isReadyForSync == true;
    var syncToZoho = canSyncZoho;
    return showDialog<_RunOptions>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Run Payment Operations'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: includeDeductionPayouts,
                    onChanged: (value) =>
                        setState(() => includeDeductionPayouts = value ?? true),
                    title: const Text('Include deduction remittances'),
                    subtitle: const Text(
                      'PAYE, pension, NHF, loans, advances, and other configured payouts.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (canSyncZoho)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: syncToZoho,
                      onChanged: (value) =>
                          setState(() => syncToZoho = value ?? false),
                      title: const Text('Sync journal to Zoho Books'),
                      subtitle: const Text(
                        'Posts the payroll run accounting entries after settlement.',
                      ),
                    )
                  else
                    const Text(
                      'Zoho sync is not configured yet. This orchestration will run salary and deduction operations only.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(
                    _RunOptions(
                      includeDeductionPayouts: includeDeductionPayouts,
                      syncToZoho: syncToZoho,
                    ),
                  ),
                  child: const Text('Run'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _syncZohoForRun(PaymentOrchestrationRun run) async {
    setState(() => _syncingZohoRunId = run.payrollRunId);
    try {
      await _orchestrationService.syncRunToZoho(orchestration: run);
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Zoho sync completed for ${run.payrollRunId}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Zoho sync failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _syncingZohoRunId = null);
      }
    }
  }

  Widget? _buildOrchestrationActions(
    PaymentOrchestrationRun run,
    Map<String, PaymentBatch> salaryBatchMap,
    Map<String, DeductionPayoutBatch> deductionBatchMap,
    bool zohoConfigured,
  ) {
    final actions = <Widget>[];
    final salaryBatch = run.salaryBatchId == null
        ? null
        : salaryBatchMap[run.salaryBatchId!];
    final deductionBatch = run.deductionBatchId == null
        ? null
        : deductionBatchMap[run.deductionBatchId!];

    if (salaryBatch != null) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _showSalaryBatchDetails(salaryBatch),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Salary Details'),
        ),
      );
      if (salaryBatch.status != PaymentBatchStatus.completed) {
        actions.add(
          ElevatedButton.icon(
            onPressed: _retryingSalaryBatchId == null
                ? () => _retrySalaryBatch(salaryBatch)
                : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Salary'),
          ),
        );
      }
    }

    if (deductionBatch != null) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _showDeductionBatchDetails(deductionBatch),
          icon: const Icon(Icons.visibility_outlined),
          label: const Text('Deduction Details'),
        ),
      );
      if (deductionBatch.status != DeductionPayoutBatchStatus.completed) {
        actions.add(
          ElevatedButton.icon(
            onPressed: _retryingDeductionBatchId == null
                ? () => _retryDeductionBatch(deductionBatch)
                : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Deductions'),
          ),
        );
      }
    }

    if (zohoConfigured &&
        run.zohoSyncStatus != ExternalSyncStatus.completed &&
        run.zohoSyncStatus != ExternalSyncStatus.processing) {
      actions.add(
        ElevatedButton.icon(
          onPressed: _syncingZohoRunId == null
              ? () => _syncZohoForRun(run)
              : null,
          icon: _syncingZohoRunId == run.payrollRunId
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync),
          label: Text(
            _syncingZohoRunId == run.payrollRunId ? 'Syncing...' : 'Sync Zoho',
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return null;
    }

    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }

  Future<void> _retrySalaryBatch(PaymentBatch batch) async {
    setState(() => _retryingSalaryBatchId = batch.id);
    try {
      await _paymentProcessingService.processPaymentBatch(batchId: batch.id);
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salary batch ${batch.payrollRunId} retried.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salary batch retry failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _retryingSalaryBatchId = null);
      }
    }
  }

  Future<void> _retryDeductionBatch(DeductionPayoutBatch batch) async {
    setState(() => _retryingDeductionBatchId = batch.id);
    try {
      await _deductionPayoutService.processPayoutBatch(batchId: batch.id);
      _refreshCurrentPeriod();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deduction batch ${batch.payrollRunId} retried.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deduction batch retry failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _retryingDeductionBatchId = null);
      }
    }
  }

  Future<void> _showSalaryBatchDetails(PaymentBatch batch) async {
    final payments = await _paymentProcessingService.getEmployeePayments(
      batch.id,
    );
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Salary Batch ${batch.payrollRunId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${payments.length} payments | ${CurrencyFormatter.formatNaira(batch.totalAmount)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: payments.isEmpty
                        ? const ModernEmptyState(
                            title: 'No employee payments found',
                          )
                        : ListView.separated(
                            itemCount: payments.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _buildPaymentDetailTile(payments[index]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeductionBatchDetails(DeductionPayoutBatch batch) async {
    final items = await _deductionPayoutService.getPayoutItems(batch.id);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deduction Batch ${batch.payrollRunId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${items.length} payouts | ${CurrencyFormatter.formatNaira(batch.totalAmount)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: items.isEmpty
                        ? const ModernEmptyState(
                            title: 'No deduction payouts found',
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) =>
                                _buildDeductionDetailTile(items[index]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportReconciliationCsv(
    List<PaymentReconciliationRow> rows,
  ) async {
    final csv = StringBuffer();
    csv.writeln(
      _csvRow([
        'Payroll Run ID',
        'Payroll Count',
        'Total Net Amount',
        'Accrual Transaction Count',
        'Salary Batch Status',
        'Salary Settlements',
        'Expected Salary Settlements',
        'Deduction Batch Status',
        'Deduction Settlements',
        'Expected Deduction Settlements',
        'Deduction Liability Base',
        'Zoho Sync Status',
        'Zoho Journal Reference',
        'Reconciled',
        'Issues',
      ]),
    );

    for (final row in rows) {
      csv.writeln(
        _csvRow([
          row.payrollRunId,
          row.payrollCount.toString(),
          row.totalNetAmount.toStringAsFixed(2),
          row.accrualTransactionCount.toString(),
          row.salaryBatchStatus?.name ?? '',
          row.salarySettlementCount.toString(),
          row.expectedSalarySettlementCount.toString(),
          row.deductionBatchStatus?.name ?? '',
          row.deductionSettlementCount.toString(),
          row.expectedDeductionSettlementCount.toString(),
          row.deductionLiabilityAmountBase.toStringAsFixed(2),
          row.zohoSyncStatus.name,
          row.zohoJournalReference ?? '',
          row.isFullyReconciled ? 'Yes' : 'No',
          row.issues.join(' | '),
        ]),
      );
    }

    try {
      await downloadCsvFile(
        fileName:
            'reconciliation_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv',
        csv: csv.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reconciliation CSV for ${_monthName(_selectedMonth)} $_selectedYear downloaded.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reconciliation export failed: $error')),
      );
    }
  }

  Future<void> _showReconciliationDetails(PaymentReconciliationRow row) async {
    final results = await Future.wait<dynamic>([
      _payrollTransactionService.getTransactionsByPayrollRun(row.payrollRunId),
      _paymentProcessingService.getPaymentBatchByPayrollRunId(row.payrollRunId),
      _deductionPayoutService.getPayoutBatchByPayrollRunId(row.payrollRunId),
      _orchestrationService.getByPayrollRunId(row.payrollRunId),
    ]);
    if (!mounted) return;

    final transactions = results[0] as List<PayrollTransaction>;
    final salaryBatch = results[1] as PaymentBatch?;
    final deductionBatch = results[2] as DeductionPayoutBatch?;
    final orchestration = results[3] as PaymentOrchestrationRun?;
    final groupedByType = <TransactionType, List<PayrollTransaction>>{};
    for (final transaction in transactions) {
      groupedByType
          .putIfAbsent(transaction.type, () => <PayrollTransaction>[])
          .add(transaction);
    }
    final orderedTypes = groupedByType.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.88,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reconciliation ${row.payrollRunId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Text('${row.payrollCount} payrolls'),
                      Text(
                        'Net: ${CurrencyFormatter.formatNaira(row.totalNetAmount)}',
                      ),
                      if ((row.zohoJournalReference ?? '').trim().isNotEmpty)
                        Text('Journal: ${row.zohoJournalReference}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      children: [
                        _buildReconciliationInfoCard(
                          row,
                          salaryBatch,
                          deductionBatch,
                          orchestration,
                        ),
                        const SizedBox(height: 12),
                        if (row.issues.isNotEmpty)
                          _buildIssueListCard(row.issues),
                        if (row.issues.isNotEmpty) const SizedBox(height: 12),
                        _buildTransactionBreakdownCard(
                          transactions.length,
                          orderedTypes,
                          groupedByType,
                        ),
                        const SizedBox(height: 12),
                        ...orderedTypes.map(
                          (type) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildTransactionTypeSection(
                              type,
                              groupedByType[type]!,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReconciliationInfoCard(
    PaymentReconciliationRow row,
    PaymentBatch? salaryBatch,
    DeductionPayoutBatch? deductionBatch,
    PaymentOrchestrationRun? orchestration,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Run Summary',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Salary settlements: ${row.salarySettlementCount}/${row.expectedSalarySettlementCount}',
                ),
                Text(
                  'Deduction settlements: ${row.deductionSettlementCount}/${row.expectedDeductionSettlementCount}',
                ),
                Text(
                  'Deduction liability base: ${row.deductionLiabilityAmountBase.toStringAsFixed(2)}',
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (salaryBatch != null)
              Text(
                'Salary batch ${salaryBatch.id}: ${salaryBatch.status.name}${salaryBatch.gatewayReference == null ? '' : ' | ${salaryBatch.gatewayReference}'}',
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else
              const Text(
                'Salary batch: none',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 6),
            if (deductionBatch != null)
              Text(
                'Deduction batch ${deductionBatch.id}: ${deductionBatch.status.name}${deductionBatch.gatewayReference == null ? '' : ' | ${deductionBatch.gatewayReference}'}',
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else
              const Text(
                'Deduction batch: none',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            const SizedBox(height: 6),
            if (orchestration != null)
              Text(
                'Orchestration ${orchestration.id}: ${orchestration.status.name} | Zoho ${orchestration.zohoSyncStatus.name}',
                style: const TextStyle(color: AppColors.textSecondary),
              )
            else
              const Text(
                'Orchestration: none',
                style: TextStyle(color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIssueListCard(List<String> issues) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Outstanding Issues',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(issue)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionBreakdownCard(
    int totalTransactions,
    List<TransactionType> orderedTypes,
    Map<TransactionType, List<PayrollTransaction>> groupedByType,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transactions ($totalTransactions)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: orderedTypes
                  .map(
                    (type) => _buildMiniStateChip(
                      '${_transactionTypeLabel(type)} ${groupedByType[type]!.length}',
                      _transactionTypeColor(type),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTypeSection(
    TransactionType type,
    List<PayrollTransaction> transactions,
  ) {
    final totalAmountBase = transactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.amountBase,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _transactionTypeLabel(type),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _buildMiniStateChip(
                  '${transactions.length}',
                  _transactionTypeColor(type),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Base total: ${totalAmountBase.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            ...transactions.map(
              (transaction) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${transaction.employeeName} | ${CurrencyFormatter.formatNaira(transaction.amount)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${transaction.debitAccountName} (${transaction.debitAccount}) -> ${transaction.creditAccountName} (${transaction.creditAccount})',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      if ((transaction.metadata ?? const <String, dynamic>{})
                          .isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _metadataPreview(transaction.metadata!),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentDetailTile(EmployeePayment payment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.employeeName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _buildStatusChip(
                label: payment.status.name,
                color: _paymentStatusColor(payment.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(CurrencyFormatter.formatNaira(payment.amount)),
              Text(
                '${payment.bankName} | ${payment.accountNumber}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (payment.completedAt != null)
                Text(
                  'Completed: ${_dateFormat.format(payment.completedAt!.toLocal())}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
          if ((payment.failureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payment.failureReason!,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
          if ((payment.gatewayReference ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Gateway ref: ${payment.gatewayReference}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeductionDetailTile(DeductionPayoutItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.recipientName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _buildStatusChip(
                label: item.status.name,
                color: _deductionItemStatusColor(item.status),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                '${_labelForDeductionType(item.payoutType)} | ${item.sourceCount} items',
              ),
              Text(CurrencyFormatter.formatNaira(item.amount)),
              if (item.bankName.trim().isNotEmpty)
                Text(
                  '${item.bankName} | ${item.accountNumber}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              if (item.completedAt != null)
                Text(
                  'Completed: ${_dateFormat.format(item.completedAt!.toLocal())}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
          if ((item.failureReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.failureReason!,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
          if ((item.gatewayReference ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Gateway ref: ${item.gatewayReference}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  void _refreshCurrentPeriod() {
    ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
    ref.invalidate(
      paymentOperationsProvider(
        PayrollPeriod(month: _selectedMonth, year: _selectedYear),
      ),
    );
  }

  void _showSuccess(String title, [String? details]) {
    if (!mounted) return;
    final content = details == null || details.trim().isEmpty
        ? title
        : '$title\n$details';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(content)));
  }

  void _showError(String title, String details) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$title\n$details')));
  }

  Widget _buildStatusChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildMiniStateChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _csvRow(List<String> values) {
    return values.map((value) => '"${value.replaceAll('"', '""')}"').join(',');
  }

  Color _paymentBatchColor(PaymentBatchStatus status) {
    switch (status) {
      case PaymentBatchStatus.pending:
        return AppColors.textSecondary;
      case PaymentBatchStatus.processing:
        return AppColors.info;
      case PaymentBatchStatus.completed:
        return AppColors.success;
      case PaymentBatchStatus.failed:
        return AppColors.error;
      case PaymentBatchStatus.partiallyCompleted:
        return AppColors.warning;
    }
  }

  Color _transactionTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.salary:
      case TransactionType.reimbursement:
      case TransactionType.incentive:
        return AppColors.primary;
      case TransactionType.salaryPayment:
      case TransactionType.deductionPayment:
        return AppColors.success;
      case TransactionType.paye:
      case TransactionType.pension:
      case TransactionType.nhf:
      case TransactionType.loan:
      case TransactionType.advance:
      case TransactionType.deduction:
        return AppColors.warning;
    }
  }

  Color _paymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return AppColors.textSecondary;
      case PaymentStatus.processing:
        return AppColors.info;
      case PaymentStatus.completed:
        return AppColors.success;
      case PaymentStatus.failed:
      case PaymentStatus.reversed:
        return AppColors.error;
    }
  }

  Color _deductionBatchColor(DeductionPayoutBatchStatus status) {
    switch (status) {
      case DeductionPayoutBatchStatus.pending:
        return AppColors.textSecondary;
      case DeductionPayoutBatchStatus.processing:
        return AppColors.info;
      case DeductionPayoutBatchStatus.completed:
        return AppColors.success;
      case DeductionPayoutBatchStatus.failed:
        return AppColors.error;
      case DeductionPayoutBatchStatus.partiallyCompleted:
        return AppColors.warning;
    }
  }

  Color _deductionItemStatusColor(DeductionPayoutItemStatus status) {
    switch (status) {
      case DeductionPayoutItemStatus.pending:
        return AppColors.textSecondary;
      case DeductionPayoutItemStatus.processing:
        return AppColors.info;
      case DeductionPayoutItemStatus.completed:
        return AppColors.success;
      case DeductionPayoutItemStatus.failed:
      case DeductionPayoutItemStatus.reversed:
        return AppColors.error;
    }
  }

  Color _orchestrationColor(PaymentOrchestrationStatus? status) {
    switch (status) {
      case null:
      case PaymentOrchestrationStatus.pending:
        return AppColors.textSecondary;
      case PaymentOrchestrationStatus.salaryProcessing:
      case PaymentOrchestrationStatus.deductionProcessing:
      case PaymentOrchestrationStatus.zohoSyncing:
        return AppColors.info;
      case PaymentOrchestrationStatus.completed:
      case PaymentOrchestrationStatus.salaryCompleted:
      case PaymentOrchestrationStatus.deductionCompleted:
        return AppColors.success;
      case PaymentOrchestrationStatus.partiallyCompleted:
        return AppColors.warning;
      case PaymentOrchestrationStatus.failed:
        return AppColors.error;
    }
  }

  String _runActionLabel(PaymentOrchestrationRun? orchestration) {
    if (orchestration == null) {
      return 'Run Payments';
    }
    switch (orchestration.status) {
      case PaymentOrchestrationStatus.failed:
      case PaymentOrchestrationStatus.partiallyCompleted:
        return 'Resume Run';
      case PaymentOrchestrationStatus.salaryProcessing:
      case PaymentOrchestrationStatus.deductionProcessing:
      case PaymentOrchestrationStatus.zohoSyncing:
        return 'Continue Run';
      case PaymentOrchestrationStatus.pending:
      case PaymentOrchestrationStatus.salaryCompleted:
      case PaymentOrchestrationStatus.deductionCompleted:
        return 'Continue Run';
      case PaymentOrchestrationStatus.completed:
        return 'Run Payments';
    }
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Unknown';
  }

  String _labelForDeductionType(DeductionPayoutType type) {
    switch (type) {
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
        return 'Other';
    }
  }

  String _transactionTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.salary:
        return 'Salary Accrual';
      case TransactionType.salaryPayment:
        return 'Salary Settlement';
      case TransactionType.deductionPayment:
        return 'Deduction Settlement';
      case TransactionType.reimbursement:
        return 'Reimbursement';
      case TransactionType.incentive:
        return 'Incentive';
      case TransactionType.paye:
        return 'PAYE';
      case TransactionType.pension:
        return 'Pension';
      case TransactionType.nhf:
        return 'NHF';
      case TransactionType.loan:
        return 'Loan';
      case TransactionType.advance:
        return 'Advance';
      case TransactionType.deduction:
        return 'Other Deduction';
    }
  }

  String _metadataPreview(Map<String, dynamic> metadata) {
    final entries = metadata.entries
        .where((entry) => entry.value != null)
        .take(3)
        .map((entry) => '${entry.key}: ${entry.value}')
        .toList();
    return entries.isEmpty ? 'No metadata' : entries.join(' | ');
  }
}

class _RunOptions {
  final bool includeDeductionPayouts;
  final bool syncToZoho;

  const _RunOptions({
    required this.includeDeductionPayouts,
    required this.syncToZoho,
  });
}

class _RecipientDialog extends StatefulWidget {
  final PayoutRecipientConfig? existing;

  const _RecipientDialog({this.existing});

  @override
  State<_RecipientDialog> createState() => _RecipientDialogState();
}

class _RecipientDialogState extends State<_RecipientDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _nameController;
  late final TextEditingController _bankNameController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _bankCodeController;
  late final TextEditingController _aliasesController;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _keyController = TextEditingController(text: existing?.key ?? '');
    _nameController = TextEditingController(text: existing?.name ?? '');
    _bankNameController = TextEditingController(text: existing?.bankName ?? '');
    _accountNumberController = TextEditingController(
      text: existing?.accountNumber ?? '',
    );
    _accountNameController = TextEditingController(
      text: existing?.accountName ?? '',
    );
    _bankCodeController = TextEditingController(text: existing?.bankCode ?? '');
    _aliasesController = TextEditingController(
      text: existing?.aliases.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _nameController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _bankCodeController.dispose();
    _aliasesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Add Payout Recipient' : 'Edit Recipient',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'Recipient Key',
                hintText: 'statutory_paye, statutory_pension, ref:LN-001',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bankNameController,
              decoration: const InputDecoration(labelText: 'Bank Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Account Number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountNameController,
              decoration: const InputDecoration(labelText: 'Account Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _bankCodeController,
              decoration: const InputDecoration(
                labelText: 'Bank Code',
                hintText: 'Optional if bank name can be mapped',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _aliasesController,
              decoration: const InputDecoration(
                labelText: 'Aliases',
                hintText: 'Comma-separated alternate lookup keys',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }

  void _submit() {
    final key = _keyController.text.trim();
    final name = _nameController.text.trim();
    final bankName = _bankNameController.text.trim();
    final accountNumber = _accountNumberController.text.trim();
    final accountName = _accountNameController.text.trim();
    if (key.isEmpty ||
        name.isEmpty ||
        bankName.isEmpty ||
        accountNumber.isEmpty ||
        accountName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All required recipient fields must be filled.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final existing = widget.existing;
    Navigator.of(context).pop(
      PayoutRecipientConfig(
        id: existing?.id ?? const Uuid().v4(),
        key: key,
        name: name,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
        bankCode: _bankCodeController.text.trim().isEmpty
            ? null
            : _bankCodeController.text.trim(),
        aliases: _aliasesController.text
            .split(',')
            .map((alias) => alias.trim())
            .where((alias) => alias.isNotEmpty)
            .toList(),
        isActive: true,
        metadata: existing?.metadata,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

class _ZohoConfigDraft {
  final String organizationId;
  final String authToken;
  final String refreshToken;
  final String baseUrl;
  final Map<String, String> accountMapping;
  final DateTime? validatedAt;

  const _ZohoConfigDraft({
    required this.organizationId,
    required this.authToken,
    required this.refreshToken,
    required this.baseUrl,
    required this.accountMapping,
    this.validatedAt,
  });
}

class _ZohoConfigDialog extends StatefulWidget {
  final ZohoSyncConfig? existing;
  final Future<ZohoTestConnectionResponse> Function(_ZohoConfigDraft draft)
  onTestConnection;

  const _ZohoConfigDialog({required this.onTestConnection, this.existing});

  @override
  State<_ZohoConfigDialog> createState() => _ZohoConfigDialogState();
}

class _ZohoConfigDialogState extends State<_ZohoConfigDialog>
    with SingleTickerProviderStateMixin {
  static const String _defaultRedirectUri = 'https://www.zoho.com/books';
  static const String _oauthScope = 'ZohoBooks.fullaccess.all';

  final _oauthService = ZohoOAuthService();
  late final TextEditingController _organizationIdController;
  late final TextEditingController _authTokenController;
  late final TextEditingController _refreshTokenController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _redirectUriController;
  late final TextEditingController _authCodeController;
  late final Map<String, TextEditingController> _accountControllers;
  late final TabController _tabController;
  bool _testingConnection = false;
  bool _exchangingCode = false;
  DateTime? _validatedAt;
  String? _oauthError;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _organizationIdController = TextEditingController(
      text: existing?.organizationId ?? '',
    );
    _authTokenController = TextEditingController(
      text: existing?.authToken ?? '',
    );
    _refreshTokenController = TextEditingController(
      text: existing?.refreshToken ?? '',
    );
    _baseUrlController = TextEditingController(
      text: existing?.baseUrl ?? ZohoSyncConfig.defaultBaseUrl,
    );
    _redirectUriController = TextEditingController(text: _defaultRedirectUri);
    _authCodeController = TextEditingController();
    _accountControllers = {
      for (final entry in ZohoSyncConfig.supportedAccounts.entries)
        entry.key: TextEditingController(
          text: existing?.accountMapping[entry.key] ?? '',
        ),
    };
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: existing?.isConfigured == true ? 1 : 0,
    );
    _validatedAt = existing?.lastValidatedAt;
  }

  @override
  void dispose() {
    _organizationIdController.dispose();
    _authTokenController.dispose();
    _refreshTokenController.dispose();
    _baseUrlController.dispose();
    _redirectUriController.dispose();
    _authCodeController.dispose();
    _tabController.dispose();
    for (final controller in _accountControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Configure Zoho Books' : 'Edit Zoho Books',
      ),
      content: SizedBox(
        width: 640,
        height: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Credentials are stored encrypted, but production Zoho OAuth secrets still need to be supplied through secure app configuration.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Connect with OAuth'),
                Tab(text: 'Manual / Edit'),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildOAuthTab(), _buildManualTab()],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: (_testingConnection || _exchangingCode)
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ListenableBuilder(
          listenable: _tabController,
          builder: (context, _) {
            if (_tabController.index != 1) {
              return const SizedBox.shrink();
            }

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: _testingConnection ? null : _handleTestConnection,
                  child: Text(
                    _testingConnection ? 'Testing...' : 'Test Connection',
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _submit, child: const Text('Save')),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildOAuthTab() {
    final authorizationUrl = _authorizationUrl;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OAuthStep(
            number: '1',
            title: 'Choose a redirect URI',
            child: TextField(
              controller: _redirectUriController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Redirect URI'),
            ),
          ),
          const SizedBox(height: 16),
          _OAuthStep(
            number: '2',
            title: 'Open the Zoho consent screen',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: SelectableText(
                          authorizationUrl.isEmpty
                              ? 'Zoho consent URL will appear here once OAuth client settings are available.'
                              : authorizationUrl,
                          style: TextStyle(
                            color: authorizationUrl.isEmpty
                                ? AppColors.textSecondary
                                : null,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy consent URL',
                        onPressed: authorizationUrl.isEmpty
                            ? null
                            : () => _copyConsentUrl(authorizationUrl),
                        icon: const Icon(Icons.copy_outlined),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: (_exchangingCode || authorizationUrl.isEmpty)
                      ? null
                      : () => _openConsentScreen(authorizationUrl),
                  child: const Text('Open Zoho Consent Screen'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OAuthStep(
            number: '3',
            title: 'Paste the authorisation code',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _authCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Authorisation Code',
                    hintText: '1000.xxxxxxxx',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'The Zoho authorisation code expires in 60 seconds.',
                  style: TextStyle(color: AppColors.warning),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OAuthStep(
            number: '4',
            title: 'Enter your organisation ID',
            child: TextField(
              controller: _organizationIdController,
              decoration: const InputDecoration(labelText: 'Organisation ID'),
            ),
          ),
          if (_oauthError != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                _oauthError!,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _exchangingCode ? null : _connectZohoBooks,
              child: Text(
                _exchangingCode ? 'Connecting...' : 'Connect Zoho Books',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _organizationIdController,
            decoration: const InputDecoration(labelText: 'Organization ID'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _authTokenController,
            decoration: const InputDecoration(labelText: 'Access Token'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _refreshTokenController,
            decoration: const InputDecoration(
              labelText: 'Refresh Token',
              helperText:
                  'Required for automatic token renewal after the one-hour access token expires.',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'https://www.zohoapis.com/books/v3',
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Account Mapping',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Map each RoiPayroll ledger account to the corresponding Zoho Books account ID.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ...ZohoSyncConfig.supportedAccounts.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _accountControllers[entry.key],
                decoration: InputDecoration(
                  labelText: '${entry.key} - ${entry.value}',
                  hintText: 'Zoho account ID',
                ),
              ),
            );
          }),
          if (_validatedAt != null)
            Text(
              'Last successful connection test: ${DateFormat('MMM d, y h:mm a').format(_validatedAt!.toLocal())}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  String get _authorizationUrl {
    try {
      return _oauthService.generateAuthorizationUrl(
        redirectUri: _redirectUriController.text.trim().isEmpty
            ? _defaultRedirectUri
            : _redirectUriController.text.trim(),
        scope: _oauthScope,
      );
    } catch (_) {
      return '';
    }
  }

  Future<void> _copyConsentUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Consent URL copied to clipboard.')),
    );
  }

  Future<void> _openConsentScreen(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      setState(() {
        _oauthError = 'The generated Zoho consent URL is invalid.';
      });
      return;
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    await _copyConsentUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open Zoho automatically, so the consent URL was copied instead.',
        ),
      ),
    );
  }

  Future<void> _connectZohoBooks() async {
    final code = _authCodeController.text.trim();
    final organizationId = _organizationIdController.text.trim();
    final redirectUri = _redirectUriController.text.trim().isEmpty
        ? _defaultRedirectUri
        : _redirectUriController.text.trim();

    if (code.isEmpty || organizationId.isEmpty) {
      setState(() {
        _oauthError =
            'Both the authorisation code and organisation ID are required.';
      });
      return;
    }

    setState(() {
      _oauthError = null;
      _exchangingCode = true;
    });

    try {
      final tokenResponse = await _oauthService.exchangeAuthorizationCode(
        code: code,
        redirectUri: redirectUri,
      );

      _organizationIdController.text = organizationId;
      _authTokenController.text = tokenResponse.accessToken;
      _refreshTokenController.text = tokenResponse.refreshToken ?? '';

      if (!mounted) {
        return;
      }

      _tabController.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Zoho connected. Complete the account mapping, then click Save.',
          ),
        ),
      );
    } on ZohoOAuthException catch (error) {
      setState(() {
        _oauthError = error.message;
      });
    } catch (error) {
      setState(() {
        _oauthError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _exchangingCode = false);
      }
    }
  }

  _ZohoConfigDraft _buildDraft() {
    return _ZohoConfigDraft(
      organizationId: _organizationIdController.text.trim(),
      authToken: _authTokenController.text.trim(),
      refreshToken: _refreshTokenController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      accountMapping: {
        for (final entry in _accountControllers.entries)
          entry.key: entry.value.text.trim(),
      },
      validatedAt: _validatedAt,
    );
  }

  Future<void> _handleTestConnection() async {
    final draft = _buildDraft();
    if (draft.organizationId.isEmpty || draft.authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization ID and access token are required.'),
        ),
      );
      return;
    }

    setState(() => _testingConnection = true);
    try {
      final response = await widget.onTestConnection(draft);
      if (!mounted) {
        return;
      }

      if (response.success) {
        final validatedAt = DateTime.now();
        setState(() => _validatedAt = validatedAt);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Connection successful${response.organizationName == null ? '' : ': ${response.organizationName}'}',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response.message)));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _testingConnection = false);
      }
    }
  }

  void _submit() {
    final draft = _buildDraft();
    if (draft.organizationId.isEmpty || draft.authToken.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Organization ID and access token are required.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(draft);
  }
}

class _OAuthStep extends StatelessWidget {
  final String number;
  final String title;
  final Widget child;

  const _OAuthStep({
    required this.number,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ],
    );
  }
}
