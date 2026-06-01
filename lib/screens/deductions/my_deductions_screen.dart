import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/employee_deduction_model.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/deduction_provider.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class MyDeductionsScreen extends ConsumerStatefulWidget {
  const MyDeductionsScreen({super.key});

  @override
  ConsumerState<MyDeductionsScreen> createState() => _MyDeductionsScreenState();
}

class _MyDeductionsScreenState extends ConsumerState<MyDeductionsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  DeductionCategory? _categoryFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeDeduction> _filtered(List<EmployeeDeduction> all) {
    final query = _search.trim().toLowerCase();

    return all.where((deduction) {
      if (deduction.status == DeductionStatus.cancelled) {
        return false;
      }
      if (_categoryFilter != null && deduction.category != _categoryFilter) {
        return false;
      }
      if (query.isEmpty) return true;

      final haystack = [
        deduction.deductionTypeName,
        _categoryLabel(deduction.category),
        deduction.referenceNumber ?? '',
        deduction.description ?? '',
        _statusLabel(deduction.status),
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  Map<DeductionCategory, List<EmployeeDeduction>> _grouped(
    List<EmployeeDeduction> deductions,
  ) {
    final map = <DeductionCategory, List<EmployeeDeduction>>{};
    for (final deduction in deductions) {
      map.putIfAbsent(deduction.category, () => <EmployeeDeduction>[]);
      map[deduction.category]!.add(deduction);
    }
    return map;
  }

  Future<void> _openNewRequest() async {
    final user = ref.read(currentUserProvider).asData?.value;
    if (user == null) return;

    final canRequestLoan = PermissionService.hasPermission(
      user,
      Permission.viewLoans,
    );
    final canOpenSalaryAdvance = PermissionService.hasPermission(
      user,
      Permission.viewSalaryAdvance,
    );

    if (!canRequestLoan && !canOpenSalaryAdvance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No deduction-related request flow is available.'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canRequestLoan)
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Request Loan'),
                subtitle: const Text('Create a new loan request'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.requestLoan);
                },
              ),
            if (canOpenSalaryAdvance)
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Salary Advance'),
                subtitle: const Text('Open salary advance requests'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.salaryAdvances);
                },
              ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(DeductionCategory category) {
    switch (category) {
      case DeductionCategory.statutory:
        return 'Statutory';
      case DeductionCategory.loan:
        return 'Loan';
      case DeductionCategory.advance:
        return 'Advance';
      case DeductionCategory.garnishment:
        return 'Garnishment';
      case DeductionCategory.insurance:
        return 'Insurance';
      case DeductionCategory.union:
        return 'Union';
      case DeductionCategory.other:
        return 'Other';
    }
  }

  String _statusLabel(DeductionStatus status) {
    switch (status) {
      case DeductionStatus.pending:
        return 'Pending';
      case DeductionStatus.active:
        return 'Active';
      case DeductionStatus.completed:
        return 'Completed';
      case DeductionStatus.cancelled:
        return 'Cancelled';
      case DeductionStatus.suspended:
        return 'Suspended';
    }
  }

  Color _statusColor(DeductionStatus status) {
    switch (status) {
      case DeductionStatus.pending:
        return AppColors.warningDark;
      case DeductionStatus.active:
        return AppColors.success;
      case DeductionStatus.completed:
        return AppColors.info;
      case DeductionStatus.cancelled:
        return AppColors.error;
      case DeductionStatus.suspended:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final myDeductionsAsync = ref.watch(myDeductionsProvider);

    return AppScaffold(
      title: 'My Deductions',
      body: currentUserAsync.when(
        loading: () => const ModernLoadingState(message: 'Loading profile...'),
        error: (error, _) => ModernErrorState(
          message: 'Failed to load profile',
          subtitle: error.toString(),
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
        data: (user) {
          if (user == null ||
              !PermissionService.hasPermission(
                user,
                Permission.viewDeductions,
              )) {
            return _buildRestrictedState(user?.getRoleName() ?? 'Unknown');
          }

          return myDeductionsAsync.when(
            loading: () =>
                const ModernLoadingState(message: 'Loading deductions...'),
            error: (error, _) => ModernErrorState(
              message: 'Failed to load my deductions',
              subtitle: error.toString(),
              onRetry: () => ref.invalidate(myDeductionsProvider),
            ),
            data: (data) {
              if (data.employeeId == null) {
                return _buildUnlinkedState();
              }

              final filtered = _filtered(data.deductions);
              final grouped = _grouped(filtered);
              final activeCount = filtered
                  .where(
                    (deduction) => deduction.status == DeductionStatus.active,
                  )
                  .length;
              final totalDeducted = filtered.fold<double>(
                0,
                (sum, deduction) => sum + deduction.totalDeducted,
              );
              final totalBalance = filtered.fold<double>(
                0,
                (sum, deduction) => sum + deduction.balance,
              );
              final hasPending = filtered.any(
                (deduction) => deduction.status == DeductionStatus.pending,
              );

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(myDeductionsProvider),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildSummaryRow(
                      activeCount: activeCount,
                      totalDeducted: totalDeducted,
                      totalBalance: totalBalance,
                      hasPending: hasPending,
                    ),
                    const SizedBox(height: 22),
                    _buildCategoriesHeader(),
                    const SizedBox(height: 16),
                    if (grouped.isEmpty)
                      _buildEmptyState()
                    else
                      ...grouped.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCategorySection(entry.key, entry.value),
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildSecurityBanner(),
                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRestrictedState(String roleLabel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.error,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to view personal deduction records. Current role: $roleLabel.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnlinkedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.person_off_outlined,
                    color: AppColors.textSecondary,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Employee Profile Not Linked',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your account is not currently mapped to an employee record, so personal deductions cannot be shown yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        final searchField = SizedBox(
          width: isWide ? 340 : double.infinity,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search records...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primaryDark),
              ),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        );

        final actions = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.deductionHistory),
              icon: const Icon(Icons.history_rounded),
              label: const Text('History'),
            ),
            ElevatedButton.icon(
              onPressed: _openNewRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Request'),
            ),
          ],
        );

        if (isWide) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Deductions',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Manage and monitor all automatic withholdings, loan repayments, and tax deductions from your payroll.',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  searchField,
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [actions],
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'My Deductions',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage and monitor all automatic withholdings, loan repayments, and tax deductions from your payroll.',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            searchField,
            const SizedBox(height: 16),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildSummaryRow({
    required int activeCount,
    required double totalDeducted,
    required double totalBalance,
    required bool hasPending,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildMetricCard(
            title: 'COUNT',
            value: activeCount.toString(),
            subtitle: 'Active Deductions',
            helper: '',
            icon: Icons.account_tree_outlined,
            dark: false,
          ),
          _buildMetricCard(
            title: 'AMOUNT',
            value: CurrencyFormatter.formatNaira(totalDeducted),
            subtitle: 'Total Deducted (YTD)',
            helper: 'Synced from payroll records',
            icon: Icons.payments_outlined,
            dark: false,
          ),
          _buildMetricCard(
            title: 'BALANCE',
            value: CurrencyFormatter.formatNaira(totalBalance),
            subtitle: 'Outstanding Obligations',
            helper: hasPending
                ? 'Pending items require review'
                : 'No Pending Overdues',
            icon: Icons.savings_outlined,
            dark: true,
          ),
        ];

        if (constraints.maxWidth >= 1100) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
            ],
          );
        }

        return Column(
          children: [
            cards[0],
            const SizedBox(height: 16),
            cards[1],
            const SizedBox(height: 16),
            cards[2],
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required String helper,
    required IconData icon,
    required bool dark,
  }) {
    final bgColor = dark ? AppColors.primaryDark : Colors.white;
    final textColor = dark ? Colors.white : AppColors.primaryDark;
    final subColor = dark ? Colors.white70 : AppColors.textSecondary;
    final iconBg = dark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.infoLight;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: dark ? AppColors.primaryDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: dark ? Colors.white : AppColors.infoDark,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: dark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            value,
            style: TextStyle(
              fontSize: 46,
              height: 1,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: subColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (helper.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              helper,
              style: TextStyle(
                color: dark ? AppColors.successLight : AppColors.textTertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoriesHeader() {
    return Row(
      children: [
        const Text(
          'All Categories',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: Container(height: 1, color: AppColors.divider)),
      ],
    );
  }

  Widget _buildCategorySection(
    DeductionCategory category,
    List<EmployeeDeduction> deductions,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _categoryLabel(category).toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              letterSpacing: 1.8,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          ...deductions.map(
            (deduction) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildDeductionCard(deduction),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionCard(EmployeeDeduction deduction) {
    final progress = deduction.totalAmount <= 0
        ? 0.0
        : (deduction.totalDeducted / deduction.totalAmount)
              .clamp(0, 1)
              .toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 780;
          final leading = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      deduction.deductionTypeName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  _buildStatusChip(deduction.status),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Text(
                    _categoryLabel(deduction.category),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  if (deduction.referenceNumber?.trim().isNotEmpty ?? false)
                    Text(
                      'Ref: ${deduction.referenceNumber!}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ],
          );

          final progressBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Progress',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _statusColor(deduction.status),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Deducted ${CurrencyFormatter.formatNaira(deduction.totalDeducted)} / ${CurrencyFormatter.formatNaira(deduction.totalAmount)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          );

          final balanceBlock = Column(
            crossAxisAlignment: isWide
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              const Text(
                'Balance',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.formatNaira(deduction.balance),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 4, child: leading),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: progressBlock),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: balanceBlock),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(height: 14),
              progressBlock,
              const SizedBox(height: 14),
              balanceBlock,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusChip(DeductionStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 54,
              color: AppColors.textDisabled,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No deductions found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'It looks like you do not have any active deductions at the moment. Any future payroll adjustments, tax withholdings, or loan repayments will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => ref.invalidate(myDeductionsProvider),
                child: const Text('Refresh Records'),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Deduction policies are available from HR/Payroll.',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Learn More'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.infoDark,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              'Security Shield Active: All deduction records are encrypted and verified against bank-grade security protocols.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'SECURE SSL',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
