import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/salary_advance_model.dart';
import 'package:roipayroll/providers/salary_advance_provider.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class SalaryAdvanceScreen extends ConsumerWidget {
  const SalaryAdvanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(salaryAdvanceDataProvider);

    return AppScaffold(
      topBar: AppBar(
        title: Text(_titleFor(dataAsync.asData?.value)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(salaryAdvanceActionsProvider).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () =>
            const ModernLoadingState(message: 'Loading salary advance desk...'),
        error: (error, _) => ModernErrorState(
          message: 'Failed to load salary advances',
          subtitle: error.toString(),
          onRetry: () => ref.read(salaryAdvanceActionsProvider).refresh(),
        ),
        data: (data) => ResponsiveLayout(
          mobile: _buildPage(context, ref, data, padding: 12, compact: true),
          tablet: _buildPage(context, ref, data, padding: 16, compact: false),
          desktop: _buildPage(context, ref, data, padding: 20, compact: false),
        ),
      ),
    );
  }

  String _titleFor(SalaryAdvanceData? data) {
    return 'Salary Advance';
  }

  Widget _buildPage(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvanceData data, {
    required double padding,
    required bool compact,
  }) {
    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        _buildHero(context, ref, data, compact: compact),
        const SizedBox(height: 18),
        _buildSignalBand(data, compact: compact),
        const SizedBox(height: 18),
        switch (data.scope) {
          SalaryAdvanceRoleScope.employee => _buildEmployeeView(
            context,
            ref,
            data,
          ),
          SalaryAdvanceRoleScope.hrApprover => _buildHrApproverView(
            context,
            ref,
            data,
          ),
          SalaryAdvanceRoleScope.financeApprover => _buildFinanceApproverView(
            context,
            ref,
            data,
          ),
          SalaryAdvanceRoleScope.adminOversight => _buildAdminOversightView(
            context,
            ref,
            data,
          ),
        },
      ],
    );
  }

  Widget _buildHero(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvanceData data, {
    required bool compact,
  }) {
    final colors = switch (data.scope) {
      SalaryAdvanceRoleScope.employee => [
        const Color(0xFF12355B),
        const Color(0xFF2F6690),
      ],
      SalaryAdvanceRoleScope.hrApprover => [
        const Color(0xFF3F2A56),
        const Color(0xFF7760A8),
      ],
      SalaryAdvanceRoleScope.financeApprover => [
        const Color(0xFF12263F),
        const Color(0xFF1E3A5F),
      ],
      SalaryAdvanceRoleScope.adminOversight => [
        const Color(0xFF162033),
        const Color(0xFF344667),
      ],
    };

    final title = switch (data.scope) {
      SalaryAdvanceRoleScope.employee => 'Request Salary Advance',
      SalaryAdvanceRoleScope.hrApprover => 'Review Salary Advance Requests',
      SalaryAdvanceRoleScope.financeApprover => 'Salary Advance Review',
      SalaryAdvanceRoleScope.adminOversight => 'Salary Advance Overview',
    };

    final subtitle = switch (data.scope) {
      SalaryAdvanceRoleScope.employee =>
        'Submit a request, track approval, and follow recovery status.',
      SalaryAdvanceRoleScope.hrApprover =>
        'Review employee requests and keep the queue moving.',
      SalaryAdvanceRoleScope.financeApprover =>
        'Manage approvals, exposure, and payroll recovery readiness.',
      SalaryAdvanceRoleScope.adminOversight =>
        'Monitor requests, approvals, and recovery across the company.',
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: EdgeInsets.all(compact ? 18 : 24),
      child: Stack(
        children: [
          Positioned(
            top: -18,
            right: -10,
            child: _glow(120, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -42,
            left: -14,
            child: _glow(150, Colors.white.withValues(alpha: 0.06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _titleFor(data).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 26 : 32,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.45,
                    fontSize: compact ? 13 : 15,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _heroFact(
                    'Pending',
                    data.pendingAdvances.length.toString(),
                    Icons.pending_actions_outlined,
                  ),
                  _heroFact(
                    'Approved',
                    data.approvedAdvances.length.toString(),
                    Icons.verified_outlined,
                  ),
                  _heroFact(
                    'Recovered',
                    data.recoveredAdvances.length.toString(),
                    Icons.currency_exchange_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (data.canRequest)
                    FilledButton.icon(
                      onPressed: data.hasEmployeeProfile
                          ? () => _showRequestSheet(context, ref)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Request Advance'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  if (data.canApprove)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${data.pendingAdvances.length} request(s) waiting for decision',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (data.scope == SalaryAdvanceRoleScope.financeApprover ||
                      data.scope == SalaryAdvanceRoleScope.adminOversight)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Secured ledger',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _heroFact(String label, String value, IconData icon) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBand(SalaryAdvanceData data, {required bool compact}) {
    final signals = switch (data.scope) {
      SalaryAdvanceRoleScope.employee => [
        _Signal(
          title: 'Open exposure',
          value: CurrencyFormatter.formatNaira(
            data.myAdvances
                .where(
                  (advance) =>
                      advance.status == SalaryAdvanceStatus.pending ||
                      advance.status == SalaryAdvanceStatus.approved,
                )
                .fold<double>(0, (sum, advance) => sum + advance.amount),
          ),
          subtitle: 'Pending and approved requests',
          color: AppColors.warning,
        ),
        _Signal(
          title: 'Recovered',
          value: CurrencyFormatter.formatNaira(
            data.myAdvances
                .where(
                  (advance) => advance.status == SalaryAdvanceStatus.recovered,
                )
                .fold<double>(0, (sum, advance) => sum + advance.amount),
          ),
          subtitle: 'Already cleared through payroll',
          color: AppColors.success,
        ),
        _Signal(
          title: 'Policy',
          value: '50%',
          subtitle: 'Maximum of monthly basic salary',
          color: AppColors.info,
        ),
      ],
      SalaryAdvanceRoleScope.hrApprover => [
        _Signal(
          title: 'Pending requests',
          value: data.pendingAdvances.length.toString(),
          subtitle: 'Employees waiting for a decision',
          color: AppColors.warning,
        ),
        _Signal(
          title: 'People impact',
          value: _uniqueEmployees(data.visibleAdvances).toString(),
          subtitle: 'Unique employees represented',
          color: AppColors.primary,
        ),
        _Signal(
          title: 'Rejected cases',
          value: data.rejectedAdvances.length.toString(),
          subtitle: 'Requests needing employee follow-up',
          color: AppColors.error,
        ),
      ],
      SalaryAdvanceRoleScope.financeApprover => [
        _Signal(
          title: 'Queue amount',
          value: CurrencyFormatter.formatNaira(
            data.pendingAdvances.fold<double>(
              0,
              (sum, advance) => sum + advance.amount,
            ),
          ),
          subtitle: 'Total amount awaiting decision',
          color: AppColors.warning,
        ),
        _Signal(
          title: 'Approved book',
          value: CurrencyFormatter.formatNaira(
            data.approvedAdvances.fold<double>(
              0,
              (sum, advance) => sum + advance.amount,
            ),
          ),
          subtitle: 'Approved and not yet recovered',
          color: AppColors.success,
        ),
        _Signal(
          title: 'Decision history',
          value:
              (data.approvedAdvances.length +
                      data.rejectedAdvances.length +
                      data.recoveredAdvances.length)
                  .toString(),
          subtitle: 'Approved or rejected records',
          color: AppColors.primary,
        ),
      ],
      SalaryAdvanceRoleScope.adminOversight => [
        _Signal(
          title: 'Pending requests',
          value: data.pendingAdvances.length.toString(),
          subtitle: 'Currently active review load',
          color: AppColors.warning,
        ),
        _Signal(
          title: 'Approved portfolio',
          value: CurrencyFormatter.formatNaira(
            data.approvedAdvances.fold<double>(
              0,
              (sum, advance) => sum + advance.amount,
            ),
          ),
          subtitle: 'Exposure not yet recovered',
          color: AppColors.success,
        ),
        _Signal(
          title: 'Recovered value',
          value: CurrencyFormatter.formatNaira(
            data.recoveredAdvances.fold<double>(
              0,
              (sum, advance) => sum + advance.amount,
            ),
          ),
          subtitle: 'Collected through payroll',
          color: AppColors.info,
        ),
      ],
    };

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: signals
          .map(
            (signal) => Container(
              width: compact ? double.infinity : 250,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: signal.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    signal.title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signal.value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signal.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmployeeView(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvanceData data,
  ) {
    if (!data.hasEmployeeProfile) {
      return _noticePanel(
        icon: Icons.badge_outlined,
        title: 'Employee profile required',
        subtitle:
            'Your account must be linked to an employee record before you can request a salary advance.',
        color: AppColors.warning,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Advance Ledger',
          'A clean history of every request, decision, and recovery event.',
        ),
        const SizedBox(height: 12),
        if (data.myAdvances.isEmpty)
          _noticePanel(
            icon: Icons.payments_outlined,
            title: 'No salary advance requests yet',
            subtitle:
                'When you create one, it will show up here with status and payroll recovery details.',
            color: AppColors.info,
          )
        else
          _ledgerShell(
            title: 'My Requests',
            subtitle: 'Personal activity stream',
            rows: data.myAdvances
                .map((advance) => _advanceRow(advance, showEmployee: false))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildHrApproverView(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvanceData data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'People Support Review',
          'HR gets a cleaner people-first queue with the live requests on one side and communication-sensitive decisions on the other.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _responsiveWidth(context, 520),
              child: _buildPendingQueue(
                context,
                ref,
                data,
                title: 'Pending Queue',
                subtitle: 'Approve or reject active requests',
              ),
            ),
            SizedBox(
              width: _responsiveWidth(context, 520),
              child: _ledgerShell(
                title: 'Employee Follow-up Ledger',
                subtitle:
                    'Rejected and recently approved requests that may need communication',
                rows:
                    _decisionHistoryFor(
                      data,
                      statuses: const {
                        SalaryAdvanceStatus.approved,
                        SalaryAdvanceStatus.rejected,
                      },
                    ).isEmpty
                    ? [
                        _emptyLane(
                          icon: Icons.forum_outlined,
                          title: 'No follow-up items',
                          subtitle:
                              'Decisions that need an HR narrative will surface here.',
                        ),
                      ]
                    : _decisionHistoryFor(
                            data,
                            statuses: const {
                              SalaryAdvanceStatus.approved,
                              SalaryAdvanceStatus.rejected,
                            },
                          )
                          .map(
                            (advance) =>
                                _advanceRow(advance, showEmployee: true),
                          )
                          .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _noticePanel(
          icon: Icons.shield_moon_outlined,
          title: 'Support posture active',
          subtitle:
              'Use HR review to keep decisions fast, empathetic, and aligned with the 50% salary cap rule already enforced in the system.',
          color: const Color(0xFF6A55A3),
        ),
      ],
    );
  }

  Widget _buildFinanceApproverView(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvanceData data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPortfolioBand(
          data,
          badgeLabel: 'Secured Ledger',
          segments: [
            _Signal(
              title: 'Pending requests',
              value: data.pendingAdvances.length.toString(),
              subtitle: 'Awaiting review',
              color: Colors.white,
            ),
            _Signal(
              title: 'Approved requests',
              value: data.approvedAdvances.length.toString(),
              subtitle: 'Open approved book',
              color: Colors.white,
            ),
            _Signal(
              title: 'Recovered requests',
              value: data.recoveredAdvances.length.toString(),
              subtitle: 'Cleared in payroll',
              color: Colors.white,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            _metricPanel(
              context: context,
              title: 'Live queue',
              value: CurrencyFormatter.formatNaira(
                data.pendingAdvances.fold<double>(
                  0,
                  (sum, advance) => sum + advance.amount,
                ),
              ),
              subtitle: 'Value of requests waiting for sign-off',
              icon: Icons.hourglass_top_rounded,
            ),
            _metricPanel(
              context: context,
              title: 'Asset value',
              value: CurrencyFormatter.formatNaira(
                data.approvedAdvances.fold<double>(
                  0,
                  (sum, advance) => sum + advance.amount,
                ),
              ),
              subtitle: 'Approved requests still sitting on the book',
              icon: Icons.account_balance_wallet_outlined,
            ),
            _metricPanel(
              context: context,
              title: 'Performance',
              value: _decisionHistoryFor(data).length.toString(),
              subtitle: 'Decision history logged for audit',
              icon: Icons.history_toggle_off_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _responsiveWidth(context, 520),
              child: _buildPendingQueue(
                context,
                ref,
                data,
                title: 'Pending Queue',
                subtitle: '${data.pendingAdvances.length} active request(s)',
              ),
            ),
            SizedBox(
              width: _responsiveWidth(context, 520),
              child: _ledgerShell(
                title: 'Decision Ledger',
                subtitle: 'Past approvals, rejections, and recoveries',
                rows: _decisionHistoryFor(data).isEmpty
                    ? [
                        _emptyLane(
                          icon: Icons.receipt_long_outlined,
                          title: 'No decision history yet',
                          subtitle:
                              'Processed requests will appear here for auditing.',
                        ),
                      ]
                    : _decisionHistoryFor(data)
                          .map(
                            (advance) =>
                                _advanceRow(advance, showEmployee: true),
                          )
                          .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _secureEngineBanner(
          title: 'Secure disbursement engine',
          subtitle:
              'All salary advance approvals are processed through end-to-end encrypted financial channels.',
        ),
      ],
    );
  }

  Widget _buildAdminOversightView(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvanceData data,
  ) {
    final decisionHistory = _decisionHistoryFor(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          'Portfolio Command',
          'Admins get a wider oversight view with queue load, approvals, recoveries, and the same live controls available to operational reviewers.',
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _responsiveWidth(context, 360),
              child: _metricPanel(
                context: context,
                title: 'Portfolio exposure',
                value: CurrencyFormatter.formatNaira(
                  data.visibleAdvances
                      .where(
                        (advance) =>
                            advance.status == SalaryAdvanceStatus.pending ||
                            advance.status == SalaryAdvanceStatus.approved,
                      )
                      .fold<double>(0, (sum, advance) => sum + advance.amount),
                ),
                subtitle: 'Pending plus approved requests across the company',
                icon: Icons.pie_chart_outline_rounded,
              ),
            ),
            SizedBox(
              width: _responsiveWidth(context, 360),
              child: _metricPanel(
                context: context,
                title: 'Employees in scope',
                value: _uniqueEmployees(data.visibleAdvances).toString(),
                subtitle: 'Unique employees represented in the ledger',
                icon: Icons.groups_2_outlined,
              ),
            ),
            SizedBox(
              width: _responsiveWidth(context, 360),
              child: _metricPanel(
                context: context,
                title: 'Recovered value',
                value: CurrencyFormatter.formatNaira(
                  data.recoveredAdvances.fold<double>(
                    0,
                    (sum, advance) => sum + advance.amount,
                  ),
                ),
                subtitle: 'Value already collected through payroll',
                icon: Icons.verified_user_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _responsiveWidth(context, 520),
              child: _buildPendingQueue(
                context,
                ref,
                data,
                title: 'Live Approval Queue',
                subtitle: 'Operational requests waiting for action',
              ),
            ),
            SizedBox(
              width: _responsiveWidth(context, 520),
              child: _ledgerShell(
                title: 'Executive Ledger',
                subtitle: 'Decision archive with recovered outcomes included',
                rows: decisionHistory.isEmpty
                    ? [
                        _emptyLane(
                          icon: Icons.dashboard_customize_outlined,
                          title: 'No command history yet',
                          subtitle:
                              'Approvals, rejections, and recoveries will appear here.',
                        ),
                      ]
                    : decisionHistory
                          .map(
                            (advance) =>
                                _advanceRow(advance, showEmployee: true),
                          )
                          .toList(),
              ),
            ),
          ],
        ),
        if (data.myAdvances.isNotEmpty) ...[
          const SizedBox(height: 18),
          _ledgerShell(
            title: 'Linked Personal Requests',
            subtitle:
                'Shown because this admin account is also linked to an employee profile',
            rows: data.myAdvances
                .map((advance) => _advanceRow(advance, showEmployee: false))
                .toList(),
          ),
        ],
        const SizedBox(height: 18),
        _secureEngineBanner(
          title: 'Secure disbursement engine',
          subtitle:
              'Approval actions and recovery logs are protected for audit-grade oversight.',
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildPendingQueue(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvanceData data, {
    required String title,
    required String subtitle,
  }) {
    return _ledgerShell(
      title: title,
      subtitle: subtitle,
      rows: data.pendingAdvances.isEmpty
          ? [
              _emptyLane(
                icon: Icons.pending_actions_outlined,
                title: 'No pending requests',
                subtitle: 'The review queue is currently clear.',
              ),
            ]
          : data.pendingAdvances
                .map(
                  (advance) => _advanceRow(
                    advance,
                    showEmployee: true,
                    actions: [
                      OutlinedButton.icon(
                        onPressed: () => _reject(context, ref, advance),
                        icon: const Icon(Icons.close, color: AppColors.error),
                        label: const Text(
                          'Reject',
                          style: TextStyle(color: AppColors.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _approve(context, ref, advance),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    ],
                  ),
                )
                .toList(),
    );
  }

  List<SalaryAdvance> _decisionHistoryFor(
    SalaryAdvanceData data, {
    Set<SalaryAdvanceStatus>? statuses,
  }) {
    final entries = [
      ...data.approvedAdvances,
      ...data.rejectedAdvances,
      ...data.recoveredAdvances,
      ...data.cancelledAdvances,
    ];
    final filtered = statuses == null
        ? entries
        : entries
              .where((advance) => statuses.contains(advance.status))
              .toList();
    filtered.sort((a, b) {
      final left =
          a.recoveredAt ?? a.rejectedAt ?? a.approvedAt ?? a.requestDate;
      final right =
          b.recoveredAt ?? b.rejectedAt ?? b.approvedAt ?? b.requestDate;
      return right.compareTo(left);
    });
    return filtered;
  }

  Widget _buildPortfolioBand(
    SalaryAdvanceData data, {
    required String badgeLabel,
    required List<_Signal> segments,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF12263F), Color(0xFF1C2A39)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runSpacing: 16,
        spacing: 16,
        children: [
          ...segments.map(
            (signal) => SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    signal.title.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    signal.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    signal.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  badgeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricPanel({
    required BuildContext context,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      width: _responsiveWidth(context, 340),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _secureEngineBanner({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D4569), Color(0xFF415B82)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _uniqueEmployees(List<SalaryAdvance> advances) {
    return advances.map((advance) => advance.employeeId).toSet().length;
  }

  double _responsiveWidth(BuildContext context, double maxWidth) {
    final available = MediaQuery.of(context).size.width - 48;
    if (available <= 0) return maxWidth;
    return available < maxWidth ? available : maxWidth;
  }

  Widget _ledgerShell({
    required String title,
    required String subtitle,
    required List<Widget> rows,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ...rows,
        ],
      ),
    );
  }

  Widget _advanceRow(
    SalaryAdvance advance, {
    required bool showEmployee,
    List<Widget>? actions,
  }) {
    final statusColor = _statusColor(advance.status);
    final decisionDate =
        advance.recoveredAt ?? advance.rejectedAt ?? advance.approvedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 54,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showEmployee)
                      Text(
                        advance.employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      CurrencyFormatter.formatNaira(advance.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Requested ${DateFormat('dd MMM yyyy').format(advance.requestDate)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _statusPill(advance.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill(
                'Cap',
                CurrencyFormatter.formatNaira(advance.maxAllowed),
              ),
              _metaPill(
                'Usage',
                '${((advance.amount / (advance.maxAllowed == 0 ? 1 : advance.maxAllowed)) * 100).clamp(0, 100).toStringAsFixed(0)}%',
              ),
              if (advance.payrollMonth != null && advance.payrollYear != null)
                _metaPill(
                  'Recovered in payroll',
                  '${advance.payrollMonth}/${advance.payrollYear}',
                  tone: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(advance.reason, style: const TextStyle(height: 1.45)),
          if ((advance.rejectionReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Rejection reason: ${advance.rejectionReason!}',
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (decisionDate != null) ...[
            const SizedBox(height: 10),
            Text(
              'Last update ${DateFormat('dd MMM yyyy').format(decisionDate)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          if (actions != null && actions.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ],
      ),
    );
  }

  Widget _emptyLane({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticePanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(SalaryAdvanceStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaPill(String label, String value, {Color? tone}) {
    final color = tone ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Color _statusColor(SalaryAdvanceStatus status) {
    switch (status) {
      case SalaryAdvanceStatus.pending:
        return AppColors.warning;
      case SalaryAdvanceStatus.approved:
        return AppColors.approved;
      case SalaryAdvanceStatus.rejected:
        return AppColors.error;
      case SalaryAdvanceStatus.recovered:
        return AppColors.success;
      case SalaryAdvanceStatus.cancelled:
        return AppColors.textSecondary;
    }
  }

  Future<void> _showRequestSheet(BuildContext context, WidgetRef ref) async {
    final data = ref.read(salaryAdvanceDataProvider).value;
    final employeeId = data?.employeeId;
    if (employeeId == null) {
      NotificationHelper.showError(
        context,
        'Employee profile not found. Contact HR.',
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final reasonController = TextEditingController();

    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _sheetShell(
          context,
          title: 'Request Salary Advance',
          subtitle:
              'Submit one active request at a time. Policy cap is 50% of monthly basic salary.',
          child: Form(
            key: formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (NGN)',
                    helperText: 'Use numbers only, for example 120000',
                  ),
                  validator: (value) {
                    final amount = double.tryParse((value ?? '').trim());
                    if (amount == null || amount <= 0) {
                      return 'Enter a valid amount';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: reasonController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    hintText: 'Emergency, medical, rent, transport...',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Reason is required';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          primaryActionLabel: 'Submit Request',
          onPrimaryAction: () {
            if (formKey.currentState?.validate() != true) return;
            Navigator.pop(context, true);
          },
        );
      },
    );

    if (submit != true || !context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Submitting request...');
    try {
      await ref
          .read(salaryAdvanceActionsProvider)
          .submit(
            employeeId: employeeId,
            amount: double.parse(amountController.text.trim()),
            reason: reasonController.text.trim(),
          );
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Salary advance submitted for approval',
      );
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Submission failed: $e');
    }
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvance advance,
  ) async {
    NotificationHelper.showLoading(context, message: 'Approving...');
    try {
      await ref.read(salaryAdvanceActionsProvider).approve(advance);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Salary advance approved');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Approval failed: $e');
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    SalaryAdvance advance,
  ) async {
    final reasonController = TextEditingController();
    final reject = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _sheetShell(
          context,
          title: 'Reject Salary Advance',
          subtitle:
              'A clear rejection reason helps the employee understand the decision.',
          child: TextField(
            controller: reasonController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          primaryActionLabel: 'Reject Request',
          primaryTone: AppColors.error,
          onPrimaryAction: () => Navigator.pop(context, true),
        );
      },
    );

    if (reject != true || !context.mounted) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      NotificationHelper.showError(context, 'Rejection reason is required.');
      return;
    }

    NotificationHelper.showLoading(context, message: 'Rejecting...');
    try {
      await ref.read(salaryAdvanceActionsProvider).reject(advance, reason);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Salary advance rejected');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Rejection failed: $e');
    }
  }

  Widget _sheetShell(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
    required String primaryActionLabel,
    required VoidCallback onPrimaryAction,
    Color primaryTone = AppColors.primary,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        top: 24,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  child,
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onPrimaryAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryTone,
                          ),
                          child: Text(primaryActionLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Signal {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _Signal({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}
