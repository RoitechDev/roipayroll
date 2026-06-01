import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/leave_balance_model.dart';
import 'package:roipayroll/models/leave_encashment_model.dart';
import 'package:roipayroll/models/leave_request_model.dart';
import 'package:roipayroll/models/leave_type_model.dart';
import 'package:roipayroll/models/public_holiday_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/leave_balance_service.dart';
import 'package:roipayroll/services/leave_encashment_service.dart';
import 'package:roipayroll/services/leave_request_service.dart';
import 'package:roipayroll/services/leave_type_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/public_holiday_service.dart';

class LeaveDashboardData {
  final List<LeaveBalance> balances;
  final List<LeaveRequest> recentRequests;

  const LeaveDashboardData({
    required this.balances,
    required this.recentRequests,
  });
}

final leaveDashboardProvider = FutureProvider<LeaveDashboardData>((ref) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  final employeeId = user?.employeeId;
  if (employeeId == null || employeeId.isEmpty) {
    return const LeaveDashboardData(balances: [], recentRequests: []);
  }

  final leaveBalanceService = LeaveBalanceService();
  final leaveRequestService = LeaveRequestService();
  final results = await Future.wait<dynamic>([
    leaveBalanceService.getEmployeeLeaveBalances(employeeId),
    leaveRequestService.getEmployeeLeaveRequests(employeeId, limit: 5),
  ]);

  return LeaveDashboardData(
    balances: results[0] as List<LeaveBalance>,
    recentRequests: results[1] as List<LeaveRequest>,
  );
});

final pendingLeaveRequestsProvider = StreamProvider<List<LeaveRequest>>((ref) {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  return LeaveRequestService().getPendingLeaveRequestsStream();
});

class LeaveBalancesQuery {
  final int year;

  const LeaveBalancesQuery({required this.year});

  @override
  bool operator ==(Object other) {
    return other is LeaveBalancesQuery && other.year == year;
  }

  @override
  int get hashCode => year.hashCode;
}

class LeaveBalancesData {
  final bool canViewAll;
  final List<LeaveBalance> balances;

  const LeaveBalancesData({required this.canViewAll, required this.balances});
}

final leaveBalancesProvider =
    FutureProvider.family<LeaveBalancesData, LeaveBalancesQuery>((
      ref,
      query,
    ) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);
      final user = await ref.watch(currentUserProvider.future);
      final canViewAll =
          user != null &&
          PermissionService.hasPermission(user, Permission.approveLeave);

      final balances = canViewAll
          ? await LeaveBalanceService().getAllLeaveBalances(query.year)
          : <LeaveBalance>[];

      return LeaveBalancesData(canViewAll: canViewAll, balances: balances);
    });

class MyLeavesData {
  final String? employeeId;
  final List<LeaveRequest> requests;

  const MyLeavesData({required this.employeeId, required this.requests});
}

final myLeavesProvider = FutureProvider<MyLeavesData>((ref) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  final employeeId = user?.employeeId;
  if (employeeId == null || employeeId.isEmpty) {
    return const MyLeavesData(employeeId: null, requests: []);
  }

  final requests = await LeaveRequestService().getEmployeeLeaveRequests(
    employeeId,
  );
  return MyLeavesData(employeeId: employeeId, requests: requests);
});

class PublicHolidaysQuery {
  final int year;

  const PublicHolidaysQuery({required this.year});

  @override
  bool operator ==(Object other) {
    return other is PublicHolidaysQuery && other.year == year;
  }

  @override
  int get hashCode => year.hashCode;
}

class PublicHolidaysData {
  final bool canManage;
  final List<PublicHoliday> holidays;

  const PublicHolidaysData({required this.canManage, required this.holidays});
}

final publicHolidaysProvider =
    FutureProvider.family<PublicHolidaysData, PublicHolidaysQuery>((
      ref,
      query,
    ) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);
      final user = await ref.watch(currentUserProvider.future);
      final canManage =
          user != null &&
          PermissionService.hasPermission(user, Permission.manageLeaveTypes);
      final holidays = await PublicHolidayService().getHolidaysByYear(
        query.year,
      );
      holidays.sort((a, b) => a.date.compareTo(b.date));
      return PublicHolidaysData(canManage: canManage, holidays: holidays);
    });

