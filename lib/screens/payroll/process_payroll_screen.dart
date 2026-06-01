import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/constants/app_strings.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/system_alert_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/payroll_provider.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/payroll_service.dart';
import 'package:roipayroll/services/pdf_service.dart';

class ProcessPayrollScreen extends ConsumerStatefulWidget {
  const ProcessPayrollScreen({super.key});

  @override
  ConsumerState<ProcessPayrollScreen> createState() =>
      _ProcessPayrollScreenState();
}

class _ProcessPayrollScreenState extends ConsumerState<ProcessPayrollScreen> {
  final _payrollService = PayrollService();
  final _employeeService = EmployeeService();
  static const int _maxVisibleAlerts = 6;
  static const int _previewBatchSize = 100;

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isPreviewing = false;
  bool _isProcessing = false;
  PayrollPreview? _payrollPreview;
  List<Payroll>? _processedPayrolls;
  List<SystemAlert> _systemAlerts = const [];
  int _visiblePreviewItems = _previewBatchSize;
  int _previewProcessed = 0;
  int _previewTotal = 0;
  String _previewStage = '';
  PreviewCancellationToken? _previewCancellationToken;
  bool _isSubmittingApprovals = false;
  bool _previewApproved = false;
  PayrollStep _currentStep = PayrollStep.preview;
  bool _approvalSubmitted = false;

