import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/expense_claim_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/expense_provider.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class ExpenseReimbursementScreen extends ConsumerStatefulWidget {
  const ExpenseReimbursementScreen({super.key});

  @override
  ConsumerState<ExpenseReimbursementScreen> createState() =>
      _ExpenseReimbursementScreenState();
}

class _ExpenseReimbursementScreenState
    extends ConsumerState<ExpenseReimbursementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(expenseDataProvider);

    return AppScaffold(
      topBar: AppBar(
        title: const Text('Expense Module'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(expenseDataProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const ModernLoadingState(message: 'Loading expenses...'),
        error: (error, _) => ModernErrorState(
          message: 'Failed to load expenses',
          subtitle: error.toString(),
          onRetry: () => ref.invalidate(expenseDataProvider),
        ),
        data: (data) {
          return ResponsiveLayout(
            mobile: _buildPage(context, ref, data, compact: true),
            tablet: _buildPage(context, ref, data, compact: false),
            desktop: _buildPage(context, ref, data, compact: false),
          );
        },
      ),
    );
  }

  Widget _buildPage(
    BuildContext context,
    WidgetRef ref,
    ExpenseData data, {
    required bool compact,
  }) {
    final mode = _resolveMode(data);
    final moduleClaims = _filterClaims(data.allClaims);
    final myClaims = _filterClaims(data.myClaims);
    final pendingClaims = _filterClaims(data.pendingClaims);
    final contentPadding = compact ? 16.0 : 24.0;
    final claimsForList = switch (mode) {
      _ExpenseViewMode.employee => myClaims,
      _ExpenseViewMode.approver => moduleClaims,
      _ExpenseViewMode.oversight => moduleClaims,
    };

    return ListView(
      padding: EdgeInsets.all(contentPadding),
      children: [
        _buildHeader(mode, data, compact: compact),
        const SizedBox(height: 18),
        _buildHero(mode, data),
        const SizedBox(height: 18),
        _buildSummaryCards(mode, data),
        const SizedBox(height: 18),
        _buildMainGrid(
          context,
          ref,
          data,
          mode: mode,
          compact: compact,
          claimsForList: claimsForList,
          pendingClaims: pendingClaims,
          myClaims: myClaims,
        ),
        if (data.canSubmit) ...[
          const SizedBox(height: 18),
          _buildSubmitBanner(context, ref, data.user!),
        ],
      ],
    );
  }

  _ExpenseViewMode _resolveMode(ExpenseData data) {
    final role = data.user?.role;
    if (data.canApprove) {
      return _ExpenseViewMode.approver;
    }
    if (role == UserRole.hr || data.canViewAll) {
      return _ExpenseViewMode.oversight;
    }
    return _ExpenseViewMode.employee;
  }

  List<ExpenseClaim> _filterClaims(List<ExpenseClaim> claims) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return claims;

    return claims
        .where((claim) {
          final haystack = [
            claim.employeeName,
            claim.description,
            claim.category.name,
            claim.status.name,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  Widget _buildHeader(
    _ExpenseViewMode mode,
    ExpenseData data, {
    required bool compact,
  }) {
    final title = switch (mode) {
      _ExpenseViewMode.employee => 'My Expense Desk',
      _ExpenseViewMode.approver => 'Expense Command Center',
      _ExpenseViewMode.oversight => 'Expense Oversight Hub',
    };
    final subtitle = switch (mode) {
      _ExpenseViewMode.employee =>
        'Submit claims, watch approvals, and track reimbursement outcomes.',
      _ExpenseViewMode.approver =>
        'Review live claims, clear approval queues, and monitor expense exposure.',
      _ExpenseViewMode.oversight =>
        'Track organization-wide expense activity without approval controls.',
    };

    final headerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: compact ? 30 : 38,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF132F4C),
            letterSpacing: -1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );

    final searchBox = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        decoration: InputDecoration(
          hintText: switch (mode) {
            _ExpenseViewMode.employee => 'Search my claims...',
            _ExpenseViewMode.approver => 'Search claims awaiting action...',
            _ExpenseViewMode.oversight => 'Search claims, people, or status...',
          },
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(Icons.close),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE2E9F3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFE2E9F3)),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = compact || constraints.maxWidth < 980;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [headerContent, const SizedBox(height: 16), searchBox],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: headerContent),
            const SizedBox(width: 18),
            searchBox,
          ],
        );
      },
    );
  }

  Widget _buildHero(_ExpenseViewMode mode, ExpenseData data) {
    final myClaims = data.myClaims;
    final pendingClaims = data.pendingClaims;
    final moduleClaims = data.allClaims;

    final awaitingReview = switch (mode) {
      _ExpenseViewMode.employee =>
        myClaims.where((claim) => claim.isPending).length,
      _ExpenseViewMode.approver => pendingClaims.length,
      _ExpenseViewMode.oversight =>
        moduleClaims.where((claim) => claim.isPending).length,
    };
    final headlineValue = switch (mode) {
      _ExpenseViewMode.employee =>
        myClaims
            .where((claim) => claim.isApproved || claim.isPaid)
            .fold<double>(0, (sum, claim) => sum + claim.amount),
      _ExpenseViewMode.approver => pendingClaims.fold<double>(
        0,
        (sum, claim) => sum + claim.amount,
      ),
      _ExpenseViewMode.oversight => moduleClaims.fold<double>(
        0,
        (sum, claim) => sum + claim.amount,
      ),
    };
    final accessLabel = switch (mode) {
      _ExpenseViewMode.employee => 'Self Service',
      _ExpenseViewMode.approver => 'Approver',
      _ExpenseViewMode.oversight => 'Oversight',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF132F4C),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF132F4C).withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 900;
          final left = Wrap(
            spacing: 26,
            runSpacing: 18,
            children: [
              _buildHeroStat(
                label: 'Awaiting Review',
                value: '$awaitingReview claim${awaitingReview == 1 ? '' : 's'}',
              ),
              _buildHeroDivider(),
              _buildHeroStat(
                label: switch (mode) {
                  _ExpenseViewMode.employee => 'Approved Value',
                  _ExpenseViewMode.approver => 'Pending Value',
                  _ExpenseViewMode.oversight => 'Module Value',
                },
                value: CurrencyFormatter.formatNaira(headlineValue),
              ),
            ],
          );

          final accessBadge = Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACCESS MODE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.70),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accessLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [left, const SizedBox(height: 18), accessBadge],
            );
          }

          return Row(
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              accessBadge,
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeroStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.8,
            color: Colors.white.withValues(alpha: 0.64),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroDivider() {
    return Container(
      width: 1,
      height: 52,
      color: Colors.white.withValues(alpha: 0.16),
    );
  }

  Widget _buildSummaryCards(_ExpenseViewMode mode, ExpenseData data) {
    final myClaims = data.myClaims;
    final allClaims = data.allClaims;
    final pendingClaims = data.pendingClaims;

    final approvedCount = myClaims.where((claim) => claim.isApproved).length;
    final rejectedCount = myClaims.where((claim) => claim.isRejected).length;
    final paidValue = myClaims
        .where((claim) => claim.isPaid)
        .fold<double>(0, (sum, claim) => sum + claim.amount);
    final approvedModuleCount = allClaims
        .where((claim) => claim.isApproved || claim.isPaid)
        .length;
    final rejectedModuleCount = allClaims
        .where((claim) => claim.isRejected)
        .length;
    final pendingValue = pendingClaims.fold<double>(
      0,
      (sum, claim) => sum + claim.amount,
    );

    final cards = switch (mode) {
      _ExpenseViewMode.employee => [
        _ExpenseMetricData(
          title: 'Total Claims',
          value: myClaims.length.toString(),
          subtitle: 'Your submitted requests',
          icon: Icons.receipt_long_outlined,
          accent: const Color(0xFFEEF3FB),
          iconColor: const Color(0xFF132F4C),
        ),
        _ExpenseMetricData(
          title: 'Pending Review',
          value: myClaims.where((claim) => claim.isPending).length.toString(),
          subtitle: 'Awaiting sign-off',
          icon: Icons.inventory_2_outlined,
          accent: const Color(0xFFEAF1FF),
          iconColor: const Color(0xFF4260B4),
        ),
        _ExpenseMetricData(
          title: 'Approved',
          value: approvedCount.toString(),
          subtitle: 'Ready for reimbursement',
          icon: Icons.check_circle_outline,
          accent: const Color(0xFFE8F7F0),
          iconColor: const Color(0xFF129A67),
        ),
        _ExpenseMetricData(
          title: 'Paid Out',
          value: CurrencyFormatter.formatNaira(paidValue),
          subtitle: '$rejectedCount rejection${rejectedCount == 1 ? '' : 's'}',
          icon: Icons.account_balance_wallet_outlined,
          accent: const Color(0xFFFDF2EF),
          iconColor: const Color(0xFFBD2D22),
        ),
      ],
      _ExpenseViewMode.approver => [
        _ExpenseMetricData(
          title: 'Pending Approvals',
          value: pendingClaims.length.toString(),
          subtitle: CurrencyFormatter.formatNaira(pendingValue),
          icon: Icons.inventory_2_outlined,
          accent: const Color(0xFFEAF1FF),
          iconColor: const Color(0xFF4260B4),
        ),
        _ExpenseMetricData(
          title: 'All Claims',
          value: allClaims.length.toString(),
          subtitle: 'Organization-wide submissions',
          icon: Icons.receipt_long_outlined,
          accent: const Color(0xFFEEF3FB),
          iconColor: const Color(0xFF132F4C),
        ),
        _ExpenseMetricData(
          title: 'Approved Pool',
          value: approvedModuleCount.toString(),
          subtitle: 'Approved or paid claims',
          icon: Icons.task_alt_outlined,
          accent: const Color(0xFFE8F7F0),
          iconColor: const Color(0xFF129A67),
        ),
        _ExpenseMetricData(
          title: 'Rejected Cases',
          value: rejectedModuleCount.toString(),
          subtitle: 'Needs follow-up or resubmission',
          icon: Icons.cancel_outlined,
          accent: const Color(0xFFFDF2EF),
          iconColor: const Color(0xFFBD2D22),
        ),
      ],
      _ExpenseViewMode.oversight => [
        _ExpenseMetricData(
          title: 'Tracked Claims',
          value: allClaims.length.toString(),
          subtitle: 'Visible across the company',
          icon: Icons.receipt_long_outlined,
          accent: const Color(0xFFEEF3FB),
          iconColor: const Color(0xFF132F4C),
        ),
        _ExpenseMetricData(
          title: 'Pending Review',
          value: allClaims.where((claim) => claim.isPending).length.toString(),
          subtitle: 'Awaiting approver action',
          icon: Icons.hourglass_top_outlined,
          accent: const Color(0xFFEAF1FF),
          iconColor: const Color(0xFF4260B4),
        ),
        _ExpenseMetricData(
          title: 'Approved Pool',
          value: approvedModuleCount.toString(),
          subtitle: 'Approved or paid activity',
          icon: Icons.check_circle_outline,
          accent: const Color(0xFFE8F7F0),
          iconColor: const Color(0xFF129A67),
        ),
        _ExpenseMetricData(
          title: 'Rejected Cases',
          value: rejectedModuleCount.toString(),
          subtitle: 'Policy or documentation issues',
          icon: Icons.cancel_outlined,
          accent: const Color(0xFFFDF2EF),
          iconColor: const Color(0xFFBD2D22),
        ),
      ],
    };

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: cards.map(_buildSummaryCard).toList(growable: false),
    );
  }

  Widget _buildSummaryCard(_ExpenseMetricData data) {
    return SizedBox(
      width: 255,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE7EDF6)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF132F4C).withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: data.accent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(data.icon, color: data.iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.subtitle,
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

  Widget _buildMainGrid(
    BuildContext context,
    WidgetRef ref,
    ExpenseData data, {
    required _ExpenseViewMode mode,
    required bool compact,
    required List<ExpenseClaim> claimsForList,
    required List<ExpenseClaim> pendingClaims,
    required List<ExpenseClaim> myClaims,
  }) {
    final leftCard = _buildClaimFeedCard(
      context,
      ref,
      data,
      mode: mode,
      claims: claimsForList,
    );
    final rightCard = switch (mode) {
      _ExpenseViewMode.employee => _buildEmployeeInsightCard(myClaims),
      _ExpenseViewMode.approver => _buildApprovalQueueCard(
        context,
        ref,
        pendingClaims,
      ),
      _ExpenseViewMode.oversight => _buildOversightCard(data.allClaims),
    };

    if (compact) {
      return Column(
        children: [leftCard, const SizedBox(height: 16), rightCard],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: leftCard),
        const SizedBox(width: 18),
        Expanded(flex: 5, child: rightCard),
      ],
    );
  }

  Widget _buildClaimFeedCard(
    BuildContext context,
    WidgetRef ref,
    ExpenseData data, {
    required _ExpenseViewMode mode,
    required List<ExpenseClaim> claims,
  }) {
    final title = switch (mode) {
      _ExpenseViewMode.employee => 'Submitted Expense Claims',
      _ExpenseViewMode.approver => 'Live Expense Activity',
      _ExpenseViewMode.oversight => 'Expense Visibility Feed',
    };
    final badge = switch (mode) {
      _ExpenseViewMode.employee =>
        '${claims.length} claim${claims.length == 1 ? '' : 's'}',
      _ExpenseViewMode.approver =>
        '${data.pendingClaims.length} awaiting sign-off',
      _ExpenseViewMode.oversight => '${data.allClaims.length} records tracked',
    };

    return _moduleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _pillBadge(
                badge,
                background: const Color(0xFFF0F4FA),
                textColor: const Color(0xFF5B6B83),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (claims.isEmpty)
            _emptyPanel(
              icon: mode == _ExpenseViewMode.approver
                  ? Icons.hourglass_disabled_outlined
                  : Icons.receipt_long_outlined,
              title: _query.isEmpty
                  ? 'No expenses yet'
                  : 'No claims match your search',
              subtitle: switch (mode) {
                _ExpenseViewMode.employee =>
                  'Your submitted expense claims will appear here for tracking.',
                _ExpenseViewMode.approver =>
                  'Team claims and recent submissions will appear here as they arrive.',
                _ExpenseViewMode.oversight =>
                  'Visible company expense activity will appear here once claims are submitted.',
              },
            )
          else
            ...claims
                .take(8)
                .map(
                  (expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildExpenseListTile(expense),
                  ),
                ),
          if (claims.length > 8) ...[
            const SizedBox(height: 4),
            Text(
              'Showing 8 of ${claims.length} matching claims',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApprovalQueueCard(
    BuildContext context,
    WidgetRef ref,
    List<ExpenseClaim> pendingClaims,
  ) {
    return _moduleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pending Approvals',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              _pillBadge(
                'Queue: ${pendingClaims.length}',
                background: const Color(0xFFEAF1FF),
                textColor: const Color(0xFF4260B4),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (pendingClaims.isEmpty)
            _emptyPanel(
              icon: Icons.hourglass_empty_outlined,
              title: 'No pending approvals',
              subtitle:
                  'Great work. There are no employee claims waiting for your sign-off.',
            )
          else
            ...pendingClaims
                .take(6)
                .map(
                  (expense) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE4EBF5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  expense.employeeName,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatNaira(expense.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF132F4C),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${expense.category.name.toUpperCase()} • ${expense.description}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_outlined,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy',
                                ).format(expense.expenseDate),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _rejectExpense(context, ref, expense),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Reject'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFBD2D22),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () =>
                                      _approveExpense(context, ref, expense),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF132F4C),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmployeeInsightCard(List<ExpenseClaim> myClaims) {
    final approvedValue = myClaims
        .where((claim) => claim.isApproved || claim.isPaid)
        .fold<double>(0, (sum, claim) => sum + claim.amount);
    final rejectedClaims = myClaims.where((claim) => claim.isRejected).toList();

    return Column(
      children: [
        _moduleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Claim Health',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _buildInsightRow(
                label: 'Approved value',
                value: CurrencyFormatter.formatNaira(approvedValue),
              ),
              _buildInsightRow(
                label: 'Pending claims',
                value: myClaims
                    .where((claim) => claim.isPending)
                    .length
                    .toString(),
              ),
              _buildInsightRow(
                label: 'Rejected claims',
                value: rejectedClaims.length.toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _moduleCard(
          backgroundColor: const Color(0xFF355179),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encryption Active',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Expense data is protected and your reimbursement timeline is monitored through approval updates.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOversightCard(List<ExpenseClaim> allClaims) {
    final statusGroups = <ExpenseStatus, int>{
      ExpenseStatus.pending: 0,
      ExpenseStatus.approved: 0,
      ExpenseStatus.rejected: 0,
      ExpenseStatus.paid: 0,
    };
    final categoryGroups = <String, int>{};

    for (final claim in allClaims) {
      statusGroups[claim.status] = (statusGroups[claim.status] ?? 0) + 1;
      categoryGroups[claim.category.name] =
          (categoryGroups[claim.category.name] ?? 0) + 1;
    }

    final topCategories = categoryGroups.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        _moduleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Oversight Snapshot',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              ...statusGroups.entries.map(
                (entry) => _buildInsightRow(
                  label: entry.key.name.toUpperCase(),
                  value: entry.value.toString(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _moduleCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              if (topCategories.isEmpty)
                const Text(
                  'No category activity yet.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...topCategories
                    .take(5)
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildInsightRow(
                          label: entry.key.toUpperCase(),
                          value: entry.value.toString(),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInsightRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildSubmitBanner(BuildContext context, WidgetRef ref, AppUser user) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE4EBF5)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.upload_file_outlined,
              color: Color(0xFF4260B4),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to submit a new claim?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 6),
                Text(
                  'Capture the amount, category, and receipt trail so the approval team can move quickly.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showSubmitDialog(context, ref, user),
            icon: const Icon(Icons.add),
            label: const Text('Submit Expense'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF132F4C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _moduleCard({
    required Widget child,
    Color backgroundColor = Colors.white,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: backgroundColor == Colors.white
              ? const Color(0xFFE7EDF6)
              : backgroundColor.withValues(alpha: 0.32),
        ),
        boxShadow: backgroundColor == Colors.white
            ? [
                BoxShadow(
                  color: const Color(0xFF132F4C).withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  Widget _pillBadge(
    String label, {
    required Color background,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }

  Widget _emptyPanel({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFD8E1ED),
          style: BorderStyle.solid,
        ),
        color: const Color(0xFFFBFDFF),
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F6FB),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 40, color: const Color(0xFFAFB9C8)),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseListTile(ExpenseClaim expense) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4EBF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Color(0xFF4260B4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.employeeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${expense.category.name.toUpperCase()} • ${expense.description}',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatNaira(expense.amount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF132F4C),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusChip(expense.status),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _tileMeta(
                Icons.calendar_today_outlined,
                DateFormat('MMM dd, yyyy').format(expense.expenseDate),
              ),
              _tileMeta(
                Icons.schedule_outlined,
                DateFormat('MMM dd, yyyy').format(expense.submittedAt),
              ),
            ],
          ),
          if ((expense.rejectionReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF2EF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Rejected: ${expense.rejectionReason}',
                style: const TextStyle(fontSize: 12, color: Color(0xFFBD2D22)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tileMeta(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildStatusChip(ExpenseStatus status) {
    final config = switch (status) {
      ExpenseStatus.pending => (
        background: const Color(0xFFEAF1FF),
        color: const Color(0xFF4260B4),
        icon: Icons.hourglass_top_outlined,
      ),
      ExpenseStatus.approved => (
        background: const Color(0xFFE8F7F0),
        color: const Color(0xFF129A67),
        icon: Icons.check_circle_outline,
      ),
      ExpenseStatus.rejected => (
        background: const Color(0xFFFDF2EF),
        color: const Color(0xFFBD2D22),
        icon: Icons.cancel_outlined,
      ),
      ExpenseStatus.paid => (
        background: const Color(0xFFEEF5FF),
        color: const Color(0xFF1A5FB4),
        icon: Icons.account_balance_wallet_outlined,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.color),
          const SizedBox(width: 5),
          Text(
            status.name.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  void _showSubmitDialog(BuildContext context, WidgetRef ref, AppUser user) {
    final formKey = GlobalKey<FormState>();
    ExpenseCategory category = ExpenseCategory.fuel;
    String description = '';
    double amount = 0;
    DateTime expenseDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit Expense Claim'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ExpenseCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: ExpenseCategory.values.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) => category = value ?? category,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required';
                    }
                    return null;
                  },
                  onSaved: (value) => description = value!.trim(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                    prefixText: 'NGN ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final parsed = double.tryParse(value.replaceAll(',', ''));
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                  onSaved: (value) =>
                      amount = double.parse(value!.replaceAll(',', '')),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: dialogContext,
                      initialDate: expenseDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      expenseDate = date;
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Expense Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('MMM dd, yyyy').format(expenseDate)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              formKey.currentState!.save();
              Navigator.pop(dialogContext);

              try {
                await ref
                    .read(expenseActionsProvider)
                    .submit(
                      employeeId: user.employeeId!,
                      employeeName: user.name,
                      category: category,
                      description: description,
                      amount: amount,
                      expenseDate: expenseDate,
                    );
                if (context.mounted) {
                  NotificationHelper.showSuccess(
                    context,
                    'Expense claim submitted successfully',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  NotificationHelper.showError(context, e.toString());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF132F4C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveExpense(
    BuildContext context,
    WidgetRef ref,
    ExpenseClaim expense,
  ) async {
    try {
      await ref.read(expenseActionsProvider).approve(expense);
      if (context.mounted) {
        NotificationHelper.showSuccess(context, 'Expense approved');
      }
    } catch (e) {
      if (context.mounted) {
        NotificationHelper.showError(context, e.toString());
      }
    }
  }

  void _rejectExpense(
    BuildContext context,
    WidgetRef ref,
    ExpenseClaim expense,
  ) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Expense'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                NotificationHelper.showError(
                  dialogContext,
                  'Please provide a reason',
                );
                return;
              }

              Navigator.pop(dialogContext);

              try {
                await ref.read(expenseActionsProvider).reject(expense, reason);
                if (context.mounted) {
                  NotificationHelper.showSuccess(context, 'Expense rejected');
                }
              } catch (e) {
                if (context.mounted) {
                  NotificationHelper.showError(context, e.toString());
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBD2D22),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

enum _ExpenseViewMode { employee, approver, oversight }

class _ExpenseMetricData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color iconColor;

  const _ExpenseMetricData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.iconColor,
  });
}
