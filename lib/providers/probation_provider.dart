import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/probation_service.dart';

class ProbationDashboardData {
  final AppUser? user;
  final bool canManage;
  final List<Employee> dueProbationEmployees;
  final List<Employee> expiringContractEmployees;

  const ProbationDashboardData({
    required this.user,
    required this.canManage,
    required this.dueProbationEmployees,
    required this.expiringContractEmployees,
  });
}

final probationDashboardProvider = FutureProvider<ProbationDashboardData>((
  ref,
) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return const ProbationDashboardData(
      user: null,
      canManage: false,
      dueProbationEmployees: <Employee>[],
      expiringContractEmployees: <Employee>[],
    );
  }

  final canManage = user.role == UserRole.admin || user.role == UserRole.hr;
  final service = ProbationService();
  final dueProbation = canManage
      ? await service.getEmployeesDueProbation(withinDays: 30)
      : <Employee>[];
  final expiringContracts = canManage
      ? await service.getEmployeesWithExpiringContracts(withinDays: 30)
      : <Employee>[];

  return ProbationDashboardData(
    user: user,
    canManage: canManage,
    dueProbationEmployees: dueProbation,
    expiringContractEmployees: expiringContracts,
  );
});

final probationActionsProvider = Provider<ProbationActions>((ref) {
  return ProbationActions(ref);
});

class ProbationActions {
  final Ref _ref;
  final ProbationService _service = ProbationService();

  ProbationActions(this._ref);

  Future<Map<String, int>> sendLifecycleReminders({int withinDays = 30}) async {
    final result = await _service.sendLifecycleReminders(
      withinDays: withinDays,
    );
    _ref.invalidate(probationDashboardProvider);
    _ref.read(appManualRefreshControllerProvider).add(DateTime.now().millisecondsSinceEpoch);
    return result;
  }
}

