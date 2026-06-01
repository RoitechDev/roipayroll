import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/models/audit_log_model.dart';
import 'package:roipayroll/models/leave_request_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/audit_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/leave_balance_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/public_holiday_service.dart';
import 'package:roipayroll/services/user_service.dart';

class LeaveRequestService extends BaseService {
  final String _collection = 'leave_requests';
  final _leaveBalanceService = LeaveBalanceService();
  final _publicHolidayService = PublicHolidayService();
  final _notificationService = NotificationService();
  final _userService = UserService();
  late final _auditService = AuditService(userService: _userService);

  // Submit leave request
  Future<LeaveRequest> submitLeaveRequest(LeaveRequest request) async {
    // Calculate working days
    final workingDays = await _calculateWorkingDays(
      request.startDate,
      request.endDate,
    );

    // Validate available balance before creating request
    final balance = await _leaveBalanceService.getBalance(
      request.employeeId,
      request.leaveTypeId,
    );
    if (balance == null) {
      throw Exception(
        'Leave balance not initialized for this leave type. Please contact HR/Admin.',
      );
    }
    if (workingDays > balance.availableBalance) {
      throw Exception(
        'Insufficient leave balance. Available: ${balance.availableBalance.toStringAsFixed(1)} days.',
      );
    }
    final updatedRequest = LeaveRequest(
      id: request.id,
      employeeId: request.employeeId,
      employeeName: request.employeeName,
      leaveTypeId: request.leaveTypeId,
      leaveTypeName: request.leaveTypeName,
      startDate: request.startDate,
      endDate: request.endDate,
      numberOfDays: workingDays,
      durationType: request.durationType,
      reason: request.reason,
      attachmentUrls: request.attachmentUrls,
      status: LeaveRequestStatus.pending,
      requestedAt: DateTime.now(),
      contactPhone: request.contactPhone,
      contactAddress: request.contactAddress,
      handoverTo: request.handoverTo,
      handoverToName: request.handoverToName,
      handoverNotes: request.handoverNotes,
    );

    try {
      final requestsRef = await companyCollection(_collection);
      await requestsRef.doc(updatedRequest.id).set(updatedRequest.toJson());
    } on FirebaseException catch (e) {
      throw Exception(
        'Failed to submit leave request (${e.code}): ${e.message ?? 'Unknown Firestore error'}',
      );
    }

    // Notify Admin/HR about new leave request
    try {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'New Leave Request',
        message:
            '${request.employeeName} requested ${request.leaveTypeName} (${workingDays.toStringAsFixed(1)} days)',
        type: NotificationType.general,
        data: {
          'leaveRequestId': request.id,
          'employeeId': request.employeeId,
          'leaveTypeId': request.leaveTypeId,
          'status': LeaveRequestStatus.pending.name,
        },
      );
    } catch (e) {
      // Log to help troubleshooting if Admin/HR are not getting notifications
      print('âŒ Leave request admin/hr notification failed: $e');
    }