  void _refreshPayrollData() {
    final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
    ref.invalidate(payrollHistoryProvider(period));
    ref.invalidate(payrollAlertsProvider(period));
    ref.invalidate(payrollPreviewProvider(period));
    ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  void dispose() {
    _previewCancellationToken?.cancel();
    super.dispose();
  }

  Future<bool> _runSystemAlertChecks({required bool isForProcessing}) async {
    final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
    final alerts = await ref.read(payrollAlertsProvider(period).future);

    if (!mounted) return false;
    setState(() => _systemAlerts = alerts);

    final criticalAlerts = alerts.where((alert) => alert.isBlocking).toList();
    if (criticalAlerts.isNotEmpty) {
      await _showBlockingAlertsDialog(
        criticalAlerts,
        isForProcessing: isForProcessing,
      );
      return false;
    }

    final warningAlerts = alerts
        .where((alert) => alert.severity == AlertSeverity.warning)
        .toList();
    if (warningAlerts.isEmpty) return true;

    final proceed = await _showWarningAlertsDialog(
      warningAlerts,
      isForProcessing: isForProcessing,
    );
    return proceed ?? false;
  }

  Future<void> _previewPayroll() async {
    setState(() {
      _isPreviewing = true;
      _processedPayrolls = null;
      _payrollPreview = null;
      _previewProcessed = 0;
      _previewTotal = 0;
      _previewStage = 'Running system checks...';
      _previewApproved = false;
      _approvalSubmitted = false;
      _currentStep = PayrollStep.preview;
    });

    try {
      _previewCancellationToken = PreviewCancellationToken();
      final canProceed = await _runSystemAlertChecks(isForProcessing: false);
      if (!canProceed) {
        if (mounted) {
          setState(() {
            _isPreviewing = false;
            _previewStage = '';
          });
        }
        _previewCancellationToken = null;
        return;
      }

      if (!mounted) return;
      setState(() => _previewStage = 'Calculating payroll preview...');

      final preview = await _payrollService.simulatePayrollWithProgress(
        _selectedMonth,
        _selectedYear,
        cancellationToken: _previewCancellationToken,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _previewProcessed = completed;
            _previewTotal = total;
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _payrollPreview = preview;
        _visiblePreviewItems = preview.items.length < _previewBatchSize
            ? preview.items.length
            : _previewBatchSize;
        _isPreviewing = false;
        _previewStage = '';
        _currentStep = PayrollStep.approve;
      });
      _previewCancellationToken = null;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payroll preview ready for ${preview.totalEmployees} active employees.',
          ),
        ),
      );
    } catch (e) {
      if (e is PayrollPreviewCancelledException) {
        if (!mounted) return;
        setState(() {
          _isPreviewing = false;
          _previewStage = '';
        });
        _previewCancellationToken = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payroll preview cancelled.')),
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _isPreviewing = false;
        _previewStage = '';
      });
      _previewCancellationToken = null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _processPayroll() async {
    final preview = _payrollPreview;
    if (preview == null || !_previewApproved) return;

    setState(() => _isProcessing = true);

    try {
      final canProceed = await _runSystemAlertChecks(isForProcessing: true);
      if (!canProceed) {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        return;
      }

      if (!mounted) return;
      final shouldProcess = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm Payroll Processing'),
            content: Text(
              'Process ${preview.totalEmployees} active employees for '
              '${_getMonthName(_selectedMonth)} $_selectedYear?\n\n'
              'Total Gross (${preview.currency}): ${CurrencyFormatter.formatCurrency(preview.totalGross, currencyCode: preview.currency)}\n'
              'Total Deductions (${preview.currency}): ${CurrencyFormatter.formatCurrency(preview.totalDeductions, currencyCode: preview.currency)}\n'
              'Total Net (${preview.currency}): ${CurrencyFormatter.formatCurrency(preview.totalNet, currencyCode: preview.currency)}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      );

      if (shouldProcess != true) {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
        return;
      }

      final employees = await _employeeService.getAllEmployees();
      final previewEmployeeIds = preview.items
          .map((item) => item.employeeId)
          .toSet();
      final employeesToProcess = employees
          .where((employee) => previewEmployeeIds.contains(employee.id))
          .toList();

      if (employeesToProcess.isEmpty) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No matching employees found to process. Refresh preview and try again.',
            ),
          ),
        );
        return;
      }

      final processingResult = await _payrollService
          .processAllPayrollsWithSummary(
            employeesToProcess,
            _selectedMonth,
            _selectedYear,
          );
      final payrolls = processingResult.payrolls;

      if (!mounted) return;
      setState(() {
        _processedPayrolls = payrolls;
        _isProcessing = false;
        _currentStep = PayrollStep.complete;
        _systemAlerts = _systemAlerts
            .where((alert) => alert.type != AlertType.payrollProcessed)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            processingResult.processingFailedCount > 0
                ? 'Payroll processed for ${payrolls.length} of ${processingResult.attemptedEmployeeCount} active employees.'
                : 'Payroll processed for ${payrolls.length} active employees!',
          ),
        ),
      );
      _refreshPayrollData();

      await _showDistributionSummaryDialog(processingResult);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _showBlockingAlertsDialog(
    List<SystemAlert> alerts, {
    required bool isForProcessing,
  }) async {
    final action = isForProcessing ? 'process payroll' : 'preview payroll';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Cannot ${isForProcessing ? 'Process' : 'Preview'} Payroll',
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fix ${alerts.length} critical issue(s) before you can $action.',
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: alerts
                          .map((alert) => _buildAlertListItem(alert))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _showWarningAlertsDialog(
    List<SystemAlert> alerts, {
    required bool isForProcessing,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isForProcessing ? 'Warning Alerts' : 'Preview Warnings'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alerts.length} warning(s) were found. You can continue, but review them first.',
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: alerts
                          .map((alert) => _buildAlertListItem(alert))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                isForProcessing ? 'Proceed Anyway' : 'Preview Anyway',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDistributionSummaryDialog(
    PayrollProcessingResult result,
  ) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Distribution Summary'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSummaryRow(
                  'Active employees attempted',
                  result.attemptedEmployeeCount.toString(),
                ),
                _buildSummaryRow(
                  'Payroll records processed',
                  result.payrolls.length.toString(),
                ),
                _buildSummaryRow(
                  'Payslip email auto-send',
                  result.autoSendPayslipEmailEnabled ? 'Enabled' : 'Disabled',
                ),
                _buildSummaryRow(
                  'Emails queued',
                  result.emailQueuedCount.toString(),
                ),
                _buildSummaryRow(
                  'Skipped (no email)',
                  result.emailSkippedNoEmailCount.toString(),
                ),
                _buildSummaryRow(
                  'Email queue failures',
                  result.emailFailedCount.toString(),
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  'In-app notification auto-send',
                  result.autoSendPayrollNotificationEnabled
                      ? 'Enabled'
                      : 'Disabled',
                ),
                _buildSummaryRow(
                  'Notifications sent',
                  result.notificationSentCount.toString(),
                ),
                _buildSummaryRow(
                  'Notification failures',
                  result.notificationFailedCount.toString(),
                ),
                const Divider(height: 24),
                _buildSummaryRow(
                  'Payroll processing failures',
                  result.processingFailedCount.toString(),
                ),
                if (result.processingFailures.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Failed Employees',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Column(
                        children: result.processingFailures
                            .map(
                              (failure) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            failure.employeeName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          Text(
                                            failure.message,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _approvePreviewForProcessing() async {
    if (_payrollPreview == null || _isPreviewing || _isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve Payroll Run'),
          content: Text(
            'Confirm that the preview for ${_getMonthName(_selectedMonth)} $_selectedYear has been reviewed and approved for processing.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _previewApproved = true;
      _currentStep = PayrollStep.process;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Preview approved. You can now process payroll.'),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAlertListItem(SystemAlert alert) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            alert.severity == AlertSeverity.critical
                ? Icons.error
                : alert.severity == AlertSeverity.warning
                ? Icons.warning
                : Icons.info,
            color: _severityColor(alert.severity),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(alert.message),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppBar(
        title: const Text(AppStrings.processPayroll),
        actions: [
          IconButton(
            tooltip: 'Off-Cycle Payroll',
            icon: const Icon(Icons.sync_alt_outlined),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.offCyclePayroll),
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildResponsiveContent(compact: true),
        tablet: _buildResponsiveContent(compact: false),
        desktop: _buildResponsiveContent(compact: false),
      ),
    );
  }

  Widget _buildResponsiveContent({required bool compact}) {
    final currentUser = ref.watch(currentUserProvider).asData?.value;
    final visibleAlerts = (_processedPayrolls?.isNotEmpty ?? false)
        ? _systemAlerts
              .where((alert) => alert.type != AlertType.payrollProcessed)
              .toList(growable: false)
        : _systemAlerts;
    final criticalCount = visibleAlerts
        .where((alert) => alert.severity == AlertSeverity.critical)
        .length;
    final warningCount = visibleAlerts
        .where((alert) => alert.severity == AlertSeverity.warning)
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = compact || constraints.maxWidth < 980;
          final preview = _payrollPreview;
          final previewItems = preview?.items ?? const [];
          final visibleCount = _visiblePreviewItems < previewItems.length
              ? _visiblePreviewItems
              : previewItems.length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ModernPayrollSteps(
                  currentStep: _currentStep,
                  maxReachableStep: _maxReachableStep(),
                  onStepTap: _onStepTap,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        if (isNarrow)
                          Column(
                            children: [
                              _buildMonthDropdown(),
                              const SizedBox(height: 12),
                              _buildYearDropdown(),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(child: _buildMonthDropdown()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildYearDropdown()),
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (isNarrow)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildPreviewButton(),
                              const SizedBox(height: 12),
                              _buildApproveButton(),
                              const SizedBox(height: 12),
                              _buildProcessButton(),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(child: _buildPreviewButton()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildApproveButton()),
                              const SizedBox(width: 12),
                              Expanded(child: _buildProcessButton()),
                            ],
                          ),
                        if (_isPreviewing) ...[
                          const SizedBox(height: 12),
                          _buildPreviewProgress(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (visibleAlerts.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverToBoxAdapter(
                  child: Card(
                    color: criticalCount > 0
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Alerts: $criticalCount critical, $warningCount warning',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: criticalCount > 0
                                  ? Colors.red.shade700
                                  : Colors.orange.shade700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ..._systemAlerts
                              .where(
                                (alert) =>
                                    !(_processedPayrolls?.isNotEmpty ??
                                        false) ||
                                    alert.type != AlertType.payrollProcessed,
                              )
                              .take(_maxVisibleAlerts)
                              .map((alert) => _buildAlertListItem(alert)),
                          if (visibleAlerts.length > _maxVisibleAlerts)
                            Text(
                              '+ ${visibleAlerts.length - _maxVisibleAlerts} more alert(s)',
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (preview != null) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Preview - ${_getMonthName(_selectedMonth)} $_selectedYear',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildRow(
                            'Active Employees In Run',
                            preview.totalEmployees.toDouble(),
                          ),
                          _buildRow(
                            'Total Gross',
                            preview.totalGross,
                            bold: true,
                            currencyCode: preview.currency,
                          ),
                          _buildRow(
                            'Total Deductions',
                            preview.totalDeductions,
                            bold: true,
                            isDeduction: true,
                            currencyCode: preview.currency,
                          ),
                          _buildRow(
                            'Total Net',
                            preview.totalNet,
                            bold: true,
                            isNet: true,
                            currencyCode: preview.currency,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final item = previewItems[index];
                    return _buildPayrollCard(
                      item.breakdown,
                      subtitleNet: item.netSalary,
                    );
                  }, childCount: visibleCount),
                ),
                if (visibleCount < previewItems.length)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        children: [
                          Text(
                            'Showing $visibleCount of ${previewItems.length} employees',
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _visiblePreviewItems += _previewBatchSize;
                              });
                            },
                            child: const Text('Load More'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else if (_processedPayrolls != null) ...[
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverToBoxAdapter(
                  child: Text(
                    'Processed Payroll',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 8)),
                if (_canSubmitProcessedForApproval(currentUser))
                  SliverToBoxAdapter(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ElevatedButton.icon(
                          onPressed: _isSubmittingApprovals
                              ? null
                              : _submitProcessedForApproval,
                          icon: _isSubmittingApprovals
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: Text(
                            _isSubmittingApprovals
                                ? 'Submitting...'
                                : 'Submit Processed For Approval',
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final payroll = _processedPayrolls![index];
                    return _buildPayrollCard(payroll, showDownload: true);
                  }, childCount: _processedPayrolls!.length),
                ),
              ] else
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedMonth,
      decoration: const InputDecoration(labelText: 'Month'),
      items: List.generate(12, (index) {
        return DropdownMenuItem(
          value: index + 1,
          child: Text(_getMonthName(index + 1)),
        );
      }),
      onChanged: (value) {
        setState(() {
          _selectedMonth = value!;
          _payrollPreview = null;
          _processedPayrolls = null;
          _systemAlerts = const [];
          _previewApproved = false;
          _approvalSubmitted = false;
          _currentStep = PayrollStep.preview;
        });
      },
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<int>(
      initialValue: _selectedYear,
      decoration: const InputDecoration(labelText: 'Year'),
      items: List.generate(5, (index) {
        final year = DateTime.now().year - 2 + index;
        return DropdownMenuItem(value: year, child: Text(year.toString()));
      }),
      onChanged: (value) {
        setState(() {
          _selectedYear = value!;
          _payrollPreview = null;
          _processedPayrolls = null;
          _systemAlerts = const [];
          _previewApproved = false;
          _approvalSubmitted = false;
          _currentStep = PayrollStep.preview;
        });
      },
    );
  }

  Widget _buildPreviewButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        onPressed: (_isPreviewing || _isProcessing) ? null : _previewPayroll,
        icon: _isPreviewing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.visibility),
        label: Text(_isPreviewing ? 'Previewing...' : 'Preview Payroll'),
      ),
    );
  }

  Widget _buildApproveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed:
            (_isPreviewing ||
                _isProcessing ||
                _payrollPreview == null ||
                _previewApproved)
            ? null
            : _approvePreviewForProcessing,
        icon: Icon(
          _previewApproved ? Icons.check_circle : Icons.task_alt_outlined,
        ),
        label: Text(
          _previewApproved ? 'Approved for Processing' : 'Approve Preview',
        ),
      ),
    );
  }

  Widget _buildPreviewProgress() {
    final hasTotal = _previewTotal > 0;
    final value = hasTotal
        ? (_previewProcessed / _previewTotal).clamp(0.0, 1.0)
        : null;
    final label = hasTotal
        ? '$_previewStage $_previewProcessed/$_previewTotal'
        : _previewStage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: value),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              _previewCancellationToken?.cancel();
              setState(() => _previewStage = 'Cancelling...');
            },
            icon: const Icon(Icons.stop_circle_outlined),
            label: const Text('Cancel Preview'),
          ),
        ),
      ],
    );
  }

  Widget _buildProcessButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed:
            (_isProcessing ||
                    _isPreviewing ||
                    _payrollPreview == null ||
                    !_previewApproved) ||
                (_payrollPreview?.totalEmployees ?? 0) == 0
            ? null
            : _processPayroll,
        icon: _isProcessing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Icon(Icons.play_arrow),
        label: Text(
          _isProcessing
              ? 'Processing...'
              : _previewApproved
              ? 'Confirm & Process'
              : 'Approve Preview First',
        ),
      ),
    );
  }

  Widget _buildPayrollCard(
    Payroll payroll, {
    bool showDownload = false,
    double? subtitleNet,
  }) {
    return Card(
      child: ExpansionTile(
        title: Text(payroll.employeeName),
        subtitle: Text(
          'Net: ${CurrencyFormatter.formatCurrency(subtitleNet ?? payroll.netSalary, currencyCode: payroll.currency)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.success,
          ),
        ),
        trailing: showDownload
            ? IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Download Payslip',
                onPressed: () async {
                  await PdfService.generatePayslip(payroll);
                },
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildRow(
                  'Basic Salary',
                  payroll.basicSalary,
                  currencyCode: payroll.currency,
                ),
                _buildRow(
                  'Allowances',
                  payroll.allowances,
                  currencyCode: payroll.currency,
                ),
                const Divider(),
                _buildRow(
                  'Gross Salary',
                  payroll.grossSalary,
                  bold: true,
                  currencyCode: payroll.currency,
                ),
                const SizedBox(height: 8),
                _buildRow(
                  'PAYE Tax',
                  payroll.paye,
                  isDeduction: true,
                  currencyCode: payroll.currency,
                ),
                _buildRow(
                  'Pension (8%)',
                  payroll.pension,
                  isDeduction: true,
                  currencyCode: payroll.currency,
                ),
                _buildRow(
                  'NHF (2.5%)',
                  payroll.nhf,
                  isDeduction: true,
                  currencyCode: payroll.currency,
                ),
                if (payroll.loanDeduction > 0)
                  _buildRow(
                    'Loan Deduction',
                    payroll.loanDeduction,
                    isDeduction: true,
                    currencyCode: payroll.currency,
                  ),
                if (payroll.otherDeductions - payroll.loanDeduction > 0)
                  _buildRow(
                    'Other Deductions',
                    payroll.otherDeductions - payroll.loanDeduction,
                    isDeduction: true,
                    currencyCode: payroll.currency,
                  ),
                const Divider(),
                _buildRow(
                  'Total Deductions',
                  payroll.totalDeductions,
                  bold: true,
                  isDeduction: true,
                  currencyCode: payroll.currency,
                ),
                const Divider(thickness: 2),
                _buildRow(
                  'Net Salary',
                  payroll.netSalary,
                  bold: true,
                  isNet: true,
                  currencyCode: payroll.currency,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    double amount, {
    bool bold = false,
    bool isDeduction = false,
    bool isNet = false,
    String currencyCode = 'NGN',
  }) {
    final isEmployeesRow = label == 'Employees';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEmployeesRow
                  ? amount.toInt().toString()
                  : CurrencyFormatter.formatCurrency(
                      amount,
                      currencyCode: currencyCode,
                    ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: isNet
                    ? AppColors.success
                    : isDeduction
                    ? AppColors.error
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return AppColors.error;
      case AlertSeverity.warning:
        return Colors.orange;
      case AlertSeverity.info:
        return AppColors.textSecondary;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  bool _canSubmitProcessedForApproval(AppUser? user) {
    if (user == null) return false;
    return user.role == UserRole.admin ||
        user.role == UserRole.hr ||
        user.role == UserRole.accountant;
  }

  Future<void> _submitProcessedForApproval() async {
    final payrolls = _processedPayrolls;
    final user = ref.read(currentUserProvider).asData?.value;
    if (payrolls == null || payrolls.isEmpty || user == null) return;

    setState(() => _isSubmittingApprovals = true);
    var submitted = 0;
    var skipped = 0;

    for (final payroll in payrolls) {
      try {
        await _payrollService.submitForApproval(payroll.id);
        submitted++;
      } catch (_) {
        skipped++;
      }
    }

    if (!mounted) return;
    setState(() => _isSubmittingApprovals = false);
    if (submitted > 0) {
      setState(() {
        _currentStep = PayrollStep.complete;
        _approvalSubmitted = true;
      });
      _refreshPayrollData();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Submitted: $submitted, Skipped: $skipped')),
    );
  }

  PayrollStep _maxReachableStep() {
    if (_approvalSubmitted) return PayrollStep.complete;
    if (_processedPayrolls?.isNotEmpty ?? false) return PayrollStep.complete;
    if (_previewApproved) return PayrollStep.process;
    if (_payrollPreview != null) return PayrollStep.approve;
    return PayrollStep.preview;
  }

  void _onStepTap(PayrollStep step) {
    final maxStep = _maxReachableStep();
    if (step.index > maxStep.index) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete earlier steps first. Current stage: ${maxStep.name}',
          ),
        ),
      );
      return;
    }
    setState(() => _currentStep = step);
  }
}

