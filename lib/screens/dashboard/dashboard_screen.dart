import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/models/payroll_trend_model.dart';
import 'package:roipayroll/models/system_alert_model.dart';
import 'package:roipayroll/models/system_health_summary_model.dart';
import 'package:roipayroll/providers/dashboard_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/screens/employees/employee_list_screen.dart';
import 'package:roipayroll/screens/payroll/process_payroll_screen.dart';
import 'package:roipayroll/screens/report/reports_screen.dart';
import 'package:roipayroll/screens/loan/request_loan_screen.dart';
import 'package:roipayroll/screens/users/create_user.dart';
import 'package:roipayroll/screens/attendance/clock_in_screen.dart';
import 'package:roipayroll/screens/attendance/attendance_list_screen.dart';
import 'package:roipayroll/screens/expense/expense_reimbursement_screen.dart';
import 'package:roipayroll/screens/exit/exit_management_screen.dart';
import 'package:roipayroll/screens/incentives/commission_bonus_screen.dart';
import 'package:roipayroll/screens/loan/loans_list_screen.dart';
import 'package:roipayroll/screens/notifications/notifications_screen.dart';
import 'package:roipayroll/screens/leave/leave_approval_screen.dart';
import 'package:roipayroll/screens/leave/my_leave_screen.dart';
import 'package:roipayroll/screens/payroll/payroll_history_screen.dart';
import 'package:roipayroll/screens/salary_advance/salary_advance_screen.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';
import 'package:roipayroll/widgets/accounting/liability_balances_dashboard.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Failed to load user: $error'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(currentUserProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (user) {
        switch (user?.role) {
          case UserRole.admin:
            return const AdminDashboardScreen();
          case UserRole.hr:
            return const HrDashboardScreen();
          case UserRole.accountant:
            return const AccountantDashboardScreen();
          case UserRole.employee:
          default:
            return const EmployeeDashboardScreen();
        }
      },
    );
  }
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int totalEmployees = 0;
  double currentMonthPayroll = 0;
  int pendingLoans = 0;
  double pendingLoanAmount = 0;
  int pendingExpenses = 0;
  double pendingExpenseAmount = 0;
  SystemHealthSummary? _systemHealth;
  AppUser? currentUser;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    return AppScaffold(
      title: 'Dashboard',
      showSearch: true,
      scrollable: false,
      padding: EdgeInsets.zero,
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load dashboard: $error'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(dashboardSummaryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (summary) {
          currentUser = summary.user;
          totalEmployees = summary.totalEmployees;
          currentMonthPayroll = summary.currentMonthPayroll;
          pendingLoans = summary.pendingLoans;
          pendingLoanAmount = summary.pendingLoanAmount;
          pendingExpenses = summary.pendingExpenses;
          pendingExpenseAmount = summary.pendingExpenseAmount;
          _systemHealth = summary.systemHealth;

          return ResponsiveLayout(
            mobile: _buildDashboardContent(summary, compact: true),
            tablet: _buildDashboardContent(summary, compact: false),
            desktop: _buildDashboardContent(summary, compact: false),
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(
    DashboardSummary summary, {
    required bool compact,
  }) {
    final approvalSummaryAsync = ref.watch(approvalInboxSummaryProvider);
    final approvalPreviewAsync = ref.watch(dashboardApprovalPreviewProvider);
    final alertsAsync = ref.watch(dashboardCriticalAlertsProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth;
        final splitPanels = contentWidth >= 1180;
        final horizontalPadding = contentWidth >= 1400
            ? 32.0
            : contentWidth >= 900
            ? 24.0
            : 16.0;
        final maxContentWidth = contentWidth >= 1500 ? 1360.0 : 1240.0;

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              compact ? 18 : 24,
              horizontalPadding,
              compact ? 18 : 24,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModernHeader(summary, compact: compact),
                    SizedBox(height: compact ? 16 : 22),
                    _buildModernMetricsGrid(summary),
                    SizedBox(height: compact ? 16 : 22),
                    if (splitPanels && _showSystemHealth())
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildApprovalPreviewCard(
                              approvalSummaryAsync,
                              approvalPreviewAsync,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 3,
                            child: Column(
                              children: [
                                _buildSystemIntegrityCard(),
                                const SizedBox(height: 20),
                                _buildCriticalAlertsCard(alertsAsync),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (_showSystemHealth()) ...[
                      _buildApprovalPreviewCard(
                        approvalSummaryAsync,
                        approvalPreviewAsync,
                      ),
                      const SizedBox(height: 20),
                      _buildSystemHealthSection(),
                    ] else ...[
                      _buildApprovalPreviewCard(
                        approvalSummaryAsync,
                        approvalPreviewAsync,
                      ),
                    ],
                    SizedBox(height: compact ? 16 : 24),
                    _buildInsightsSection(),
                    SizedBox(height: compact ? 16 : 24),
                    _buildQuickActionsSection(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickActionsSection() {
    final actions = _buildRoleBasedActions();
    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;

        return _buildOverviewSurface(
          padding: const EdgeInsets.all(20),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCE8FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFF274E91),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quick Actions',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A1730),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Perform critical operations instantly.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(spacing: 12, runSpacing: 12, children: actions),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE8FF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF274E91),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0A1730),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Perform critical operations instantly.',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Flexible(
                      flex: 3,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 12,
                        runSpacing: 12,
                        children: actions,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _buildRoleBasedActions() {
    return _buildAvailableQuickActions()
        .map(
          (action) => _buildActionButton(
            action.title,
            action.icon,
            action.color,
            () => _navigate(action.screen),
          ),
        )
        .toList();
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final isPrimary = title == 'Process Payroll';
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFF071A34) : color,
          foregroundColor: isPrimary ? Colors.white : const Color(0xFF0A1730),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildModernHeader(DashboardSummary summary, {required bool compact}) {
    final statusDate = DateFormat('MMMM d, y').format(DateTime.now());
    final headerActions = <Widget>[];
    final primaryAction = _buildPrimaryHeaderAction();
    final secondaryAction = _buildSecondaryHeaderAction();

    if (secondaryAction != null) {
      headerActions.add(
        _buildHeaderButton(
          label: secondaryAction.title,
          icon: secondaryAction.icon,
          filled: false,
          onTap: () => _navigate(secondaryAction.screen),
        ),
      );
    }
    if (primaryAction != null) {
      headerActions.add(
        _buildHeaderButton(
          label: primaryAction.title,
          icon: primaryAction.icon,
          filled: true,
          onTap: () => _navigate(primaryAction.screen),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final titleSize = constraints.maxWidth < 700
            ? 28.0
            : constraints.maxWidth < 1100
            ? 34.0
            : 40.0;

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Financial Overview',
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0A1730),
                  letterSpacing: -1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Status as of $statusDate',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
              ),
              if (headerActions.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(spacing: 12, runSpacing: 12, children: headerActions),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial Overview',
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0A1730),
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Status as of $statusDate',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (headerActions.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: headerActions,
              ),
          ],
        );
      },
    );
  }

  Widget _buildModernMetricsGrid(DashboardSummary summary) {
    final payrollTrend = summary.systemHealth.payrollGrowthPercentage;

    final cards = <_DashboardMetricCardData>[
      _DashboardMetricCardData(
        label: 'TOTAL EMPLOYEES',
        value: NumberFormat.decimalPattern(
          'en_NG',
        ).format(summary.totalEmployees),
        badge: '${summary.systemHealth.activeEmployeeCount} active',
        badgeColor: const Color(0xFFE7F4EC),
        badgeTextColor: AppColors.success,
        icon: Icons.groups_2_outlined,
        iconColor: const Color(0xFF3C5A8B),
        iconBackground: const Color(0xFFD9E7FF),
        onTap: () => _navigate(const EmployeeListScreen()),
      ),
      _DashboardMetricCardData(
        label: 'MONTHLY PAYROLL',
        value: _formatDashboardCurrency(summary.currentMonthPayroll),
        badge: _formatTrendBadge(payrollTrend),
        badgeColor: payrollTrend >= 0
            ? const Color(0xFFE6F6EE)
            : const Color(0xFFFFE9E7),
        badgeTextColor: payrollTrend >= 0 ? AppColors.success : AppColors.error,
        icon: Icons.account_balance_outlined,
        iconColor: const Color(0xFF476A9E),
        iconBackground: const Color(0xFFDDE8FF),
      ),
      _DashboardMetricCardData(
        label: 'PENDING LOANS',
        value: _formatDashboardCurrency(pendingLoanAmount),
        badge: pendingLoans == 0 ? 'All clear' : '$pendingLoans pending',
        badgeColor: pendingLoans == 0
            ? const Color(0xFFE9F6ED)
            : const Color(0xFFFFECE8),
        badgeTextColor: pendingLoans == 0 ? AppColors.success : AppColors.error,
        icon: Icons.credit_score_outlined,
        iconColor: const Color(0xFF365489),
        iconBackground: const Color(0xFFDDE8FF),
        onTap: () => _navigate(const LoansListScreen()),
      ),
      _DashboardMetricCardData(
        label: 'PENDING EXPENSES',
        value: _formatDashboardCurrency(pendingExpenseAmount),
        badge: pendingExpenses == 0 ? 'All clear' : '$pendingExpenses new',
        badgeColor: const Color(0xFFF0F4FA),
        badgeTextColor: const Color(0xFF21324F),
        icon: Icons.receipt_long_outlined,
        iconColor: Colors.white,
        iconBackground: const Color(0xFF2E4C72),
        onTap: () => _navigate(const ExpenseReimbursementScreen()),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1180
            ? 4
            : width >= 700
            ? 2
            : 1;
        const spacing = 16.0;
        final cardWidth = columns == 1
            ? width
            : (width - ((columns - 1) * spacing)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) =>
                    SizedBox(width: cardWidth, child: _buildMetricCard(card)),
              )
              .toList(),
        );
      },
    );
  }

  bool _showSystemHealth() {
    final user = currentUser;
    if (user == null) return false;
    return PermissionService.hasPermission(user, Permission.viewPayroll) ||
        PermissionService.hasPermission(user, Permission.viewReports) ||
        PermissionService.hasPermission(user, Permission.viewEmployees);
  }

  bool _hasPermission(Permission permission) {
    final user = currentUser;
    return user != null && PermissionService.hasPermission(user, permission);
  }

  List<_DashboardQuickAction> _buildAvailableQuickActions() {
    final user = currentUser;
    if (user == null) return const [];

    final actions = <_DashboardQuickAction>[];

    void addAction(bool allowed, _DashboardQuickAction action) {
      if (!allowed) return;
      final exists = actions.any((item) => item.title == action.title);
      if (!exists) {
        actions.add(action);
      }
    }

    switch (user.role) {
      case UserRole.admin:
        addAction(
          _hasPermission(Permission.processPayroll),
          const _DashboardQuickAction(
            title: 'Process Payroll',
            icon: Icons.play_circle_fill_rounded,
            color: AppColors.success,
            screen: ProcessPayrollScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.manageUsers),
          const _DashboardQuickAction(
            title: 'Create User',
            icon: Icons.person_add_alt_1_rounded,
            color: AppColors.info,
            screen: CreateUserScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.approveExpenses),
          const _DashboardQuickAction(
            title: 'Review Expenses',
            icon: Icons.receipt_long_outlined,
            color: AppColors.warning,
            screen: ExpenseReimbursementScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.viewReports),
          const _DashboardQuickAction(
            title: 'View Reports',
            icon: Icons.bar_chart_rounded,
            color: AppColors.primary,
            screen: ReportsScreen(),
          ),
        );
        break;
      case UserRole.hr:
        addAction(
          _hasPermission(Permission.viewEmployees),
          const _DashboardQuickAction(
            title: 'Manage Employees',
            icon: Icons.people_outline,
            color: AppColors.primary,
            screen: EmployeeListScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.approveLeave),
          const _DashboardQuickAction(
            title: 'Review Leave',
            icon: Icons.event_available_rounded,
            color: AppColors.success,
            screen: LeaveApprovalsScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.viewAttendance),
          const _DashboardQuickAction(
            title: 'Attendance',
            icon: Icons.access_time_rounded,
            color: AppColors.info,
            screen: AttendanceListScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.approveExitManagement),
          const _DashboardQuickAction(
            title: 'Exit Cases',
            icon: Icons.logout_rounded,
            color: AppColors.warning,
            screen: ExitManagementScreen(),
          ),
        );
        break;
      case UserRole.accountant:
        addAction(
          _hasPermission(Permission.processPayroll),
          const _DashboardQuickAction(
            title: 'Process Payroll',
            icon: Icons.play_circle_fill_rounded,
            color: AppColors.success,
            screen: ProcessPayrollScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.approveExpenses),
          const _DashboardQuickAction(
            title: 'Review Expenses',
            icon: Icons.receipt_long_outlined,
            color: AppColors.warning,
            screen: ExpenseReimbursementScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.viewReports),
          const _DashboardQuickAction(
            title: 'View Reports',
            icon: Icons.bar_chart_rounded,
            color: AppColors.primary,
            screen: ReportsScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.approveLoan),
          const _DashboardQuickAction(
            title: 'Review Loans',
            icon: Icons.account_balance_wallet_outlined,
            color: AppColors.info,
            screen: LoansListScreen(),
          ),
        );
        break;
      case UserRole.employee:
        addAction(
          _hasPermission(Permission.viewAttendance),
          const _DashboardQuickAction(
            title: 'Clock In/Out',
            icon: Icons.access_time_rounded,
            color: AppColors.info,
            screen: ClockInScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.viewLeave),
          const _DashboardQuickAction(
            title: 'My Leave',
            icon: Icons.beach_access_rounded,
            color: AppColors.primary,
            screen: MyLeavesScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.viewLoans),
          const _DashboardQuickAction(
            title: 'Request Loan',
            icon: Icons.add_card_rounded,
            color: AppColors.warning,
            screen: RequestLoanScreen(),
          ),
        );
        addAction(
          _hasPermission(Permission.viewExpenses),
          const _DashboardQuickAction(
            title: 'Expenses',
            icon: Icons.receipt_long_outlined,
            color: AppColors.success,
            screen: ExpenseReimbursementScreen(),
          ),
        );
        break;
    }

    return actions.take(4).toList();
  }

  _DashboardQuickAction? _buildPrimaryHeaderAction() {
    final actions = _buildAvailableQuickActions();
    if (actions.isEmpty) return null;

    final preferredTitle = switch (currentUser?.role) {
      UserRole.admin => 'Process Payroll',
      UserRole.hr => 'Review Leave',
      UserRole.accountant => 'Process Payroll',
      UserRole.employee => 'Clock In/Out',
      null => null,
    };

    if (preferredTitle != null) {
      for (final action in actions) {
        if (action.title == preferredTitle) {
          return action;
        }
      }
    }

    return actions.first;
  }

  _DashboardQuickAction? _buildSecondaryHeaderAction() {
    if (_hasPermission(Permission.viewReports)) {
      return const _DashboardQuickAction(
        title: 'Export Report',
        icon: Icons.download_rounded,
        color: AppColors.primary,
        screen: ReportsScreen(),
      );
    }
    if (_hasPermission(Permission.viewPayroll)) {
      return const _DashboardQuickAction(
        title: 'Payroll History',
        icon: Icons.history_rounded,
        color: AppColors.primary,
        screen: PayrollHistoryScreen(),
      );
    }
    if (_hasPermission(Permission.viewEmployees)) {
      return const _DashboardQuickAction(
        title: 'Employees',
        icon: Icons.groups_2_outlined,
        color: AppColors.primary,
        screen: EmployeeListScreen(),
      );
    }
    return null;
  }

  Widget _buildSystemHealthSection() {
    final alertsAsync = ref.watch(dashboardCriticalAlertsProvider);
    return Column(
      children: [
        _buildSystemIntegrityCard(),
        const SizedBox(height: 20),
        _buildCriticalAlertsCard(alertsAsync),
      ],
    );
  }

  Widget _buildInsightsSection() {
    final trendsAsync = ref.watch(dashboardPayrollTrendProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 1120;
        if (split) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildPayrollTrendsCard(trendsAsync),
                  ),
                  const SizedBox(width: 20),
                  Expanded(flex: 4, child: _buildDepartmentDistributionCard()),
                ],
              ),
              const SizedBox(height: 20),
              const LiabilityBalancesDashboard(),
            ],
          );
        }

        return Column(
          children: [
            _buildPayrollTrendsCard(trendsAsync),
            const SizedBox(height: 20),
            _buildDepartmentDistributionCard(),
            const SizedBox(height: 20),
            const LiabilityBalancesDashboard(),
          ],
        );
      },
    );
  }

  Widget _buildHeaderButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? const Color(0xFF071A34) : Colors.white,
          foregroundColor: filled ? Colors.white : const Color(0xFF071A34),
          side: BorderSide(
            color: filled ? const Color(0xFF071A34) : const Color(0xFFD6E0EC),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildMetricCard(_DashboardMetricCardData card) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 290;

        return InkWell(
          onTap: card.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: EdgeInsets.all(compact ? 18 : 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A1730).withValues(alpha: 0.06),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: compact ? 50 : 56,
                      width: compact ? 50 : 56,
                      decoration: BoxDecoration(
                        color: card.iconBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        card.icon,
                        color: card.iconColor,
                        size: compact ? 24 : 28,
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: card.badgeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          card.badge,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 12 : 13,
                            fontWeight: FontWeight.w700,
                            color: card.badgeTextColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 14 : 18),
                Text(
                  card.label,
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    letterSpacing: compact ? 1.2 : 1.6,
                    color: const Color(0xFF61728A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  card.value,
                  style: TextStyle(
                    fontSize: compact ? 22 : 26,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0A1730),
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildApprovalPreviewCard(
    AsyncValue<ApprovalInboxSummary> approvalSummaryAsync,
    AsyncValue<List<DashboardApprovalPreviewItem>> approvalPreviewAsync,
  ) {
    return _buildOverviewSurface(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Approval Inbox',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0A1730),
                      ),
                    ),
                    const SizedBox(height: 8),
                    approvalSummaryAsync.when(
                      loading: () => const Text(
                        'Loading pending approvals...',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      error: (_, _) => const Text(
                        'Approval activity is temporarily unavailable.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      data: (summary) => Text(
                        summary.totalPending == 0
                            ? 'You have no high-priority requests awaiting review.'
                            : 'You have ${summary.totalPending} high-priority request${summary.totalPending == 1 ? '' : 's'} awaiting review.',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _openPrimaryApprovalQueue(
                  approvalSummaryAsync.asData?.value,
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 22),
          approvalPreviewAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 6),
            error: (error, _) => Text(
              'Failed to load approval preview: $error',
              style: const TextStyle(color: AppColors.error),
            ),
            data: (items) {
              if (items.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6FB),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'All approval queues are clear right now.',
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              }

              return Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildApprovalPreviewRow(item),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalPreviewRow(DashboardApprovalPreviewItem item) {
    final meta = _approvalMeta(item.module);
    final timeLabel = DateFormat('MMM d').format(item.createdAt);

    return InkWell(
      onTap: () => _navigate(meta.screen),
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5EBF3)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0A1730).withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(meta.icon, color: meta.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A1730),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.amount == null
                        ? '${item.subtitle} • $timeLabel'
                        : '${item.subtitle} • ${CurrencyFormatter.formatNairaNoDecimals(item.amount!)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                meta.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: meta.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewSurface({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1730).withValues(alpha: 0.05),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }

  String _formatDashboardCurrency(double amount) {
    if (amount <= 0) return CurrencyFormatter.formatNairaNoDecimals(0);
    if (amount >= 1000000) return CurrencyFormatter.formatCompact(amount);
    return CurrencyFormatter.formatNairaNoDecimals(amount);
  }

  String _formatTrendBadge(double growth) {
    if (growth == 0) return '0.0%';
    final prefix = growth > 0 ? '+' : '';
    return '$prefix${growth.toStringAsFixed(1)}%';
  }

  _DashboardApprovalMeta _approvalMeta(DashboardApprovalModule module) {
    return switch (module) {
      DashboardApprovalModule.leave => const _DashboardApprovalMeta(
        label: 'Leave',
        icon: Icons.flight_takeoff_rounded,
        color: Color(0xFF2F5B9D),
        screen: LeaveApprovalsScreen(),
      ),
      DashboardApprovalModule.loan => const _DashboardApprovalMeta(
        label: 'Loans',
        icon: Icons.account_balance_outlined,
        color: AppColors.warning,
        screen: LoansListScreen(),
      ),
      DashboardApprovalModule.salaryAdvance => const _DashboardApprovalMeta(
        label: 'Advance',
        icon: Icons.payments_outlined,
        color: Color(0xFF325F9F),
        screen: SalaryAdvanceScreen(),
      ),
      DashboardApprovalModule.expense => const _DashboardApprovalMeta(
        label: 'Expense',
        icon: Icons.medical_services_outlined,
        color: AppColors.success,
        screen: ExpenseReimbursementScreen(),
      ),
      DashboardApprovalModule.exit => const _DashboardApprovalMeta(
        label: 'Exit',
        icon: Icons.trending_up_rounded,
        color: AppColors.error,
        screen: ExitManagementScreen(),
      ),
      DashboardApprovalModule.incentive => const _DashboardApprovalMeta(
        label: 'Bonus',
        icon: Icons.workspace_premium_outlined,
        color: AppColors.accent,
        screen: CommissionBonusScreen(),
      ),
    };
  }

  void _openPrimaryApprovalQueue(ApprovalInboxSummary? summary) {
    if (summary == null) return;
    if (summary.canApproveExpenses) {
      _navigate(const ExpenseReimbursementScreen());
      return;
    }
    if (summary.canApproveLeave) {
      _navigate(const LeaveApprovalsScreen());
      return;
    }
    if (summary.canApproveLoan) {
      _navigate(const LoansListScreen());
      return;
    }
    if (summary.canApproveSalaryAdvance) {
      _navigate(const SalaryAdvanceScreen());
      return;
    }
    if (summary.canApproveExitManagement) {
      _navigate(const ExitManagementScreen());
      return;
    }
    if (summary.canApproveIncentives) {
      _navigate(const CommissionBonusScreen());
    }
  }

  Widget _buildSystemIntegrityCard() {
    final health = _systemHealth;
    if (health == null) {
      return _buildOverviewSurface(
        child: const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final statusText = switch (health.status) {
      PayrollStatus.notProcessed => 'NOT PROCESSED',
      PayrollStatus.processing => 'PROCESSING',
      PayrollStatus.completed => 'COMPLETED',
    };
    final statusColor = switch (health.status) {
      PayrollStatus.notProcessed => AppColors.warning,
      PayrollStatus.processing => const Color(0xFF5C8BFF),
      PayrollStatus.completed => AppColors.success,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF314C72),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1730).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'System Integrity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildIntegrityRow(
            label: 'Data Encryption',
            value: 'ACTIVE',
            valueColor: AppColors.success,
          ),
          const SizedBox(height: 12),
          _buildIntegrityRow(
            label: 'Payroll Status',
            value: statusText,
            valueColor: statusColor,
          ),
          const SizedBox(height: 12),
          _buildIntegrityRow(
            label: 'Alert Monitor',
            value: health.alertCount == 0
                ? 'CLEAR'
                : '${health.alertCount} OPEN',
            valueColor: health.alertCount == 0
                ? AppColors.success
                : AppColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14.5, color: Colors.white),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalAlertsCard(AsyncValue<List<SystemAlert>> alertsAsync) {
    return _buildOverviewSurface(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 10),
              Text(
                'Critical Alerts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0A1730),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          alertsAsync.when(
            loading: () => const LinearProgressIndicator(minHeight: 6),
            error: (error, _) => Text(
              'Unable to load alerts: $error',
              style: const TextStyle(color: AppColors.error),
            ),
            data: (alerts) {
              if (alerts.isEmpty) {
                return const Text(
                  'No active payroll or data integrity alerts right now.',
                  style: TextStyle(
                    fontSize: 14.5,
                    color: AppColors.textSecondary,
                  ),
                );
              }

              return Column(
                children: alerts.take(3).map((alert) {
                  final color = switch (alert.severity) {
                    AlertSeverity.critical => AppColors.error,
                    AlertSeverity.warning => AppColors.warning,
                    AlertSeverity.info => AppColors.info,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 46,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                alert.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A1730),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                alert.message,
                                style: const TextStyle(
                                  fontSize: 13.5,
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
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollTrendsCard(
    AsyncValue<List<MonthlyPayrollTrend>> trendsAsync,
  ) {
    return _buildOverviewSurface(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Payroll Trends',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0A1730),
                  ),
                ),
              ),
              _buildStaticToggle(label: 'MONTHLY', selected: true),
              const SizedBox(width: 8),
              _buildStaticToggle(label: 'QUARTERLY'),
            ],
          ),
          const SizedBox(height: 18),
          trendsAsync.when(
            loading: () => const SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => SizedBox(
              height: 260,
              child: Center(
                child: Text(
                  'Unable to load payroll trends: $error',
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            ),
            data: (trends) {
              if (trends.isEmpty) {
                return const SizedBox(
                  height: 260,
                  child: Center(
                    child: Text(
                      'No payroll trend data available.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              final maxValue = trends
                  .map((trend) => trend.totalNet)
                  .fold<double>(0, (max, value) => value > max ? value : max);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Latest net payroll: ${CurrencyFormatter.formatNairaNoDecimals(trends.last.totalNet)}',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 260,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: trends.asMap().entries.map((entry) {
                        final index = entry.key;
                        final trend = entry.value;
                        final barHeight = maxValue <= 0
                            ? 0.2
                            : (trend.totalNet / maxValue).clamp(0.2, 1.0);
                        final highlighted = index == trends.length - 1;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.formatCompact(
                                    trend.totalNet,
                                  ),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: highlighted
                                        ? const Color(0xFF0A1730)
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: double.infinity,
                                      height: 210 * barHeight,
                                      decoration: BoxDecoration(
                                        color: highlighted
                                            ? const Color(0xFF071A34)
                                            : const Color(0xFFAEC5EA),
                                        borderRadius:
                                            const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  trend.period.split(' ').first.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStaticToggle({required String label, bool selected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? Colors.white : const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? const Color(0xFFD9E0EA) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: selected ? const Color(0xFF0A1730) : const Color(0xFF73849D),
        ),
      ),
    );
  }

  Widget _buildDepartmentDistributionCard() {
    final health = _systemHealth;
    final entries = health?.employeesByDepartment.entries.toList() ?? [];
    entries.sort((a, b) => b.value.compareTo(a.value));
    final total = health?.activeEmployeeCount == 0 || health == null
        ? entries.fold<int>(
            0,
            (runningTotal, entry) => runningTotal + entry.value,
          )
        : health.activeEmployeeCount;

    return _buildOverviewSurface(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Departmental Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A1730),
            ),
          ),
          const SizedBox(height: 22),
          if (entries.isEmpty)
            const Text(
              'No active department data yet.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else
            Column(
              children: entries.take(5).map((entry) {
                final percent = total == 0 ? 0.0 : (entry.value / total) * 100;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0A1730),
                              ),
                            ),
                          ),
                          Text(
                            '${percent.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF526781),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : entry.value / total,
                          minHeight: 10,
                          backgroundColor: const Color(0xFFEAF0F7),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0A1730),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // Widget _buildFeaturesCard() {
  //   // final features = _getRoleFeatures();

  //   return Card(
  //     child: Padding(
  //       padding: const EdgeInsets.all(20),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Row(
  //             children: [
  //               Container(
  //                 padding: const EdgeInsets.all(8),
  //                 decoration: BoxDecoration(
  //                   color: AppColors.success.withOpacity(0.1),
  //                   borderRadius: BorderRadius.circular(8),
  //                 ),
  //                 child: const Icon(
  //                   Icons.check_circle_outline,
  //                   color: AppColors.success,
  //                   size: 20,
  //                 ),
  //               ),
  //               const SizedBox(width: 12),
  //               Text(
  //                 'Your Available Features',
  //                 style: Theme.of(context).textTheme.headlineSmall,
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 16),
  //           ...features.map(
  //             (feature) => Padding(
  //               padding: const EdgeInsets.symmetric(vertical: 4),
  //               child: Row(
  //                 children: [
  //                   const Icon(Icons.check, size: 18, color: AppColors.success),
  //                   const SizedBox(width: 12),
  //                   Text(feature, style: const TextStyle(fontSize: 14)),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // List<String> _getRoleFeatures() {
  //   if (currentUser?.role == UserRole.admin) {
  //     return [
  //       'Employee Management',
  //       'Payroll Processing',
  //       'Loan Management',
  //       'Attendance Tracking',
  //       'User Management',
  //       'Reports & Analytics',
  //       'Real-time Notifications',
  //     ];
  //   } else if (currentUser?.role == UserRole.hr) {
  //     return [
  //       'Employee Management',
  //       'Attendance Tracking',
  //       'Personal Loans',
  //       'HR Reports',
  //       'Attendance Notifications',
  //     ];
  //   } else if (currentUser?.role == UserRole.accountant) {
  //     return [
  //       'Payroll Processing',
  //       'Loan Management',
  //       'Financial Reports',
  //       'Payment Processing',
  //       'Loan Notifications',
  //     ];
  //   } else {
  //     return [
  //       'Clock In/Out',
  //       'View Attendance',
  //       'Request Loans',
  //       'Track My Loans',
  //       'Instant Notifications',
  //     ];
  //   }
  // }

  void _navigate(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(approvalInboxSummaryProvider);
    ref.invalidate(dashboardApprovalPreviewProvider);
    ref.invalidate(dashboardCriticalAlertsProvider);
    ref.invalidate(dashboardPayrollTrendProvider);
  }
}

class _DashboardMetricCardData {
  final String label;
  final String value;
  final String badge;
  final Color badgeColor;
  final Color badgeTextColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback? onTap;

  const _DashboardMetricCardData({
    required this.label,
    required this.value,
    required this.badge,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.onTap,
  });
}

class _DashboardQuickAction {
  final String title;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _DashboardQuickAction({
    required this.title,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class _DashboardApprovalMeta {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _DashboardApprovalMeta({
    required this.label,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class HrDashboardScreen extends ConsumerWidget {
  const HrDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = AuthService();
    final notificationService = NotificationService();
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final userId = authService.currentUser?.uid;

    return AppScaffold(
      title: 'HR Dashboard',
      showSearch: true,
      scrollable: false,
      padding: EdgeInsets.zero,
      headerActions: _buildNotificationAction(
        context,
        userId,
        notificationService,
      ),
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(
          'Failed to load HR dashboard: $error',
          () => ref.invalidate(dashboardSummaryProvider),
        ),
        data: (summary) {
          return ResponsiveLayout(
            mobile: _buildHrContent(context, ref, summary, compact: true),
            tablet: _buildHrContent(context, ref, summary, compact: false),
            desktop: _buildHrContent(context, ref, summary, compact: false),
          );
        },
      ),
    );
  }

  Widget _buildHrContent(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary, {
    required bool compact,
  }) {
    return _buildRoleDashboardShell(
      summary: summary,
      compact: compact,
      subtitle: 'People, attendance, and workforce health at a glance.',
      sections: [
        _buildHrDashboardMetrics(context, ref, summary),
        _buildApprovalInboxCard(
          context,
          ref,
          title: 'Approval Inbox',
          subtitle:
              'Stay ahead of employee requests across leave, expenses, exits, and more.',
        ),
        _buildExpenseQueueCard(
          context,
          ref,
          summary.pendingExpenses,
          title: 'Expense Queue',
          subtitle: 'Keep approvals moving for employee reimbursements.',
        ),
        _buildHrInsights(context),
        _buildHrQuickActions(context, ref),
      ],
    );
  }

  Widget _buildHrDashboardMetrics(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary,
  ) {
    final pendingAsync = ref.watch(pendingLeaveRequestsProvider);
    final pendingCount = pendingAsync.maybeWhen(
      data: (requests) => requests.length,
      orElse: () => null,
    );
    final pendingLabel = pendingCount == null
        ? 'Loading...'
        : pendingCount == 0
        ? 'No pending'
        : 'Pending approval';

    return _buildRoleMetricGrid([
      _RoleMetricCardData(
        title: 'Total Employees',
        value: summary.totalEmployees.toString(),
        detail: '${summary.systemHealth.activeEmployeeCount} active right now',
        icon: Icons.people_outline,
        color: AppColors.primary,
        onTap: () => _navigate(context, const EmployeeListScreen(), ref: ref),
      ),
      _RoleMetricCardData(
        title: 'Leave Requests',
        value: pendingCount?.toString() ?? '-',
        detail: pendingLabel,
        icon: Icons.assignment_turned_in_outlined,
        color: pendingCount == null || pendingCount == 0
            ? AppColors.info
            : AppColors.warning,
        onTap: () => _navigate(context, const LeaveApprovalsScreen(), ref: ref),
      ),
      _RoleMetricCardData(
        title: 'Pending Expenses',
        value: summary.pendingExpenses.toString(),
        detail: summary.pendingExpenses == 0
            ? 'Nothing waiting for review'
            : 'Needs reimbursement review',
        icon: Icons.receipt_long_outlined,
        color: summary.pendingExpenses == 0
            ? AppColors.success
            : AppColors.error,
        onTap: () =>
            _navigate(context, const ExpenseReimbursementScreen(), ref: ref),
      ),
    ]);
  }

  // ignore: unused_element
  Widget _buildHrMetrics(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary,
  ) {
    final pendingAsync = ref.watch(pendingLeaveRequestsProvider);
    final pendingCount = pendingAsync.maybeWhen(
      data: (requests) => requests.length,
      orElse: () => null,
    );
    final pendingLabel = pendingCount == null
        ? 'Loading...'
        : pendingCount == 0
        ? 'No pending'
        : 'Pending approval';

    return ModernMetricsGrid(
      metrics: [
        ModernMetricCard(
          title: 'Total Employees',
          value: summary.totalEmployees.toString(),
          trend: '${summary.systemHealth.activeEmployeeCount} active',
          trendDirection: TrendDirection.neutral,
          icon: Icons.people_outline,
          color: AppColors.primary,
          onTap: () => _navigate(context, const EmployeeListScreen(), ref: ref),
        ),
        ModernMetricCard(
          title: 'Leave Requests',
          value: pendingCount?.toString() ?? '—',
          trend: pendingLabel,
          trendDirection: pendingCount == null || pendingCount == 0
              ? TrendDirection.neutral
              : TrendDirection.down,
          icon: Icons.assignment_turned_in_outlined,
          color: pendingCount == null || pendingCount == 0
              ? AppColors.info
              : AppColors.warning,
          onTap: () =>
              _navigate(context, const LeaveApprovalsScreen(), ref: ref),
        ),
      ],
    );
  }

  Widget _buildHrInsights(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: _InsightCard(
                title: 'Attendance Compliance',
                child: _LiveAttendanceCompliance(),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _InsightCard(
                title: 'Leave Requests',
                child: _LiveLeaveRequestsBars(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHrQuickActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              title: 'Manage Employees',
              icon: Icons.people_outline,
              color: AppColors.primary,
              onTap: () =>
                  _navigate(context, const EmployeeListScreen(), ref: ref),
            ),
            _buildActionButton(
              title: 'Leave Approvals',
              icon: Icons.assignment_turned_in_outlined,
              color: AppColors.info,
              onTap: () =>
                  _navigate(context, const LeaveApprovalsScreen(), ref: ref),
            ),
            _buildActionButton(
              title: 'Attendance',
              icon: Icons.fact_check_outlined,
              color: AppColors.warning,
              onTap: () =>
                  _navigate(context, const AttendanceListScreen(), ref: ref),
            ),
          ],
        ),
      ],
    );
  }
}

class AccountantDashboardScreen extends ConsumerWidget {
  const AccountantDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = AuthService();
    final notificationService = NotificationService();
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final userId = authService.currentUser?.uid;

    return AppScaffold(
      title: 'Accountant Dashboard',
      showSearch: true,
      scrollable: false,
      padding: EdgeInsets.zero,
      headerActions: _buildNotificationAction(
        context,
        userId,
        notificationService,
      ),
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(
          'Failed to load accountant dashboard: $error',
          () => ref.invalidate(dashboardSummaryProvider),
        ),
        data: (summary) {
          return ResponsiveLayout(
            mobile: _buildAccountantContent(
              context,
              ref,
              summary,
              compact: true,
            ),
            tablet: _buildAccountantContent(
              context,
              ref,
              summary,
              compact: false,
            ),
            desktop: _buildAccountantContent(
              context,
              ref,
              summary,
              compact: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountantContent(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary, {
    required bool compact,
  }) {
    return _buildRoleDashboardShell(
      summary: summary,
      compact: compact,
      subtitle: 'Payroll performance and financial exposure.',
      sections: [
        _buildAccountantDashboardMetrics(summary),
        _buildApprovalInboxCard(
          context,
          ref,
          title: 'Approval Inbox',
          subtitle:
              'Keep financial approvals moving across loans, advances, expenses, and incentives.',
        ),
        _buildAccountantInsights(context),
        _buildAccountantQuickActions(context, ref),
      ],
    );
  }

  Widget _buildAccountantDashboardMetrics(DashboardSummary summary) {
    final payrollTrend = summary.systemHealth.payrollGrowthPercentage;

    return _buildRoleMetricGrid([
      _RoleMetricCardData(
        title: 'Monthly Payroll',
        value: CurrencyFormatter.formatNaira(summary.currentMonthPayroll),
        detail: '${payrollTrend.toStringAsFixed(1)}% from last cycle',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.success,
      ),
      _RoleMetricCardData(
        title: 'Loan Exposure',
        value:
            '${summary.systemHealth.loanExposurePercentage.toStringAsFixed(1)}%',
        detail: summary.systemHealth.loanExposurePercentage > 60
            ? 'High risk concentration'
            : 'Stable exposure level',
        icon: Icons.trending_down_outlined,
        color: summary.systemHealth.loanExposurePercentage > 60
            ? AppColors.error
            : AppColors.info,
      ),
      _RoleMetricCardData(
        title: 'Average Salary',
        value: CurrencyFormatter.formatNaira(summary.systemHealth.avgSalary),
        detail: 'Across active payroll records',
        icon: Icons.analytics_outlined,
        color: AppColors.primary,
      ),
    ]);
  }

  // ignore: unused_element
  Widget _buildAccountantMetrics(DashboardSummary summary) {
    final payrollTrend = summary.systemHealth.payrollGrowthPercentage;
    final payrollDirection = payrollTrend > 0
        ? TrendDirection.up
        : payrollTrend < 0
        ? TrendDirection.down
        : TrendDirection.neutral;

    return ModernMetricsGrid(
      metrics: [
        ModernMetricCard(
          title: 'Monthly Payroll',
          value: CurrencyFormatter.formatNaira(summary.currentMonthPayroll),
          trend: '${payrollTrend.toStringAsFixed(1)}%',
          trendDirection: payrollDirection,
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.success,
        ),
        ModernMetricCard(
          title: 'Loan Exposure',
          value:
              '${summary.systemHealth.loanExposurePercentage.toStringAsFixed(1)}%',
          trend: summary.systemHealth.loanExposurePercentage > 60
              ? 'High risk'
              : 'Stable',
          trendDirection: summary.systemHealth.loanExposurePercentage > 60
              ? TrendDirection.down
              : TrendDirection.up,
          icon: Icons.trending_down_outlined,
          color: summary.systemHealth.loanExposurePercentage > 60
              ? AppColors.error
              : AppColors.info,
        ),
        ModernMetricCard(
          title: 'Avg Salary',
          value: CurrencyFormatter.formatCompact(
            summary.systemHealth.avgSalary,
          ),
          trend: 'Company-wide',
          trendDirection: TrendDirection.neutral,
          icon: Icons.analytics_outlined,
          color: AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildAccountantInsights(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(
              child: _InsightCard(
                title: 'Payroll Variance',
                child: _LivePayrollVariance(),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: _InsightCard(
                title: 'Loan Exposure',
                child: _LiveLoanExposure(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const LiabilityBalancesDashboard(),
      ],
    );
  }

  Widget _buildAccountantQuickActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              title: 'Process Payroll',
              icon: Icons.calculate_outlined,
              color: AppColors.success,
              onTap: () =>
                  _navigate(context, const ProcessPayrollScreen(), ref: ref),
            ),
            _buildActionButton(
              title: 'Payroll History',
              icon: Icons.history,
              color: AppColors.info,
              onTap: () =>
                  _navigate(context, const PayrollHistoryScreen(), ref: ref),
            ),
            _buildActionButton(
              title: 'View Reports',
              icon: Icons.bar_chart,
              color: AppColors.primary,
              onTap: () => _navigate(context, const ReportsScreen(), ref: ref),
            ),
          ],
        ),
      ],
    );
  }
}

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = AuthService();
    final notificationService = NotificationService();
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final userId = authService.currentUser?.uid;

    return AppScaffold(
      title: 'My Dashboard',
      showSearch: false,
      scrollable: false,
      padding: EdgeInsets.zero,
      headerActions: _buildNotificationAction(
        context,
        userId,
        notificationService,
      ),
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(
          'Failed to load dashboard: $error',
          () => ref.invalidate(dashboardSummaryProvider),
        ),
        data: (summary) {
          return ResponsiveLayout(
            mobile: _buildEmployeeContent(context, ref, summary, compact: true),
            tablet: _buildEmployeeContent(
              context,
              ref,
              summary,
              compact: false,
            ),
            desktop: _buildEmployeeContent(
              context,
              ref,
              summary,
              compact: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmployeeContent(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary, {
    required bool compact,
  }) {
    return _buildRoleDashboardShell(
      summary: summary,
      compact: compact,
      subtitle: 'Your personal payroll and attendance snapshot.',
      sections: [
        _buildEmployeeDashboardMetrics(context, ref, summary),
        _buildEmployeeInsights(context, summary),
        _buildEmployeeQuickActions(context, ref),
      ],
    );
  }

  Widget _buildEmployeeDashboardMetrics(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary,
  ) {
    final statusLabel = switch (summary.systemHealth.status) {
      PayrollStatus.notProcessed => 'Not Processed',
      PayrollStatus.processing => 'Processing',
      PayrollStatus.completed => 'Completed',
    };
    final leaveAsync = ref.watch(leaveDashboardProvider);
    final leaveBalance = leaveAsync.maybeWhen(
      data: (data) => data.balances.fold<double>(
        0,
        (total, balance) => total + balance.availableBalance,
      ),
      orElse: () => null,
    );
    final leaveBalanceLabel = leaveBalance == null
        ? 'Loading...'
        : '${leaveBalance.toStringAsFixed(1)} days available';

    return _buildRoleMetricGrid([
      _RoleMetricCardData(
        title: 'My Loans',
        value: CurrencyFormatter.formatNaira(summary.myLoans),
        detail: summary.myLoans <= 0
            ? 'No active loans'
            : 'Outstanding balance',
        icon: Icons.credit_card_outlined,
        color: summary.myLoans <= 0 ? AppColors.success : AppColors.warning,
        onTap: () => _navigate(context, const RequestLoanScreen(), ref: ref),
      ),
      _RoleMetricCardData(
        title: 'Payroll Status',
        value: statusLabel,
        detail: 'Current company payroll cycle',
        icon: Icons.payments_outlined,
        color: AppColors.info,
      ),
      _RoleMetricCardData(
        title: 'My Leave Balance',
        value: leaveBalance == null ? '-' : leaveBalance.toStringAsFixed(1),
        detail: leaveBalanceLabel,
        icon: Icons.beach_access_outlined,
        color: AppColors.primary,
        onTap: () => _navigate(context, const MyLeavesScreen(), ref: ref),
      ),
    ]);
  }

  // ignore: unused_element
  Widget _buildEmployeeMetrics(
    BuildContext context,
    WidgetRef ref,
    DashboardSummary summary,
  ) {
    final statusLabel = switch (summary.systemHealth.status) {
      PayrollStatus.notProcessed => 'Not Processed',
      PayrollStatus.processing => 'Processing',
      PayrollStatus.completed => 'Completed',
    };
    final leaveAsync = ref.watch(leaveDashboardProvider);
    final leaveBalance = leaveAsync.maybeWhen(
      data: (data) =>
          // ignore: avoid_types_as_parameter_names
          data.balances.fold<double>(0, (sum, b) => sum + b.availableBalance),
      orElse: () => null,
    );
    final leaveBalanceLabel = leaveBalance == null
        ? 'Loading...'
        : '${leaveBalance.toStringAsFixed(1)} days';

    return ModernMetricsGrid(
      metrics: [
        ModernMetricCard(
          title: 'My Loans',
          value: CurrencyFormatter.formatNaira(summary.myLoans),
          trend: summary.myLoans <= 0 ? 'No active loans' : 'Outstanding',
          trendDirection: summary.myLoans <= 0
              ? TrendDirection.neutral
              : TrendDirection.down,
          icon: Icons.credit_card_outlined,
          color: summary.myLoans <= 0 ? AppColors.success : AppColors.warning,
          onTap: () => _navigate(context, const RequestLoanScreen(), ref: ref),
        ),
        ModernMetricCard(
          title: 'Payroll Status',
          value: statusLabel,
          trend: 'Company payroll',
          trendDirection: TrendDirection.neutral,
          icon: Icons.payments_outlined,
          color: AppColors.info,
        ),
        ModernMetricCard(
          title: 'My Leave Balance',
          value: leaveBalance == null ? '—' : leaveBalance.toStringAsFixed(1),
          trend: leaveBalanceLabel,
          trendDirection: TrendDirection.neutral,
          icon: Icons.beach_access_outlined,
          color: AppColors.primary,
          onTap: () => _navigate(context, const MyLeavesScreen(), ref: ref),
        ),
      ],
    );
  }

  Widget _buildEmployeeInsights(
    BuildContext context,
    DashboardSummary summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insights', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _InsightCard(
                title: 'My Attendance',
                child: _LiveMyAttendance(employeeId: summary.user?.employeeId),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _InsightCard(
                title: 'My Leave Usage',
                child: _LiveMyLeaveUsage(employeeId: summary.user?.employeeId),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeeQuickActions(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              title: 'Clock In/Out',
              icon: Icons.access_time,
              color: AppColors.info,
              onTap: () => _navigate(context, const ClockInScreen(), ref: ref),
            ),
            _buildActionButton(
              title: 'My Leave',
              icon: Icons.beach_access_outlined,
              color: AppColors.primary,
              onTap: () => _navigate(context, const MyLeavesScreen(), ref: ref),
            ),
            _buildActionButton(
              title: 'Request Loan',
              icon: Icons.add_card,
              color: AppColors.warning,
              onTap: () =>
                  _navigate(context, const RequestLoanScreen(), ref: ref),
            ),
          ],
        ),
      ],
    );
  }
}

Widget _buildErrorState(String message, VoidCallback onRetry) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}

Widget _buildExpenseQueueCard(
  BuildContext context,
  WidgetRef ref,
  int pendingExpenses, {
  required String title,
  required String subtitle,
}) {
  final hasPending = pendingExpenses > 0;

  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (hasPending ? AppColors.warning : AppColors.info)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              color: hasPending ? AppColors.warning : AppColors.info,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
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
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pendingExpenses.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: hasPending ? AppColors.warning : AppColors.info,
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => _navigate(
                  context,
                  const ExpenseReimbursementScreen(),
                  ref: ref,
                ),
                child: const Text('Open Expenses'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildApprovalInboxCard(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String subtitle,
}) {
  final inboxAsync = ref.watch(approvalInboxSummaryProvider);

  return inboxAsync.when(
    loading: () => Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Loading approval inbox...',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12),
            LinearProgressIndicator(minHeight: 6),
          ],
        ),
      ),
    ),
    error: (error, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Approval data could not be loaded right now.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              error.toString(),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    ),
    data: (summary) {
      if (!summary.hasVisibleModules) {
        return const SizedBox.shrink();
      }

      final items = <_ApprovalInboxItem>[
        if (summary.canApproveLeave)
          _ApprovalInboxItem(
            title: 'Leave',
            subtitle: 'Requests to review',
            count: summary.pendingLeaveRequests,
            icon: Icons.beach_access_outlined,
            color: AppColors.primary,
            screen: const LeaveApprovalsScreen(),
          ),
        if (summary.canApproveLoan)
          _ApprovalInboxItem(
            title: 'Loans',
            subtitle: 'Applications awaiting review',
            count: summary.pendingLoans,
            icon: Icons.account_balance_outlined,
            color: AppColors.warning,
            screen: const LoansListScreen(),
          ),
        if (summary.canApproveSalaryAdvance)
          _ApprovalInboxItem(
            title: 'Salary Advance',
            subtitle: 'Advance requests in queue',
            count: summary.pendingSalaryAdvances,
            icon: Icons.payments_outlined,
            color: AppColors.info,
            screen: const SalaryAdvanceScreen(),
          ),
        if (summary.canApproveExpenses)
          _ApprovalInboxItem(
            title: 'Expenses',
            subtitle: 'Claims awaiting approval',
            count: summary.pendingExpenses,
            icon: Icons.receipt_long_outlined,
            color: AppColors.success,
            screen: const ExpenseReimbursementScreen(),
          ),
        if (summary.canApproveExitManagement)
          _ApprovalInboxItem(
            title: 'Exit',
            subtitle: 'Requests in offboarding flow',
            count: summary.pendingExitRequests,
            icon: Icons.logout_outlined,
            color: AppColors.error,
            screen: const ExitManagementScreen(),
          ),
        if (summary.canApproveIncentives)
          _ApprovalInboxItem(
            title: 'Commission & Bonus',
            subtitle: 'Entries pending sign-off',
            count: summary.pendingIncentives,
            icon: Icons.workspace_premium_outlined,
            color: AppColors.accent,
            screen: const CommissionBonusScreen(),
          ),
      ];

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: summary.totalPending == 0
                          ? AppColors.success.withValues(alpha: 0.10)
                          : AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      summary.totalPending == 0
                          ? 'All clear'
                          : '${summary.totalPending} pending',
                      style: TextStyle(
                        color: summary.totalPending == 0
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items
                    .map((item) => _buildApprovalInboxTile(context, ref, item))
                    .toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildApprovalInboxTile(
  BuildContext context,
  WidgetRef ref,
  _ApprovalInboxItem item,
) {
  final isClear = item.count == 0;

  return SizedBox(
    width: 220,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => item.screen),
        );
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(approvalInboxSummaryProvider);
      },
      child: Ink(
        decoration: BoxDecoration(
          color: isClear
              ? AppColors.surfaceVariant
              : item.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isClear
                ? AppColors.border
                : item.color.withValues(alpha: 0.24),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isClear
                          ? Colors.white
                          : item.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.icon,
                      color: isClear ? AppColors.textSecondary : item.color,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    item.count.toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isClear ? AppColors.textPrimary : item.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Text(
                isClear ? 'No pending items' : 'Open review queue',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isClear ? AppColors.textSecondary : item.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ApprovalInboxItem {
  final String title;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final Widget screen;

  const _ApprovalInboxItem({
    required this.title,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    required this.screen,
  });
}

class _WatchSafeQueryBuilder extends StatelessWidget {
  final Query<Map<String, dynamic>> query;
  final Widget loadingChild;
  final Widget Function(QuerySnapshot<Map<String, dynamic>> snapshot) builder;

  const _WatchSafeQueryBuilder({
    required this.query,
    required this.loadingChild,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
        future: query.get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return loadingChild;
          }
          return builder(snapshot.data!);
        },
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return loadingChild;
        }
        return builder(snapshot.data!);
      },
    );
  }
}

Widget? _buildNotificationAction(
  BuildContext context,
  String? userId,
  NotificationService notificationService,
) {
  if (userId == null) return null;
  return StreamBuilder<int>(
    stream: notificationService.getUnreadCountStream(userId),
    builder: (context, snapshot) {
      final unreadCount = snapshot.data ?? 0;
      return Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
          if (unreadCount > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    },
  );
}

Widget _buildRoleDashboardShell({
  required DashboardSummary summary,
  required bool compact,
  required String subtitle,
  required List<Widget> sections,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final horizontalPadding = constraints.maxWidth >= 1400
          ? 32.0
          : constraints.maxWidth >= 960
          ? 24.0
          : 16.0;
      final maxWidth = constraints.maxWidth >= 1500 ? 1320.0 : 1220.0;

      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            compact ? 18 : 24,
            horizontalPadding,
            compact ? 18 : 24,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(summary, compact: compact, subtitle: subtitle),
                  SizedBox(height: compact ? 16 : 22),
                  ...sections.expand(
                    (section) => [section, SizedBox(height: compact ? 16 : 22)],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildHeader(
  DashboardSummary summary, {
  required bool compact,
  required String subtitle,
}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(compact ? 20 : 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0A1730).withValues(alpha: 0.04),
          blurRadius: 24,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 820;
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome back, ${summary.user?.name ?? 'User'}',
              style: TextStyle(
                fontSize: compact ? 26 : 32,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0A1730),
                letterSpacing: -0.9,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        );
        final badge = Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            (summary.user?.role.name ?? 'user').toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5E79),
              letterSpacing: 1.8,
            ),
          ),
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 14), badge],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            badge,
          ],
        );
      },
    ),
  );
}

Widget _buildRoleMetricGrid(List<_RoleMetricCardData> cards) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1120;
      final medium = constraints.maxWidth >= 760;
      final cardWidth = wide
          ? (constraints.maxWidth - 32) / 3
          : medium
          ? (constraints.maxWidth - 16) / 2
          : constraints.maxWidth;

      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards
            .map(
              (card) =>
                  SizedBox(width: cardWidth, child: _RoleMetricCard(card)),
            )
            .toList(),
      );
    },
  );
}

class _RoleMetricCardData {
  final String title;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _RoleMetricCardData({
    required this.title,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    this.onTap,
  });
}

class _RoleMetricCard extends StatelessWidget {
  final _RoleMetricCardData data;

  const _RoleMetricCard(this.data);

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1730).withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(height: 18),
          Text(
            data.title.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF667A96),
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0A1730),
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.detail,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );

    if (data.onTap == null) return content;
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(22),
      child: content,
    );
  }
}

Widget _buildActionButton({
  required String title,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return SizedBox(
    width: 220,
    height: 54,
    child: ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
  );
}

Future<void> _navigate(
  BuildContext context,
  Widget screen, {
  WidgetRef? ref,
}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => screen),
  );
  if (ref != null) {
    ref.invalidate(dashboardSummaryProvider);
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InsightCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1730).withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A1730),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 170, child: child),
          ],
        ),
      ),
    );
  }
}

