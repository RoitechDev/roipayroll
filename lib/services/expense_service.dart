import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/models/expense_category_model.dart'
    as expense_category;
import 'package:roipayroll/models/expense_claim_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/transaction_service.dart';
import 'package:uuid/uuid.dart';

class ExpenseService extends BaseService {
  final String _collection = 'expenses';
  final NotificationService _notificationService = NotificationService();
  final TransactionService _transactionService = TransactionService();

  Future<ExpenseClaim> submitExpense({
    required String employeeId,
    required String employeeName,
    required ExpenseCategory category,
    required double amount,
    required String description,
    required DateTime expenseDate,
    String? receiptUrl,
    String? receiptName,
    bool isTaxable = false,
    String? categoryId,
  }) async {
    final claim = ExpenseClaim(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      category: category,
      amount: amount,
      description: description,
      expenseDate: DateTime(
        expenseDate.year,
        expenseDate.month,
        expenseDate.day,
      ),
      submittedAt: DateTime.now(),
      receiptUrl: receiptUrl?.trim().isEmpty == true
          ? null
          : receiptUrl?.trim(),
      receiptName: receiptName?.trim().isEmpty == true
          ? null
          : receiptName?.trim(),
      isTaxable: isTaxable,
      categoryId: categoryId,
    );

    final ref = await companyCollection(_collection);
    await ref.doc(claim.id).set(claim.toJson());
    await _notifyApproversOfNewExpense(claim);
    return claim;
  }

