import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/exit_clearance_model.dart';
import 'package:roipayroll/models/exit_management_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/exit_clearance_service.dart';
import 'package:roipayroll/services/exit_management_service.dart';
import 'package:roipayroll/services/permission_service.dart';

enum ExitRoleScope { employee, reviewer, finance }

class ExitManagementData {
  final AppUser? user;
  final ExitRoleScope scope;
  final bool canRequest;
  final bool canReview;
  final bool canInitiateTermination;
  final bool canViewSettlement;
  final List<ExitRequest> visibleRequests;
  final List<ExitRequest> myRequests;
  final Map<String, List<ClearanceItem>> clearanceByRequestId;

  const ExitManagementData({
    required this.user,
    required this.scope,
    required this.canRequest,
    required this.canReview,
    required this.canInitiateTermination,
    required this.canViewSettlement,
    required this.visibleRequests,
    required this.myRequests,
    required this.clearanceByRequestId,
  });

  String? get employeeId {
    final value = user?.employeeId?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  bool get hasEmployeeProfile => employeeId != null;

  List<ExitRequest> get pendingRequests => _byStatus(ExitStatus.pending);
  List<ExitRequest> get approvedRequests => _byStatus(ExitStatus.approved);
  List<ExitRequest> get rejectedRequests => _byStatus(ExitStatus.rejected);
  List<ExitRequest> get completedRequests => _byStatus(ExitStatus.completed);

  List<ExitRequest> _byStatus(ExitStatus status) {
    return visibleRequests
        .where((request) => request.status == status)
        .toList();
  }

  List<ClearanceItem> clearanceFor(String requestId) {
    return clearanceByRequestId[requestId] ?? const <ClearanceItem>[];
  }

  int clearanceCompletedCount(String requestId) {
    return clearanceFor(requestId)
        .where(
          (item) =>
              item.status == ClearanceStatus.cleared ||
              item.status == ClearanceStatus.notApplicable,
        )
        .length;
  }

  bool isFullyCleared(String requestId) {
    final items = clearanceFor(requestId);
    if (items.isEmpty) return false;
    return items.every(
      (item) =>
          item.status == ClearanceStatus.cleared ||
          item.status == ClearanceStatus.notApplicable,
    );
  }
}

final exitManagementDataProvider = FutureProvider<ExitManagementData>((
  ref,
) async {
  ref.watch(appRefreshProvider);

  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return const ExitManagementData(
      user: null,
      scope: ExitRoleScope.employee,
      canRequest: false,
      canReview: false,
      canInitiateTermination: false,
      canViewSettlement: false,
      visibleRequests: <ExitRequest>[],
      myRequests: <ExitRequest>[],
      clearanceByRequestId: <String, List<ClearanceItem>>{},
    );
  }

  final service = ExitManagementService();
  final clearanceService = ExitClearanceService();
  final canReview = PermissionService.hasPermission(
    user,
    Permission.approveExitManagement,
  );
  final canViewSettlement = user.role == UserRole.accountant;
  final canInitiateTermination = canReview;
  final canRequest = user.role == UserRole.employee;
  final scope = canReview
      ? ExitRoleScope.reviewer
      : canViewSettlement
      ? ExitRoleScope.finance
      : ExitRoleScope.employee;

  final employeeId = user.employeeId?.trim() ?? '';
  final visibleRequests = switch (scope) {
    ExitRoleScope.reviewer => await service.getAllExitRequests(),
    ExitRoleScope.finance => await service.getExitRequestsByStatuses(const {
      ExitStatus.approved,
      ExitStatus.completed,
    }),
    ExitRoleScope.employee =>
      employeeId.isEmpty
          ? <ExitRequest>[]
          : await service.getEmployeeExitRequests(employeeId),
  };

  final myRequests = employeeId.isEmpty
      ? <ExitRequest>[]
      : scope == ExitRoleScope.employee
      ? visibleRequests
      : visibleRequests
            .where((request) => request.employeeId == employeeId)
            .toList();

  final clearanceRequestIds = visibleRequests
      .where(
        (request) =>
            request.status == ExitStatus.approved ||
            request.status == ExitStatus.completed,
      )
      .map((request) => request.id)
      .toSet();

  final clearanceByRequestId = <String, List<ClearanceItem>>{};
  for (final requestId in clearanceRequestIds) {
    clearanceByRequestId[requestId] = await clearanceService.getClearanceItems(
      requestId,
    );
  }

  return ExitManagementData(
    user: user,
    scope: scope,
    canRequest: canRequest,
    canReview: canReview,
    canInitiateTermination: canInitiateTermination,
    canViewSettlement: canViewSettlement,
    visibleRequests: visibleRequests,
    myRequests: myRequests,
    clearanceByRequestId: clearanceByRequestId,
  );
});

final exitManagementActionsProvider = Provider<ExitManagementActions>((ref) {
  return ExitManagementActions(ref);
});

class ExitManagementActions {
  final Ref _ref;
  final _service = ExitManagementService();

  ExitManagementActions(this._ref);

  void refresh() {
    _ref.invalidate(exitManagementDataProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> submit({
    required String employeeId,
    required DateTime resignationDate,
    required DateTime lastWorkingDate,
    required String reason,
    ExitType exitType = ExitType.resignation,
    int? noticePeriodDays,
  }) async {
    await _service.submitExitRequest(
      employeeId: employeeId,
      resignationDate: resignationDate,
      lastWorkingDate: lastWorkingDate,
      reason: reason,
      exitType: exitType,
      noticePeriodDays: noticePeriodDays,
    );
    refresh();
  }

  Future<void> approve(
    ExitRequest request, {
    bool? eligibleForRehire,
    String? rehireRemarks,
    String? performanceRating,
  }) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.updateExitStatus(
      request.id,
      ExitStatus.approved,
      reviewedBy: user.id,
      eligibleForRehire: eligibleForRehire,
      rehireRemarks: rehireRemarks,
      performanceRating: performanceRating,
    );
    refresh();
  }

  Future<void> reject(ExitRequest request, String reason) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.updateExitStatus(
      request.id,
      ExitStatus.rejected,
      reviewedBy: user.id,
      rejectionReason: reason,
    );
    refresh();
  }

  Future<void> complete(ExitRequest request) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.updateExitStatus(
      request.id,
      ExitStatus.completed,
      reviewedBy: user.id,
    );
    refresh();
  }

  Future<void> initiateTermination({
    required String employeeId,
    required DateTime terminationDate,
    required String reason,
    ExitType exitType = ExitType.termination,
    bool? eligibleForRehire,
    String? rehireRemarks,
  }) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) throw Exception('User profile not found.');
    await _service.initiateTermination(
      employeeId: employeeId,
      initiatedBy: user.id,
      terminationDate: terminationDate,
      reason: reason,
      exitType: exitType,
      eligibleForRehire: eligibleForRehire,
      rehireRemarks: rehireRemarks,
    );
    refresh();
  }
}
