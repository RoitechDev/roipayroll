import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/models/salary_advance_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/transaction_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:uuid/uuid.dart';

class SalaryAdvanceService extends BaseService {
  final String _collection = 'salary_advances';
  final EmployeeService _employeeService = EmployeeService();
  final NotificationService _notificationService = NotificationService();
  final TransactionService _transactionService = TransactionService();
  final UserService _userService = UserService();

  Future<SalaryAdvance> requestSalaryAdvance({
    required String employeeId,
    required double amount,
    required String reason,
  }) async {
    final requester = await _userService.getCurrentUserProfile();
    if (requester == null) {
      throw Exception('User profile not found.');
    }
    PermissionService.requirePermission(
      requester,
      Permission.viewSalaryAdvance,
    );
    if (requester.role != UserRole.employee) {
      throw Exception(
        'Salary advance requests are only available to employee accounts.',
      );
    }
    final requesterEmployeeId = requester.employeeId?.trim() ?? '';
    if (requesterEmployeeId.isEmpty ||
        requesterEmployeeId != employeeId.trim()) {
      throw Exception(
        'You can only request a salary advance for your own profile.',
      );
    }

    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Reason is required.');
    }
    if (amount <= 0) {
      throw Exception('Amount must be greater than zero.');
    }

    final employee = await _employeeService.getEmployeeById(employeeId);
    if (employee == null) {
      throw Exception('Employee not found.');
    }

    final maxAllowed = employee.basicSalary * 0.5;
    if (maxAllowed <= 0) {
      throw Exception('Employee salary is not configured.');
    }
    if (amount > maxAllowed) {
      throw Exception(
        'Max salary advance is ${maxAllowed.toStringAsFixed(2)} (50% of monthly salary).',
      );
    }

    final existingOutstanding = await _getOutstandingAdvances(employeeId);
    if (existingOutstanding.isNotEmpty) {
      throw Exception(
        'Employee already has a pending/approved salary advance awaiting recovery.',
      );
    }

    final advance = SalaryAdvance(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employee.fullName,
      amount: amount,
      maxAllowed: maxAllowed,
      requestDate: DateTime.now(),
      status: SalaryAdvanceStatus.pending,
      reason: normalizedReason,
    );