class LeaveTypesData {
  final bool canManage;
  final List<LeaveType> leaveTypes;

  const LeaveTypesData({required this.canManage, required this.leaveTypes});
}

final leaveTypesProvider = FutureProvider<LeaveTypesData>((ref) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  final canManage =
      user != null &&
      PermissionService.hasPermission(user, Permission.manageLeaveTypes);
  final leaveTypes = canManage
      ? await LeaveTypeService().getAllLeaveTypes()
      : <LeaveType>[];
  return LeaveTypesData(canManage: canManage, leaveTypes: leaveTypes);
});

class LeaveEncashmentData {
  final bool canManage;
  final List<LeaveEncashment> pendingRequests;
  final List<LeaveEncashment> processedRequests;

  const LeaveEncashmentData({
    required this.canManage,
    required this.pendingRequests,
    required this.processedRequests,
  });
}

final leaveEncashmentProvider = FutureProvider<LeaveEncashmentData>((
  ref,
) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  final canManage =
      user != null &&
      PermissionService.hasPermission(user, Permission.approveLeave);

  if (!canManage) {
    return const LeaveEncashmentData(
      canManage: false,
      pendingRequests: <LeaveEncashment>[],
      processedRequests: <LeaveEncashment>[],
    );
  }

  final service = LeaveEncashmentService();
  final results = await Future.wait<dynamic>([
    service.getPendingEncashments(),
    service.getProcessedEncashments(),
  ]);
  return LeaveEncashmentData(
    canManage: true,
    pendingRequests: results[0] as List<LeaveEncashment>,
    processedRequests: results[1] as List<LeaveEncashment>,
  );
});

class ApplyLeaveData {
  final String? employeeId;
  final String employeeName;
  final List<LeaveType> leaveTypes;
  final List<LeaveBalance> balances;

  const ApplyLeaveData({
    required this.employeeId,
    required this.employeeName,
    required this.leaveTypes,
    required this.balances,
  });
}

final applyLeaveDataProvider = FutureProvider<ApplyLeaveData>((ref) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final user = await ref.watch(currentUserProvider.future);
  final leaveTypeService = LeaveTypeService();
  await leaveTypeService.seedDefaultLeaveTypesIfEmpty();

  final leaveTypes = await leaveTypeService.getActiveLeaveTypes();
  final balances = user?.employeeId != null
      ? await LeaveBalanceService().getEmployeeLeaveBalances(user!.employeeId!)
      : <LeaveBalance>[];

  return ApplyLeaveData(
    employeeId: user?.employeeId,
    employeeName: user?.name ?? '',
    leaveTypes: leaveTypes.isNotEmpty
        ? leaveTypes
        : LeaveType.defaultLeaveTypes,
    balances: balances,
  );
});

final leaveApprovalActionsProvider = Provider<LeaveApprovalActions>((ref) {
  return LeaveApprovalActions(ref);
});

class LeaveApprovalActions {
  final Ref _ref;
  final LeaveRequestService _leaveRequestService = LeaveRequestService();

  LeaveApprovalActions(this._ref);

  Future<void> approve(LeaveRequest request) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) {
      throw Exception('User profile not found.');
    }

    await _leaveRequestService.approveLeaveRequest(
      request.id,
      user.id,
      user.name,
    );
    _ref.invalidate(pendingLeaveRequestsProvider);
    _ref.read(appManualRefreshControllerProvider).add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> reject(LeaveRequest request, String remarks) async {
    final user = await _ref.read(currentUserProvider.future);
    if (user == null) {
      throw Exception('User profile not found.');
    }

    await _leaveRequestService.rejectLeaveRequest(
      request.id,
      user.id,
      user.name,
      remarks,
    );
    _ref.invalidate(pendingLeaveRequestsProvider);
    _ref.read(appManualRefreshControllerProvider).add(DateTime.now().millisecondsSinceEpoch);
  }
}

