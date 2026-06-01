import 'package:flutter/foundation.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/expense_claim_model.dart';
import 'package:roipayroll/models/exit_management_model.dart';
import 'package:roipayroll/models/loan_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/exit_clearance_service.dart';
import 'package:roipayroll/services/expense_service.dart';
import 'package:roipayroll/services/leave_balance_service.dart';
import 'package:roipayroll/services/loan_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:uuid/uuid.dart';

class ExitManagementService extends BaseService {
  final String _collection = 'exit_requests';
  final EmployeeService _employeeService = EmployeeService();
  final LeaveBalanceService _leaveBalanceService = LeaveBalanceService();
  final LoanService _loanService = LoanService();
  final ExpenseService _expenseService = ExpenseService();
  final NotificationService _notificationService = NotificationService();
  final ExitClearanceService _clearanceService = ExitClearanceService();
  final UserService _userService = UserService();

  Future<ExitRequest> submitExitRequest({
    required String employeeId,
    required DateTime resignationDate,
    required DateTime lastWorkingDate,
    required String reason,
    ExitType exitType = ExitType.resignation,
    int? noticePeriodDays,
    bool? eligibleForRehire,
    String? rehireRemarks,
  }) async {
    final requester = await _userService.getCurrentUserProfile();
    if (requester == null) {
      throw Exception('User profile not found.');
    }
    PermissionService.requirePermission(
      requester,
      Permission.viewExitManagement,
    );
    if (requester.role != UserRole.employee) {
      throw Exception('Only employees can submit self-service exit requests.');
    }
    final requesterEmployeeId = requester.employeeId?.trim() ?? '';
    if (requesterEmployeeId.isEmpty ||
        requesterEmployeeId != employeeId.trim()) {
      throw Exception(
        'You can only submit an exit request for your own profile.',
      );
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Reason is required.');
    }
    if (lastWorkingDate.isBefore(resignationDate)) {
      throw Exception('Last working date cannot be before resignation date.');
    }

    final employee = await _employeeService.getEmployeeById(employeeId);
    if (employee == null) {
      throw Exception('Employee not found.');
    }

    final resolvedNoticeDays = _resolveNoticePeriodDays(
      employee,
      exitType,
      noticePeriodDays,
    );
    final noticeStartDate = resignationDate;
    final givenNoticeDays = lastWorkingDate.difference(resignationDate).inDays;
    final shortNoticeDays = (resolvedNoticeDays - givenNoticeDays)
        .clamp(0, resolvedNoticeDays)
        .toInt();
    final isShortNotice = shortNoticeDays > 0;
    final resolvedRehireEligibility =
        eligibleForRehire ?? _defaultRehireEligibility(exitType);

    final settlement = await calculateFinalSettlement(
      employeeId,
      lastWorkingDate,
    );
    final now = DateTime.now();
    final request = ExitRequest(
      id: const Uuid().v4(),
      employeeId: employee.id,
      employeeName: employee.fullName,
      resignationDate: resignationDate,
      lastWorkingDate: lastWorkingDate,
      reason: normalizedReason,
      exitType: exitType,
      noticePeriodDays: resolvedNoticeDays,
      noticeStartDate: noticeStartDate,
      isShortNotice: isShortNotice,
      shortNoticeDays: shortNoticeDays,
      eligibleForRehire: resolvedRehireEligibility,
      rehireRemarks: rehireRemarks,
      status: ExitStatus.pending,
      finalSettlement: settlement,
      createdAt: now,
      updatedAt: now,
    );

    final ref = await companyCollection(_collection);
    await ref.doc(request.id).set(request.toJson());
    await _notifyExitReviewTeam(request);
    return request;
  }

  Future<ExitRequest> initiateTermination({
    required String employeeId,
    required String initiatedBy,
    required DateTime terminationDate,
    required String reason,
    ExitType exitType = ExitType.termination,
    bool? eligibleForRehire,
    String? rehireRemarks,
  }) async {
    final reviewer = await _userService.getCurrentUserProfile();
    if (reviewer == null) {
      throw Exception('User profile not found.');
    }
    PermissionService.requirePermission(
      reviewer,
      Permission.approveExitManagement,
    );

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Reason is required.');
    }

    final employee = await _employeeService.getEmployeeById(employeeId);
    if (employee == null) {
      throw Exception('Employee not found.');
    }

    final resolvedRehireEligibility =
        eligibleForRehire ?? _defaultRehireEligibility(exitType);

