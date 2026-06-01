import 'dart:async';

import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/company_module_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';

class AppSidebar extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback? onToggle;

  const AppSidebar({super.key, required this.isCollapsed, this.onToggle});

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _effectiveCollapsed = false;
  final _userService = UserService();
  final _authService = AuthService();
  final _moduleService = CompanyModuleService();
  AppUser? _user;
  StreamSubscription<Map<String, bool>>? _moduleSubscription;
  Map<String, bool> _enabledModules = Map<String, bool>.from(
    CompanyModuleService.defaultModules,
  );
  final Map<String, bool> _expanded = {
    'employees': false,
    'attendance': false,
    'payroll': false,
    'deductions': false,
    'leave': false,
    'reports': false,
    'users': false,
  };

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _userService.getCurrentUserProfile();
    if (!mounted) return;
    if (user != null) {
      setState(() {
        _user = user;
      });
      _moduleSubscription?.cancel();
      _moduleSubscription = _moduleService
          .watchCompanyModules(user.companyId)
          .listen((modules) {
            if (!mounted) return;
            setState(() => _enabledModules = modules);
          });
      return;
    }
    setState(() => _user = user);
  }

  @override
  void dispose() {
    _moduleSubscription?.cancel();
    super.dispose();
  }

  bool _moduleEnabled(String key) {
    return CompanyModuleService.isModuleEnabledInMap(key, _enabledModules);
  }

  @override
  Widget build(BuildContext context) {
    final currentRoute =
        ModalRoute.of(context)?.settings.name ?? AppRoutes.dashboard;
    final requestedWidth = widget.isCollapsed ? 82.0 : 286.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : requestedWidth;
        final actualWidth = requestedWidth > maxWidth
            ? maxWidth
            : requestedWidth;
        _effectiveCollapsed = widget.isCollapsed || actualWidth <= 140;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: actualWidth,
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9FC),
            border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              _buildBrand(),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (_moduleEnabled('dashboard') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewDashboard,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.dashboard_outlined,
                        label: 'Dashboard',
                        route: AppRoutes.dashboard,
                      ),
                    _section(
                      context,
                      currentRoute,
                      keyName: 'employees',
                      icon: Icons.people_outline,
                      label: 'Employees',
                      visible:
                          _moduleEnabled('employees') &&
                          _user != null &&
                          PermissionService.hasPermission(
                            _user!,
                            Permission.viewEmployees,
                          ),
                      children: [
                        _subItem(
                          context,
                          currentRoute,
                          label: 'All Employees',
                          route: AppRoutes.employeeList,
                        ),
                      ],
                    ),
                    if (_moduleEnabled('payroll') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewAllowances,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.payments_outlined,
                        label: 'Allowances',
                        route: AppRoutes.allowanceManagement,
                      ),
                    if (_moduleEnabled('attendance') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewAttendance,
                        ))
                      _section(
                        context,
                        currentRoute,
                        keyName: 'attendance',
                        icon: Icons.access_time_outlined,
                        label: 'Attendance',
                        children: [
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Clock In/Out',
                            route: AppRoutes.clockIn,
                          ),
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Attendance List',
                            route: AppRoutes.attendanceList,
                          ),
                        ],
                      ),
                    if (_moduleEnabled('payroll'))
                      _section(
                        context,
                        currentRoute,
                        keyName: 'payroll',
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Payroll',
                        visible:
                            _user != null &&
                            PermissionService.hasPermission(
                              _user!,
                              Permission.viewPayroll,
                            ),
                        children: [
                          if (_user != null &&
                              PermissionService.hasPermission(
                                _user!,
                                Permission.processPayroll,
                              ))
                            _subItem(
                              context,
                              currentRoute,
                              label: 'Process Payroll',
                              route: AppRoutes.processPayroll,
                            ),
                          if (_user != null &&
                              PermissionService.hasPermission(
                                _user!,
                                Permission.processPayroll,
                              ))
                            _subItem(
                              context,
                              currentRoute,
                              label: 'Off-Cycle Payroll',
                              route: AppRoutes.offCyclePayroll,
                            ),
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Payroll History',
                            route: AppRoutes.payrollHistory,
                          ),
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Financial Transactions',
                            route: AppRoutes.transactionList,
                          ),
                          if (_user != null &&
                              PermissionService.hasPermission(
                                _user!,
                                Permission.processPayroll,
                              ))
                            _subItem(
                              context,
                              currentRoute,
                              label: 'Payment Operations',
                              route: AppRoutes.paymentOperations,
                            ),
                        ],
                      ),
                    if (_moduleEnabled('dashboard') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewDashboard,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        route: AppRoutes.notifications,
                      ),
                    if (_moduleEnabled('deductions') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewDeductions,
                        ))
                      _section(
                        context,
                        currentRoute,
                        keyName: 'deductions',
                        icon: Icons.remove_circle_outline,
                        label: 'Deductions',
                        children: [
                          if (_user != null &&
                              PermissionService.hasPermission(
                                _user!,
                                Permission.manageDeductions,
                              ))
                            _subItem(
                              context,
                              currentRoute,
                              label: 'Employee Deductions',
                              route: AppRoutes.employeeDeductions,
                            ),
                          if (_user != null &&
                              PermissionService.hasPermission(
                                _user!,
                                Permission.manageDeductions,
                              ))
                            _subItem(
                              context,
                              currentRoute,
                              label: 'Assign Deduction',
                              route: AppRoutes.assignDeduction,
                            ),
                          if (_user != null &&
                              PermissionService.hasPermission(
                                _user!,
                                Permission.manageDeductions,
                              ))
                            _subItem(
                              context,
                              currentRoute,
                              label: 'Deduction Types',
                              route: AppRoutes.deductionTypes,
                            ),
                          _subItem(
                            context,
                            currentRoute,
                            label: 'My Deductions',
                            route: AppRoutes.myDeductions,
                          ),
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Deduction History',
                            route: AppRoutes.deductionHistory,
                          ),
                        ],
                      ),
                    if (_moduleEnabled('expense') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewExpenses,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.receipt_long_outlined,
                        label: 'Expenses',
                        route: AppRoutes.expenseReimbursements,
                      ),
                    if (_moduleEnabled('salary_advance') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewSalaryAdvance,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.request_quote_outlined,
                        label: 'Salary Advance',
                        route: AppRoutes.salaryAdvances,
                      ),
                    if (_moduleEnabled('exit') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewExitManagement,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.logout_outlined,
                        label: 'Exit Management',
                        route: AppRoutes.exitManagement,
                      ),
                    if (_moduleEnabled('incentives') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewIncentives,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.workspace_premium_outlined,
                        label: 'Commission & Bonus',
                        route: AppRoutes.commissionBonus,
                      ),
                    if (_moduleEnabled('documents') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewDocuments,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.folder_open_outlined,
                        label: 'Documents',
                        route: AppRoutes.documentManagement,
                      ),
                    if (_moduleEnabled('compliance') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewCompliance,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.shield_outlined,
                        label: 'Compliance',
                        route: AppRoutes.compliance,
                      ),
                    if (_moduleEnabled('probation') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewProbation,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.rule_folder_outlined,
                        label: 'Probation & Contract',
                        route: AppRoutes.probation,
                      ),
                    _section(
                      context,
                      currentRoute,
                      keyName: 'leave',
                      icon: Icons.event_available_outlined,
                      label: 'Leave',
                      visible:
                          _moduleEnabled('leave') &&
                          _user != null &&
                          PermissionService.hasPermission(
                            _user!,
                            Permission.viewLeave,
                          ),
                      children: [
                        _subItem(
                          context,
                          currentRoute,
                          label: 'Leave Dashboard',
                          route: AppRoutes.leaveDashboard,
                        ),
                        _subItem(
                          context,
                          currentRoute,
                          label: 'Apply Leave',
                          route: AppRoutes.leaveApply,
                        ),
                        _subItem(
                          context,
                          currentRoute,
                          label: 'My Leave',
                          route: AppRoutes.leaveMy,
                        ),
                        if (_user != null &&
                            PermissionService.hasPermission(
                              _user!,
                              Permission.approveLeave,
                            ))
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Leave Approvals',
                            route: AppRoutes.leaveApprovals,
                          ),
                        if (_user != null &&
                            PermissionService.hasPermission(
                              _user!,
                              Permission.approveLeave,
                            ))
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Leave Balances',
                            route: AppRoutes.leaveBalances,
                          ),
                        if (_user != null &&
                            PermissionService.hasPermission(
                              _user!,
                              Permission.manageLeaveTypes,
                            ))
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Leave Types',
                            route: AppRoutes.leaveTypes,
                          ),
                        if (_user != null &&
                            PermissionService.hasPermission(
                              _user!,
                              Permission.approveLeave,
                            ))
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Leave Encashment',
                            route: AppRoutes.leaveEncashment,
                          ),
                        if (_user != null &&
                            PermissionService.hasPermission(
                              _user!,
                              Permission.manageLeaveTypes,
                            ))
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Public Holidays',
                            route: AppRoutes.publicHolidays,
                          ),
                      ],
                    ),
                    if (_moduleEnabled('loans') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewLoans,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.account_balance_outlined,
                        label: 'Loans',
                        route: AppRoutes.loansList,
                      ),
                    if (_moduleEnabled('loans') &&
                        _user != null &&
                        PermissionService.hasPermission(
                          _user!,
                          Permission.viewLoans,
                        ))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.add_circle_outline,
                        label: 'Request Loan',
                        route: AppRoutes.requestLoan,
                      ),
                    _section(
                      context,
                      currentRoute,
                      keyName: 'reports',
                      icon: Icons.bar_chart_outlined,
                      label: 'Reports',
                      visible:
                          _moduleEnabled('reports') &&
                          _user != null &&
                          PermissionService.hasPermission(
                            _user!,
                            Permission.viewReports,
                          ),
                      children: [
                        _subItem(
                          context,
                          currentRoute,
                          label: 'Reports Overview',
                          route: AppRoutes.reports,
                        ),
                        if (_moduleEnabled('audit') &&
                            _user != null &&
                            PermissionService.hasPermission(
                              _user!,
                              Permission.viewAuditLogs,
                            ))
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Audit Logs',
                            route: AppRoutes.auditLogs,
                          ),
                      ],
                    ),
                    if (_moduleEnabled('users'))
                      _section(
                        context,
                        currentRoute,
                        keyName: 'users',
                        icon: Icons.admin_panel_settings_outlined,
                        label: 'Users / Roles',
                        visible:
                            _user != null &&
                            PermissionService.hasPermission(
                              _user!,
                              Permission.manageUsers,
                            ),
                        children: [
                          _subItem(
                            context,
                            currentRoute,
                            label: 'Create User',
                            route: AppRoutes.createUser,
                          ),
                        ],
                      ),
                    if (_moduleEnabled('settings'))
                      _navItem(
                        context,
                        currentRoute,
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        route: AppRoutes.settings,
                      ),
                  ],
                ),
              ),
              if (!_effectiveCollapsed) _buildSecurityBadge(),
              _buildLogout(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrand() {
    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              _effectiveCollapsed ||
              constraints.maxWidth < 140 ||
              constraints.maxHeight < 72;
          if (compact) {
            final logoSize = constraints.maxHeight < 64 ? 34.0 : 38.0;
            final showToggle =
                widget.onToggle != null && constraints.maxHeight >= 54;
            final toggleSize = constraints.maxHeight < 64 ? 14.0 : 16.0;
            final spacing = showToggle ? 2.0 : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFF071A34),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                SizedBox(height: spacing),
                if (showToggle)
                  SizedBox(
                    width: toggleSize,
                    height: toggleSize,
                    child: InkWell(
                      onTap: widget.onToggle,
                      borderRadius: BorderRadius.circular(999),
                      child: Icon(
                        Icons.chevron_right,
                        color: Color(0xFF071A34),
                        size: toggleSize,
                      ),
                    ),
                  ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFF071A34),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Roipayroll',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF0A1730),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (widget.onToggle != null)
                    IconButton(
                      tooltip: 'Collapse sidebar',
                      onPressed: widget.onToggle,
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Color(0xFF607089),
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'ENTERPRISE CONSOLE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF6C7B90),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSecurityBadge() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 64) {
          return const SizedBox.shrink();
        }

        final compact = constraints.maxWidth < 170;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: compact
              ? const Center(
                  child: Tooltip(
                    message: 'Security monitored',
                    child: Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Color(0xFF35548A),
                    ),
                  ),
                )
              : const Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: Color(0xFF35548A),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Security monitored',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A1730),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _section(
    BuildContext context,
    String currentRoute, {
    required String keyName,
    required IconData icon,
    required String label,
    required List<Widget> children,
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();
    final expanded = _expanded[keyName] ?? false;
    return Column(
      children: [
        _navGroupHeader(
          context,
          icon: icon,
          label: label,
          expanded: expanded,
          onTap: () {
            setState(() {
              _expanded[keyName] = !expanded;
            });
          },
        ),
        if (expanded && !_effectiveCollapsed)
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(children: children),
          ),
      ],
    );
  }

  Widget _navGroupHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _effectiveCollapsed || constraints.maxWidth < 140;
        if (compact) {
          return Tooltip(
            message: label,
            child: InkWell(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF526781)),
              ),
            ),
          );
        }

        final content = Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF526781)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF54657B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
                color: const Color(0xFF73849D),
              ),
            ],
          ),
        );
        return Tooltip(
          message: label,
          child: InkWell(onTap: onTap, child: content),
        );
      },
    );
  }

  Widget _subItem(
    BuildContext context,
    String currentRoute, {
    required String label,
    required String route,
  }) {
    final isActive = currentRoute == route;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _effectiveCollapsed || constraints.maxWidth < 140;
        if (compact) {
          return Tooltip(
            message: label,
            child: InkWell(
              onTap: () {
                if (route == currentRoute) return;
                Navigator.pushNamed(context, route);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFDCE4EE)
                        : Colors.transparent,
                  ),
                ),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF071A34)
                        : const Color(0xFF73849D),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        }

        return Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              if (route == currentRoute) return;
              Navigator.pushNamed(context, route);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFDCE4EE)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF071A34)
                          : const Color(0xFF73849D),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF071A34)
                            : const Color(0xFF55657C),
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
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

  Widget _navItem(
    BuildContext context,
    String currentRoute, {
    required IconData icon,
    required String label,
    required String route,
    bool visible = true,
  }) {
    if (!visible) return const SizedBox.shrink();
    final isActive = currentRoute == route;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _effectiveCollapsed || constraints.maxWidth < 140;
        final content = compact
            ? Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFDCE4EE)
                        : Colors.transparent,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? const Color(0xFF071A34)
                      : const Color(0xFF526781),
                ),
              )
            : Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isActive
                        ? const Color(0xFFDCE4EE)
                        : Colors.transparent,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF0A1730,
                            ).withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isActive
                          ? const Color(0xFF071A34)
                          : const Color(0xFF526781),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFF071A34)
                              : const Color(0xFF55657C),
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              );

        return Tooltip(
          message: label,
          child: InkWell(
            onTap: () {
              if (route == currentRoute) return;
              Navigator.pushNamed(context, route);
            },
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildLogout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _effectiveCollapsed || constraints.maxWidth < 160;
        if (compact) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Tooltip(
              message: 'Logout',
              child: InkWell(
                onTap: () async {
                  await _authService.logout();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.logout,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: InkWell(
            onTap: () async {
              await _authService.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.logout, size: 18, color: AppColors.error),
                  const SizedBox(width: 10),
                  const Text(
                    'Logout',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
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
}
