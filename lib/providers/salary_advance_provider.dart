import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/salary_advance_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/salary_advance_service.dart';

enum SalaryAdvanceRoleScope {
  employee,
  hrApprover,
  financeApprover,
  adminOversight,
}

class SalaryAdvanceData {
  final AppUser? user;
  final SalaryAdvanceRoleScope scope;
  final bool canRequest;
  final bool canApprove;
  final List<SalaryAdvance> visibleAdvances;
  final List<SalaryAdvance> myAdvances;

  const SalaryAdvanceData({
    required this.user,
    required this.scope,
    required this.canRequest,
    required this.canApprove,
    required this.visibleAdvances,
    required this.myAdvances,
  });

  String? get employeeId {
    final value = user?.employeeId?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  bool get hasEmployeeProfile => employeeId != null;

  List<SalaryAdvance> get pendingAdvances =>
      _byStatus(SalaryAdvanceStatus.pending);
  List<SalaryAdvance> get approvedAdvances =>
      _byStatus(SalaryAdvanceStatus.approved);
  List<SalaryAdvance> get rejectedAdvances =>
      _byStatus(SalaryAdvanceStatus.rejected);
  List<SalaryAdvance> get recoveredAdvances =>
      _byStatus(SalaryAdvanceStatus.recovered);
  List<SalaryAdvance> get cancelledAdvances =>
      _byStatus(SalaryAdvanceStatus.cancelled);

  List<SalaryAdvance> _byStatus(SalaryAdvanceStatus status) {
    return visibleAdvances
        .where((advance) => advance.status == status)
        .toList();
  }
}

final salaryAdvanceDataProvider = FutureProvider<SalaryAdvanceData>((
  ref,
) async {
  ref.watch(appRefreshProvider);

  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return const SalaryAdvanceData(
      user: null,
      scope: SalaryAdvanceRoleScope.employee,
      canRequest: false,
      canApprove: false,
      visibleAdvances: <SalaryAdvance>[],
      myAdvances: <SalaryAdvance>[],
    );
  }

  final canApprove = PermissionService.hasPermission(
    user,
    Permission.approveSalaryAdvance,
  );
  final canRequest = user.role == UserRole.employee;
  final service = SalaryAdvanceService();
  final employeeId = user.employeeId?.trim() ?? '';

  final visibleAdvances = canApprove
      ? await service.getAllAdvances()
      : employeeId.isEmpty
      ? <SalaryAdvance>[]
      : await service.getEmployeeAdvances(employeeId);

  final myAdvances = employeeId.isEmpty
      ? <SalaryAdvance>[]
      : canApprove
      ? visibleAdvances
            .where((advance) => advance.employeeId == employeeId)
            .toList()
      : visibleAdvances;

  return SalaryAdvanceData(
    user: user,
    scope: switch (user.role) {
      UserRole.admin => SalaryAdvanceRoleScope.adminOversight,
      UserRole.hr => SalaryAdvanceRoleScope.hrApprover,
      UserRole.accountant => SalaryAdvanceRoleScope.financeApprover,
      UserRole.employee => SalaryAdvanceRoleScope.employee,
    },
    canRequest: canRequest,
    canApprove: canApprove,
    visibleAdvances: visibleAdvances,
    myAdvances: myAdvances,
  );
});

final salaryAdvanceActionsProvider = Provider<SalaryAdvanceActions>((ref) {
  return SalaryAdvanceActions(ref);
});

class SalaryAdvanceActions {
  final Ref _ref;
  final _service = SalaryAdvanceService();

  SalaryAdvanceActions(this._ref);

  void refresh() {
    _ref.invalidate(salaryAdvanceDataProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> submit({
    required String employeeId,
    required double amount,
    required String reason,
  }) async {
    await _service.requestSalaryAdvance(
      employeeId: employeeId,
      amount: amount,
      reason: reason,
    );
    refresh();
  }

  Future<void> approve(SalaryAdvance advance) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.approveSalaryAdvance(advance.id, user);
    refresh();
  }

  Future<void> reject(SalaryAdvance advance, String reason) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.rejectSalaryAdvance(advance.id, user, reason);
    refresh();
  }
}
