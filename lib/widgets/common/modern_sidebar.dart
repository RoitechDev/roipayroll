import 'dart:async';

import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/company_module_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/models/user_model.dart';

class ModernSidebar extends StatefulWidget {
  const ModernSidebar({super.key});

  @override
  State<ModernSidebar> createState() => _ModernSidebarState();
}

class _ModernSidebarState extends State<ModernSidebar> {
  final _userService = UserService();
  final _authService = AuthService();
  final _moduleService = CompanyModuleService();
  AppUser? currentUser;
  StreamSubscription<Map<String, bool>>? _moduleSubscription;
  Map<String, bool> _enabledModules = Map<String, bool>.from(
    CompanyModuleService.defaultModules,
  );
  String currentRoute = '/dashboard';

  // Track which sections are expanded
  final Map<String, bool> _expandedSections = {
    'employees': false,
    'payroll': false,
    'reports': false,
    'settings': false,
    'leave': false,
    'attendance': false,
  };

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _userService.getCurrentUserProfile();
    if (user != null) {
      setState(() {
        currentUser = user;
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
    if (!mounted) return;
    setState(() {
      currentUser = user;
    });
  }

  @override
  void dispose() {
    _moduleSubscription?.cancel();
    super.dispose();
  }

  bool _moduleEnabled(String key) {
    return CompanyModuleService.isModuleEnabledInMap(key, _enabledModules);
  }

  void _toggleSection(String section) {
    setState(() {
      _expandedSections[section] = !(_expandedSections[section] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/dashboard';
    currentRoute = route;

    return Drawer(
      child: Container(
        color: AppColors.primary,
        child: Column(
          children: [
            // Header with Logo
            _buildHeader(),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  // Dashboard
                  if (_moduleEnabled('dashboard'))
                    _buildMenuItem(
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      route: AppRoutes.dashboard,
                    ),

                  // Employees Section
                  if (_moduleEnabled('employees') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewEmployees,
                      ))
                    _buildExpandableSection(
                      icon: Icons.people_outline,
                      label: 'Employees',
                      sectionKey: 'employees',
                      children: [
                        if (currentUser != null &&
                            PermissionService.hasPermission(
                              currentUser!,
                              Permission.viewEmployees,
                            ))
                          // _buildSubMenuItem(
                          //   icon: Icons.person_add_outlined,
                          //   label: 'Add Employee',
                          //   route: AppRoutes.addEmployee,
                          // ),
                          _buildSubMenuItem(
                            icon: Icons.list_alt,
                            label: 'All Employees',
                            route: AppRoutes.employeeList,
                          ),
                      ],
                    ),

                  // Payroll Section
                  if (_moduleEnabled('payroll') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewPayroll,
                      ))
                    _buildExpandableSection(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Payroll',
                      sectionKey: 'payroll',
                      children: [
                        if (currentUser != null &&
                            PermissionService.hasPermission(
                              currentUser!,
                              Permission.processPayroll,
                            ))
                          _buildSubMenuItem(
                            icon: Icons.calculate_outlined,
                            label: 'Process Payroll',
                            route: AppRoutes.processPayroll,
                          ),
                        if (currentUser != null &&
                            PermissionService.hasPermission(
                              currentUser!,
                              Permission.processPayroll,
                            ))
                          _buildSubMenuItem(
                            icon: Icons.sync_alt_outlined,
                            label: 'Off-Cycle Payroll',
                            route: AppRoutes.offCyclePayroll,
                          ),
                        _buildSubMenuItem(
                          icon: Icons.history,
                          label: 'Payroll History',
                          route: AppRoutes.payrollHistory,
                        ),
                        _buildSubMenuItem(
                          icon: Icons.receipt_long_outlined,
                          label: 'Financial Transactions',
                          route: AppRoutes.transactionList,
                        ),
                        if (currentUser != null &&
                            PermissionService.hasPermission(
                              currentUser!,
                              Permission.processPayroll,
                            ))
                          _buildSubMenuItem(
                            icon: Icons.tune_outlined,
                            label: 'Payment Operations',
                            route: AppRoutes.paymentOperations,
                          ),
                      ],
                    ),

                  // Loans
                  if (_moduleEnabled('loans'))
                    _buildMenuItem(
                      icon: Icons.account_balance_outlined,
                      label: 'Loans',
                      route: AppRoutes.loansList,
                    ),
                  if (_moduleEnabled('salary_advance') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewSalaryAdvance,
                      ))
                    _buildMenuItem(
                      icon: Icons.request_quote_outlined,
                      label: 'Salary Advance',
                      route: AppRoutes.salaryAdvances,
                    ),
                  if (_moduleEnabled('exit') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewExitManagement,
                      ))
                    _buildMenuItem(
                      icon: Icons.logout_outlined,
                      label: 'Exit Management',
                      route: AppRoutes.exitManagement,
                    ),
                  if (_moduleEnabled('expense') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewExpenses,
                      ))
                    _buildMenuItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Expenses',
                      route: AppRoutes.expenseReimbursements,
                    ),
                  if (_moduleEnabled('incentives') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewIncentives,
                      ))
                    _buildMenuItem(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Commission & Bonus',
                      route: AppRoutes.commissionBonus,
                    ),
                  if (_moduleEnabled('documents') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewDocuments,
                      ))
                    _buildMenuItem(
                      icon: Icons.folder_open_outlined,
                      label: 'Documents',
                      route: AppRoutes.documentManagement,
                    ),
                  if (_moduleEnabled('compliance') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewCompliance,
                      ))
                    _buildMenuItem(
                      icon: Icons.shield_outlined,
                      label: 'Compliance',
                      route: AppRoutes.compliance,
                    ),
                  if (_moduleEnabled('probation') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewProbation,
                      ))
                    _buildMenuItem(
                      icon: Icons.rule_folder_outlined,
                      label: 'Probation & Contract',
                      route: AppRoutes.probation,
                    ),

