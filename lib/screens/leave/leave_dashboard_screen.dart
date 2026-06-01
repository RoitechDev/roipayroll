import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/leave_balance_model.dart';
import 'package:roipayroll/models/leave_encashment_model.dart';
import 'package:roipayroll/models/leave_request_model.dart';
import 'package:roipayroll/models/leave_type_model.dart';
import 'package:roipayroll/models/public_holiday_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/widgets/modern/index.dart';

enum _LeaveWorkspaceTab {
  overview,
  request,
  timeline,
  approvals,
  balances,
  encashment,
  holidays,
  types,
}

class _LeaveTabConfig {
  final _LeaveWorkspaceTab id;
  final String label;
  final IconData icon;
  final String subtitle;

  const _LeaveTabConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.subtitle,
  });
}

class LeaveDashboardScreen extends ConsumerStatefulWidget {
  const LeaveDashboardScreen({super.key});

  @override
  ConsumerState<LeaveDashboardScreen> createState() =>
      _LeaveDashboardScreenState();
}

class _LeaveDashboardScreenState extends ConsumerState<LeaveDashboardScreen> {
  static final DateFormat _monthDayFormat = DateFormat('MMM d');
  static final DateFormat _fullDateFormat = DateFormat('MMM d, y');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: 'NGN ',
    decimalDigits: 0,
  );

  _LeaveWorkspaceTab? _selectedTab;

  int get _currentYear => DateTime.now().year;

  List<_LeaveTabConfig> _tabsFor(AppUser user) {
    final canApprove = PermissionService.hasPermission(
      user,
      Permission.approveLeave,
    );
    final canManagePolicies = PermissionService.hasPermission(
      user,
      Permission.manageLeaveTypes,
    );
    final hasEmployeeProfile = user.employeeId?.trim().isNotEmpty ?? false;
    final isEmployeeSelfService =
        user.role == UserRole.employee && hasEmployeeProfile;

    final tabs = <_LeaveTabConfig>[
      const _LeaveTabConfig(
        id: _LeaveWorkspaceTab.overview,
        label: 'Overview',
        icon: Icons.auto_graph_outlined,
        subtitle: 'Snapshot',
      ),
    ];

    if (isEmployeeSelfService) {
      tabs.addAll(const [
        _LeaveTabConfig(
          id: _LeaveWorkspaceTab.request,
          label: 'Request',
          icon: Icons.note_add_outlined,
          subtitle: 'Apply',
        ),
        _LeaveTabConfig(
          id: _LeaveWorkspaceTab.timeline,
          label: 'My Leave',
          icon: Icons.timeline_outlined,
          subtitle: 'History',
        ),
      ]);
    } else if (hasEmployeeProfile && !canApprove) {
      tabs.add(
        const _LeaveTabConfig(
          id: _LeaveWorkspaceTab.timeline,
          label: 'My Leave',
          icon: Icons.timeline_outlined,
          subtitle: 'History',
        ),
      );
    }

    if (canApprove) {
      tabs.addAll(const [
        _LeaveTabConfig(
          id: _LeaveWorkspaceTab.approvals,
          label: 'Approvals',
          icon: Icons.fact_check_outlined,
          subtitle: 'Queue',
        ),
        _LeaveTabConfig(
          id: _LeaveWorkspaceTab.balances,
          label: 'Balances',
          icon: Icons.stacked_bar_chart_outlined,
          subtitle: 'Allocations',
        ),
        _LeaveTabConfig(
          id: _LeaveWorkspaceTab.encashment,
          label: 'Encashment',
          icon: Icons.currency_exchange_outlined,
          subtitle: 'Cash-out',
        ),
      ]);
    }

    tabs.add(
      const _LeaveTabConfig(
        id: _LeaveWorkspaceTab.holidays,
        label: 'Calendar',
        icon: Icons.event_outlined,
        subtitle: 'Holidays',
      ),
    );

    if (canManagePolicies) {
      tabs.add(
        const _LeaveTabConfig(
          id: _LeaveWorkspaceTab.types,
          label: 'Policies',
          icon: Icons.rule_folder_outlined,
          subtitle: 'Leave types',
        ),
      );
    }

    return tabs;
  }

  Future<void> _refreshTab(_LeaveWorkspaceTab tab) async {
    switch (tab) {
      case _LeaveWorkspaceTab.overview:
        ref.invalidate(leaveDashboardProvider);
        ref.invalidate(
          publicHolidaysProvider(PublicHolidaysQuery(year: _currentYear)),
        );
        ref.invalidate(
          leaveBalancesProvider(LeaveBalancesQuery(year: _currentYear)),
        );
        ref.invalidate(leaveEncashmentProvider);
        ref.invalidate(leaveTypesProvider);
        ref.invalidate(pendingLeaveRequestsProvider);
        break;
      case _LeaveWorkspaceTab.request:
        ref.invalidate(applyLeaveDataProvider);
        break;
      case _LeaveWorkspaceTab.timeline:
        ref.invalidate(myLeavesProvider);
        break;
      case _LeaveWorkspaceTab.approvals:
        ref.invalidate(pendingLeaveRequestsProvider);
        break;
      case _LeaveWorkspaceTab.balances:
        ref.invalidate(
          leaveBalancesProvider(LeaveBalancesQuery(year: _currentYear)),
        );
        break;
      case _LeaveWorkspaceTab.encashment:
        ref.invalidate(leaveEncashmentProvider);
        break;
      case _LeaveWorkspaceTab.holidays:
        ref.invalidate(
          publicHolidaysProvider(PublicHolidaysQuery(year: _currentYear)),
        );
        break;
      case _LeaveWorkspaceTab.types:
        ref.invalidate(leaveTypesProvider);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return userAsync.when(
      loading: () => const AppScaffold(
        title: 'Leave Studio',
        body: ModernLoadingState(message: 'Loading leave workspace...'),
      ),
      error: (error, _) => AppScaffold(
        title: 'Leave Studio',
        body: ModernErrorState(
          message: 'Unable to load leave workspace',
          subtitle: '$error',
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const AppScaffold(
            title: 'Leave Studio',
            body: ModernErrorState(
              message: 'User profile not found',
              subtitle: 'Please sign in again to continue.',
            ),
          );
        }

        final tabs = _tabsFor(user);
        final activeTab = tabs.any((tab) => tab.id == _selectedTab)
            ? _selectedTab!
            : tabs.first.id;

        return AppScaffold(
          title: 'Leave Studio',
          showSearch: true,
          topBar: AppBar(
            title: const Text('Leave Studio'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => _refreshTab(activeTab),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 920;
              return ListView(
                padding: EdgeInsets.all(compact ? 12 : 20),
                children: [
                  _buildHero(user, activeTab, compact: compact),
                  const SizedBox(height: 18),
                  _buildTabStrip(tabs, activeTab, compact: compact),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    child: KeyedSubtree(
                      key: ValueKey(activeTab),
                      child: _buildTabContent(
                        context,
                        user,
                        activeTab,
                        compact: compact,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHero(
    AppUser user,
    _LeaveWorkspaceTab activeTab, {
    required bool compact,
  }) {
    final canApprove = PermissionService.hasPermission(
      user,
      Permission.approveLeave,
    );
    final canManagePolicies = PermissionService.hasPermission(
      user,
      Permission.manageLeaveTypes,
    );

    final title = switch (user.role) {
      UserRole.employee => 'Leave Dashboard',
      UserRole.hr => 'Direct the leave desk without menu clutter.',
      UserRole.admin =>
        'See approvals, policy, and balance control at a glance.',
      UserRole.accountant =>
        'Track leave posture from a cleaner, role-aware command view.',
    };

    final subtitle = switch (activeTab) {
      _LeaveWorkspaceTab.overview =>
        'This workspace brings leave activity, policy, and planning into one tabbed surface so each role sees the right layer first.',
      _LeaveWorkspaceTab.request =>
        'Prepare the right request, check your balance, and move into the full form only when you are ready.',
      _LeaveWorkspaceTab.timeline =>
        'Review your leave story across pending, approved, rejected, and upcoming time away.',
      _LeaveWorkspaceTab.approvals =>
        'Focus on the requests waiting on review and move them forward without digging through nested menus.',
      _LeaveWorkspaceTab.balances =>
        'Inspect allocation patterns and spot where leave capacity is getting tight.',
      _LeaveWorkspaceTab.encashment =>
        'Keep encashment decisions visible without letting them disappear inside the main leave flow.',
      _LeaveWorkspaceTab.holidays =>
        'Anchor leave planning to the holiday calendar so decisions stay grounded in real dates.',
      _LeaveWorkspaceTab.types =>
        'Treat leave policy as a product surface, not a buried setup panel.',
    };

    final accent = canManagePolicies
        ? const Color(0xFFE6B85C)
        : canApprove
        ? const Color(0xFFF28F3B)
        : const Color(0xFF7BD389);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF14342B), Color(0xFF245C4A), Color(0xFF3D7A64)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -12,
            right: -18,
            child: _glowOrb(140, accent.withValues(alpha: 0.18)),
          ),
          Positioned(
            bottom: -54,
            left: -10,
            child: _glowOrb(190, Colors.white.withValues(alpha: 0.06)),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 18 : 24),
            child: Column(
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
                    '${user.getRoleName().toUpperCase()} LEAVE WORKSPACE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 28 : 34,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: compact ? 13 : 15,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _heroBadge(
                      icon: Icons.view_compact_outlined,
                      label: 'Tabs instead of nested leave menus',
                    ),
                    _heroBadge(
                      icon: Icons.lock_outline,
                      label: 'Role-aware surfaces',
                    ),
                    _heroBadge(
                      icon: Icons.route_outlined,
                      label: 'Fast path to deeper leave tools',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip(
    List<_LeaveTabConfig> tabs,
    _LeaveWorkspaceTab activeTab, {
    required bool compact,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1E8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE4DDD0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((tab) {
            final selected = tab.id == activeTab;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _selectedTab = tab.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 12 : 16,
                    vertical: compact ? 10 : 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: selected
                        ? const Color(0xFF1F5D4A)
                        : Colors.transparent,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        tab.icon,
                        size: 18,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tab.label,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            tab.subtitle,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.76)
                                  : AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    AppUser user,
    _LeaveWorkspaceTab tab, {
    required bool compact,
  }) {
    return switch (tab) {
      _LeaveWorkspaceTab.overview => _buildOverviewTab(
        context,
        user,
        compact: compact,
      ),
      _LeaveWorkspaceTab.request => _buildRequestTab(context, compact: compact),
      _LeaveWorkspaceTab.timeline => _buildTimelineTab(
        context,
        compact: compact,
      ),
      _LeaveWorkspaceTab.approvals => _buildApprovalsTab(
        context,
        compact: compact,
      ),
      _LeaveWorkspaceTab.balances => _buildBalancesTab(
        context,
        compact: compact,
      ),
      _LeaveWorkspaceTab.encashment => _buildEncashmentTab(
        context,
        compact: compact,
      ),
      _LeaveWorkspaceTab.holidays => _buildHolidaysTab(
        context,
        user,
        compact: compact,
      ),
      _LeaveWorkspaceTab.types => _buildTypesTab(context, compact: compact),
    };
  }

  Widget _buildOverviewTab(
    BuildContext context,
    AppUser user, {
    required bool compact,
  }) {
    final canApprove = PermissionService.hasPermission(
      user,
      Permission.approveLeave,
    );
    return canApprove
        ? _buildOperationsOverview(context, user, compact: compact)
        : _buildPersonalOverview(context, user, compact: compact);
  }

  Widget _buildPersonalOverview(
    BuildContext context,
    AppUser user, {
    required bool compact,
  }) {
    final dashboardAsync = ref.watch(leaveDashboardProvider);
    final holidaysAsync = ref.watch(
      publicHolidaysProvider(PublicHolidaysQuery(year: _currentYear)),
    );

    return dashboardAsync.when(
      loading: () =>
          const ModernLoadingState(message: 'Loading leave overview...'),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load leave overview',
        subtitle: '$error',
        onRetry: () => ref.invalidate(leaveDashboardProvider),
      ),
      data: (dashboard) {
        final upcomingHoliday = holidaysAsync.maybeWhen(
          data: (data) {
            for (final holiday in data.holidays) {
              if (!holiday.date.isBefore(DateTime.now())) {
                return holiday;
              }
            }
            return null;
          },
          orElse: () => null,
        );
        final totalBalance = dashboard.balances.fold<double>(
          0,
          (sum, item) => sum + item.balance,
        );
        final pendingCount = dashboard.recentRequests
            .where((item) => item.status == LeaveRequestStatus.pending)
            .length;
        final upcomingTrips = dashboard.recentRequests
            .where((item) => item.isFuture || item.isOngoing)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernMetricsGrid(
              metrics: [
                ModernMetricCard(
                  title: 'Available Days',
                  value: totalBalance.toStringAsFixed(1),
                  trend: '${dashboard.balances.length} active balances',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.beach_access_outlined,
                  color: AppColors.success,
                ),
                ModernMetricCard(
                  title: 'Pending Requests',
                  value: pendingCount.toString(),
                  trend: pendingCount == 0 ? 'Clear queue' : 'Awaiting review',
                  trendDirection: pendingCount == 0
                      ? TrendDirection.neutral
                      : TrendDirection.down,
                  icon: Icons.schedule_outlined,
                  color: AppColors.warning,
                ),
                ModernMetricCard(
                  title: 'Upcoming Time Off',
                  value: upcomingTrips.toString(),
                  trend: 'Future and ongoing leave',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.flight_takeoff_outlined,
                  color: AppColors.primary,
                ),
                ModernMetricCard(
                  title: 'Next Holiday',
                  value: upcomingHoliday == null
                      ? 'None'
                      : _monthDayFormat.format(upcomingHoliday.date),
                  trend: upcomingHoliday?.name ?? 'No upcoming holiday loaded',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.celebration_outlined,
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _featurePanel(
              title: 'Leave Runway',
              subtitle:
                  'Move from understanding your balance to filing a request without bouncing across the menu.',
              accent: const Color(0xFF245C4A),
              compact: compact,
              leading: _badgeIcon(Icons.alt_route_outlined),
              actions: [
                _primaryAction(
                  label: 'Open Apply Leave',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.leaveApply),
                ),
                _secondaryAction(
                  label: 'See My Leave',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.leaveMy),
                ),
              ],
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: dashboard.balances.take(4).map((balance) {
                  return _miniBalanceChip(
                    balance.leaveTypeName,
                    '${balance.balance.toStringAsFixed(1)} days',
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: compact ? double.infinity : 420,
                  child: _sectionCard(
                    title: 'Balance Preview',
                    subtitle: 'Where you still have room to plan time away.',
                    child: dashboard.balances.isEmpty
                        ? const ModernEmptyState(
                            title: 'No leave balances found',
                            subtitle:
                                'Balances will appear here once leave allocations are available.',
                          )
                        : Column(
                            children: dashboard.balances.take(4).map((balance) {
                              return _balancePreviewCard(balance);
                            }).toList(),
                          ),
                  ),
                ),
                SizedBox(
                  width: compact ? double.infinity : 420,
                  child: _sectionCard(
                    title: 'Recent Requests',
                    subtitle:
                        'A quick pulse on the requests already in motion.',
                    child: dashboard.recentRequests.isEmpty
                        ? const ModernEmptyState(
                            title: 'No leave requests yet',
                            subtitle:
                                'Your recent leave applications will show up here.',
                          )
                        : Column(
                            children: dashboard.recentRequests.take(4).map((
                              request,
                            ) {
                              return _requestPreviewCard(request);
                            }).toList(),
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationsOverview(
    BuildContext context,
    AppUser user, {
    required bool compact,
  }) {
    final approvalsAsync = ref.watch(pendingLeaveRequestsProvider);
    final balancesAsync = ref.watch(
      leaveBalancesProvider(LeaveBalancesQuery(year: _currentYear)),
    );
    final encashmentAsync = ref.watch(leaveEncashmentProvider);
    final holidaysAsync = ref.watch(
      publicHolidaysProvider(PublicHolidaysQuery(year: _currentYear)),
    );
    final typesAsync = ref.watch(leaveTypesProvider);

    return approvalsAsync.when(
      loading: () =>
          const ModernLoadingState(message: 'Loading leave operations...'),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load leave operations',
        subtitle: '$error',
        onRetry: () => ref.invalidate(pendingLeaveRequestsProvider),
      ),
      data: (approvals) {
        final balanceCount = balancesAsync.asData?.value.balances.length ?? 0;
        final encashmentQueue =
            encashmentAsync.asData?.value.pendingRequests.length ?? 0;
        final policyCount =
            typesAsync.asData?.value.leaveTypes
                .where((item) => item.isActive)
                .length ??
            0;
        final nextHolidayName = holidaysAsync.asData?.value.holidays
            .where((holiday) => !holiday.date.isBefore(DateTime.now()))
            .map((holiday) => holiday.name)
            .take(1)
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernMetricsGrid(
              metrics: [
                ModernMetricCard(
                  title: 'Pending Approvals',
                  value: approvals.length.toString(),
                  trend: approvals.isEmpty
                      ? 'No requests waiting'
                      : 'Needs attention',
                  trendDirection: approvals.isEmpty
                      ? TrendDirection.neutral
                      : TrendDirection.down,
                  icon: Icons.fact_check_outlined,
                  color: AppColors.warning,
                ),
                ModernMetricCard(
                  title: 'Balance Records',
                  value: balanceCount.toString(),
                  trend: 'Tracked for $_currentYear',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.stacked_bar_chart_outlined,
                  color: AppColors.primary,
                ),
                ModernMetricCard(
                  title: 'Encashment Queue',
                  value: encashmentQueue.toString(),
                  trend: encashmentQueue == 0 ? 'Stable' : 'Cash-out requests',
                  trendDirection: encashmentQueue == 0
                      ? TrendDirection.neutral
                      : TrendDirection.down,
                  icon: Icons.currency_exchange_outlined,
                  color: AppColors.info,
                ),
                ModernMetricCard(
                  title: 'Policy Surface',
                  value: policyCount.toString(),
                  trend: nextHolidayName?.isNotEmpty == true
                      ? 'Next holiday: ${nextHolidayName!.first}'
                      : 'Holiday calendar synced',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.rule_folder_outlined,
                  color: const Color(0xFFE6B85C),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _featurePanel(
              title: 'Operations Lane',
              subtitle:
                  'Run approvals, balances, encashment, and policy from one place while the deeper tools stay a click away.',
              accent: const Color(0xFFF28F3B),
              compact: compact,
              leading: _badgeIcon(Icons.dashboard_customize_outlined),
              actions: [
                _primaryAction(
                  label: 'Open Approvals',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.leaveApprovals),
                ),
                _secondaryAction(
                  label: 'Manage Policies',
                  onTap:
                      PermissionService.hasPermission(
                        user,
                        Permission.manageLeaveTypes,
                      )
                      ? () => Navigator.pushNamed(context, AppRoutes.leaveTypes)
                      : null,
                ),
              ],
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _utilityCard(
                    title: 'Approvals',
                    subtitle: '${approvals.length} requests in queue',
                    icon: Icons.fact_check_outlined,
                    color: AppColors.warning,
                    onTap: () => setState(
                      () => _selectedTab = _LeaveWorkspaceTab.approvals,
                    ),
                  ),
                  _utilityCard(
                    title: 'Balances',
                    subtitle: '$balanceCount balance records',
                    icon: Icons.stacked_bar_chart_outlined,
                    color: AppColors.primary,
                    onTap: () => setState(
                      () => _selectedTab = _LeaveWorkspaceTab.balances,
                    ),
                  ),
                  _utilityCard(
                    title: 'Encashment',
                    subtitle: '$encashmentQueue requests pending',
                    icon: Icons.currency_exchange_outlined,
                    color: AppColors.info,
                    onTap: () => setState(
                      () => _selectedTab = _LeaveWorkspaceTab.encashment,
                    ),
                  ),
                  if (PermissionService.hasPermission(
                    user,
                    Permission.manageLeaveTypes,
                  ))
                    _utilityCard(
                      title: 'Policies',
                      subtitle: '$policyCount active leave types',
                      icon: Icons.rule_folder_outlined,
                      color: const Color(0xFFE6B85C),
                      onTap: () => setState(
                        () => _selectedTab = _LeaveWorkspaceTab.types,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: compact ? double.infinity : 420,
                  child: _sectionCard(
                    title: 'Approval Queue Preview',
                    subtitle:
                        'Who is waiting, what type, and when the request landed.',
                    child: approvals.isEmpty
                        ? const ModernEmptyState(
                            title: 'Approval queue is clear',
                            subtitle:
                                'Pending leave requests will appear here when employees submit them.',
                          )
                        : Column(
                            children: approvals.take(5).map((request) {
                              return _requestPreviewCard(
                                request,
                                showEmployee: true,
                              );
                            }).toList(),
                          ),
                  ),
                ),
                SizedBox(
                  width: compact ? double.infinity : 420,
                  child: _sectionCard(
                    title: 'Holiday Signal',
                    subtitle:
                        'Keep the next holidays visible while you approve and plan leave.',
                    child: holidaysAsync.when(
                      loading: () => const ModernLoadingState(
                        message: 'Loading holiday calendar...',
                      ),
                      error: (error, _) => ModernErrorState(
                        message: 'Unable to load holidays',
                        subtitle: '$error',
                        onRetry: () => ref.invalidate(
                          publicHolidaysProvider(
                            PublicHolidaysQuery(year: _currentYear),
                          ),
                        ),
                      ),
                      data: (holidayData) {
                        final upcoming = holidayData.holidays
                            .where(
                              (holiday) =>
                                  !holiday.date.isBefore(DateTime.now()),
                            )
                            .take(4)
                            .toList();
                        if (upcoming.isEmpty) {
                          return const ModernEmptyState(
                            title: 'No upcoming holidays',
                            subtitle: 'Add or review holidays for this year.',
                          );
                        }
                        return Column(
                          children: upcoming.map(_holidayPreviewCard).toList(),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildRequestTab(BuildContext context, {required bool compact}) {
    final applyDataAsync = ref.watch(applyLeaveDataProvider);

    return applyDataAsync.when(
      loading: () => const ModernLoadingState(
        message: 'Preparing leave request workspace...',
      ),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load leave request data',
        subtitle: '$error',
        onRetry: () => ref.invalidate(applyLeaveDataProvider),
      ),
      data: (data) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _featurePanel(
              title: 'Request Builder',
              subtitle:
                  'Use this prep space to understand available leave types and balances before opening the full request form.',
              accent: const Color(0xFF4B6CB7),
              compact: compact,
              leading: _badgeIcon(Icons.edit_note_outlined),
              actions: [
                _primaryAction(
                  label: 'Open Full Leave Form',
                  onTap: data.employeeId == null
                      ? null
                      : () =>
                            Navigator.pushNamed(context, AppRoutes.leaveApply),
                ),
                _secondaryAction(
                  label: 'See My Leave',
                  onTap: data.employeeId == null
                      ? null
                      : () => Navigator.pushNamed(context, AppRoutes.leaveMy),
                ),
              ],
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: data.balances.take(4).map((balance) {
                  return _miniBalanceChip(
                    balance.leaveTypeName,
                    '${balance.availableBalance.toStringAsFixed(1)} available',
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Leave Type Spotlights',
              subtitle:
                  'Each card gives a quick sense of notice, entitlement, and supporting rules.',
              child: data.leaveTypes.isEmpty
                  ? const ModernEmptyState(
                      title: 'No leave types configured',
                      subtitle:
                          'Leave types need to be set up before requests can be submitted.',
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: data.leaveTypes.take(6).map((leaveType) {
                        return SizedBox(
                          width: compact ? double.infinity : 280,
                          child: _leaveTypeSpotlight(leaveType),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineTab(BuildContext context, {required bool compact}) {
    final myLeavesAsync = ref.watch(myLeavesProvider);

    return myLeavesAsync.when(
      loading: () =>
          const ModernLoadingState(message: 'Loading leave timeline...'),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load leave timeline',
        subtitle: '$error',
        onRetry: () => ref.invalidate(myLeavesProvider),
      ),
      data: (data) {
        final requests = data.requests;
        final pending = requests.where((item) => item.isPending).length;
        final approved = requests.where((item) => item.isApproved).length;
        final rejected = requests.where((item) => item.isRejected).length;
        final upcoming = requests
            .where((item) => item.isFuture || item.isOngoing)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernMetricsGrid(
              metrics: [
                ModernMetricCard(
                  title: 'Total Requests',
                  value: requests.length.toString(),
                  trend: 'Personal leave history',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.layers_outlined,
                  color: AppColors.primary,
                ),
                ModernMetricCard(
                  title: 'Pending',
                  value: pending.toString(),
                  trend: pending == 0 ? 'Nothing waiting' : 'Awaiting review',
                  trendDirection: pending == 0
                      ? TrendDirection.neutral
                      : TrendDirection.down,
                  icon: Icons.schedule_outlined,
                  color: AppColors.warning,
                ),
                ModernMetricCard(
                  title: 'Approved',
                  value: approved.toString(),
                  trend: 'Completed approvals',
                  trendDirection: TrendDirection.up,
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                ModernMetricCard(
                  title: 'Upcoming',
                  value: upcoming.toString(),
                  trend: '$rejected rejected',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.event_available_outlined,
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Timeline Preview',
              subtitle:
                  'The latest requests across statuses, with the full screen still available for deeper review.',
              action: _secondaryAction(
                label: 'Open Full History',
                onTap: () => Navigator.pushNamed(context, AppRoutes.leaveMy),
              ),
              child: requests.isEmpty
                  ? const ModernEmptyState(
                      title: 'No leave requests found',
                      subtitle:
                          'Once leave applications are submitted, they will show up here.',
                    )
                  : Column(
                      children: requests.take(8).map((request) {
                        return _requestPreviewCard(request);
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildApprovalsTab(BuildContext context, {required bool compact}) {
    final approvalsAsync = ref.watch(pendingLeaveRequestsProvider);

    return approvalsAsync.when(
      loading: () =>
          const ModernLoadingState(message: 'Loading approval queue...'),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load approval queue',
        subtitle: '$error',
        onRetry: () => ref.invalidate(pendingLeaveRequestsProvider),
      ),
      data: (requests) {
        final urgent = requests
            .where(
              (item) => item.startDate.isBefore(
                DateTime.now().add(const Duration(days: 7)),
              ),
            )
            .length;
        final totalDays = requests.fold<double>(
          0,
          (sum, item) => sum + item.numberOfDays,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernMetricsGrid(
              metrics: [
                ModernMetricCard(
                  title: 'Waiting Review',
                  value: requests.length.toString(),
                  trend: 'Pending leave decisions',
                  trendDirection: requests.isEmpty
                      ? TrendDirection.neutral
                      : TrendDirection.down,
                  icon: Icons.fact_check_outlined,
                  color: AppColors.warning,
                ),
                ModernMetricCard(
                  title: 'Urgent Window',
                  value: urgent.toString(),
                  trend: 'Starting within 7 days',
                  trendDirection: urgent == 0
                      ? TrendDirection.neutral
                      : TrendDirection.down,
                  icon: Icons.timer_outlined,
                  color: AppColors.error,
                ),
                ModernMetricCard(
                  title: 'Leave Days',
                  value: totalDays.toStringAsFixed(1),
                  trend: 'Across current queue',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.calendar_view_week_outlined,
                  color: AppColors.primary,
                ),
                ModernMetricCard(
                  title: 'Action Surface',
                  value: requests.isEmpty ? 'Clear' : 'Live',
                  trend: 'Full review flow available',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.open_in_new_outlined,
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Pending Requests',
              subtitle:
                  'This preview keeps the queue visible here while the full approval tools remain in the dedicated screen.',
              action: _primaryAction(
                label: 'Open Approval Screen',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.leaveApprovals),
              ),
              child: requests.isEmpty
                  ? const ModernEmptyState(
                      title: 'No pending leave approvals',
                      subtitle: 'The approval queue is currently clear.',
                    )
                  : Column(
                      children: requests.take(10).map((request) {
                        return _requestPreviewCard(request, showEmployee: true);
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBalancesTab(BuildContext context, {required bool compact}) {
    final balancesAsync = ref.watch(
      leaveBalancesProvider(LeaveBalancesQuery(year: _currentYear)),
    );

    return balancesAsync.when(
      loading: () =>
          const ModernLoadingState(message: 'Loading leave balances...'),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load leave balances',
        subtitle: '$error',
        onRetry: () => ref.invalidate(
          leaveBalancesProvider(LeaveBalancesQuery(year: _currentYear)),
        ),
      ),
      data: (data) {
        final balances = data.balances;
        final lowBalanceCount = balances
            .where((item) => item.availableBalance <= 2)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernMetricsGrid(
              metrics: [
                ModernMetricCard(
                  title: 'Balance Records',
                  value: balances.length.toString(),
                  trend: 'For $_currentYear',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.stacked_bar_chart_outlined,
                  color: AppColors.primary,
                ),
                ModernMetricCard(
                  title: 'Low Balance Signals',
                  value: lowBalanceCount.toString(),
                  trend: '2 days or less available',
                  trendDirection: lowBalanceCount == 0
                      ? TrendDirection.neutral
                      : TrendDirection.down,
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.warning,
                ),
                ModernMetricCard(
                  title: 'Allocated Days',
                  value: balances
                      .fold<double>(0, (sum, item) => sum + item.allocated)
                      .toStringAsFixed(1),
                  trend: 'Across tracked balances',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.layers_clear_outlined,
                  color: AppColors.success,
                ),
                ModernMetricCard(
                  title: 'Pending Days',
                  value: balances
                      .fold<double>(0, (sum, item) => sum + item.pending)
                      .toStringAsFixed(1),
                  trend: 'Waiting to resolve',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.pending_actions_outlined,
                  color: AppColors.info,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Balance Field',
              subtitle:
                  'A quick operational pass through leave allocations, usage, and what remains.',
              action: _primaryAction(
                label: 'Open Balance Screen',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.leaveBalances),
              ),
              child: balances.isEmpty
                  ? const ModernEmptyState(
                      title: 'No leave balances found',
                      subtitle:
                          'Balance records will appear here when allocations are available.',
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: balances.take(8).map((balance) {
                        return SizedBox(
                          width: compact ? double.infinity : 320,
                          child: _balancePreviewCard(balance, dense: false),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEncashmentTab(BuildContext context, {required bool compact}) {
    final encashmentAsync = ref.watch(leaveEncashmentProvider);

    return encashmentAsync.when(
      loading: () =>
          const ModernLoadingState(message: 'Loading encashment desk...'),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load leave encashment',
        subtitle: '$error',
        onRetry: () => ref.invalidate(leaveEncashmentProvider),
      ),
      data: (data) {
        final pendingRequests = data.pendingRequests;
        final processedRequests = data.processedRequests;
        final pendingValue = pendingRequests.fold<double>(
          0,
          (sum, item) => sum + item.encashmentAmount,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernMetricsGrid(
              metrics: [
                ModernMetricCard(
                  title: 'Pending Cash-out',
                  value: pendingRequests.length.toString(),
                  trend: 'Requests awaiting action',
                  trendDirection: pendingRequests.isEmpty
                      ? TrendDirection.neutral
                      : TrendDirection.down,
                  icon: Icons.currency_exchange_outlined,
                  color: AppColors.warning,
                ),
                ModernMetricCard(
                  title: 'Pending Value',
                  value: _currencyFormat.format(pendingValue),
                  trend: 'Current encashment exposure',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.account_balance_wallet_outlined,
                  color: AppColors.info,
                ),
                ModernMetricCard(
                  title: 'Processed Requests',
                  value: processedRequests.length.toString(),
                  trend: 'Historical handled requests',
                  trendDirection: TrendDirection.up,
                  icon: Icons.task_alt_outlined,
                  color: AppColors.success,
                ),
                ModernMetricCard(
                  title: 'Request Days',
                  value: pendingRequests
                      .fold<double>(0, (sum, item) => sum + item.daysToEncash)
                      .toStringAsFixed(1),
                  trend: 'Pending days to cash out',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.calendar_today_outlined,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Pending Encashment Preview',
              subtitle:
                  'See the queue and value at risk before stepping into the full management screen.',
              action: _primaryAction(
                label: 'Open Encashment Screen',
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.leaveEncashment),
              ),
              child: pendingRequests.isEmpty
                  ? const ModernEmptyState(
                      title: 'No pending encashment requests',
                      subtitle:
                          'Encashment submissions will appear here when employees file them.',
                    )
                  : Column(
                      children: pendingRequests.take(8).map((request) {
                        return _encashmentPreviewCard(request);
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHolidaysTab(
    BuildContext context,
    AppUser user, {
    required bool compact,
  }) {
    final holidaysAsync = ref.watch(
      publicHolidaysProvider(PublicHolidaysQuery(year: _currentYear)),
    );
    final canManage = PermissionService.hasPermission(
      user,
      Permission.manageLeaveTypes,
    );

    return holidaysAsync.when(
      loading: () =>
          const ModernLoadingState(message: 'Loading holiday calendar...'),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load holiday calendar',
        subtitle: '$error',
        onRetry: () => ref.invalidate(
          publicHolidaysProvider(PublicHolidaysQuery(year: _currentYear)),
        ),
      ),
      data: (data) {
        final upcoming = data.holidays
            .where((holiday) => !holiday.date.isBefore(DateTime.now()))
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _featurePanel(
              title: 'Holiday Compass',
              subtitle:
                  'Keep public holidays close to leave planning so request timing stays realistic.',
              accent: const Color(0xFF8E6C88),
              compact: compact,
              leading: _badgeIcon(Icons.event_outlined),
              actions: [
                _primaryAction(
                  label: 'Open Holiday Screen',
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.publicHolidays),
                ),
                _secondaryAction(
                  label: canManage ? 'Manage Holidays' : 'Planning View',
                  onTap: canManage
                      ? () => Navigator.pushNamed(
                          context,
                          AppRoutes.publicHolidays,
                        )
                      : null,
                ),
              ],
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _miniBalanceChip(
                    'Upcoming',
                    '${upcoming.length} left in $_currentYear',
                  ),
                  _miniBalanceChip(
                    'Optional',
                    '${data.holidays.where((item) => item.isOptional).length} days',
                  ),
                  _miniBalanceChip(
                    'Active',
                    '${data.holidays.where((item) => item.isActive).length} entries',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Calendar Preview',
              subtitle:
                  'A simple yearly glance at the holidays shaping leave plans.',
              child: data.holidays.isEmpty
                  ? const ModernEmptyState(
                      title: 'No public holidays found',
                      subtitle:
                          'Holidays will appear here once the yearly calendar is configured.',
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: data.holidays.take(10).map((holiday) {
                        return SizedBox(
                          width: compact ? double.infinity : 280,
                          child: _holidayPreviewCard(holiday),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTypesTab(BuildContext context, {required bool compact}) {
    final leaveTypesAsync = ref.watch(leaveTypesProvider);

    return leaveTypesAsync.when(
      loading: () =>
          const ModernLoadingState(message: 'Loading leave policies...'),
      error: (error, _) => ModernErrorState(
        message: 'Unable to load leave policies',
        subtitle: '$error',
        onRetry: () => ref.invalidate(leaveTypesProvider),
      ),
      data: (data) {
        final activeTypes = data.leaveTypes
            .where((item) => item.isActive)
            .toList();
        final paidTypes = activeTypes.where((item) => item.isPaid).length;
        final encashableTypes = activeTypes
            .where((item) => item.encashable)
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ModernMetricsGrid(
              metrics: [
                ModernMetricCard(
                  title: 'Active Types',
                  value: activeTypes.length.toString(),
                  trend: 'Policy set in use',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.rule_folder_outlined,
                  color: const Color(0xFFE6B85C),
                ),
                ModernMetricCard(
                  title: 'Paid Types',
                  value: paidTypes.toString(),
                  trend: 'Salary-protected leave',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.payments_outlined,
                  color: AppColors.success,
                ),
                ModernMetricCard(
                  title: 'Encashable',
                  value: encashableTypes.toString(),
                  trend: 'Can convert unused days',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.currency_exchange_outlined,
                  color: AppColors.info,
                ),
                ModernMetricCard(
                  title: 'Documentation Rules',
                  value: activeTypes
                      .where((item) => item.requiresDocuments)
                      .length
                      .toString(),
                  trend: 'Need supporting evidence',
                  trendDirection: TrendDirection.neutral,
                  icon: Icons.attachment_outlined,
                  color: AppColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _sectionCard(
              title: 'Policy Studio',
              subtitle:
                  'A cleaner preview of leave type rules, with the full editor still available from the dedicated screen.',
              action: _primaryAction(
                label: 'Open Leave Types',
                onTap: () => Navigator.pushNamed(context, AppRoutes.leaveTypes),
              ),
              child: activeTypes.isEmpty
                  ? const ModernEmptyState(
                      title: 'No active leave types found',
                      subtitle:
                          'Active leave policies will appear here once they are configured.',
                    )
                  : Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: activeTypes.take(8).map((leaveType) {
                        return SizedBox(
                          width: compact ? double.infinity : 300,
                          child: _leaveTypeSpotlight(leaveType),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E1D5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
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
              if (action != null) ...[const SizedBox(width: 12), action],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _featurePanel({
    required String title,
    required String subtitle,
    required Color accent,
    required bool compact,
    required Widget leading,
    required Widget child,
    required List<Widget> actions,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            const Color(0xFFF8F5EF),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              leading,
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 520 : 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _badgeIcon(IconData icon) {
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: const Color(0xFF245C4A)),
    );
  }

  Widget _primaryAction({required String label, required VoidCallback? onTap}) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1F5D4A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );
  }

  Widget _secondaryAction({
    required String label,
    required VoidCallback? onTap,
  }) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF1F5D4A),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        side: const BorderSide(color: Color(0xFFB7CABB)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Text(label),
    );
  }

  Widget _miniBalanceChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DED2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _utilityCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balancePreviewCard(LeaveBalance balance, {bool dense = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(dense ? 14 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6EF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E0D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  balance.leaveTypeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _statPill(
                '${balance.availableBalance.toStringAsFixed(1)} left',
                color: balance.availableBalance <= 2
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _miniBalanceChip(
                'Allocated',
                balance.allocated.toStringAsFixed(1),
              ),
              _miniBalanceChip('Used', balance.used.toStringAsFixed(1)),
              _miniBalanceChip('Pending', balance.pending.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _requestPreviewCard(
    LeaveRequest request, {
    bool showEmployee = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F7F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E1D5)),
      ),
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
                      request.leaveTypeName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      showEmployee ? request.employeeName : request.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              _statusChip(request.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statPill(
                '${_monthDayFormat.format(request.startDate)} - ${_monthDayFormat.format(request.endDate)}',
                color: AppColors.primary,
              ),
              _statPill(
                '${request.numberOfDays.toStringAsFixed(1)} days',
                color: AppColors.info,
              ),
              _statPill(
                'Requested ${_monthDayFormat.format(request.requestedAt)}',
                color: const Color(0xFF7A6F63),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _holidayPreviewCard(PublicHoliday holiday) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F3F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6DCE7)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _holidayIcon(holiday.type),
              color: const Color(0xFF8E6C88),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holiday.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _fullDateFormat.format(holiday.date),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          _statPill(
            holiday.type.name.toUpperCase(),
            color: const Color(0xFF8E6C88),
          ),
        ],
      ),
    );
  }

  Widget _leaveTypeSpotlight(LeaveType leaveType) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE7E0D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F1E4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _leaveTypeIcon(leaveType.category),
                  color: const Color(0xFF9A6B11),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leaveType.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      leaveType.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statPill(
                '${leaveType.daysPerYear.toStringAsFixed(0)} days/year',
                color: AppColors.primary,
              ),
              _statPill(
                '${leaveType.minNoticeDays} day notice',
                color: AppColors.info,
              ),
              _statPill(
                leaveType.isPaid ? 'Paid' : 'Unpaid',
                color: leaveType.isPaid ? AppColors.success : AppColors.warning,
              ),
              if (leaveType.encashable)
                _statPill('Encashable', color: const Color(0xFF9A6B11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _encashmentPreviewCard(LeaveEncashment request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD8E8EB)),
      ),
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
                      request.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      request.leaveTypeName,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _statPill(
                _currencyFormat.format(request.encashmentAmount),
                color: AppColors.info,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _statPill(
                '${request.daysToEncash.toStringAsFixed(1)} days',
                color: AppColors.primary,
              ),
              _statPill(
                'Requested ${_monthDayFormat.format(request.requestedAt)}',
                color: const Color(0xFF7A6F63),
              ),
              _statPill(
                request.status.name.toUpperCase(),
                color: request.isProcessed
                    ? AppColors.success
                    : request.isApproved
                    ? AppColors.info
                    : AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statPill(String label, {required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusChip(LeaveRequestStatus status) {
    final (label, color) = switch (status) {
      LeaveRequestStatus.pending => ('PENDING', AppColors.warning),
      LeaveRequestStatus.approved => ('APPROVED', AppColors.success),
      LeaveRequestStatus.rejected => ('REJECTED', AppColors.error),
      LeaveRequestStatus.cancelled => ('CANCELLED', AppColors.textSecondary),
    };

    return _statPill(label, color: color);
  }

  Widget _heroBadge({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glowOrb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        height: size,
        width: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }

  IconData _holidayIcon(HolidayType type) {
    return switch (type) {
      HolidayType.national => Icons.flag_outlined,
      HolidayType.religious => Icons.auto_awesome_outlined,
      HolidayType.regional => Icons.location_on_outlined,
      HolidayType.company => Icons.apartment_outlined,
    };
  }

  IconData _leaveTypeIcon(LeaveCategory category) {
    return switch (category) {
      LeaveCategory.annual => Icons.beach_access_outlined,
      LeaveCategory.sick => Icons.local_hospital_outlined,
      LeaveCategory.casual => Icons.weekend_outlined,
      LeaveCategory.maternity => Icons.child_friendly_outlined,
      LeaveCategory.paternity => Icons.family_restroom_outlined,
      LeaveCategory.bereavement => Icons.favorite_border_outlined,
      LeaveCategory.study => Icons.school_outlined,
      LeaveCategory.unpaid => Icons.money_off_csred_outlined,
      LeaveCategory.compensatory => Icons.refresh_outlined,
    };
  }
}