class _LiveAttendanceCompliance extends StatelessWidget {
  const _LiveAttendanceCompliance();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));

    return FutureBuilder<String?>(
      future: UserService().getCurrentCompanyId(),
      builder: (context, companySnapshot) {
        final companyId = companySnapshot.data;
        if (!companySnapshot.hasData ||
            companyId == null ||
            companyId.isEmpty) {
          return const _ShimmerSpark();
        }
        return _WatchSafeQueryBuilder(
          query: FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('attendance')
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start)),
          loadingChild: const _ShimmerSpark(),
          builder: (snapshot) {
            final buckets = List.generate(
              5,
              (_) => {'attended': 0, 'total': 0},
            );
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final ts = data['date'] as Timestamp?;
              final status = (data['status'] ?? '').toString();
              if (ts == null) continue;
              final d = ts.toDate();
              final daysAgo = now.difference(d).inDays;
              final bucket = (4 - (daysAgo / 7).floor()).clamp(0, 4);
              buckets[bucket]['total'] = buckets[bucket]['total']! + 1;
              if (status == 'present' ||
                  status == 'late' ||
                  status == 'halfDay') {
                buckets[bucket]['attended'] = buckets[bucket]['attended']! + 1;
              }
            }

            final values = buckets.map((b) {
              final total = b['total']!;
              final attended = b['attended']!;
              if (total == 0) return 0.0;
              return attended / total;
            }).toList();

            return _AnimatedLineSpark(values: values, normalize: false);
          },
        );
      },
    );
  }
}

