import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/core/utils/date_formatter.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/loan_model.dart';
import 'package:roipayroll/providers/loan_provider.dart';
import 'package:roipayroll/screens/loan/request_loan_screen.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/loan_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class LoansListScreen extends ConsumerStatefulWidget {
  const LoansListScreen({super.key});

  @override
  ConsumerState<LoansListScreen> createState() => _LoansListScreenState();
}

class _LoansListScreenState extends ConsumerState<LoansListScreen> {
  final _loanService = LoanService();
  final _employeeService = EmployeeService();

  final Map<String, String> _employeeNameCache = {};
  final Map<String, LoanRiskAssessment> _loanRiskCache = {};

  String _selectedFilter = 'All';

  static const List<String> _filters = [
    'All',
    'Pending',
    'Active',
    'Completed',
    'Rejected',
  ];

  bool _isNameMissing(String name) {
    return name.trim().isEmpty || name.trim().toLowerCase() == 'unknown';
  }

  String _displayName(Loan loan) {
    final cached = _employeeNameCache[loan.employeeId];
    if (cached != null && cached.trim().isNotEmpty) return cached;
    return _isNameMissing(loan.employeeName) ? 'Employee' : loan.employeeName;
  }

  Future<void> _hydrateEmployeeNames(List<Loan> loans) async {
    final missingIds = loans
        .where((loan) => _isNameMissing(loan.employeeName))
        .map((loan) => loan.employeeId)
        .where((id) => !_employeeNameCache.containsKey(id))
        .toSet();

    if (missingIds.isEmpty) return;

    for (final id in missingIds) {
      final employee = await _employeeService.getEmployeeById(id);
      if (employee != null && employee.fullName.trim().isNotEmpty) {
        _employeeNameCache[id] = employee.fullName.trim();
      }
    }

    if (mounted) setState(() {});
  }

  void _queueHydrateEmployeeNames(List<Loan> loans) {
    Future.microtask(() => _hydrateEmployeeNames(loans));
  }

  void _refreshLoans() {
    ref.read(loanActionsProvider).refresh();
  }

  Future<void> _approveLoan(Loan loan) async {
    final confirm = await NotificationHelper.showConfirmDialog(
      context,
      title: 'Approve Loan',
      message:
          'Approve ${CurrencyFormatter.formatNaira(loan.amount)} for ${_displayName(loan)}?',
      confirmText: 'Approve',
    );

    if (confirm != true || !mounted) return;

    NotificationHelper.showLoading(context, message: 'Approving loan...');
    try {
      await ref.read(loanActionsProvider).approve(loan);
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Loan approved successfully');
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Failed to approve loan: $e');
    }
  }

  Future<void> _rejectLoan(Loan loan) async {
    final reason = await NotificationHelper.showInputDialog(
      context,
      title: 'Reject Loan',
      hint: 'Enter rejection reason',
    );

    if ((reason ?? '').trim().isEmpty || !mounted) return;

    NotificationHelper.showLoading(context, message: 'Rejecting loan...');
    try {
      await ref.read(loanActionsProvider).reject(loan, reason!.trim());
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Loan rejected');
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Failed to reject loan: $e');
    }
  }

