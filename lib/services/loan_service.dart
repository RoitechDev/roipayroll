import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/employee_deduction_model.dart';
import 'package:roipayroll/models/loan_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/audit_log_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/audit_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/employee_deduction_service.dart';
import 'package:roipayroll/services/encryption_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/transaction_service.dart';
import 'package:roipayroll/services/user_service.dart';

class LoanService extends BaseService {
  static const String _loanDeductionCollection = 'employee_deductions';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService;
  final UserService _userService;
  final TransactionService _transactionService = TransactionService();
  late final EmployeeDeductionService _employeeDeductionService;
  late final AuditService _auditService;

  LoanService({
    NotificationService? notificationService,
    EmployeeDeductionService? employeeDeductionService,
    AuditService? auditService,
    UserService? userService,
  }) : _notificationService = notificationService ?? NotificationService(),
       _userService = userService ?? UserService() {
    _employeeDeductionService =
        employeeDeductionService ??
        EmployeeDeductionService(userService: UserService());
    _auditService = auditService ?? AuditService(userService: UserService());
  }

  final String _collection = 'loans';

  Future<void> requestLoan(Loan loan) async {
    final requester = await _userService.getCurrentUserProfile();
    if (requester == null) throw Exception('User profile not found.');

    PermissionService.requirePermission(requester, Permission.viewLoans);
    final requesterEmployeeId = requester.employeeId?.trim() ?? '';
    if (requesterEmployeeId.isEmpty) {
      throw Exception('Your account is not linked to an employee profile.');
    }
    if (requesterEmployeeId != loan.employeeId.trim()) {
      throw Exception('You can only request a loan for your own profile.');
    }

    final normalizedReason = loan.reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Reason is required.');
    }
    if (loan.amount <= 0) {
      throw Exception('Loan amount must be greater than zero.');
    }
    if (loan.durationMonths <= 0 || loan.monthlyDeduction <= 0) {
      throw Exception('Repayment duration is invalid.');
    }

    final loanData = loan.toJson();
    loanData['reason'] = normalizedReason;
    loanData['employeeId'] = requesterEmployeeId;