class _LiveLeaveRequestsBars extends StatelessWidget {
  const _LiveLeaveRequestsBars();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));

    return FutureBuilder<String?>(
      future: UserService().getCurrentCompanyId(),
      builder: (context, companySnapshot) {
        final companyId = companySnapshot.data;
        if (!companySnapshot.hasData ||
            companyId == null ||
            companyId.isEmpty) {
          return const _ShimmerBars();
        }
        return _WatchSafeQueryBuilder(
          query: FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('leave_requests')
              .where(
                'requestedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              ),
          loadingChild: const _ShimmerBars(),
          builder: (snapshot) {
            int pending = 0;
            int approved = 0;
            int rejected = 0;

            for (final doc in snapshot.docs) {
              final status = (doc.data()['status'] ?? '').toString();
              if (status == 'pending') pending += 1;
              if (status == 'approved') approved += 1;
              if (status == 'rejected') rejected += 1;
            }

            return _AnimatedBarSpark(
              values: [
                pending.toDouble(),
                approved.toDouble(),
                rejected.toDouble(),
              ],
            );
          },
        );
      },
    );
  }
}

class _LivePayrollVariance extends StatelessWidget {
  const _LivePayrollVariance();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 5, 1);

    return FutureBuilder<String?>(
      future: UserService().getCurrentCompanyId(),
      builder: (context, companySnapshot) {
        final companyId = companySnapshot.data;
        if (!companySnapshot.hasData ||
            companyId == null ||
            companyId.isEmpty) {
          return const _ShimmerSpark();
        }
        return _WatchSafeQueryBuilder(
          query: FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('payrolls')
              .orderBy('processedDate', descending: true)
              .where(
                'processedDate',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              ),
          loadingChild: const _ShimmerSpark(),
          builder: (snapshot) {
            final docs = snapshot.docs;
            final Map<String, double> totals = {};
            for (final doc in docs) {
              final data = doc.data();
              final ts = data['processedDate'] as Timestamp?;
              final net = (data['netSalary'] ?? 0).toDouble();
              if (ts == null) continue;
              final d = ts.toDate();
              final key = '${d.year}-${d.month}';
              totals[key] = (totals[key] ?? 0) + net;
            }

            final points = <double>[];
            for (int i = 5; i >= 0; i--) {
              final d = DateTime(now.year, now.month - i, 1);
              final key = '${d.year}-${d.month}';
              points.add(totals[key] ?? 0);
            }

            return _AnimatedLineSpark(values: points);
          },
        );
      },
    );
  }
}

