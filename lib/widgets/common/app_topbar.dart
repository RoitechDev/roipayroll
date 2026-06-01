import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';

class AppTopBar extends StatefulWidget {
  final String title;
  final bool showSearch;
  final Widget? actions;

  const AppTopBar({
    super.key,
    required this.title,
    this.showSearch = false,
    this.actions,
  });

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  final _userService = UserService();
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _userService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() => _user = user);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 900;
        final ultraCompact = width < 720;
        final showSearch = widget.showSearch && !ultraCompact;
        final showTitle = widget.title.isNotEmpty && !showSearch;

        return Material(
          color: Colors.white,
          elevation: 0,
          child: Container(
            height: 72,
            padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 26),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              children: [
                if (showTitle)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 180 : 260),
                    child: Text(
                      widget.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0A1730),
                      ),
                    ),
                  )
                else if (showSearch)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: compact ? 280 : 420,
                      minWidth: compact ? 240 : 340,
                    ),
                    child: _SearchField(),
                  ),
                if (showSearch) ...[const Spacer()] else const Spacer(),
                widget.actions ??
                    _topActionButton(
                      icon: Icons.notifications_outlined,
                      tooltip: 'Notifications',
                      onTap: () {
                        final currentRoute = ModalRoute.of(
                          context,
                        )?.settings.name;
                        if (currentRoute == AppRoutes.notifications) return;
                        Navigator.pushNamed(context, AppRoutes.notifications);
                      },
                    ),
                const SizedBox(width: 6),
                _topActionButton(
                  icon: Icons.help_outline_rounded,
                  tooltip: 'Help',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Help center is coming soon.'),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                _topActionButton(
                  icon: Icons.settings_outlined,
                  tooltip: 'Settings',
                  onTap: () {
                    final currentRoute = ModalRoute.of(context)?.settings.name;
                    if (currentRoute == AppRoutes.settings) return;
                    Navigator.pushNamed(context, AppRoutes.settings);
                  },
                ),
                const SizedBox(width: 18),
                Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                const SizedBox(width: 18),
                _UserBadge(user: _user, compact: compact),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _topActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return IconButton(
      onPressed: onTap ?? () {},
      tooltip: tooltip,
      icon: Icon(icon, color: const Color(0xFF3A4A60), size: 22),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFFF3F6FB),
        foregroundColor: const Color(0xFF3A4A60),
        minimumSize: const Size(42, 42),
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final UserService _userService = UserService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _debounce;
  AppUser? _currentUser;
  List<_SearchItem> _options = const [];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _userService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() => _currentUser = user);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSubmit(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return;

    if (_options.isNotEmpty) {
      _navigateToItem(_options.first);
      return;
    }

    final targetRoute = _resolveRoute(query);
    if (targetRoute == null || targetRoute.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No matching module found')));
      return;
    }

    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == targetRoute) return;
    Navigator.pushNamed(context, targetRoute);
  }

  void _onQueryChanged(String rawQuery) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      final query = rawQuery.trim().toLowerCase();
      if (query.isEmpty) {
        if (!mounted) return;
        setState(() => _options = const []);
        return;
      }

      final routeSuggestions = _buildRouteSuggestions(query, _currentUser);
      final peopleSuggestions = await _buildPeopleSuggestions(query);

      if (!mounted) return;
      setState(() {
        _options = [
          ...routeSuggestions,
          ...peopleSuggestions,
        ].take(10).toList();
      });
    });
  }

  void _navigateToItem(_SearchItem item) {
    final route = item.route;
    if (route == null || route.isEmpty) return;
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == route) return;
    Navigator.pushNamed(context, route);
  }

  List<_SearchItem> _buildRouteSuggestions(String query, AppUser? user) {
    final catalog = <_RouteEntry>[
      _RouteEntry('Dashboard', AppRoutes.dashboard, (u) => true),
      _RouteEntry(
        'Employees',
        AppRoutes.employeeList,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.viewEmployees),
      ),
      _RouteEntry('Attendance', AppRoutes.attendanceList, (u) => true),
      _RouteEntry('Clock In / Out', AppRoutes.clockIn, (u) => true),
      _RouteEntry(
        'Payroll History',
        AppRoutes.payrollHistory,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.viewPayroll),
      ),
      _RouteEntry(
        'Financial Transactions',
        AppRoutes.transactionList,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.viewPayroll),
      ),
      _RouteEntry(
        'Payment Operations',
        AppRoutes.paymentOperations,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.processPayroll),
      ),
      _RouteEntry(
        'Process Payroll',
        AppRoutes.processPayroll,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.processPayroll),
      ),
      _RouteEntry(
        'Off-Cycle Payroll',
        AppRoutes.offCyclePayroll,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.processPayroll),
      ),
      _RouteEntry('Loans', AppRoutes.loansList, (u) => true),
      _RouteEntry('Request Loan', AppRoutes.requestLoan, (u) => true),
      _RouteEntry(
        'Salary Advance',
        AppRoutes.salaryAdvances,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.viewSalaryAdvance),
      ),
      _RouteEntry(
        'Exit Management',
        AppRoutes.exitManagement,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.viewExitManagement),
      ),
      _RouteEntry('Commission & Bonus', AppRoutes.commissionBonus, (u) => true),
      _RouteEntry('Incentives', AppRoutes.commissionBonus, (u) => true),
      _RouteEntry('Documents', AppRoutes.documentManagement, (u) => true),
      _RouteEntry(
        'Probation & Contract',
        AppRoutes.probation,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.approveLeave),
      ),
      _RouteEntry('Leave Dashboard', AppRoutes.leaveDashboard, (u) => true),
      _RouteEntry('Apply Leave', AppRoutes.leaveApply, (u) => true),
      _RouteEntry('My Leaves', AppRoutes.leaveMy, (u) => true),
      _RouteEntry(
        'Leave Approvals',
        AppRoutes.leaveApprovals,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.approveLeave),
      ),
      _RouteEntry(
        'Leave Balances',
        AppRoutes.leaveBalances,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.approveLeave),
      ),
      _RouteEntry(
        'Leave Types',
        AppRoutes.leaveTypes,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.approveLeave),
      ),
      _RouteEntry(
        'Leave Encashment',
        AppRoutes.leaveEncashment,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.approveLeave),
      ),
      _RouteEntry(
        'Public Holidays',
        AppRoutes.publicHolidays,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.approveLeave),
      ),
      _RouteEntry(
        'Reports',
        AppRoutes.reports,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.viewReports),
      ),
      _RouteEntry(
        'Audit Logs',
        AppRoutes.auditLogs,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.viewAuditLogs),
      ),
      _RouteEntry(
        'Users',
        AppRoutes.usersList,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.manageUsers),
      ),
      _RouteEntry(
        'Create User',
        AppRoutes.createUser,
        (u) =>
            u != null &&
            PermissionService.hasPermission(u, Permission.manageUsers),
      ),
      _RouteEntry('Settings', AppRoutes.settings, (u) => true),
      _RouteEntry('Deduction History', AppRoutes.deductionHistory, (u) => true),
    ];

    return catalog
        .where((entry) => entry.canAccess(user))
        .where((entry) => entry.label.toLowerCase().contains(query))
        .map(
          (entry) => _SearchItem(
            title: entry.label,
            subtitle: 'Module',
            route: entry.route,
            icon: Icons.grid_view_outlined,
          ),
        )
        .toList();
  }

  Future<List<_SearchItem>> _buildPeopleSuggestions(String query) async {
    final List<_SearchItem> out = [];
    final companyId = _currentUser?.companyId;
    if (companyId == null || companyId.isEmpty) {
      return out;
    }

    try {
      final employeesSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('employees')
          .limit(50)
          .get();
      for (final doc in employeesSnapshot.docs) {
        final data = doc.data();
        final firstName = (data['firstName'] ?? '').toString();
        final lastName = (data['lastName'] ?? '').toString();
        final fullName = '$firstName $lastName'.trim();
        final email = (data['email'] ?? '').toString();
        if (fullName.toLowerCase().contains(query) ||
            email.toLowerCase().contains(query)) {
          out.add(
            _SearchItem(
              title: fullName.isEmpty ? 'Unknown Employee' : fullName,
              subtitle: email.isEmpty ? 'Employee' : 'Employee | $email',
              route: AppRoutes.employeeList,
              icon: Icons.badge_outlined,
            ),
          );
        }
      }
    } catch (_) {}

    try {
      final usersSnapshot = await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .limit(50)
          .get();
      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString();
        final email = (data['email'] ?? '').toString();
        if (name.toLowerCase().contains(query) ||
            email.toLowerCase().contains(query)) {
          out.add(
            _SearchItem(
              title: name.isEmpty ? 'Unknown User' : name,
              subtitle: email.isEmpty ? 'User' : 'User | $email',
              route: AppRoutes.usersList,
              icon: Icons.person_outline,
            ),
          );
        }
      }
    } catch (_) {}

    return out;
  }

  String? _resolveRoute(String query) {
    final routes = <String, String>{
      'dashboard': AppRoutes.dashboard,
      'employee': AppRoutes.employeeList,
      'employees': AppRoutes.employeeList,
      'attendance': AppRoutes.attendanceList,
      'clock in': AppRoutes.clockIn,
      'payroll': AppRoutes.payrollHistory,
      'payment operations': AppRoutes.paymentOperations,
      'payments': AppRoutes.paymentOperations,
      'process payroll': AppRoutes.processPayroll,
      'off-cycle payroll': AppRoutes.offCyclePayroll,
      'off cycle payroll': AppRoutes.offCyclePayroll,
      'transactions': AppRoutes.transactionList,
      'transaction': AppRoutes.transactionList,
      'financial transactions': AppRoutes.transactionList,
      'ledger': AppRoutes.transactionList,
      'accounting': AppRoutes.transactionList,
      'adhoc payroll': AppRoutes.offCyclePayroll,
      'ad hoc payroll': AppRoutes.offCyclePayroll,
      'loan': AppRoutes.loansList,
      'request loan': AppRoutes.requestLoan,
      'expense': AppRoutes.expenseReimbursements,
      'expenses': AppRoutes.expenseReimbursements,
      'reimbursement': AppRoutes.expenseReimbursements,
      'reimbursements': AppRoutes.expenseReimbursements,
      'salary advance': AppRoutes.salaryAdvances,
      'advance': AppRoutes.salaryAdvances,
      'salary advances': AppRoutes.salaryAdvances,
      'exit': AppRoutes.exitManagement,
      'resignation': AppRoutes.exitManagement,
      'offboarding': AppRoutes.exitManagement,
      'exit management': AppRoutes.exitManagement,
      'commission': AppRoutes.commissionBonus,
      'bonus': AppRoutes.commissionBonus,
      'incentive': AppRoutes.commissionBonus,
      'incentives': AppRoutes.commissionBonus,
      'document': AppRoutes.documentManagement,
      'documents': AppRoutes.documentManagement,
      'certificate': AppRoutes.documentManagement,
      'certification': AppRoutes.documentManagement,
      'probation': AppRoutes.probation,
      'contract': AppRoutes.probation,
      'probation contract': AppRoutes.probation,
      'leave': AppRoutes.leaveDashboard,
      'apply leave': AppRoutes.leaveApply,
      'my leaves': AppRoutes.leaveMy,
      'approval': AppRoutes.leaveApprovals,
      'leave approval': AppRoutes.leaveApprovals,
      'leave balances': AppRoutes.leaveBalances,
      'leave types': AppRoutes.leaveTypes,
      'encashment': AppRoutes.leaveEncashment,
      'holiday': AppRoutes.publicHolidays,
      'report': AppRoutes.reports,
      'audit': AppRoutes.auditLogs,
      'audit logs': AppRoutes.auditLogs,
      'users': AppRoutes.usersList,
      'create user': AppRoutes.createUser,
      'settings': AppRoutes.settings,
      'deduction': AppRoutes.deductionHistory,
    };

    for (final entry in routes.entries) {
      if (query.contains(entry.key)) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<_SearchItem>(
      optionsBuilder: (textEditingValue) {
        if (textEditingValue.text.trim().isEmpty) {
          return const Iterable<_SearchItem>.empty();
        }
        return _options;
      },
      displayStringForOption: (option) => option.title,
      onSelected: _navigateToItem,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onChanged: _onQueryChanged,
          onSubmitted: _onSubmit,
          decoration: InputDecoration(
            hintText: 'Search data, employees, reports...',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: const Color(0xFFF1F4F8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFCAD6E4)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final result = options.toList();
        final screenWidth = MediaQuery.of(context).size.width;
        final dropdownMaxWidth = (screenWidth - 32).clamp(220.0, 720.0);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 320,
                minWidth: 220,
                maxWidth: dropdownMaxWidth,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: result.length,
                itemBuilder: (context, index) {
                  final item = result[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(item.icon, color: AppColors.textSecondary),
                    title: Text(
                      item.title,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      item.subtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onTap: () => onSelected(item),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SearchItem {
  final String title;
  final String subtitle;
  final String? route;
  final IconData icon;

  const _SearchItem({
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
  });
}

class _RouteEntry {
  final String label;
  final String route;
  final bool Function(AppUser?) canAccess;

  const _RouteEntry(this.label, this.route, this.canAccess);
}

class _UserBadge extends StatelessWidget {
  final AppUser? user;
  final bool compact;

  const _UserBadge({required this.user, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'User';
    final role = (user?.getRoleName() ?? 'Employee').toUpperCase();
    return Row(
      children: [
        if (!compact)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0A1730),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.6,
                    color: Color(0xFF5F7087),
                  ),
                ),
              ],
            ),
          ),
        if (!compact) const SizedBox(width: 12),
        CircleAvatar(
          radius: compact ? 16 : 18,
          backgroundColor: const Color(0xFF071A34),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