    // Notify employee that request was submitted
    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef.doc(request.employeeId).get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];

      if (userId != null) {
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Leave Request Submitted',
          message:
              'Your ${request.leaveTypeName} request has been submitted for approval.',
          type: NotificationType.general,
          data: {
            'leaveRequestId': request.id,
            'status': LeaveRequestStatus.pending.name,
          },
        );
      }
    } catch (e) {
      // Ignore notification errors
    }

    // Update pending balance
    try {
      await _leaveBalanceService.updateBalanceForRequest(
        request.employeeId,
        request.leaveTypeId,
        workingDays,
        true,
      );
    } on FirebaseException catch (e) {
      // Some projects restrict employees from writing leave_balances directly.
      // Do not fail submission once leave_request has been created.
      if (e.code != 'permission-denied') rethrow;
      print('Leave balance pending update skipped: ${e.code} ${e.message}');
    }

    return updatedRequest;
  }

  // Approve leave request
  Future<void> approveLeaveRequest(
    String requestId,
    String approverId,
    String approverName, {
    String? remarks,
  }) async {
    final request = await getLeaveRequestById(requestId);
    if (request == null) throw Exception('Request not found');

    final requestsRef = await companyCollection(_collection);
    final processedAt = DateTime.now();
    await requestsRef.doc(requestId).update({
      'status': LeaveRequestStatus.approved.name,
      'processedAt': Timestamp.fromDate(processedAt),
      'processedBy': approverId,
      'processedByName': approverName,
      'remarks': remarks,
    });
    await _auditService.logAction(
      action: AuditAction.leaveApproved,
      entityType: 'leave_request',
      entityId: request.id,
      entityName: '${request.employeeName} - ${request.leaveTypeName}',
      before: request.toJson(),
      after: request
          .copyWith(
            status: LeaveRequestStatus.approved,
            processedAt: processedAt,
            processedBy: approverId,
            processedByName: approverName,
            remarks: remarks,
          )
          .toJson(),
    );

    // Notify Admin/HR about approval
    try {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Leave Approved',
        message:
            '${request.employeeName}\'s ${request.leaveTypeName} request was approved.',
        type: NotificationType.general,
        data: {
          'leaveRequestId': request.id,
          'employeeId': request.employeeId,
          'status': LeaveRequestStatus.approved.name,
        },
      );
    } catch (e) {
      print('âŒ Leave approval admin/hr notification failed: $e');
    }

    // Notify employee about approval
    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef.doc(request.employeeId).get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];

      if (userId != null) {
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Leave Approved',
          message: 'Your ${request.leaveTypeName} request has been approved.',
          type: NotificationType.general,
          data: {
            'leaveRequestId': request.id,
            'status': LeaveRequestStatus.approved.name,
          },
        );
      }
    } catch (e) {
      // Ignore notification errors
    }

    // Move from pending to used balance
    await _leaveBalanceService.updateBalanceForRequest(
      request.employeeId,
      request.leaveTypeId,
      request.numberOfDays,
      false,
    );
  }

  // Reject leave request
  Future<void> rejectLeaveRequest(
    String requestId,
    String approverId,
    String approverName,
    String remarks,
  ) async {
    final request = await getLeaveRequestById(requestId);
    if (request == null) throw Exception('Request not found');

    final requestsRef = await companyCollection(_collection);
    final processedAt = DateTime.now();
    await requestsRef.doc(requestId).update({
      'status': LeaveRequestStatus.rejected.name,
      'processedAt': Timestamp.fromDate(processedAt),
      'processedBy': approverId,
      'processedByName': approverName,
      'remarks': remarks,
    });
    await _auditService.logAction(
      action: AuditAction.leaveRejected,
      entityType: 'leave_request',
      entityId: request.id,
      entityName: '${request.employeeName} - ${request.leaveTypeName}',
      before: request.toJson(),
      after: request
          .copyWith(
            status: LeaveRequestStatus.rejected,
            processedAt: processedAt,
            processedBy: approverId,
            processedByName: approverName,
            remarks: remarks,
          )
          .toJson(),
    );

    // Notify Admin/HR about rejection
    try {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Leave Rejected',
        message:
            '${request.employeeName}\'s ${request.leaveTypeName} request was rejected.',
        type: NotificationType.general,
        data: {
          'leaveRequestId': request.id,
          'employeeId': request.employeeId,
          'status': LeaveRequestStatus.rejected.name,
        },
      );
    } catch (e) {
      print('âŒ Leave rejection admin/hr notification failed: $e');
    }

    // Notify employee about rejection
    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef.doc(request.employeeId).get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];

      if (userId != null) {
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Leave Rejected',
          message:
              'Your ${request.leaveTypeName} request was rejected. Reason: $remarks',
          type: NotificationType.general,
          data: {
            'leaveRequestId': request.id,
            'status': LeaveRequestStatus.rejected.name,
          },
        );
      }
    } catch (e) {
      // Ignore notification errors
    }

    // Remove from pending balance
    await _leaveBalanceService.cancelPendingBalance(
      request.employeeId,
      request.leaveTypeId,
      request.numberOfDays,
    );
  }

  // Cancel leave request
  Future<void> cancelLeaveRequest(String requestId) async {
    final request = await getLeaveRequestById(requestId);
    if (request == null) throw Exception('Request not found');

    if (request.status != LeaveRequestStatus.pending) {
      throw Exception('Can only cancel pending requests');
    }

    final requestsRef = await companyCollection(_collection);
    await requestsRef.doc(requestId).update({
      'status': LeaveRequestStatus.cancelled.name,
    });

    // Remove from pending balance
    await _leaveBalanceService.cancelPendingBalance(
      request.employeeId,
      request.leaveTypeId,
      request.numberOfDays,
    );
  }

  // Get leave request by ID
  Future<LeaveRequest?> getLeaveRequestById(String id) async {
    final requestsRef = await companyCollection(_collection);
    final doc = await requestsRef.doc(id).get();
    if (!doc.exists) return null;
    final data = docDataNullable(doc);
    return data == null ? null : LeaveRequest.fromJson(data);
  }

  // Get employee leave requests
  Future<List<LeaveRequest>> getEmployeeLeaveRequests(
    String employeeId, {
    int? limit,
  }) async {
    final requestsRef = await companyCollection(_collection);
    Query query = requestsRef.where('employeeId', isEqualTo: employeeId);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    final requests = snapshot.docs
        .map((doc) => LeaveRequest.fromJson(docData(doc)))
        .toList();
    requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return requests;
  }

  // Get pending leave requests (for approvers)
  Future<List<LeaveRequest>> getPendingLeaveRequests() async {
    final requestsRef = await companyCollection(_collection);
    final snapshot = await requestsRef
        .where('status', isEqualTo: LeaveRequestStatus.pending.name)
        .get();

    final requests = snapshot.docs
        .map((doc) => LeaveRequest.fromJson(docData(doc)))
        .toList();
    requests.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
    return requests;
  }

  // Stream pending leave requests (live approvals list)
  Stream<List<LeaveRequest>> getPendingLeaveRequestsStream() async* {
    final requestsRef = await companyCollection(_collection);
    final query = requestsRef.where(
      'status',
      isEqualTo: LeaveRequestStatus.pending.name,
    );

    List<LeaveRequest> parseRequests(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final requests = snapshot.docs
          .map((doc) => LeaveRequest.fromJson(docData(doc)))
          .toList();
      requests.sort((a, b) => a.requestedAt.compareTo(b.requestedAt));
      return requests;
    }

    if (kIsWeb) {
      yield* webPollingStream(() async => parseRequests(await query.get()));
      return;
    }

    yield* query.snapshots().map(parseRequests);
  }

  // Get all leave requests (admin/HR)
  Future<List<LeaveRequest>> getAllLeaveRequests({
    LeaveRequestStatus? status,
    int? limit,
  }) async {
    final requestsRef = await companyCollection(_collection);
    Query query = requestsRef;

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    query = query.orderBy('requestedAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => LeaveRequest.fromJson(docData(doc)))
        .toList();
  }

  // Calculate working days excluding weekends and holidays
  Future<double> _calculateWorkingDays(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final holidays = await _publicHolidayService.getHolidaysInRange(
      startDate,
      endDate,
    );

    double workingDays = 0;
    DateTime current = startDate;

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      // Skip weekends
      if (current.weekday != DateTime.saturday &&
          current.weekday != DateTime.sunday) {
        // Skip holidays
        final isHoliday = holidays.any(
          (h) =>
              h.date.year == current.year &&
              h.date.month == current.month &&
              h.date.day == current.day,
        );

        if (!isHoliday) {
          workingDays += 1;
        }
      }

      current = current.add(const Duration(days: 1));
    }

    return workingDays;
  }
}