class _LiveLoanExposure extends StatelessWidget {
  const _LiveLoanExposure();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: UserService().getCurrentCompanyId(),
      builder: (context, companySnapshot) {
        final companyId = companySnapshot.data;
        if (!companySnapshot.hasData ||
            companyId == null ||
            companyId.isEmpty) {
          return const _ShimmerBars();
        }
        return _WatchSafeQueryBuilder(
          query: FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('loans'),
          loadingChild: const _ShimmerBars(),
          builder: (snapshot) {
            double pending = 0;
            double active = 0;
            double rejected = 0;

            for (final doc in snapshot.docs) {
              final data = doc.data();
              final status = (data['status'] ?? '').toString();
              final amount = (data['amount'] ?? 0).toDouble();
              if (status == 'pending') pending += amount;
              if (status == 'active' || status == 'approved') active += amount;
              if (status == 'rejected') rejected += amount;
            }

            return _AnimatedBarSpark(values: [pending, active, rejected]);
          },
        );
      },
    );
  }
}

class _LiveMyAttendance extends StatelessWidget {
  final String? employeeId;

  const _LiveMyAttendance({required this.employeeId});

  @override
  Widget build(BuildContext context) {
    if (employeeId == null) return const _ShimmerSpark();
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 30));

    return FutureBuilder<String?>(
      future: UserService().getCurrentCompanyId(),
      builder: (context, companySnapshot) {
        final companyId = companySnapshot.data;
        if (!companySnapshot.hasData ||
            companyId == null ||
            companyId.isEmpty) {
          return const _ShimmerSpark();
        }
        return _WatchSafeQueryBuilder(
          query: FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('attendance')
              .where('employeeId', isEqualTo: employeeId)
              .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start)),
          loadingChild: const _ShimmerSpark(),
          builder: (snapshot) {
            final buckets = List.generate(
              5,
              (_) => {'attended': 0, 'total': 0},
            );
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final ts = data['date'] as Timestamp?;
              final status = (data['status'] ?? '').toString();
              if (ts == null) continue;
              final d = ts.toDate();
              final daysAgo = now.difference(d).inDays;
              final bucket = (4 - (daysAgo / 7).floor()).clamp(0, 4);
              buckets[bucket]['total'] = buckets[bucket]['total']! + 1;
              if (status == 'present' ||
                  status == 'late' ||
                  status == 'halfDay') {
                buckets[bucket]['attended'] = buckets[bucket]['attended']! + 1;
              }
            }

            final values = buckets.map((b) {
              final total = b['total']!;
              final attended = b['attended']!;
              if (total == 0) return 0.0;
              return attended / total;
            }).toList();

            return _AnimatedLineSpark(values: values, normalize: false);
          },
        );
      },
    );
  }
}

