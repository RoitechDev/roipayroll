import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/expense_claim_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/expense_service.dart';
import 'package:roipayroll/services/permission_service.dart';

class ExpenseData {
  final AppUser? user;
  final bool canApprove;
  final bool canViewAll;
  final bool canSubmit;
  final List<ExpenseClaim> myClaims;
  final List<ExpenseClaim> pendingClaims;
  final List<ExpenseClaim> allClaims;

  const ExpenseData({
    required this.user,
    required this.canApprove,
    required this.canViewAll,
    required this.canSubmit,
    required this.myClaims,
    required this.pendingClaims,
    required this.allClaims,
  });
}

final expenseDataProvider = FutureProvider<ExpenseData>((ref) async {
  ref.watch(appRefreshProvider); // manual button
  // don't watch auto-refresh unless needed
  // ref.watch(appAutoRefreshProvider);

  final user = await ref.watch(currentUserProvider.future);

  if (user == null) {
    return const ExpenseData(
      user: null,
      canApprove: false,
      canViewAll: false,
      canSubmit: false,
      myClaims: <ExpenseClaim>[],
      pendingClaims: <ExpenseClaim>[],
      allClaims: <ExpenseClaim>[],
    );
  }

  final canApprove = PermissionService.hasPermission(
    user,
    Permission.approveExpenses,
  );
  final canViewAll = user.role != UserRole.employee;
  final canSubmit = (user.employeeId ?? '').trim().isNotEmpty;

  final service = ExpenseService();
  final myClaims = !canSubmit
      ? <ExpenseClaim>[]
      : await service.getEmployeeExpenses(user.employeeId!.trim());
  final pendingClaims = canApprove
      ? await service.getPendingExpenses()
      : <ExpenseClaim>[];
  final allClaims = canViewAll ? await service.getAllExpenses() : myClaims;

  return ExpenseData(
    user: user,
    canApprove: canApprove,
    canViewAll: canViewAll,
    canSubmit: canSubmit,
    myClaims: myClaims,
    pendingClaims: pendingClaims,
    allClaims: allClaims,
  );
});

void refreshExpenses(WidgetRef ref) {
  ref.invalidate(expenseDataProvider);
  ref
      .read(appManualRefreshControllerProvider)
      .add(DateTime.now().millisecondsSinceEpoch);
}

final expenseActionsProvider = Provider<ExpenseActions>((ref) {
  return ExpenseActions(ref);
});

class ExpenseActions {
  final Ref _ref;
  final _service = ExpenseService();

  ExpenseActions(this._ref);

  Future<void> submit({
    required String employeeId,
    required String employeeName,
    required ExpenseCategory category,
    required double amount,
    required String description,
    required DateTime expenseDate,
    String? receiptUrl,
    String? receiptName,
  }) async {
    await _service.submitExpense(
      employeeId: employeeId,
      employeeName: employeeName,
      category: category,
      amount: amount,
      description: description,
      expenseDate: expenseDate,
      receiptUrl: receiptUrl,
      receiptName: receiptName,
    );
    _ref.invalidate(expenseDataProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> approve(ExpenseClaim claim) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.approveExpense(claim.id, user.id, user.name);
    _ref.invalidate(expenseDataProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> reject(ExpenseClaim claim, String reason) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.rejectExpense(claim.id, user.id, user.name, reason);
    _ref.invalidate(expenseDataProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }
}
