import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/models/user_model.dart';

class ModernAppDrawer extends StatefulWidget {
  const ModernAppDrawer({super.key});

  @override
  State<ModernAppDrawer> createState() => _ModernAppDrawerState();
}

class _ModernAppDrawerState extends State<ModernAppDrawer> {
  final _userService = UserService();
  final _authService = AuthService();
  AppUser? currentUser;
  String currentRoute = '/dashboard';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _userService.getCurrentUserProfile();
    setState(() {
      currentUser = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/dashboard';
    currentRoute = route;

    return Drawer(
      child: Container(
        color: AppColors.background,
        child: Column(
          children: [
            // Modern Logo Section with Gradient
            Container(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Roipayroll',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Payroll System',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewDashboard,
                      ))
                    _buildMenuItem(
                      context,
                      icon: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      route: AppRoutes.dashboard,
                    ),

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewEmployees,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.people_outline,
                      label: 'Employees',
                      route: AppRoutes.employeeList,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.manageUsers,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.person_add_outlined,
                      label: 'Create User',
                      route: AppRoutes.createUser,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.createEmployee,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.person_add_alt_outlined,
                      label: 'Add Employee',
                      route: AppRoutes.addEmployee,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.processPayroll,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.attach_money_outlined,
                      label: 'Payroll',
                      route: AppRoutes.processPayroll,
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.sync_alt_outlined,
                      label: 'Off-Cycle Payroll',
                      route: AppRoutes.offCyclePayroll,
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.tune_outlined,
                      label: 'Payment Operations',
                      route: AppRoutes.paymentOperations,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewPayroll,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.receipt_long_outlined,
                      label: 'Financial Transactions',
                      route: AppRoutes.transactionList,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewLoans,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Loans',
                      route: AppRoutes.loansList,
                    ),
                  ],
                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewSalaryAdvance,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.request_quote_outlined,
                      label: 'Salary Advance',
                      route: AppRoutes.salaryAdvances,
                    ),
                  ],
                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewExitManagement,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.logout_outlined,
                      label: 'Exit Management',
                      route: AppRoutes.exitManagement,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewAttendance,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.access_time_outlined,
                      label: 'Attendance',
                      route: AppRoutes.attendanceList,
                    ),
                  ],
                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewProbation,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.rule_folder_outlined,
                      label: 'Probation & Contract',
                      route: AppRoutes.probation,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewLeave,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.event_available_outlined,
                      label: 'Leave Dashboard',
                      route: AppRoutes.leaveDashboard,
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.note_add_outlined,
                      label: 'Apply Leave',
                      route: AppRoutes.leaveApply,
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.list_alt,
                      label: 'My Leaves',
                      route: AppRoutes.leaveMy,
                    ),
                  ],
                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.approveLeave,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.approval_outlined,
                      label: 'Approvals',
                      route: AppRoutes.leaveApprovals,
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Leave Balances',
                      route: AppRoutes.leaveBalances,
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.swap_horiz,
                      label: 'Encashments',
                      route: AppRoutes.leaveEncashment,
                    ),
                  ],
                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.approveLeave,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.category_outlined,
                      label: 'Leave Types',
                      route: AppRoutes.leaveTypes,
                    ),
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.event,
                      label: 'Public Holidays',
                      route: AppRoutes.publicHolidays,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewReports,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.bar_chart_outlined,
                      label: 'Reports',
                      route: AppRoutes.reports,
                    ),
                    if (currentUser != null &&
                        PermissionService.hasPermission(
                          currentUser!,
                          Permission.viewAuditLogs,
                        )) ...[
                      const SizedBox(height: 4),
                      _buildMenuItem(
                        context,
                        icon: Icons.history_toggle_off,
                        label: 'Audit Logs',
                        route: AppRoutes.auditLogs,
                      ),
                    ],
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewCompliance,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.shield_outlined,
                      label: 'Compliance',
                      route: AppRoutes.compliance,
                    ),
                  ],

                  if (currentUser != null &&
                      PermissionService.hasPermission(
                        currentUser!,
                        Permission.viewSettings,
                      )) ...[
                    const SizedBox(height: 4),
                    _buildMenuItem(
                      context,
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      route: AppRoutes.settings,
                    ),
                  ],
                ],
              ),
            ),

            // Modern Profile Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
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
                                color: AppColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            InkWell(
                              onTap: () async {
                                await _authService.logout();
                                if (context.mounted) {
                                  Navigator.pushReplacementNamed(
                                    context,
                                    AppRoutes.login,
                                  );
                                }
                              },
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.logout,
                                    size: 14,
                                    color: AppColors.error,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Log Out',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
  }) {
    final isActive = currentRoute == route;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (route != currentRoute) {
            Navigator.pushNamed(context, route);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: isActive ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