    final settlement = await calculateFinalSettlement(
      employeeId,
      terminationDate,
    );
    final now = DateTime.now();
    final request = ExitRequest(
      id: const Uuid().v4(),
      employeeId: employee.id,
      employeeName: employee.fullName,
      resignationDate: terminationDate,
      lastWorkingDate: terminationDate,
      reason: normalizedReason,
      exitType: exitType,
      initiatedBy: initiatedBy,
      noticePeriodDays: 0,
      noticeStartDate: terminationDate,
      isShortNotice: false,
      shortNoticeDays: 0,
      eligibleForRehire: resolvedRehireEligibility,
      rehireRemarks: rehireRemarks,
      status: ExitStatus.approved,
      finalSettlement: settlement,
      reviewedBy: initiatedBy,
      reviewedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    final ref = await companyCollection(_collection);
    await ref.doc(request.id).set(request.toJson());
    await _clearanceService.ensureClearanceChecklist(request.id);
    await _notifyExitReviewTeam(request);
    return request;
  }

  Future<List<ExitRequest>> getAllExitRequests() async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((doc) => ExitRequest.fromJson(docData(doc)))
        .toList();
  }

  Future<List<ExitRequest>> getEmployeeExitRequests(String employeeId) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => ExitRequest.fromJson(docData(doc)))
        .toList();
  }

  Future<List<ExitRequest>> getExitRequestsByStatus(ExitStatus status) async {
    return getExitRequestsByStatuses({status});
  }

  Future<List<ExitRequest>> getExitRequestsByStatuses(
    Set<ExitStatus> statuses,
  ) async {
    if (statuses.isEmpty) return <ExitRequest>[];
    final ref = await companyCollection(_collection);
    final snapshot = statuses.length == 1
        ? await ref.where('status', isEqualTo: statuses.first.name).get()
        : await ref
              .where(
                'status',
                whereIn: statuses.map((status) => status.name).toList(),
              )
              .get();
    final requests = snapshot.docs
        .map((doc) => ExitRequest.fromJson(docData(doc)))
        .toList();
    requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return requests;
  }

  Future<ExitRequest?> getExitRequestById(String requestId) async {
    final ref = await companyCollection(_collection);
    final doc = await ref.doc(requestId).get();
    final data = docDataNullable(doc);
    if (data == null) return null;
    return ExitRequest.fromJson(data);
  }

  Future<void> updateExitStatus(
    String requestId,
    ExitStatus status, {
    String? reviewedBy,
    String? rejectionReason,
    bool? eligibleForRehire,
    String? rehireRemarks,
    String? performanceRating,
  }) async {
    final reviewer = await _userService.getCurrentUserProfile();
    if (reviewer == null) {
      throw Exception('User profile not found.');
    }
    PermissionService.requirePermission(
      reviewer,
      Permission.approveExitManagement,
    );

    final existing = await getExitRequestById(requestId);
    if (existing == null) {
      throw Exception('Exit request not found.');
    }
    if (status == ExitStatus.completed &&
        !await _clearanceService.isExitFullyCleared(requestId)) {
      throw Exception(
        'Clearance must be completed before an exit can be marked as completed.',
      );
    }
    if (status == ExitStatus.approved &&
        existing.status != ExitStatus.pending) {
      throw Exception('Only pending exit requests can be approved.');
    }
    if (status == ExitStatus.rejected &&
        existing.status != ExitStatus.pending) {
      throw Exception('Only pending exit requests can be rejected.');
    }
    if (status == ExitStatus.completed &&
        existing.status != ExitStatus.approved) {
      throw Exception('Only approved exit requests can be completed.');
    }

    final normalizedRejectionReason = rejectionReason?.trim();
    if (status == ExitStatus.rejected &&
        (normalizedRejectionReason == null ||
            normalizedRejectionReason.isEmpty)) {
      throw Exception('Rejection reason is required.');
    }

    FinalSettlement? settlement = existing.finalSettlement;
    if (status == ExitStatus.approved || status == ExitStatus.completed) {
      settlement = await calculateFinalSettlement(
        existing.employeeId,
        existing.lastWorkingDate,
      );
    }

    final updated = existing.copyWith(
      status: status,
      finalSettlement: settlement,
      reviewedBy: reviewedBy,
      reviewedAt: DateTime.now(),
      rejectionReason: status == ExitStatus.rejected
          ? normalizedRejectionReason
          : null,
      eligibleForRehire: eligibleForRehire ?? existing.eligibleForRehire,
      rehireRemarks: rehireRemarks ?? existing.rehireRemarks,
      performanceRating: performanceRating ?? existing.performanceRating,
      updatedAt: DateTime.now(),
    );

    final ref = await companyCollection(_collection);
    await ref.doc(requestId).update(updated.toJson());

    if (status == ExitStatus.completed) {
      final employee = await _employeeService.getEmployeeById(
        existing.employeeId,
      );
      if (employee != null) {
        await _employeeService.updateEmployee(
          employee.copyWith(status: 'inactive'),
        );
      }
    }

    if (status == ExitStatus.approved) {
      await _clearanceService.ensureClearanceChecklist(requestId);
    }

    await _notifyEmployeeExitUpdate(updated);
  }

  int _resolveNoticePeriodDays(
    Employee employee,
    ExitType exitType,
    int? overrideDays,
  ) {
    if (exitType == ExitType.termination ||
        exitType == ExitType.absconding ||
        exitType == ExitType.contractExpiry) {
      return 0;
    }
    if (overrideDays != null) return overrideDays;
    return 30;
  }

  bool _defaultRehireEligibility(ExitType exitType) {
    switch (exitType) {
      case ExitType.termination:
      case ExitType.absconding:
        return false;
      default:
        return true;
    }
  }

  Future<FinalSettlement> calculateFinalSettlement(
    String employeeId,
    DateTime lastWorkingDate,
  ) async {
    final employee = await _employeeService.getEmployeeById(employeeId);
    if (employee == null) {
      throw Exception('Employee not found.');
    }

    final yearsWorked =
        lastWorkingDate.difference(employee.hireDate).inDays / 365;
    final completedYears = yearsWorked.isNegative ? 0 : yearsWorked.floor();
    final gratuity = employee.basicSalary * completedYears;

    final leaveBalances = await _leaveBalanceService.getEmployeeLeaveBalances(
      employeeId,
    );
    final totalUnusedLeaveDays = leaveBalances.fold<double>(
      0.0,
      (runningTotal, balance) =>
          runningTotal + (balance.balance > 0 ? balance.balance : 0.0),
    );
    final unusedLeaveValue =
        (totalUnusedLeaveDays / 22.0) * employee.basicSalary;

    final loans = await _loanService.getEmployeeLoans(employeeId);
    final outstandingLoans = loans
        .where(
          (loan) =>
              loan.status == LoanStatus.active ||
              loan.status == LoanStatus.approved,
        )
        .fold<double>(
          0.0,
          (runningTotal, loan) =>
              runningTotal +
              (loan.remainingBalance > 0 ? loan.remainingBalance : 0.0),
        );

    final expenses = await _expenseService.getEmployeeExpenses(employeeId);
    final pendingReimbursements = expenses
        .where(
          (claim) =>
              claim.status == ExpenseStatus.pending ||
              claim.status == ExpenseStatus.approved,
        )
        .fold<double>(
          0.0,
          (runningTotal, claim) => runningTotal + claim.amount,
        );

    final proratedSalary = _calculateProratedSalary(employee, lastWorkingDate);
    final netSettlement =
        proratedSalary +
        unusedLeaveValue +
        gratuity +
        pendingReimbursements -
        outstandingLoans;

    return FinalSettlement(
      proratedSalary: proratedSalary,
      unusedLeaveValue: unusedLeaveValue,
      gratuity: gratuity,
      pendingReimbursements: pendingReimbursements,
      outstandingLoans: outstandingLoans,
      netSettlement: netSettlement,
    );
  }

  double _calculateProratedSalary(Employee employee, DateTime lastWorkingDate) {
    final monthDays = DateTime(
      lastWorkingDate.year,
      lastWorkingDate.month + 1,
      0,
    ).day;
    final workedDays = lastWorkingDate.day.clamp(0, monthDays);
    if (monthDays <= 0) return 0;
    return (employee.basicSalary / monthDays) * workedDays;
  }

  Future<void> _notifyExitReviewTeam(ExitRequest request) async {
    try {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr, UserRole.accountant],
        title: 'New Exit Request',
        message:
            '${request.employeeName} submitted an exit request. Last day: ${request.lastWorkingDate.day}/${request.lastWorkingDate.month}/${request.lastWorkingDate.year}.',
        type: NotificationType.general,
        data: {
          'type': 'exit_request',
          'exitRequestId': request.id,
          'employeeId': request.employeeId,
          'employeeName': request.employeeName,
          'lastWorkingDate': request.lastWorkingDate.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error notifying exit review team: $e');
    }
  }

  Future<void> _notifyEmployeeExitUpdate(ExitRequest request) async {
    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef.doc(request.employeeId).get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];
      if (userId == null || userId.toString().trim().isEmpty) return;

      final statusLabel = request.status.name.toUpperCase();
      await _notificationService.sendNotification(
        userId: userId.toString(),
        title: 'Exit Request Update',
        message: 'Your exit request status is now $statusLabel.',
        type: NotificationType.general,
        data: {
          'type': 'exit_request_status',
          'exitRequestId': request.id,
          'status': request.status.name,
          'rejectionReason': request.rejectionReason,
          'netSettlement': request.finalSettlement?.netSettlement,
        },
      );
    } catch (e) {
      debugPrint('Error notifying employee about exit update: $e');
    }
  }
}