class _LiveMyLeaveUsage extends StatelessWidget {
  final String? employeeId;

  const _LiveMyLeaveUsage({required this.employeeId});

  @override
  Widget build(BuildContext context) {
    if (employeeId == null) return const _ShimmerBars();
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 5, 1);

    return FutureBuilder<String?>(
      future: UserService().getCurrentCompanyId(),
      builder: (context, companySnapshot) {
        final companyId = companySnapshot.data;
        if (!companySnapshot.hasData ||
            companyId == null ||
            companyId.isEmpty) {
          return const _ShimmerBars();
        }
        return _WatchSafeQueryBuilder(
          query: FirebaseFirestore.instance
              .collection('companies')
              .doc(companyId)
              .collection('leave_requests')
              .where('employeeId', isEqualTo: employeeId)
              .where(
                'requestedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(start),
              ),
          loadingChild: const _ShimmerBars(),
          builder: (snapshot) {
            final counts = List.generate(6, (_) => 0.0);
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final ts = data['requestedAt'] as Timestamp?;
              final days = (data['numberOfDays'] ?? 0).toDouble();
              if (ts == null) continue;
              final d = ts.toDate();
              final index = (5 - (now.month - d.month)).clamp(0, 5);
              counts[index] += days;
            }

            return _AnimatedBarSpark(values: counts);
          },
        );
      },
    );
  }
}