  Future<void> _fixLoanNames() async {
    NotificationHelper.showLoading(context, message: 'Fixing loan names...');
    try {
      final updated = await ref.read(loanActionsProvider).backfillNames();
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        updated == 0
            ? 'No loan names needed updates'
            : 'Updated $updated loan(s)',
      );
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Failed to update loan names');
    }
  }

  List<Loan> _applyFilter(List<Loan> loans) {
    if (_selectedFilter == 'All') return loans;

    final status = LoanStatus.values.firstWhere(
      (value) => value.name == _selectedFilter.toLowerCase(),
      orElse: () => LoanStatus.pending,
    );
    return loans.where((loan) => loan.status == status).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(loanDashboardProvider);
    final dashboard = dataAsync.asData?.value;

    return AppScaffold(
      topBar: AppBar(
        title: Text(_titleFor(dashboard)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshLoans,
            icon: const Icon(Icons.refresh),
          ),
          if (dashboard?.canViewAll == true)
            IconButton(
              tooltip: 'Fix Loan Names',
              onPressed: _fixLoanNames,
              icon: const Icon(Icons.person_search_outlined),
            ),
        ],
      ),
      floatingActionButton: dashboard?.canRequest == true
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RequestLoanScreen(),
                  ),
                );
                if (result == true) _refreshLoans();
              },
              icon: const Icon(Icons.add),
              label: const Text('Request Loan'),
            )
          : null,
      body: dataAsync.when(
        loading: () => const ModernLoadingState(message: 'Loading loans...'),
        error: (error, _) => ModernErrorState(
          message: 'Failed to load loans',
          subtitle: error.toString(),
          onRetry: _refreshLoans,
        ),
        data: (data) => ResponsiveLayout(
          mobile: _buildContent(data, padding: 12),
          tablet: _buildContent(data, padding: 16),
          desktop: _buildContent(data, padding: 20),
        ),
      ),
    );
  }

  String _titleFor(LoanDashboardData? data) {
    return switch (data?.scope) {
      LoanRoleScope.approver => 'Loan Approval Center',
      LoanRoleScope.reviewer => 'Loan Oversight',
      LoanRoleScope.employee => 'My Loans',
      null => 'Loans',
    };
  }

  Widget _buildContent(LoanDashboardData data, {required double padding}) {
    final loans = data.visibleLoans;
    final filteredLoans = _applyFilter(loans);
    _queueHydrateEmployeeNames(loans);

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        _buildHeroCard(data),
        const SizedBox(height: 16),
        if (data.canViewAll && data.myLoans.isNotEmpty) ...[
          _buildMySnapshot(data),
          const SizedBox(height: 16),
        ],
        ModernMetricsGrid(metrics: _buildMetrics(data)),
        const SizedBox(height: 16),
        _buildFilterBar(filteredLoans.length),
        const SizedBox(height: 16),
        if (filteredLoans.isEmpty)
          SizedBox(
            height: 240,
            child: ModernEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: _emptyTitleFor(data),
              subtitle: _emptySubtitleFor(data),
            ),
          )
        else
          ...filteredLoans.map((loan) => _buildLoanCard(loan, data: data)),
      ],
    );
  }

  Widget _buildHeroCard(LoanDashboardData data) {
    final colors = switch (data.scope) {
      LoanRoleScope.approver => [AppColors.primary, AppColors.success],
      LoanRoleScope.reviewer => [AppColors.primary, AppColors.info],
      LoanRoleScope.employee => [AppColors.primary, AppColors.accentDark],
    };

    final subtitle = switch (data.scope) {
      LoanRoleScope.approver =>
        'Review pending requests, assess repayment risk, and approve or reject from one queue.',
      LoanRoleScope.reviewer =>
        'Track company-wide loan activity in read-only mode and monitor repayment exposure.',
      LoanRoleScope.employee =>
        'Follow your loan requests, see balances, and keep an eye on repayment progress.',
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleFor(data),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroMetric('Visible Loans', data.visibleLoans.length.toString()),
              _heroMetric('Pending', data.pendingLoans.length.toString()),
              _heroMetric(
                'Outstanding',
                CurrencyFormatter.formatNaira(
                  _sumOutstanding(data.visibleLoans),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMySnapshot(LoanDashboardData data) {
    final myOutstanding = _sumOutstanding(data.myLoans);
    final myPending = data.myLoans
        .where((loan) => loan.status == LoanStatus.pending)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Borrowing Snapshot',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'You can review company activity here while still tracking your own requests separately.',
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _snapshotChip('My loans', data.myLoans.length.toString()),
                _snapshotChip('My pending', myPending.toString()),
                _snapshotChip(
                  'My outstanding',
                  CurrencyFormatter.formatNaira(myOutstanding),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshotChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<ModernMetricCard> _buildMetrics(LoanDashboardData data) {
    if (data.scope == LoanRoleScope.employee) {
      return [
        ModernMetricCard(
          title: 'Requests',
          value: data.visibleLoans.length.toString(),
          icon: Icons.receipt_long_outlined,
          color: AppColors.primary,
        ),
        ModernMetricCard(
          title: 'Pending',
          value: data.pendingLoans.length.toString(),
          icon: Icons.pending_actions_outlined,
          color: AppColors.warning,
        ),
        ModernMetricCard(
          title: 'Active',
          value: data.activeLoans.length.toString(),
          icon: Icons.play_circle_outline,
          color: AppColors.success,
        ),
        ModernMetricCard(
          title: 'Outstanding',
          value: CurrencyFormatter.formatNaira(
            _sumOutstanding(data.visibleLoans),
          ),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.info,
        ),
      ];
    }

    return [
      ModernMetricCard(
        title: 'Portfolio',
        value: data.visibleLoans.length.toString(),
        icon: Icons.inventory_2_outlined,
        color: AppColors.primary,
      ),
      ModernMetricCard(
        title: 'Pending Review',
        value: data.pendingLoans.length.toString(),
        icon: Icons.fact_check_outlined,
        color: AppColors.warning,
      ),
      ModernMetricCard(
        title: 'Active Loans',
        value: data.activeLoans.length.toString(),
        icon: Icons.sync_alt_outlined,
        color: AppColors.success,
      ),
      ModernMetricCard(
        title: 'Exposure',
        value: CurrencyFormatter.formatNaira(
          _sumOutstanding(data.visibleLoans),
        ),
        icon: Icons.savings_outlined,
        color: AppColors.info,
      ),
    ];
  }

  Widget _buildFilterBar(int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count result${count == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final selected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedFilter = filter);
                      },
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emptyTitleFor(LoanDashboardData data) {
    return switch (data.scope) {
      LoanRoleScope.approver => 'No loans match this filter',
      LoanRoleScope.reviewer => 'No company loans match this filter',
      LoanRoleScope.employee => 'No loan requests yet',
    };
  }

  String _emptySubtitleFor(LoanDashboardData data) {
    return switch (data.scope) {
      LoanRoleScope.approver =>
        'Pending and processed requests will appear here as soon as they are created.',
      LoanRoleScope.reviewer =>
        'You can switch filters to inspect a different part of the loan portfolio.',
      LoanRoleScope.employee =>
        'Create your first loan request to start tracking approvals and repayments.',
    };
  }

  Widget _buildLoanCard(Loan loan, {required LoanDashboardData data}) {
    final statusColor = _getStatusColor(loan.status);
    final progress = loan.amount <= 0
        ? 0.0
        : (loan.totalRepaid / loan.amount).clamp(0.0, 1.0);
    final isMine = data.employeeId == loan.employeeId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: statusColor, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.14),
                    child: Icon(
                      _getStatusIcon(loan.status),
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              _displayName(loan),
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isMine && data.canViewAll)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.infoLight,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'My request',
                                  style: TextStyle(
                                    color: AppColors.info,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          CurrencyFormatter.formatNaira(loan.amount),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requested ${DateFormatter.formatShort(loan.requestDate)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusBadge(
                    status: loan.status.name.toUpperCase(),
                    color: statusColor,
                  ),
                ],
              ),
              if (data.canViewAll && loan.status == LoanStatus.pending) ...[
                const SizedBox(height: 14),
                _buildRiskBadge(loan),
              ],
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                backgroundColor: AppColors.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress * 100).toStringAsFixed(0)}% repaid',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _detailPill('Duration', '${loan.durationMonths} months'),
                  _detailPill(
                    'Monthly deduction',
                    CurrencyFormatter.formatNaira(loan.monthlyDeduction),
                  ),
                  _detailPill(
                    'Total repaid',
                    CurrencyFormatter.formatNaira(loan.totalRepaid),
                  ),
                  _detailPill(
                    'Balance',
                    CurrencyFormatter.formatNaira(loan.remainingBalance),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loan.reason,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (loan.approvedBy != null || loan.rejectionReason != null) ...[
                const SizedBox(height: 16),
                if (loan.approvedBy != null)
                  _infoRow('Approved by', loan.approvedBy!),
                if (loan.approvalDate != null)
                  _infoRow(
                    'Approval date',
                    DateFormatter.formatStandard(loan.approvalDate!),
                  ),
                if (loan.rejectionReason != null)
                  _infoRow('Rejection reason', loan.rejectionReason!),
              ],
              if (data.canApprove && loan.status == LoanStatus.pending) ...[
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectLoan(loan),
                        icon: const Icon(Icons.close, color: AppColors.error),
                        label: const Text(
                          'Reject',
                          style: TextStyle(color: AppColors.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _approveLoan(loan),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildRiskBadge(Loan loan) {
    final cacheKey = '${loan.id}_${loan.amount.toStringAsFixed(2)}';
    final cached = _loanRiskCache[cacheKey];
    if (cached != null) {
      return _riskChip(cached);
    }

    return FutureBuilder<LoanRiskAssessment>(
      future: _loanService.calculateLoanRisk(
        employeeId: loan.employeeId,
        requestedAmount: loan.amount,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _loanRiskCache[cacheKey] = snapshot.data!;
          return _riskChip(snapshot.data!);
        }
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      },
    );
  }

  Widget _riskChip(LoanRiskAssessment risk) {
    final color = _riskColor(risk.level);
    return Tooltip(
      message: risk.reason,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Risk ${risk.label}',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  double _sumOutstanding(List<Loan> loans) {
    return loans.fold<double>(0, (sum, loan) => sum + loan.remainingBalance);
  }

  Color _getStatusColor(LoanStatus status) {
    switch (status) {
      case LoanStatus.pending:
        return AppColors.warning;
      case LoanStatus.approved:
      case LoanStatus.active:
        return AppColors.success;
      case LoanStatus.completed:
        return AppColors.info;
      case LoanStatus.rejected:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(LoanStatus status) {
    switch (status) {
      case LoanStatus.pending:
        return Icons.hourglass_empty;
      case LoanStatus.approved:
      case LoanStatus.active:
        return Icons.check_circle_outline;
      case LoanStatus.completed:
        return Icons.done_all_outlined;
      case LoanStatus.rejected:
        return Icons.cancel_outlined;
    }
  }

  Color _riskColor(LoanRiskLevel level) {
    switch (level) {
      case LoanRiskLevel.low:
        return AppColors.success;
      case LoanRiskLevel.medium:
        return AppColors.warning;
      case LoanRiskLevel.high:
        return AppColors.error;
    }
  }
}
