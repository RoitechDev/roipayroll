import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/incentive_entry_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/incentive_service.dart';

class IncentiveData {
  final AppUser? user;
  final bool canApprove;
  final List<IncentiveEntry> myEntries;
  final List<IncentiveEntry> pendingEntries;

  const IncentiveData({
    required this.user,
    required this.canApprove,
    required this.myEntries,
    required this.pendingEntries,
  });
}

final incentiveDataProvider = FutureProvider<IncentiveData>((ref) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return const IncentiveData(
      user: null,
      canApprove: false,
      myEntries: <IncentiveEntry>[],
      pendingEntries: <IncentiveEntry>[],
    );
  }

  final canApprove =
      user.role == UserRole.admin ||
      user.role == UserRole.hr ||
      user.role == UserRole.accountant;

  final service = IncentiveService();
  final myEntries = (user.employeeId ?? '').trim().isEmpty
      ? <IncentiveEntry>[]
      : await service.getEmployeeIncentives(user.employeeId!.trim());
  final pendingEntries = canApprove
      ? await service.getPendingIncentives()
      : <IncentiveEntry>[];

  return IncentiveData(
    user: user,
    canApprove: canApprove,
    myEntries: myEntries,
    pendingEntries: pendingEntries,
  );
});

final incentiveActionsProvider = Provider<IncentiveActions>((ref) {
  return IncentiveActions(ref);
});

class IncentiveActions {
  final Ref _ref;
  final _service = IncentiveService();

  IncentiveActions(this._ref);

  Future<void> submit({
    required String employeeId,
    required String employeeName,
    required IncentiveType type,
    required double amount,
    required String description,
    required DateTime incentiveDate,
    double? salesAmount,
    double? commissionRatePercent,
    String? tierName,
    String? performancePeriod,
  }) async {
    await _service.submitIncentive(
      employeeId: employeeId,
      employeeName: employeeName,
      type: type,
      amount: amount,
      description: description,
      incentiveDate: incentiveDate,
      salesAmount: salesAmount,
      commissionRatePercent: commissionRatePercent,
      tierName: tierName,
      performancePeriod: performancePeriod,
    );
    _ref.invalidate(incentiveDataProvider);
    _ref.read(appManualRefreshControllerProvider).add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> approve(IncentiveEntry entry) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.approveIncentive(entry.id, user.id, user.name);
    _ref.invalidate(incentiveDataProvider);
    _ref.read(appManualRefreshControllerProvider).add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> reject(IncentiveEntry entry, String reason) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.rejectIncentive(entry.id, user.id, user.name, reason);
    _ref.invalidate(incentiveDataProvider);
    _ref.read(appManualRefreshControllerProvider).add(DateTime.now().millisecondsSinceEpoch);
  }
}