    final ref = await companyCollection(_collection);
    await ref.doc(advance.id).set(advance.toJson());
    await _notifyApproversOfNewRequest(advance);
    return advance;
  }

  Future<List<SalaryAdvance>> getAllAdvances() async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.get();
    final advances = snapshot.docs
        .map((doc) => SalaryAdvance.fromJson(docData(doc)))
        .toList();
    advances.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    return advances;
  }

  Future<List<SalaryAdvance>> getAdvancesByStatuses(
    Set<SalaryAdvanceStatus> statuses,
  ) async {
    if (statuses.isEmpty) return <SalaryAdvance>[];
    final ref = await companyCollection(_collection);
    final snapshot = statuses.length == 1
        ? await ref.where('status', isEqualTo: statuses.first.name).get()
        : await ref
              .where(
                'status',
                whereIn: statuses.map((status) => status.name).toList(),
              )
              .get();
    final advances = snapshot.docs
        .map((doc) => SalaryAdvance.fromJson(docData(doc)))
        .toList();
    advances.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    return advances;
  }

  Future<void> approveSalaryAdvance(String advanceId, AppUser approver) async {
    PermissionService.requirePermission(
      approver,
      Permission.approveSalaryAdvance,
    );
    final approverName = approver.name.trim().isEmpty
        ? approver.email
        : approver.name.trim();
    final companyId = await getCompanyId();
    final ref = companyCollectionRef(companyId, _collection);
    final lockKey = 'salary_advance_approval_$advanceId';
    SalaryAdvance? advance;

    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'advanceId': advanceId,
              'operation': 'approveSalaryAdvance',
              'approverId': approver.id,
              'approverName': approverName,
            },
          );

      final existing = await transaction.get(ref.doc(advanceId));
      final data = docDataNullable(existing);
      if (data == null) {
        throw Exception('Salary advance request not found.');
      }
      final currentAdvance = SalaryAdvance.fromJson(data);
      advance = currentAdvance;

      if (!shouldProceed) {
        if (currentAdvance.status == SalaryAdvanceStatus.approved) {
          throw Exception('Salary advance already approved.');
        }
        throw Exception('Salary advance approval is already in progress.');
      }

      if (currentAdvance.status != SalaryAdvanceStatus.pending) {
        throw Exception('Only pending salary advances can be approved.');
      }

      _transactionService.updateWithVersion(transaction, existing.reference, {
        'status': SalaryAdvanceStatus.approved.name,
        'approvedBy': approver.id,
        'approvedByName': approverName,
        'approvedAt': Timestamp.now(),
        'rejectedAt': null,
        'rejectedBy': null,
        'rejectedByName': null,
        'rejectionReason': null,
      });
    });

    if (advance == null) {
      return;
    }
    await _notifyEmployeeDecision(
      advance!,
      approved: true,
      reviewerName: approverName,
    );
  }

  Future<void> rejectSalaryAdvance(
    String advanceId,
    AppUser approver,
    String reason,
  ) async {
    PermissionService.requirePermission(
      approver,
      Permission.approveSalaryAdvance,
    );
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Rejection reason is required.');
    }

    final approverName = approver.name.trim().isEmpty
        ? approver.email
        : approver.name.trim();
    final companyId = await getCompanyId();
    final ref = companyCollectionRef(companyId, _collection);
    final lockKey = 'salary_advance_rejection_$advanceId';
    SalaryAdvance? advance;

    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'advanceId': advanceId,
              'operation': 'rejectSalaryAdvance',
              'approverId': approver.id,
              'approverName': approverName,
            },
          );

      final existing = await transaction.get(ref.doc(advanceId));
      final data = docDataNullable(existing);
      if (data == null) {
        throw Exception('Salary advance request not found.');
      }
      final currentAdvance = SalaryAdvance.fromJson(data);
      advance = currentAdvance;

      if (!shouldProceed) {
        if (currentAdvance.status == SalaryAdvanceStatus.rejected) {
          throw Exception('Salary advance already rejected.');
        }
        throw Exception('Salary advance rejection is already in progress.');
      }

      if (currentAdvance.status != SalaryAdvanceStatus.pending) {
        throw Exception('Only pending salary advances can be rejected.');
      }

      _transactionService.updateWithVersion(transaction, existing.reference, {
        'status': SalaryAdvanceStatus.rejected.name,
        'rejectedBy': approver.id,
        'rejectedByName': approverName,
        'rejectedAt': Timestamp.now(),
        'rejectionReason': normalizedReason,
      });
    });

    if (advance == null) {
      return;
    }
    await _notifyEmployeeDecision(
      advance!,
      approved: false,
      reviewerName: approverName,
      rejectionReason: normalizedReason,
    );
  }

  Future<List<SalaryAdvance>> getEmployeeAdvances(String employeeId) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.where('employeeId', isEqualTo: employeeId).get();
    final advances = snapshot.docs
        .map((doc) => SalaryAdvance.fromJson(docData(doc)))
        .toList();
    advances.sort((a, b) => b.requestDate.compareTo(a.requestDate));
    return advances;
  }

  Future<List<SalaryAdvance>> getPendingAdvances() async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('status', isEqualTo: SalaryAdvanceStatus.pending.name)
        .get();
    final advances = snapshot.docs
        .map((doc) => SalaryAdvance.fromJson(docData(doc)))
        .toList();
    advances.sort((a, b) => a.requestDate.compareTo(b.requestDate));
    return advances;
  }

  Future<List<SalaryAdvance>> getApprovedUnrecoveredForPayroll(
    String employeeId,
    int month,
    int year,
  ) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: SalaryAdvanceStatus.approved.name)
        .get();

    final periodEnd = DateTime(year, month + 1, 0, 23, 59, 59, 999);
    final advances = snapshot.docs
        .map((doc) => SalaryAdvance.fromJson(docData(doc)))
        .where((advance) {
          if (advance.payrollId != null &&
              advance.payrollId!.trim().isNotEmpty) {
            return false;
          }
          if (advance.approvedAt == null) return false;
          return !advance.approvedAt!.isAfter(periodEnd);
        })
        .toList();
    advances.sort((a, b) => a.requestDate.compareTo(b.requestDate));
    return advances;
  }

  Future<void> markAdvancesRecovered(
    List<String> advanceIds, {
    required String payrollId,
    required int payrollMonth,
    required int payrollYear,
  }) async {
    if (advanceIds.isEmpty) return;
    final ref = await companyCollection(_collection);
    final batch = firestore.batch();
    for (final id in advanceIds) {
      batch.update(ref.doc(id), {
        'status': SalaryAdvanceStatus.recovered.name,
        'payrollId': payrollId,
        'payrollMonth': payrollMonth,
        'payrollYear': payrollYear,
        'recoveredAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }

  Future<void> unmarkAdvancesRecoveredForPayroll(String payrollId) async {
    final normalizedPayrollId = payrollId.trim();
    if (normalizedPayrollId.isEmpty) return;

    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('payrollId', isEqualTo: normalizedPayrollId)
        .get();
    if (snapshot.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': SalaryAdvanceStatus.approved.name,
        'payrollId': null,
        'payrollMonth': null,
        'payrollYear': null,
        'recoveredAt': null,
      });
    }
    await batch.commit();
  }

  Future<SalaryAdvance?> getSalaryAdvanceById(String id) async {
    final ref = await companyCollection(_collection);
    final doc = await ref.doc(id).get();
    final data = docDataNullable(doc);
    if (data == null) return null;
    return SalaryAdvance.fromJson(data);
  }

  Future<List<SalaryAdvance>> _getOutstandingAdvances(String employeeId) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('employeeId', isEqualTo: employeeId)
        .where(
          'status',
          whereIn: [
            SalaryAdvanceStatus.pending.name,
            SalaryAdvanceStatus.approved.name,
          ],
        )
        .get();

    final advances = snapshot.docs
        .map((doc) => SalaryAdvance.fromJson(docData(doc)))
        .toList();
    return advances.where((advance) {
      final isPending = advance.status == SalaryAdvanceStatus.pending;
      final isApprovedUnrecovered =
          advance.status == SalaryAdvanceStatus.approved &&
          (advance.payrollId == null || advance.payrollId!.trim().isEmpty);
      return isPending || isApprovedUnrecovered;
    }).toList();
  }

  Future<void> _notifyApproversOfNewRequest(SalaryAdvance advance) async {
    try {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr, UserRole.accountant],
        title: 'New Salary Advance Request',
        message:
            '${advance.employeeName} requested ${CurrencyFormatter.formatNaira(advance.amount)}.',
        type: NotificationType.salaryAdvanceRequest,
        data: {
          'salaryAdvanceId': advance.id,
          'employeeId': advance.employeeId,
          'employeeName': advance.employeeName,
          'amount': advance.amount,
          'reason': advance.reason,
          'requestDate': advance.requestDate.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error sending salary advance request notification: $e');
    }
  }

  Future<void> _notifyEmployeeDecision(
    SalaryAdvance advance, {
    required bool approved,
    required String reviewerName,
    String? rejectionReason,
  }) async {
    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef.doc(advance.employeeId).get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];
      if (userId == null || userId.toString().trim().isEmpty) return;

      await _notificationService.sendNotification(
        userId: userId.toString(),
        title: approved ? 'Salary Advance Approved' : 'Salary Advance Rejected',
        message: approved
            ? 'Your salary advance request for ${CurrencyFormatter.formatNaira(advance.amount)} was approved by $reviewerName.'
            : 'Your salary advance request for ${CurrencyFormatter.formatNaira(advance.amount)} was rejected by $reviewerName. Reason: ${rejectionReason ?? 'No reason provided'}',
        type: approved
            ? NotificationType.salaryAdvanceApproved
            : NotificationType.salaryAdvanceRejected,
        data: {
          'salaryAdvanceId': advance.id,
          'employeeId': advance.employeeId,
          'employeeName': advance.employeeName,
          'amount': advance.amount,
          'reason': advance.reason,
          'reviewerName': reviewerName,
          if (!approved) 'rejectionReason': rejectionReason,
        },
      );
    } catch (e) {
      debugPrint('Error sending salary advance decision notification: $e');
    }
  }
}