  Future<List<ExpenseClaim>> getEmployeeExpenses(String employeeId) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.where('employeeId', isEqualTo: employeeId).get();
    final claims = snapshot.docs
        .map((doc) => ExpenseClaim.fromJson(docData(doc)))
        .toList();
    claims.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return claims;
  }

  Future<List<ExpenseClaim>> getPendingExpenses() async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('status', isEqualTo: ExpenseStatus.pending.name)
        .get();
    final claims = snapshot.docs
        .map((doc) => ExpenseClaim.fromJson(docData(doc)))
        .toList();
    claims.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    return claims;
  }

  Future<List<ExpenseClaim>> getAllExpenses() async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.get();
    final claims = snapshot.docs
        .map((doc) => ExpenseClaim.fromJson(docData(doc)))
        .toList();
    claims.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return claims;
  }

  Stream<List<ExpenseClaim>> getPendingExpensesStream() async* {
    final ref = await companyCollection(_collection);
    final query = ref.where('status', isEqualTo: ExpenseStatus.pending.name);

    List<ExpenseClaim> parseClaims(
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      final claims = snapshot.docs
          .map((doc) => ExpenseClaim.fromJson(docData(doc)))
          .toList();
      claims.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
      return claims;
    }

    if (kIsWeb) {
      yield* webPollingStream(() async => parseClaims(await query.get()));
      return;
    }

    yield* query.snapshots().map(parseClaims);
  }

  Future<void> approveExpense(
    String id,
    String approverId,
    String approverName,
  ) async {
    final companyId = await getCompanyId();
    final ref = companyCollectionRef(companyId, _collection);
    final lockKey = 'expense_approval_$id';
    ExpenseClaim? claim;

    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'expenseId': id,
              'operation': 'approveExpense',
              'approverId': approverId,
              'approverName': approverName,
            },
          );

      final doc = await transaction.get(ref.doc(id));
      final data = docDataNullable(doc);
      if (data == null) {
        throw Exception('Expense claim not found.');
      }
      final currentClaim = ExpenseClaim.fromJson(data);
      claim = currentClaim;

      if (!shouldProceed) {
        if (currentClaim.status == ExpenseStatus.approved ||
            currentClaim.status == ExpenseStatus.paid) {
          return;
        }
        throw Exception('Expense approval is already in progress.');
      }

      if (currentClaim.status == ExpenseStatus.approved ||
          currentClaim.status == ExpenseStatus.paid) {
        return;
      }

      _transactionService.updateWithVersion(transaction, doc.reference, {
        'status': ExpenseStatus.approved.name,
        'approvedBy': approverId,
        'approvedByName': approverName,
        'approvedAt': Timestamp.now(),
        'rejectionReason': null,
      });
    });

    if (claim == null) {
      return;
    }
    await _notifyEmployeeExpenseDecision(
      claim!,
      approved: true,
      reviewerName: approverName,
    );
  }

  Future<void> rejectExpense(
    String id,
    String approverId,
    String approverName,
    String reason,
  ) async {
    final companyId = await getCompanyId();
    final ref = companyCollectionRef(companyId, _collection);
    final lockKey = 'expense_rejection_$id';
    ExpenseClaim? claim;

    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'expenseId': id,
              'operation': 'rejectExpense',
              'approverId': approverId,
              'approverName': approverName,
            },
          );

      final doc = await transaction.get(ref.doc(id));
      final data = docDataNullable(doc);
      if (data == null) {
        throw Exception('Expense claim not found.');
      }
      final currentClaim = ExpenseClaim.fromJson(data);
      claim = currentClaim;

      if (!shouldProceed) {
        if (currentClaim.status == ExpenseStatus.rejected) {
          return;
        }
        throw Exception('Expense rejection is already in progress.');
      }

      if (currentClaim.status == ExpenseStatus.rejected) {
        return;
      }

      _transactionService.updateWithVersion(transaction, doc.reference, {
        'status': ExpenseStatus.rejected.name,
        'approvedBy': approverId,
        'approvedByName': approverName,
        'approvedAt': Timestamp.now(),
        'rejectionReason': reason,
      });
    });

    if (claim == null) {
      return;
    }
    await _notifyEmployeeExpenseDecision(
      claim!,
      approved: false,
      reviewerName: approverName,
      rejectionReason: reason,
    );
  }

  Future<List<ExpenseClaim>> getApprovedExpensesForPayroll(
    String employeeId,
    int month,
    int year,
  ) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: ExpenseStatus.approved.name)
        .get();

    final periodEnd = DateTime(year, month + 1, 0, 23, 59, 59, 999);
    return snapshot.docs
        .map((doc) => ExpenseClaim.fromJson(docData(doc)))
        .where((claim) {
          if (claim.payrollId != null && claim.payrollId!.trim().isNotEmpty) {
            return false;
          }
          if (claim.approvedAt == null) return false;
          return !claim.approvedAt!.isAfter(periodEnd);
        })
        .toList();
  }

  Future<void> markExpensesPaid(
    List<String> expenseIds, {
    required String payrollId,
    required int payrollMonth,
    required int payrollYear,
  }) async {
    if (expenseIds.isEmpty) return;
    final ref = await companyCollection(_collection);
    final batch = firestore.batch();
    for (final id in expenseIds) {
      batch.update(ref.doc(id), {
        'status': ExpenseStatus.paid.name,
        'payrollId': payrollId,
        'payrollMonth': payrollMonth,
        'payrollYear': payrollYear,
        'paidAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }

  Future<void> unmarkExpensesPaidForPayroll(String payrollId) async {
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
        'status': ExpenseStatus.approved.name,
        'payrollId': null,
        'payrollMonth': null,
        'payrollYear': null,
        'paidAt': null,
      });
    }
    await batch.commit();
  }

  Future<double> getMonthlyTotal(
    String employeeId,
    expense_category.ExpenseCategory category,
    int month,
    int year,
  ) async {
    final ref = await companyCollection(_collection);
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

    final snapshot = await ref
        .where('employeeId', isEqualTo: employeeId)
        .where('category', isEqualTo: category.name)
        .where(
          'expenseDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        )
        .where('expenseDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .where(
          'status',
          whereIn: [ExpenseStatus.approved.name, ExpenseStatus.paid.name],
        )
        .get();

    return snapshot.docs
        .map((doc) => ExpenseClaim.fromJson(docData(doc)))
        .fold<double>(0.0, (total, claim) => total + claim.amount);
  }

  Future<ExpenseValidationResult> validateExpense(
    ExpenseClaim claim,
    expense_category.ExpenseCategory category,
  ) async {
    final violations = <String>[];

    if (category.maxLimitPerClaim != null &&
        claim.amount > category.maxLimitPerClaim!) {
      violations.add(
        'Amount exceeds maximum limit of ₦${category.maxLimitPerClaim!.toStringAsFixed(0)} for ${category.name}',
      );
    }

    if (category.monthlyLimit != null) {
      final monthTotal = await getMonthlyTotal(
        claim.employeeId,
        category,
        claim.expenseDate.month,
        claim.expenseDate.year,
      );

      final newTotal = monthTotal + claim.amount;
      if (newTotal > category.monthlyLimit!) {
        violations.add(
          'This claim would exceed monthly limit of ₦${category.monthlyLimit!.toStringAsFixed(0)} '
          '(Current: ₦${monthTotal.toStringAsFixed(0)}, New: ₦${newTotal.toStringAsFixed(0)})',
        );
      }
    }

    final receiptRequired =
        category.requiresReceipt ||
        (category.receiptThreshold != null &&
            claim.amount > category.receiptThreshold!);

    if (receiptRequired &&
        (claim.receiptUrl == null || claim.receiptUrl!.trim().isEmpty)) {
      violations.add('Receipt required for this expense');
    }

    final needsFinanceApproval =
        category.requiresFinanceApproval ||
        (category.financeApprovalThreshold != null &&
            claim.amount > category.financeApprovalThreshold!);

    return ExpenseValidationResult(
      isValid: violations.isEmpty,
      violations: violations,
      requiresFinanceApproval: needsFinanceApproval,
    );
  }
}

extension on ExpenseService {
  Future<void> _notifyApproversOfNewExpense(ExpenseClaim claim) async {
    try {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'New Expense Claim',
        message:
            '${claim.employeeName} submitted ${CurrencyFormatter.formatNaira(claim.amount)} for ${claim.category.name.toUpperCase()}.',
        type: NotificationType.expenseRequest,
        data: {
          'expenseId': claim.id,
          'employeeId': claim.employeeId,
          'employeeName': claim.employeeName,
          'amount': claim.amount,
          'category': claim.category.name,
          'expenseDate': claim.expenseDate.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error sending expense request notification: $e');
    }
  }

  Future<void> _notifyEmployeeExpenseDecision(
    ExpenseClaim claim, {
    required bool approved,
    required String reviewerName,
    String? rejectionReason,
  }) async {
    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef.doc(claim.employeeId).get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];
      if (userId == null || userId.toString().trim().isEmpty) {
        return;
      }

      await _notificationService.sendNotification(
        userId: userId.toString(),
        title: approved ? 'Expense Approved' : 'Expense Rejected',
        message: approved
            ? 'Your ${claim.category.name} expense for ${CurrencyFormatter.formatNaira(claim.amount)} was approved by $reviewerName.'
            : 'Your ${claim.category.name} expense for ${CurrencyFormatter.formatNaira(claim.amount)} was rejected by $reviewerName. Reason: ${rejectionReason ?? 'No reason provided'}.',
        type: approved
            ? NotificationType.expenseApproved
            : NotificationType.expenseRejected,
        data: {
          'expenseId': claim.id,
          'employeeId': claim.employeeId,
          'amount': claim.amount,
          'category': claim.category.name,
          if (!approved) 'rejectionReason': rejectionReason,
        },
      );
    } catch (e) {
      debugPrint('Error sending expense decision notification: $e');
    }
  }
}

class ExpenseValidationResult {
  final bool isValid;
  final List<String> violations;
  final bool requiresFinanceApproval;

  ExpenseValidationResult({
    required this.isValid,
    required this.violations,
    this.requiresFinanceApproval = false,
  });
}
