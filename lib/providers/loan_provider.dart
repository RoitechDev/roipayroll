import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/loan_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/loan_service.dart';
import 'package:roipayroll/services/permission_service.dart';

enum LoanRoleScope { employee, reviewer, approver }

class LoanDashboardData {
  final AppUser? user;
  final LoanRoleScope scope;
  final bool canRequest;
  final bool canApprove;
  final bool canViewAll;
  final List<Loan> visibleLoans;
  final List<Loan> myLoans;

  const LoanDashboardData({
    required this.user,
    required this.scope,
    required this.canRequest,
    required this.canApprove,
    required this.canViewAll,
    required this.visibleLoans,
    required this.myLoans,
  });

  String? get employeeId {
    final value = user?.employeeId?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  bool get hasEmployeeProfile => employeeId != null;

  List<Loan> get pendingLoans => _byStatus(LoanStatus.pending);
  List<Loan> get activeLoans => _byStatus(LoanStatus.active);
  List<Loan> get completedLoans => _byStatus(LoanStatus.completed);
  List<Loan> get rejectedLoans => _byStatus(LoanStatus.rejected);

  List<Loan> _byStatus(LoanStatus status) {
    return visibleLoans.where((loan) => loan.status == status).toList();
  }
}

final loanDashboardProvider = FutureProvider<LoanDashboardData>((ref) async {
  ref.watch(appRefreshProvider);

  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return const LoanDashboardData(
      user: null,
      scope: LoanRoleScope.employee,
      canRequest: false,
      canApprove: false,
      canViewAll: false,
      visibleLoans: <Loan>[],
      myLoans: <Loan>[],
    );
  }

  final canApprove = PermissionService.hasPermission(
    user,
    Permission.approveLoan,
  );
  final canViewAll = canApprove || user.role == UserRole.hr;
  final canRequest =
      PermissionService.hasPermission(user, Permission.viewLoans) &&
      (user.employeeId?.trim().isNotEmpty ?? false);
  final scope = canApprove
      ? LoanRoleScope.approver
      : canViewAll
      ? LoanRoleScope.reviewer
      : LoanRoleScope.employee;

  final service = LoanService();
  final employeeId = user.employeeId?.trim() ?? '';

  final visibleLoans = canViewAll
      ? await service.getAllLoans()
      : employeeId.isEmpty
      ? <Loan>[]
      : await service.getEmployeeLoans(employeeId);

  final myLoans = employeeId.isEmpty
      ? <Loan>[]
      : visibleLoans.where((loan) => loan.employeeId == employeeId).toList();

  return LoanDashboardData(
    user: user,
    scope: scope,
    canRequest: canRequest,
    canApprove: canApprove,
    canViewAll: canViewAll,
    visibleLoans: visibleLoans,
    myLoans: myLoans,
  );
});

final loanActionsProvider = Provider<LoanActions>((ref) {
  return LoanActions(ref);
});

class LoanActions {
  final Ref _ref;
  final LoanService _service = LoanService();

  LoanActions(this._ref);

  void refresh() {
    _ref.invalidate(loanDashboardProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> approve(Loan loan) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');

    await _service.approveLoan(loan.id, user);
    refresh();
  }

  Future<void> reject(Loan loan, String reason) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');

    await _service.rejectLoan(loan.id, user, reason);
    refresh();
  }

  Future<int> backfillNames() async {
    final updated = await _service.backfillLoanEmployeeNames();
    refresh();
    return updated;
  }
}
