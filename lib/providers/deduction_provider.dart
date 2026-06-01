import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/employee_deduction_model.dart';
import 'package:roipayroll/models/deduction_transaction_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/user_service_provider.dart';
import 'package:roipayroll/services/deduction_transaction_service.dart';
import 'package:roipayroll/services/employee_deduction_service.dart';
import 'package:roipayroll/services/permission_service.dart';

class DeductionHistoryQuery {
  final DateTime? from;
  final DateTime? to;

  const DeductionHistoryQuery({this.from, this.to});

  @override
  bool operator ==(Object other) {
    return other is DeductionHistoryQuery &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode => Object.hash(from, to);
}

class DeductionHistoryData {
  final bool canViewAll;
  final String? employeeId;
  final List<DeductionTransaction> transactions;

  const DeductionHistoryData({
    required this.canViewAll,
    required this.employeeId,
    required this.transactions,
  });
}

final deductionHistoryProvider =
    FutureProvider.family<DeductionHistoryData, DeductionHistoryQuery>((
      ref,
      query,
    ) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);
      final user = await ref.watch(currentUserProvider.future);
      final canViewAll =
          user != null &&
          PermissionService.hasPermission(user, Permission.manageDeductions);
      final employeeId = user?.employeeId;
      final service = DeductionTransactionService();

      List<DeductionTransaction> transactions;
      if (canViewAll) {
        transactions = await service.getAllTransactions(
          from: query.from,
          to: query.to,
        );
      } else if (employeeId != null && employeeId.isNotEmpty) {
        transactions = await service.getEmployeeTransactions(
          employeeId,
          from: query.from,
          to: query.to,
        );
      } else {
        transactions = [];
      }

      return DeductionHistoryData(
        canViewAll: canViewAll,
        employeeId: employeeId,
        transactions: transactions,
      );
    });

class MyDeductionsData {
  final String? employeeId;
  final List<EmployeeDeduction> deductions;

  const MyDeductionsData({required this.employeeId, required this.deductions});
}

final myDeductionsProvider = FutureProvider<MyDeductionsData>((ref) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  final employeeId = user?.employeeId;
  if (employeeId == null || employeeId.isEmpty) {
    return const MyDeductionsData(employeeId: null, deductions: []);
  }

  final deductions = await EmployeeDeductionService(
    userService: ref.watch(userServiceProvider),
  ).getEmployeeDeductions(employeeId);
  return MyDeductionsData(employeeId: employeeId, deductions: deductions);
});

class EmployeeDeductionsData {
  final bool canManage;
  final String roleLabel;
  final List<EmployeeDeduction> deductions;

  const EmployeeDeductionsData({
    required this.canManage,
    required this.roleLabel,
    required this.deductions,
  });
}

final employeeDeductionsProvider = FutureProvider<EmployeeDeductionsData>((
  ref,
) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  final canManage =
      user != null &&
      PermissionService.hasPermission(user, Permission.manageDeductions);
  final roleLabel = user?.getRoleName() ?? 'Unknown';

  final deductions = canManage
      ? await EmployeeDeductionService(
          userService: ref.watch(userServiceProvider),
        ).getAllDeductions()
      : <EmployeeDeduction>[];

  return EmployeeDeductionsData(
    canManage: canManage,
    roleLabel: roleLabel,
    deductions: deductions,
  );
});