    final loansRef = await companyCollection(_collection);
    await loansRef.doc(loan.id).set(loanData);
  }

  Future<List<Loan>> getAllLoans() async {
    final loansRef = await companyCollection(_collection);
    final snapshot = await loansRef
        .orderBy('requestDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Loan.fromJson(docData(doc))).toList();
  }

  Future<List<Loan>> getEmployeeLoans(String employeeId) async {
    final loansRef = await companyCollection(_collection);
    final snapshot = await loansRef
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('requestDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Loan.fromJson(docData(doc))).toList();
  }

  Future<List<Loan>> getLoansByStatus(LoanStatus status) async {
    final loansRef = await companyCollection(_collection);
    final snapshot = await loansRef
        .where('status', isEqualTo: status.name)
        .orderBy('requestDate', descending: true)
        .get();
    return snapshot.docs.map((doc) => Loan.fromJson(docData(doc))).toList();
  }

  Future<List<Loan>> getPendingLoans() async =>
      getLoansByStatus(LoanStatus.pending);

  Future<List<Loan>> getActiveLoans() async =>
      getLoansByStatus(LoanStatus.active);

  Future<void> approveLoan(String loanId, AppUser approver) async {
    PermissionService.requirePermission(approver, Permission.approveLoan);
    final approverName = approver.name.trim().isEmpty
        ? approver.email
        : approver.name.trim();
    final companyId = await getCompanyId();
    final loansRef = companyCollectionRef(companyId, _collection);
    final deductionsRef = companyCollectionRef(
      companyId,
      _loanDeductionCollection,
    );
    final lockKey = 'loan_approval_$loanId';
    Loan? originalLoan;
    Loan? updatedLoan;

    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'loanId': loanId,
              'operation': 'approveLoan',
              'approverId': approver.id,
              'approverName': approverName,
            },
          );

      final loanDoc = await transaction.get(loansRef.doc(loanId));
      if (!loanDoc.exists) throw Exception('Loan not found: $loanId');

      final loanData = docDataNullable(loanDoc);
      if (loanData == null) throw Exception('Loan not found: $loanId');
      final loan = Loan.fromJson(loanData);
      originalLoan = loan;

      if (!shouldProceed) {
        if (loan.status == LoanStatus.active ||
            loan.status == LoanStatus.completed) {
          return;
        }
        throw Exception('Loan approval is already in progress.');
      }

      if (loan.status == LoanStatus.active ||
          loan.status == LoanStatus.completed) {
        return;
      }

      final nextLoan = loan.copyWith(
        status: LoanStatus.active,
        approvalDate: DateTime.now(),
        approvedBy: approverName,
      );
      updatedLoan = nextLoan;
      _transactionService.updateWithVersion(
        transaction,
        loanDoc.reference,
        nextLoan.toJson(),
      );

      final deduction = _buildLoanDeduction(
        loan: nextLoan,
        approvedBy: approverName,
      );
      final deductionRef = deductionsRef.doc(_loanDeductionDocumentId(loanId));
      final deductionDoc = await transaction.get(deductionRef);
      if (!deductionDoc.exists) {
        _transactionService.setDoc(
          transaction,
          deductionRef,
          deduction.toJson(),
        );
      }
    });

    if (updatedLoan == null || originalLoan == null) {
      return;
    }

    await _auditService.logAction(
      action: AuditAction.loanApproved,
      entityType: 'loan',
      entityId: originalLoan!.id,
      entityName: '${originalLoan!.employeeName} loan',
      before: originalLoan!.toJson(),
      after: updatedLoan!.toJson(),
    );

    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef
          .doc(originalLoan!.employeeId)
          .get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];
      if (userId != null) {
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Loan Approved',
          message:
              'Your loan request for ${CurrencyFormatter.formatNaira(originalLoan!.amount)} was approved.',
          type: NotificationType.loanApproved,
          data: {
            'loanId': loanId,
            'amount': originalLoan!.amount,
            'monthlyDeduction': updatedLoan!.monthlyDeduction,
            'durationMonths': updatedLoan!.durationMonths,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending approval notification: $e');
    }
  }

  Future<void> rejectLoan(
    String loanId,
    AppUser approver,
    String rejectionReason,
  ) async {
    PermissionService.requirePermission(approver, Permission.approveLoan);
    final normalizedReason = rejectionReason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Rejection reason is required.');
    }

    final approverName = approver.name.trim().isEmpty
        ? approver.email
        : approver.name.trim();
    final companyId = await getCompanyId();
    final loansRef = companyCollectionRef(companyId, _collection);
    final lockKey = 'loan_rejection_$loanId';
    Loan? originalLoan;
    Loan? updatedLoan;

    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'loanId': loanId,
              'operation': 'rejectLoan',
              'approverId': approver.id,
              'approverName': approverName,
            },
          );

      final loanDoc = await transaction.get(loansRef.doc(loanId));
      if (!loanDoc.exists) throw Exception('Loan not found: $loanId');

      final loanData = docDataNullable(loanDoc);
      if (loanData == null) throw Exception('Loan not found: $loanId');
      final loan = Loan.fromJson(loanData);
      originalLoan = loan;

      if (!shouldProceed) {
        if (loan.status == LoanStatus.rejected ||
            loan.status == LoanStatus.completed) {
          return;
        }
        throw Exception('Loan rejection is already in progress.');
      }

      if (loan.status == LoanStatus.rejected ||
          loan.status == LoanStatus.completed) {
        return;
      }

      final nextLoan = loan.copyWith(
        status: LoanStatus.rejected,
        rejectionReason: normalizedReason,
      );
      updatedLoan = nextLoan;
      _transactionService.updateWithVersion(
        transaction,
        loanDoc.reference,
        nextLoan.toJson(),
      );
    });

    if (updatedLoan == null || originalLoan == null) {
      return;
    }

    await _auditService.logAction(
      action: AuditAction.loanRejected,
      entityType: 'loan',
      entityId: originalLoan!.id,
      entityName: '${originalLoan!.employeeName} loan',
      before: originalLoan!.toJson(),
      after: updatedLoan!.toJson(),
    );

    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef
          .doc(originalLoan!.employeeId)
          .get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];
      if (userId != null) {
        await _notificationService.sendNotification(
          userId: userId,
          title: 'Loan Request Rejected',
          message:
              'Your loan request for ${CurrencyFormatter.formatNaira(originalLoan!.amount)} was not approved. Reason: $normalizedReason',
          type: NotificationType.loanRejected,
          data: {
            'loanId': loanId,
            'amount': originalLoan!.amount,
            'reason': normalizedReason,
          },
        );
      }
    } catch (e) {
      debugPrint('Error sending rejection notification: $e');
    }
  }

  Future<void> updateLoanRepayment(String loanId, double paymentAmount) async {
    final companyId = await getCompanyId();
    final loansRef = companyCollectionRef(companyId, _collection);
    var completed = false;

    await _transactionService.runTransaction<void>((transaction) async {
      final loanDoc = await transaction.get(loansRef.doc(loanId));
      if (!loanDoc.exists) throw Exception('Loan not found: $loanId');

      final loanData = docDataNullable(loanDoc);
      if (loanData == null) throw Exception('Loan not found: $loanId');
      final loan = Loan.fromJson(loanData);
      final newTotalRepaid = (loan.totalRepaid + paymentAmount)
          .clamp(0.0, loan.amount)
          .toDouble();
      final updatedLoan = loan.copyWith(
        totalRepaid: newTotalRepaid,
        status: newTotalRepaid >= loan.amount
            ? LoanStatus.completed
            : LoanStatus.active,
      );
      completed = updatedLoan.status == LoanStatus.completed;
      _transactionService.updateWithVersion(
        transaction,
        loanDoc.reference,
        updatedLoan.toJson(),
      );
    });

    if (completed) {
      await _completeLoanLinkedDeduction(loanId);
    }
  }

  Future<void> reverseLoanRepayment(String loanId, double paymentAmount) async {
    final companyId = await getCompanyId();
    final loansRef = companyCollectionRef(companyId, _collection);

    await _transactionService.runTransaction<void>((transaction) async {
      final loanDoc = await transaction.get(loansRef.doc(loanId));
      if (!loanDoc.exists) throw Exception('Loan not found: $loanId');

      final loanData = docDataNullable(loanDoc);
      if (loanData == null) throw Exception('Loan not found: $loanId');
      final loan = Loan.fromJson(loanData);
      final newTotalRepaid = (loan.totalRepaid - paymentAmount).clamp(
        0.0,
        loan.amount,
      );
      final updatedLoan = loan.copyWith(
        totalRepaid: newTotalRepaid.toDouble(),
        status: newTotalRepaid >= loan.amount
            ? LoanStatus.completed
            : LoanStatus.active,
      );
      _transactionService.updateWithVersion(
        transaction,
        loanDoc.reference,
        updatedLoan.toJson(),
      );
    });
  }

  Future<Loan?> getLoanById(String loanId) async {
    final loansRef = await companyCollection(_collection);
    final doc = await loansRef.doc(loanId).get();
    if (!doc.exists) return null;
    final data = docDataNullable(doc);
    return data == null ? null : Loan.fromJson(data);
  }

  Stream<List<Loan>> getLoansStream() async* {
    final loansRef = await companyCollection(_collection);
    final query = loansRef.orderBy('requestDate', descending: true);

    if (kIsWeb) {
      yield* webPollingStream(() async {
        final snapshot = await query.get();
        return snapshot.docs.map((d) => Loan.fromJson(docData(d))).toList();
      });
      return;
    }

    yield* query.snapshots().map(
      (s) => s.docs.map((d) => Loan.fromJson(docData(d))).toList(),
    );
  }

  Stream<List<Loan>> getEmployeeLoansStream(String employeeId) async* {
    final loansRef = await companyCollection(_collection);
    final query = loansRef
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('requestDate', descending: true);

    if (kIsWeb) {
      yield* webPollingStream(() async {
        final snapshot = await query.get();
        return snapshot.docs.map((d) => Loan.fromJson(docData(d))).toList();
      });
      return;
    }

    yield* query.snapshots().map(
      (s) => s.docs.map((d) => Loan.fromJson(docData(d))).toList(),
    );
  }

  Future<double> getEmployeeOutstandingLoans(String employeeId) async {
    final loansRef = await companyCollection(_collection);
    final activeLoans = await loansRef
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: LoanStatus.active.name)
        .get();

    double total = 0;
    for (final doc in activeLoans.docs) {
      total += Loan.fromJson(docData(doc)).remainingBalance;
    }
    return total;
  }

  Future<double> getEmployeeMonthlyLoanDeduction(String employeeId) async {
    final loansRef = await companyCollection(_collection);
    final activeLoans = await loansRef
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: LoanStatus.active.name)
        .get();

    double total = 0;
    for (final doc in activeLoans.docs) {
      total += Loan.fromJson(docData(doc)).monthlyDeduction;
    }
    return total;
  }

  Future<LoanRiskAssessment> calculateLoanRisk({
    required String employeeId,
    required double requestedAmount,
  }) async {
    final employeesRef = await companyCollection('employees');
    final employeeDoc = await employeesRef.doc(employeeId).get();
    final employeeData = docDataNullable(employeeDoc) ?? <String, dynamic>{};

    final basicSalary = _toDouble(
      employeeData['basicSalary'] ?? employeeData['salary'],
    );
    final activeLoans = await getLoansByEmployeeAndStatuses(
      employeeId: employeeId,
      statuses: {LoanStatus.active, LoanStatus.pending},
    );

    final salaryRatio = basicSalary > 0
        ? (requestedAmount / basicSalary)
        : double.infinity;
    final activeLoanCount = activeLoans.length;

    LoanRiskLevel level = LoanRiskLevel.low;
    if (salaryRatio > 1.0 || activeLoanCount >= 2) {
      level = LoanRiskLevel.high;
    } else if (salaryRatio >= 0.5 || activeLoanCount == 1) {
      level = LoanRiskLevel.medium;
    }

    final ratioPercent = salaryRatio.isFinite ? (salaryRatio * 100) : 0;
    final reason = basicSalary <= 0
        ? 'Salary not configured for this employee.'
        : '${ratioPercent.toStringAsFixed(0)}% of monthly salary, $activeLoanCount active/pending loan(s).';

    return LoanRiskAssessment(
      level: level,
      label: level.name.toUpperCase(),
      reason: reason,
      salaryRatio: salaryRatio.isFinite ? salaryRatio : 0,
      activeLoanCount: activeLoanCount,
    );
  }

  Future<List<Loan>> getLoansByEmployeeAndStatuses({
    required String employeeId,
    required Set<LoanStatus> statuses,
  }) async {
    if (statuses.isEmpty) return [];
    final loansRef = await companyCollection(_collection);
    final statusNames = statuses.map((s) => s.name).toList();
    final snapshot = await loansRef
        .where('employeeId', isEqualTo: employeeId)
        .where('status', whereIn: statusNames)
        .get();
    return snapshot.docs.map((doc) => Loan.fromJson(docData(doc))).toList();
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  Future<int> backfillLoanEmployeeNames() async {
    final loansRef = await companyCollection(_collection);
    final loansSnapshot = await loansRef.get();
    if (loansSnapshot.docs.isEmpty) return 0;

    final employeesRef = await companyCollection('employees');
    final employeesSnapshot = await employeesRef.get();
    final Map<String, String> employeeNames = {};

    for (final doc in employeesSnapshot.docs) {
      final data = docData(doc);
      final fullName = data['fullName'] ?? data['name'] ?? data['displayName'];
      String resolved = '';
      if (fullName is String && fullName.trim().isNotEmpty) {
        resolved = fullName.trim();
      } else {
        final combined = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'
            .trim();
        if (combined.isNotEmpty) resolved = combined;
      }
      if (resolved.isNotEmpty) employeeNames[doc.id] = resolved;
    }

    WriteBatch batch = firestore.batch();
    int batchCount = 0;
    int updated = 0;

    for (final doc in loansSnapshot.docs) {
      final data = docData(doc);
      final employeeName = (data['employeeName'] ?? '').toString().trim();
      final employeeId = data['employeeId']?.toString();
      final isMissing =
          employeeName.isEmpty || employeeName.toLowerCase() == 'unknown';
      if (!isMissing || employeeId == null) continue;

      final resolved = employeeNames[employeeId];
      if (resolved == null || resolved.trim().isEmpty) continue;

      batch.update(doc.reference, {'employeeName': resolved});
      updated += 1;
      batchCount += 1;

      if (batchCount >= 450) {
        await batch.commit();
        batch = firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) await batch.commit();
    return updated;
  }

  Future<void> deleteLoan(String loanId) async {
    final loansRef = await companyCollection(_collection);
    await loansRef.doc(loanId).delete();
  }

  String _loanDeductionDocumentId(String loanId) => 'loan_deduction_$loanId';

  EmployeeDeduction _buildLoanDeduction({
    required Loan loan,
    required String approvedBy,
  }) {
    final now = DateTime.now();
    return EmployeeDeduction(
      id: _loanDeductionDocumentId(loan.id),
      employeeId: loan.employeeId,
      employeeName: loan.employeeName,
      deductionTypeId: 'loan_repayment',
      deductionTypeName: 'Loan Repayment',
      category: DeductionCategory.loan,
      calculationMethod: DeductionCalculationMethod.fixedAmount,
      frequency: DeductionFrequency.monthly,
      status: DeductionStatus.active,
      totalAmount: loan.amount,
      amountPerPayroll: loan.monthlyDeduction,
      totalDeducted: loan.totalRepaid,
      totalInstallments: loan.durationMonths,
      installmentsPaid: 0,
      startDate: now,
      nextDeductionDate: now,
      requiresApproval: false,
      approvedBy: approvedBy,
      approvedAt: now,
      referenceNumber: loan.id,
      description: 'Auto-created from approved loan',
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _completeLoanLinkedDeduction(String loanId) async {
    final deductions = await _employeeDeductionService.getAllDeductions(
      category: DeductionCategory.loan,
    );
    for (final deduction in deductions) {
      if (deduction.referenceNumber == loanId &&
          deduction.status != DeductionStatus.completed) {
        await _employeeDeductionService.completeDeduction(deduction.id);
      }
    }
  }

  Future<void> ensureEmployeeProfileExists() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw 'User not authenticated';

    final employeesRef = await companyCollection('employees');
    final employeeSnapshot = await employeesRef
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (employeeSnapshot.docs.isEmpty) {
      final user = _auth.currentUser!;
      final employeeData = await EncryptionService.encryptFields({
        'userId': userId,
        'email': user.email ?? '',
        'fullName': user.displayName ?? user.email?.split('@')[0] ?? 'Employee',
        'phone': user.phoneNumber ?? '',
        'position': 'Employee',
        'department': 'General',
        'salary': 0.0,
        'dateHired': Timestamp.now(),
        'isActive': true,
        'createdAt': Timestamp.now(),
      }, Employee.sensitiveFields);
      await employeesRef.add(employeeData);
    }
  }
}
