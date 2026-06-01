import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/core/utils/date_formatter.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/dashboard_provider.dart';
import 'package:roipayroll/providers/employee_provider.dart';
import 'package:roipayroll/screens/employees/edit_employee_screen.dart';
import 'package:roipayroll/services/employee_deduction_service.dart';
import 'package:roipayroll/services/employee_invitation_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class EmployeeDetailScreen extends ConsumerStatefulWidget {
  final Employee employee;

  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  ConsumerState<EmployeeDetailScreen> createState() =>
      _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends ConsumerState<EmployeeDetailScreen> {
  final EmployeeService employeeService = EmployeeService();
  final EmployeeInvitationService invitationService =
      EmployeeInvitationService();
  final UserService userService = UserService();
  late final EmployeeDeductionService deductionService;

  late Future<_EmployeeDetailMeta> _metaFuture;

  @override
  void initState() {
    super.initState();
    deductionService = EmployeeDeductionService(userService: userService);
    _metaFuture = _loadMeta(widget.employee.id);
  }

  Future<_EmployeeDetailMeta> _loadMeta(String employeeId) async {
    AppUser? linkedUser;
    try {
      final users = await userService.getAllUsers();
      linkedUser = users.where((u) => u.employeeId == employeeId).firstOrNull;
      linkedUser ??= users
          .where((u) => u.id == widget.employee.userId)
          .firstOrNull;
    } catch (_) {}

    try {
      final deductions = await deductionService.getActiveDeductions(employeeId);
      final totalMonthlyDeductions = deductions.fold<double>(
        0,
        (sum, item) => sum + item.amountPerPayroll,
      );
      return _EmployeeDetailMeta(
        linkedUser: linkedUser,
        totalMonthlyDeductions: totalMonthlyDeductions,
        activeDeductionCount: deductions.length,
      );
    } catch (_) {
      return _EmployeeDetailMeta(
        linkedUser: linkedUser,
        totalMonthlyDeductions: 0,
        activeDeductionCount: 0,
      );
    }
  }

  void _refreshMeta() {
    setState(() {
      _metaFuture = _loadMeta(widget.employee.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);
    final employeeAsync = ref.watch(employeeProvider(widget.employee.id));

    return AppScaffold(
      title: 'Employee Details',
      padding: EdgeInsets.zero,
      child: currentUserAsync.when(
        loading: () => const Center(
          child: ModernLoadingState(message: 'Loading access...'),
        ),
        error: (error, _) => Center(
          child: ModernErrorState(
            message: 'Failed to load employee access',
            subtitle: error.toString(),
          ),
        ),
        data: (viewer) {
          if (viewer == null) {
            return const Center(
              child: ModernEmptyState(
                icon: Icons.person_off_outlined,
                title: 'User profile unavailable',
                subtitle: 'Please sign in again to view employee details.',
              ),
            );
          }

          final employee = employeeAsync.asData?.value ?? widget.employee;

          final permissions = _EmployeeDetailPermissions.fromUser(viewer);
          return FutureBuilder<_EmployeeDetailMeta>(
            future: _metaFuture,
            builder: (context, snapshot) {
              final meta = snapshot.data ?? const _EmployeeDetailMeta.empty();
              return _buildScreen(
                employee: employee,
                permissions: permissions,
                meta: meta,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildScreen({
    required Employee employee,
    required _EmployeeDetailPermissions permissions,
    required _EmployeeDetailMeta meta,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth >= 1400
            ? 34.0
            : constraints.maxWidth >= 1100
            ? 24.0
            : 16.0;
        final compact = constraints.maxWidth < 920;

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(padding, 24, padding, 28),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBackRow(),
                    const SizedBox(height: 18),
                    _buildHero(employee, meta),
                    if (_hasPrimaryActions(employee, permissions, meta)) ...[
                      const SizedBox(height: 18),
                      _buildPrimaryActions(employee, permissions, meta),
                    ],
                    const SizedBox(height: 26),
                    _buildSectionCard(
                      title: 'Personal Information',
                      child: _DetailGrid(
                        compact: compact,
                        children: [
                          _DetailItem(
                            icon: Icons.email_outlined,
                            label: 'EMAIL ADDRESS',
                            value: employee.email,
                          ),
                          _DetailItem(
                            icon: Icons.phone_outlined,
                            label: 'PHONE NUMBER',
                            value: employee.phone.isEmpty
                                ? 'Not set'
                                : employee.phone,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      title: 'Employment Details',
                      footer: permissions.canManageLifecycle
                          ? _buildLifecycleActions(employee)
                          : null,
                      child: _DetailGrid(
                        compact: compact,
                        children: [
                          _DetailItem(
                            icon: Icons.badge_outlined,
                            label: 'EMPLOYEE ID',
                            value: employee.id,
                          ),
                          _DetailItem(
                            icon: Icons.apartment_outlined,
                            label: 'DEPARTMENT',
                            value: employee.department,
                          ),
                          _DetailItem(
                            icon: Icons.work_outline_rounded,
                            label: 'POSITION',
                            value: employee.position,
                          ),
                          _DetailItem(
                            icon: Icons.verified_user_outlined,
                            label: 'HR STATUS',
                            value: employee.status.toUpperCase(),
                          ),
                          _DetailItem(
                            icon: Icons.description_outlined,
                            label: 'EMPLOYMENT TYPE',
                            value: employee.employmentType.name.toUpperCase(),
                          ),
                          _DetailItem(
                            icon: Icons.calendar_month_outlined,
                            label: 'HIRE DATE',
                            value: DateFormatter.formatStandard(
                              employee.hireDate,
                            ),
                          ),
                          _DetailItem(
                            icon: Icons.history_toggle_off_outlined,
                            label: 'YEARS OF SERVICE',
                            value: DateFormatter.calculateWorkDuration(
                              employee.hireDate,
                            ),
                          ),
                          _DetailItem(
                            icon: Icons.assignment_ind_outlined,
                            label: 'PROBATION STATUS',
                            value: _probationStatusLabel(employee),
                            valueColor: _probationStatusColor(employee),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      title: 'Compensation',
                      footer: permissions.canViewDeductions
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.deductionHistory,
                                  );
                                },
                                icon: const Icon(Icons.history_toggle_off),
                                label: const Text('Open Deduction History'),
                              ),
                            )
                          : null,
                      child: _DetailGrid(
                        compact: compact,
                        children: [
                          _DetailItem(
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'BASIC SALARY',
                            value: permissions.canViewSalary
                                ? CurrencyFormatter.formatCurrency(
                                    employee.basicSalary,
                                    currencyCode: 'NGN',
                                  )
                                : 'Restricted',
                          ),
                          _DetailItem(
                            icon: Icons.remove_circle_outline,
                            label: 'MONTHLY DEDUCTIONS',
                            value:
                                permissions.canViewSalary ||
                                    permissions.canViewDeductions
                                ? CurrencyFormatter.formatCurrency(
                                    meta.totalMonthlyDeductions,
                                    currencyCode: 'NGN',
                                  )
                                : 'Restricted',
                            valueColor: meta.totalMonthlyDeductions > 0
                                ? AppColors.error
                                : null,
                          ),
                          _DetailItem(
                            icon: Icons.payments_outlined,
                            label: 'PAYOUT CURRENCY',
                            value: 'NGN - Nigerian Naira',
                          ),
                          _DetailItem(
                            icon: Icons.list_alt_outlined,
                            label: 'ACTIVE DEDUCTIONS',
                            value: permissions.canViewDeductions
                                ? '${meta.activeDeductionCount}'
                                : 'Restricted',
                          ),
                        ],
                      ),
                    ),
                    if (permissions.canViewSensitive &&
                        ((_safe(employee.bankName).isNotEmpty) ||
                            (_safe(employee.accountNumber).isNotEmpty))) ...[
                      const SizedBox(height: 18),
                      _buildSectionCard(
                        title: 'Bank Details',
                        child: _DetailGrid(
                          compact: compact,
                          children: [
                            if (_safe(employee.bankName).isNotEmpty)
                              _DetailItem(
                                icon: Icons.account_balance_outlined,
                                label: 'BANK NAME',
                                value: employee.bankName!,
                              ),
                            if (_safe(employee.accountNumber).isNotEmpty)
                              _DetailItem(
                                icon: Icons.credit_card_outlined,
                                label: 'ACCOUNT NUMBER',
                                value: employee.accountNumber!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackRow() {
    return InkWell(
      onTap: () => Navigator.of(context).maybePop(),
      borderRadius: BorderRadius.circular(12),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back_rounded, color: Color(0xFF667A96)),
            SizedBox(width: 10),
            Text(
              'Employee Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A1730),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(Employee employee, _EmployeeDetailMeta meta) {
    return Column(
      children: [
        _AvatarBadge(name: employee.fullName, seed: employee.id),
        const SizedBox(height: 18),
        Text(
          employee.fullName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A1730),
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatusBadge(label: employee.status.toUpperCase()),
            Text(
              _linkedUserLabel(employee, meta.linkedUser),
              style: const TextStyle(fontSize: 15, color: Color(0xFF4D5F78)),
            ),
          ],
        ),
      ],
    );
  }

  bool _hasPrimaryActions(
    Employee employee,
    _EmployeeDetailPermissions permissions,
    _EmployeeDetailMeta meta,
  ) {
    return permissions.canEdit ||
        permissions.canDelete ||
        (permissions.canManageInvitations &&
            (employee.canInvite ||
                employee.invitationStatus == InvitationStatus.inviteFailed ||
                meta.linkedUser == null));
  }

  Widget _buildPrimaryActions(
    Employee employee,
    _EmployeeDetailPermissions permissions,
    _EmployeeDetailMeta meta,
  ) {
    final actions = <Widget>[];

    if (permissions.canEdit) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _editEmployee(employee),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF17263D),
            side: const BorderSide(color: Color(0xFFD8E0EB)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text(
            'Edit Employee',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (permissions.canManageInvitations && employee.canInvite) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _inviteEmployeeToLogin(employee),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF17263D),
            side: const BorderSide(color: Color(0xFFD8E0EB)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: Icon(
            employee.invitationStatus == InvitationStatus.inviteFailed
                ? Icons.refresh_rounded
                : Icons.send_outlined,
            size: 18,
          ),
          label: Text(
            employee.invitationStatus == InvitationStatus.inviteFailed
                ? 'Retry Invitation'
                : 'Send Login Invite',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (permissions.canManageInvitations &&
        employee.invitationStatus == InvitationStatus.inviteFailed) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _resetAndUpdateEmail(employee),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF17263D),
            side: const BorderSide(color: Color(0xFFD8E0EB)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.settings_backup_restore, size: 18),
          label: const Text(
            'Reset & Update Email',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    if (permissions.canDelete) {
      actions.add(
        TextButton.icon(
          onPressed: () => _deleteEmployee(employee),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.error,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text(
            'Archive Employee',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: actions,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    Widget? footer,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1730).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 18),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A1730),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFECF0F5)),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 24),
            child: child,
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: footer,
            ),
        ],
      ),
    );
  }

  Widget _buildLifecycleActions(Employee employee) {
    final buttons = <Widget>[];
    if (!employee.isProbationConfirmed) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _confirmProbation(employee),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF071A34),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.verified_outlined, size: 18),
          label: const Text(
            'Confirm Probation',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }
    buttons.add(
      OutlinedButton.icon(
        onPressed: () => _extendContract(employee),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF17263D),
          side: const BorderSide(color: Color(0xFFD8E0EB)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.event_repeat_outlined, size: 18),
        label: const Text(
          'Extend Contract',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
    return Wrap(spacing: 12, runSpacing: 12, children: buttons);
  }

  String _linkedUserLabel(Employee employee, AppUser? linkedUser) {
    if (linkedUser != null || employee.hasLogin || employee.userId != null) {
      return 'Login account already linked';
    }
    switch (employee.invitationStatus) {
      case InvitationStatus.notInvited:
        return 'Login invitation not sent';
      case InvitationStatus.inviteSent:
        return 'Login invitation sent';
      case InvitationStatus.inviteFailed:
        return 'Login invitation needs attention';
      case InvitationStatus.passwordChanged:
        return 'Password has been set';
      case InvitationStatus.active:
        return 'Login account already linked';
    }
  }

  String _probationStatusLabel(Employee employee) {
    if (employee.isProbationConfirmed) return 'Confirmed';
    if (employee.probationEndDate == null) return 'Not set';
    final days = employee.probationEndDate!.difference(DateTime.now()).inDays;
    if (days < 0) {
      return 'Expired ${days.abs()} day${days.abs() == 1 ? '' : 's'} ago';
    }
    if (days == 0) return 'Ends today';
    return 'Ending in $days day${days == 1 ? '' : 's'}';
  }

  Color? _probationStatusColor(Employee employee) {
    if (employee.isProbationConfirmed) return AppColors.success;
    if (employee.probationEndDate == null) return null;
    final days = employee.probationEndDate!.difference(DateTime.now()).inDays;
    if (days <= 14) return AppColors.error;
    return const Color(0xFF8A5A00);
  }

  String _safe(String? value) => value?.trim() ?? '';

  Future<void> _editEmployee(Employee employee) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditEmployeeScreen(employee: employee),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      ref.invalidate(employeeProvider(employee.id));
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
      _refreshMeta();
    }
  }

  Future<void> _deleteEmployee(Employee employee) async {
    final reason = await NotificationHelper.showInputDialog(
      context,
      title: 'Delete Reason',
      hint: 'Enter deletion reason (required)',
    );
    if (reason == null || reason.trim().isEmpty || !mounted) return;

    final confirm = await NotificationHelper.showConfirmDialog(
      context,
      title: 'Delete Employee',
      message:
          'Are you sure you want to archive ${employee.fullName}?\n\nReason: ${reason.trim()}',
      confirmText: 'Delete',
      isDangerous: true,
    );

    if (!confirm || !mounted) return;

    NotificationHelper.showLoading(context);
    try {
      await employeeService.deleteEmployee(employee.id, reason: reason.trim());
      if (!mounted) return;
      ref.invalidate(employeeProvider(employee.id));
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Employee archived');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, e.toString());
    }
  }

  Future<void> _inviteEmployeeToLogin(Employee employee) async {
    final email = employee.email.trim();
    if (email.isEmpty) {
      NotificationHelper.showError(
        context,
        'This employee has no email address for invitation.',
      );
      return;
    }

    final confirm = await NotificationHelper.showConfirmDialog(
      context,
      title: 'Send Login Invitation',
      message:
          'Send a login invitation to $email?\n\nThe employee will receive a password reset email to set a password.',
      confirmText: 'Send Invite',
    );
    if (!confirm || !mounted) return;

    NotificationHelper.showLoading(context, message: 'Sending invitation...');
    try {
      await invitationService.inviteEmployee(employee);
      if (!mounted) return;
      ref.invalidate(employeeProvider(employee.id));
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
      _refreshMeta();
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Invitation sent to $email.');
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, e.toString());
    }
  }

  Future<void> _resetAndUpdateEmail(Employee employee) async {
    final newEmail = await NotificationHelper.showInputDialog(
      context,
      title: 'Update Email & Reset',
      hint: 'Enter corrected email address',
      initialValue: employee.email,
    );

    if (!mounted || newEmail == null || newEmail.trim().isEmpty) return;

    NotificationHelper.showLoading(context, message: 'Updating invitation...');
    try {
      await invitationService.updateEmailAndReset(employee.id, newEmail.trim());
      if (!mounted) return;
      ref.invalidate(employeeProvider(employee.id));
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
      _refreshMeta();
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Email updated and invitation reset.',
      );
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, e.toString());
    }
  }

  Future<void> _confirmProbation(Employee employee) async {
    final confirmed = await NotificationHelper.showConfirmDialog(
      context,
      title: 'Confirm Probation',
      message:
          'Confirm probation for ${employee.fullName}? This marks the employee as confirmed.',
      confirmText: 'Confirm',
    );
    if (!confirmed || !mounted) return;

    final updated = employee.copyWith(
      isProbationConfirmed: true,
      employmentType: employee.employmentType == EmploymentType.probation
          ? EmploymentType.permanent
          : employee.employmentType,
    );
    await _updateLifecycle(
      updated,
      successMessage: 'Probation confirmed successfully.',
    );
  }

  Future<void> _extendContract(Employee employee) async {
    final baseline = employee.contractEndDate ?? DateTime.now();
    final initialDate = baseline.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(days: 30))
        : baseline.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null || !mounted) return;

    final updated = employee.copyWith(
      contractEndDate: picked,
      employmentType: employee.employmentType == EmploymentType.permanent
          ? EmploymentType.contract
          : employee.employmentType,
    );
    await _updateLifecycle(
      updated,
      successMessage: 'Contract end date updated successfully.',
    );
  }

  Future<void> _updateLifecycle(
    Employee updated, {
    required String successMessage,
  }) async {
    NotificationHelper.showLoading(context, message: 'Saving changes...');
    try {
      await employeeService.updateEmployee(updated);
      if (!mounted) return;
      ref.invalidate(employeeProvider(updated.id));
      ref.invalidate(employeeListProvider);
      ref.invalidate(dashboardSummaryProvider);
      _refreshMeta();
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, successMessage);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, e.toString());
    }
  }
}

class _EmployeeDetailPermissions {
  final bool canEdit;
  final bool canDelete;
  final bool canViewSalary;
  final bool canViewDeductions;
  final bool canManageLifecycle;
  final bool canManageInvitations;
  final bool canViewSensitive;

  const _EmployeeDetailPermissions({
    required this.canEdit,
    required this.canDelete,
    required this.canViewSalary,
    required this.canViewDeductions,
    required this.canManageLifecycle,
    required this.canManageInvitations,
    required this.canViewSensitive,
  });

  factory _EmployeeDetailPermissions.fromUser(AppUser user) {
    final canEdit = PermissionService.hasPermission(
      user,
      Permission.editEmployee,
    );
    final canManageUsers = PermissionService.hasPermission(
      user,
      Permission.manageUsers,
    );
    final canViewSalary = PermissionService.hasPermission(
      user,
      Permission.viewPayroll,
    );
    return _EmployeeDetailPermissions(
      canEdit: canEdit,
      canDelete: PermissionService.hasPermission(
        user,
        Permission.deleteEmployee,
      ),
      canViewSalary: canViewSalary,
      canViewDeductions:
          PermissionService.hasPermission(user, Permission.viewDeductions) ||
          canViewSalary,
      canManageLifecycle:
          PermissionService.hasPermission(user, Permission.manageProbation) ||
          PermissionService.hasPermission(user, Permission.approveContract) ||
          canEdit,
      canManageInvitations: canEdit || canManageUsers,
      canViewSensitive: canViewSalary || canManageUsers || canEdit,
    );
  }
}

class _EmployeeDetailMeta {
  final AppUser? linkedUser;
  final double totalMonthlyDeductions;
  final int activeDeductionCount;

  const _EmployeeDetailMeta({
    required this.linkedUser,
    required this.totalMonthlyDeductions,
    required this.activeDeductionCount,
  });

  const _EmployeeDetailMeta.empty()
    : linkedUser = null,
      totalMonthlyDeductions = 0,
      activeDeductionCount = 0;
}

class _DetailGrid extends StatelessWidget {
  final bool compact;
  final List<Widget> children;

  const _DetailGrid({required this.compact, required this.children});

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: child,
              ),
            )
            .toList(),
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 28),
            Expanded(
              child: i + 1 < children.length
                  ? children[i + 1]
                  : const SizedBox(),
            ),
          ],
        ),
      );
    }

    return Column(
      children: rows
          .map(
            (row) =>
                Padding(padding: const EdgeInsets.only(bottom: 22), child: row),
          )
          .toList(),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF90A3BE), size: 24),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.1,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF667A96),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: valueColor ?? const Color(0xFF0A1730),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  final String name;
  final String seed;

  const _AvatarBadge({required this.name, required this.seed});

  @override
  Widget build(BuildContext context) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : parts.length == 1
        ? parts.first[0].toUpperCase()
        : '${parts.first[0]}${parts.last[0]}'.toUpperCase();

    return Container(
      width: 102,
      height: 102,
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A1730).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: Color(0xFF8FA2BC),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;

  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD9F8E7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w800,
          color: Color(0xFF0B8F54),
        ),
      ),
    );
  }
}