class _ShimmerSpark extends StatelessWidget {
  const _ShimmerSpark();

  @override
  Widget build(BuildContext context) {
    return const _PulseBox(height: 140);
  }
}

class _ShimmerBars extends StatelessWidget {
  const _ShimmerBars();

  @override
  Widget build(BuildContext context) {
    return const _PulseBox(height: 140);
  }
}

class _PulseBox extends StatefulWidget {
  final double height;

  const _PulseBox({required this.height});

  @override
  State<_PulseBox> createState() => _PulseBoxState();
}

class _PulseBoxState extends State<_PulseBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.5, end: 0.9).animate(_controller),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _AnimatedLineSpark extends StatelessWidget {
  final List<double> values;
  final bool normalize;

  const _AnimatedLineSpark({required this.values, this.normalize = true});

  @override
  Widget build(BuildContext context) {
    final key = ValueKey(values.join('|'));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: TweenAnimationBuilder<double>(
        key: key,
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        builder: (context, t, _) {
          return CustomPaint(
            painter: _LineSparkPainter(
              values: values,
              t: t,
              normalize: normalize,
            ),
            child: Container(),
          );
        },
      ),
    );
  }
}

class _AnimatedBarSpark extends StatelessWidget {
  final List<double> values;

  const _AnimatedBarSpark({required this.values});