enum PayrollStep { preview, approve, process, complete }

class _ModernPayrollSteps extends StatelessWidget {
  final PayrollStep currentStep;
  final ValueChanged<PayrollStep> onStepTap;
  final PayrollStep maxReachableStep;

  const _ModernPayrollSteps({
    required this.currentStep,
    required this.onStepTap,
    required this.maxReachableStep,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payroll Workflow',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildStep(
            step: PayrollStep.preview,
            title: 'Preview',
            subtitle: 'Review calculations',
            icon: Icons.visibility_outlined,
          ),
          _buildStep(
            step: PayrollStep.approve,
            title: 'Approve',
            subtitle: 'Get approvals',
            icon: Icons.check_circle_outline,
          ),
          _buildStep(
            step: PayrollStep.process,
            title: 'Process',
            subtitle: 'Generate payslips',
            icon: Icons.play_circle_outline,
          ),
          _buildStep(
            step: PayrollStep.complete,
            title: 'Complete',
            subtitle: 'Lock payroll',
            icon: Icons.lock_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required PayrollStep step,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isActive = currentStep == step;
    final isCompleted = step.index < currentStep.index;
    final isReachable = step.index <= maxReachableStep.index;

    return InkWell(
      onTap: isReachable ? () => onStepTap(step) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.success
                    : isActive
                    ? AppColors.primary
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isCompleted ? Icons.check : icon,
                color: !isReachable
                    ? AppColors.textTertiary
                    : (isCompleted || isActive)
                    ? Colors.white
                    : AppColors.textSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: !isReachable
                          ? AppColors.textTertiary
                          : isActive
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