                  // Attendance
                  if (_moduleEnabled('attendance') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewAttendance,
                      ))
                    _buildExpandableSection(
                      icon: Icons.access_time_outlined,
                      label: 'Attendance',
                      sectionKey: 'attendance',
                      children: [
                        _buildSubMenuItem(
                          icon: Icons.login,
                          label: 'Clock In/Out',
                          route: AppRoutes.clockIn,
                        ),
                        _buildSubMenuItem(
                          icon: Icons.list,
                          label: 'Attendance List',
                          route: AppRoutes.attendanceList,
                        ),
                      ],
                    ),

                  // Leave
                  if (_moduleEnabled('leave') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewLeave,
                      ))
                    _buildMenuItem(
                      icon: Icons.event_available_outlined,
                      label: 'Leave',
                      route: AppRoutes.leaveDashboard,
                    ),

                  // Reports
                  if (_moduleEnabled('reports') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewReports,
                      ))
                    _buildExpandableSection(
                      icon: Icons.bar_chart_outlined,
                      label: 'Reports',
                      sectionKey: 'reports',
                      children: [
                        _buildSubMenuItem(
                          icon: Icons.analytics_outlined,
                          label: 'Analytics',
                          route: AppRoutes.reports,
                        ),
                        if (_moduleEnabled('audit') &&
                            currentUser != null &&
                            PermissionService.hasPermission(
                              currentUser!,
                              Permission.viewAuditLogs,
                            ))
                          _buildSubMenuItem(
                            icon: Icons.history_toggle_off,
                            label: 'Audit Logs',
                            route: AppRoutes.auditLogs,
                          ),
                      ],
                    ),

                  // Users Management
                  if (_moduleEnabled('users') &&
                      currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.manageUsers,
                      ))
                    _buildMenuItem(
                      icon: Icons.admin_panel_settings_outlined,
                      label: 'Users',
                      route: AppRoutes.createUser,
                    ),

                  Divider(color: AppColors.primaryDark, height: 24),

                  // Settings
                  if (_moduleEnabled('settings'))
                    _buildMenuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      route: AppRoutes.settings,
                    ),
                ],
              ),
            ),

            // User Profile Footer
            _buildUserFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.primaryDark, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Roipayroll',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.surface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Payroll Management',
                  style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String route,
  }) {
    final isActive = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            if (route != currentRoute) {
              Navigator.pushNamed(context, route);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive ? AppColors.surface : AppColors.textTertiary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive
                          ? AppColors.surface
                          : AppColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required IconData icon,
    required String label,
    required String sectionKey,
    required List<Widget> children,
  }) {
    final isExpanded = _expandedSections[sectionKey] ?? false;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleSection(sectionKey),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 20, color: AppColors.textTertiary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
                      color: AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(children: children),
          ),
      ],
    );
  }

  Widget _buildSubMenuItem({
    required IconData icon,
    required String label,
    required String route,
  }) {
    final isActive = currentRoute == route;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            if (route != currentRoute) {
              Navigator.pushNamed(context, route);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Icon(
                  icon,
                  size: 18,
                  color: isActive ? AppColors.primary : AppColors.textTertiary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: isActive
                          ? AppColors.primary
                          : AppColors.textDisabled,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.primaryDark, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.successGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                currentUser?.name[0].toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUser?.name ?? 'User',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  currentUser?.getRoleName() ?? 'Employee',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            color: AppColors.error,
            onPressed: () async {
              await _authService.logout();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}