  @override
  Widget build(BuildContext context) {
    final maxValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a > b ? a : b);
    final key = ValueKey(values.join('|'));
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Row(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: maxValue == 0 ? 0 : v / maxValue),
                  duration: const Duration(milliseconds: 900),
                  builder: (context, value, _) {
                    return Container(
                      height: 120 * value,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LineSparkPainter extends CustomPainter {
  final List<double> values;
  final double t;
  final bool normalize;

  _LineSparkPainter({required this.values, this.t = 1, this.normalize = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    if (values.isEmpty) return;
    final safeValues = values.length == 1
        ? [values.first, values.first]
        : values;
    final maxValue = safeValues.reduce((a, b) => a > b ? a : b);
    final points = <Offset>[];

    for (int i = 0; i < safeValues.length; i++) {
      final x = size.width * (i / (safeValues.length - 1));
      final v = normalize && maxValue > 0
          ? safeValues[i] / maxValue
          : safeValues[i];
      final y = size.height * (1 - v) * 0.85 + size.height * 0.1;
      points.add(Offset(x, y));
    }

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final metric = path.computeMetrics().first;
    final extract = metric.extractPath(0, metric.length * t);
    canvas.drawPath(extract, paint);
  }

  @override
  bool shouldRepaint(covariant _LineSparkPainter oldDelegate) {
    return oldDelegate.t != t ||
        oldDelegate.values != values ||
        oldDelegate.normalize != normalize;
  }
}
