import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/loan_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/system_health_summary_model.dart';
import 'package:roipayroll/models/payroll_trend_model.dart';
import 'package:roipayroll/models/system_alert_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/models/audit_log_model.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/services/allowances_service.dart';
import 'package:roipayroll/services/attendance_summary_service.dart';
import 'package:roipayroll/services/attendance_service.dart';
import 'package:roipayroll/services/audit_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/employee_deduction_service.dart';
import 'package:roipayroll/services/expense_service.dart';
import 'package:roipayroll/services/incentive_service.dart';
import 'package:roipayroll/services/loan_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/payroll_deduction_service.dart';
import 'package:roipayroll/services/pdf_service.dart';
import 'package:roipayroll/services/salary_advance_service.dart';
import 'package:roipayroll/services/contract_service.dart';
import 'package:roipayroll/services/deduction_transaction_service.dart';
import 'package:roipayroll/services/employee_document_service.dart';
import 'package:roipayroll/services/payroll_transaction_service.dart';
import 'package:roipayroll/services/transaction_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/models/contract_record_model.dart';
import 'package:uuid/uuid.dart';

class PayrollService extends BaseService {
  final String _collection = 'payrolls';
  static const Duration _previewCacheTtl = Duration(minutes: 2);
  static const int _calculationBatchSize = 12;
  static final Map<String, _PayrollCalcCacheEntry> _payrollCalcCache = {};
  final _allowancesService = AllowancesService();
  final _loanService = LoanService();
  final _attendanceService = AttendanceService();
  final _attendanceSummaryService = AttendanceSummaryService();
  final _payrollDeductionService = PayrollDeductionService();
  final _transactionService = TransactionService();
  final _deductionTransactionService = DeductionTransactionService();
  final _userService = UserService();
  late final _employeeDeductionService = EmployeeDeductionService(
    userService: _userService,
  );
  final _employeeService = EmployeeService();
  final _expenseService = ExpenseService();
  final _incentiveService = IncentiveService();
  final _salaryAdvanceService = SalaryAdvanceService();
  final _notificationService = NotificationService();
  late final _auditService = AuditService(userService: _userService);
  final _contractService = ContractService();
  final _documentService = EmployeeDocumentService();
  final _payrollTransactionService = PayrollTransactionService();

  Future<Payroll> processEmployeePayroll(
    Employee employee,
    int month,
    int year, {
    String? payslipPdfUrl,
    String? payrollRunId,
  }) async {
    final automationSettings = await _loadAutomationSettings();
    final result = await _processEmployeePayrollInternal(
      employee,
      month,
      year,
      automationSettings: automationSettings,
      payslipPdfUrl: payslipPdfUrl,
      payrollRunId: payrollRunId,
    );
    return result.payroll;
  }

  Future<Payroll> processOffCyclePayroll({
    required String employeeId,
    required PayrollType type,
    required double amount,
    required String reason,
    DateTime? paymentDate,
  }) async {
    if (type == PayrollType.regular) {
      throw Exception('Use regular payroll processing for monthly payroll.');
    }
    if (amount <= 0) {
      throw Exception('Off-cycle payroll amount must be greater than zero.');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Reason is required for off-cycle payroll.');
    }

    final employee = await _employeeService.getEmployeeById(employeeId);
    if (employee == null) {
      throw Exception('Employee not found.');
    }

    final effectiveDate = paymentDate ?? DateTime.now();
    await _ensureMonthNotLocked(effectiveDate.month, effectiveDate.year);

    final multiCurrency = await _loadMultiCurrencySettings();
    final payoutCurrency = CurrencyFormatter.normalizeCurrencyCode(
      employee.payoutCurrency,
    );
    final exchangeRateToBase = multiCurrency.exchangeRateFor(payoutCurrency);
    final amountBase = amount * exchangeRateToBase;

    final offCycleTaxBase = _calculateOffCycleTaxBase(
      payrollType: type,
      amountBase: amountBase,
    );
    final payeBase = offCycleTaxBase['paye'] ?? 0.0;
    final pensionBase = offCycleTaxBase['pension'] ?? 0.0;
    final nhfBase = offCycleTaxBase['nhf'] ?? 0.0;
    final totalDeductionsBase = payeBase + pensionBase + nhfBase;
    final netSalaryBase = amountBase - totalDeductionsBase;

    final paye = payeBase / exchangeRateToBase;
    final pension = pensionBase / exchangeRateToBase;
    final nhf = nhfBase / exchangeRateToBase;
    final totalDeductions = totalDeductionsBase / exchangeRateToBase;
    final netSalary = netSalaryBase / exchangeRateToBase;

    final payroll = Payroll(
      id: const Uuid().v4(),
      employeeId: employee.id,
      employeeName: employee.fullName,
      month: effectiveDate.month,
      year: effectiveDate.year,
      currency: payoutCurrency,
      baseCurrency: multiCurrency.baseCurrency,
      exchangeRateToBase: exchangeRateToBase,
      basicSalary: 0.0,
      allowances: amount,
      grossSalary: amount,
      paye: paye,
      pension: pension,
      nhf: nhf,
      loanDeduction: 0.0,
      otherDeductions: 0.0,
      totalDeductions: totalDeductions,
      netSalary: netSalary,
      basicSalaryBase: 0.0,
      allowancesBase: amountBase,
      grossSalaryBase: amountBase,
      payeBase: payeBase,
      pensionBase: pensionBase,
      nhfBase: nhfBase,
      loanDeductionBase: 0.0,
      otherDeductionsBase: 0.0,
      totalDeductionsBase: totalDeductionsBase,
      netSalaryBase: netSalaryBase,
      processedDate: effectiveDate,
      payrollType: type,
      offCycleAmount: amount,
      offCycleReason: normalizedReason,
      status: 'pending',
      approvalStatus: PayrollApprovalStatus.draft,
    );

    final payrollsRef = await companyCollection(_collection);
    await payrollsRef.doc(payroll.id).set(payroll.toJson());
    await _generateFinancialTransactions(
      payroll: payroll,
      payrollRunId: _resolvePayrollRunId(payroll.id),
    );
    await _auditService.logAction(
      action: AuditAction.payrollProcessed,
      entityType: 'payroll',
      entityId: payroll.id,
      entityName:
          '${payroll.employeeName} Off-cycle ${type.name.toUpperCase()} ${_monthName(payroll.month)} ${payroll.year}',
      after: payroll.toJson(),
    );

    return payroll;
  }

  Future<_ProcessedPayrollResult> _processEmployeePayrollInternal(
    Employee employee,
    int month,
    int year, {
    required _PayrollAutomationSettings automationSettings,
    String? payslipPdfUrl,
    String? payrollRunId,
  }) async {
    await _ensureMonthNotLocked(month, year);
    await _checkDuplicatePayments(employee.id, month, year);
    final result = await _getPayrollCalculation(
      employee,
      month,
      year,
      forceRefresh: true,
    );
    final payroll = result.payroll;

    final companyId = await getCompanyId();
    final payrollsRef = companyCollectionRef(companyId, _collection);
    final lockKey = _payrollIdempotencyKey(employee.id, month, year);

    await _transactionService.runTransaction<void>((transaction) async {
      final shouldProceed = await _transactionService
          .checkAndSetIdempotencyLock(
            transaction,
            companyId: companyId,
            lockKey: lockKey,
            metadata: {
              'employeeId': employee.id,
              'employeeName': employee.fullName,
              'month': month,
              'year': year,
              'operation': 'processPayroll',
              'payrollId': payroll.id,
            },
          );
      if (!shouldProceed) {
        throw DuplicatePaymentException(
          'Employee ${employee.id} already has payroll processing in progress for $month/$year.',
        );
      }
      _transactionService.setDoc(
        transaction,
        payrollsRef.doc(payroll.id),
        payroll.toJson(),
      );
    });

    try {
      await _applyPayrollLinkedRecords(payroll: payroll, calculation: result);
    } catch (error, stackTrace) {
      try {
        await _rollbackPayrollLinkedRecords(payroll);
      } catch (rollbackError, rollbackStack) {
        developer.log(
          'Failed to rollback payroll linked records for ${payroll.id}',
          name: 'PayrollService',
          error: rollbackError,
          stackTrace: rollbackStack,
        );
      }

      try {
        await payrollsRef.doc(payroll.id).delete();
      } catch (deleteError, deleteStack) {
        developer.log(
          'Failed to delete payroll ${payroll.id} after linked record failure',
          name: 'PayrollService',
          error: deleteError,
          stackTrace: deleteStack,
        );
      }

      try {
        await _transactionService.removeIdempotencyLock(companyId, lockKey);
      } catch (lockError, lockStack) {
        developer.log(
          'Failed to release payroll idempotency lock $lockKey',
          name: 'PayrollService',
          error: lockError,
          stackTrace: lockStack,
        );
      }

      Error.throwWithStackTrace(error, stackTrace);
    }

    await _generateFinancialTransactions(
      payroll: payroll,
      payrollRunId: _resolvePayrollRunId(payrollRunId ?? payroll.id),
    );

    await _auditService.logAction(
      action: AuditAction.payrollProcessed,
      entityType: 'payroll',
      entityId: payroll.id,
      entityName: '${payroll.employeeName} ${_monthName(month)} $year',
      after: payroll.toJson(),
    );

    final dispatchResult = await _notifyAndQueuePayslip(
      employee,
      payroll,
      automationSettings: automationSettings,
    );
    await _storePayslipDocumentIfAvailable(
      employee: employee,
      payroll: payroll,
      payslipPdfUrl: payslipPdfUrl,
    );
    return _ProcessedPayrollResult(
      payroll: payroll,
      dispatchResult: dispatchResult,
    );
  }

  Future<PayrollPreview> simulatePayroll(int month, int year) async {
    return simulatePayrollWithProgress(month, year);
  }

  Future<PayrollPreview> simulatePayrollWithProgress(
    int month,
    int year, {
    void Function(int completed, int total)? onProgress,
    PreviewCancellationToken? cancellationToken,
  }) async {
    if (cancellationToken?.isCancelled == true) {
      throw PayrollPreviewCancelledException();
    }

    final multiCurrencySettings = await _loadMultiCurrencySettings();
    final employees = await _employeeService.getAllEmployees();
    final activeEmployees = employees
        .where((employee) => employee.status == 'active')
        .toList();
    onProgress?.call(0, activeEmployees.length);

    final previews = await _mapInBatches<Employee, PayrollPreviewItem>(
      activeEmployees,
      batchSize: _calculationBatchSize,
      task: (employee) async {
        if (cancellationToken?.isCancelled == true) {
          throw PayrollPreviewCancelledException();
        }
        final result = await _getPayrollCalculation(employee, month, year);
        final payroll = result.payroll;
        return PayrollPreviewItem(
          employeeId: employee.id,
          employeeName: employee.fullName,
          grossSalary: payroll.grossSalaryBase,
          netSalary: payroll.netSalaryBase,
          totalDeductions: payroll.totalDeductionsBase,
          breakdown: payroll,
        );
      },
      onProgress: onProgress,
      shouldStop: () => cancellationToken?.isCancelled == true,
    );
    final totalGross = previews.fold<double>(
      0.0,
      (acc, item) => acc + item.grossSalary,
    );
    final totalNet = previews.fold<double>(
      0.0,
      (acc, item) => acc + item.netSalary,
    );
    final totalDeductions = previews.fold<double>(
      0.0,
      (acc, item) => acc + item.totalDeductions,
    );

    return PayrollPreview(
      month: month,
      year: year,
      totalEmployees: activeEmployees.length,
      totalGross: totalGross,
      totalNet: totalNet,
      totalDeductions: totalDeductions,
      items: previews,
      generatedAt: DateTime.now(),
      currency: multiCurrencySettings.baseCurrency,
    );
  }

  Future<List<SystemAlert>> generateSystemAlerts(int month, int year) async {
    final alerts = <SystemAlert>[];
    final employees = await _employeeService.getAllEmployees();
    final activeEmployees = employees
        .where((employee) => employee.status == 'active')
        .toList();

    final missingSalaryEmployees = activeEmployees
        .where((employee) => employee.basicSalary <= 0)
        .toList();
    for (final employee in missingSalaryEmployees) {
      alerts.add(
        SystemAlert(
          type: AlertType.missingSalary,
          severity: AlertSeverity.critical,
          title: 'Missing Salary Configuration',
          message: '${employee.fullName} has no basic salary set.',
          employeeId: employee.id,
          employeeName: employee.fullName,
        ),
      );
    }

    final existingPayrolls = await getPayrollsByMonth(month, year);
    if (existingPayrolls.isNotEmpty) {
      alerts.add(
        SystemAlert(
          type: AlertType.payrollProcessed,
          severity: AlertSeverity.critical,
          title: 'Payroll Already Processed',
          message:
              'Payroll for ${_monthName(month)} $year already exists (${existingPayrolls.length} records).',
          metadata: {'count': existingPayrolls.length},
        ),
      );
    }

    final emailGroups = <String, List<Employee>>{};
    for (final employee in activeEmployees) {
      final normalizedEmail = employee.email.trim().toLowerCase();
      if (normalizedEmail.isEmpty) continue;
      emailGroups
          .putIfAbsent(normalizedEmail, () => <Employee>[])
          .add(employee);
    }
    for (final entry in emailGroups.entries) {
      if (entry.value.length < 2) continue;
      alerts.add(
        SystemAlert(
          type: AlertType.duplicateEmail,
          severity: AlertSeverity.critical,
          title: 'Duplicate Employee Email',
          message:
              '${entry.key} is assigned to ${entry.value.length} employees.',
          metadata: {
            'email': entry.key,
            'employeeIds': entry.value.map((employee) => employee.id).toList(),
          },
        ),
      );
    }

    final companyId = await getCompanyId();
    final usersSnapshot = await firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .get();
    final validRoles = UserRole.values.map((role) => role.name).toSet();
    for (final userDoc in usersSnapshot.docs) {
      final userData = userDoc.data();
      final role = (userData['role'] ?? '').toString().trim().toLowerCase();
      if (role.isNotEmpty && validRoles.contains(role)) {
        continue;
      }

      final userLabel = (userData['name'] ?? userData['email'] ?? userDoc.id)
          .toString();
      alerts.add(
        SystemAlert(
          type: AlertType.userWithoutRole,
          severity: AlertSeverity.critical,
          title: 'User Role Missing',
          message: '$userLabel has no valid role assigned.',
          metadata: {
            'userId': userDoc.id,
            'name': userData['name'],
            'email': userData['email'],
          },
        ),
      );
    }

    final leaveBalancesRef = await companyCollection('leave_balances');
    final leaveBalanceSnapshot = await leaveBalancesRef
        .where('year', isEqualTo: year)
        .get();
    final employeesWithLeaveBalances = leaveBalanceSnapshot.docs
        .map((doc) => (docData(doc)['employeeId'] ?? '').toString())
        .where((employeeId) => employeeId.isNotEmpty)
        .toSet();

    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0, 23, 59, 59, 999);

    final employeeAlertGroups =
        await _mapInBatches<Employee, List<SystemAlert>>(
          activeEmployees,
          batchSize: _calculationBatchSize,
          task: (employee) {
            return _buildEmployeeAlerts(
              employee: employee,
              month: month,
              year: year,
              startDate: startDate,
              endDate: endDate,
              employeesWithLeaveBalances: employeesWithLeaveBalances,
            );
          },
        );
    for (final group in employeeAlertGroups) {
      alerts.addAll(group);
    }

    final severityOrder = {
      AlertSeverity.critical: 0,
      AlertSeverity.warning: 1,
      AlertSeverity.info: 2,
    };
    alerts.sort(
      (a, b) => (severityOrder[a.severity] ?? 99).compareTo(
        severityOrder[b.severity] ?? 99,
      ),
    );
    return alerts;
  }

  Future<_PayrollCalculationResult> _getPayrollCalculation(
    Employee employee,
    int month,
    int year, {
    bool forceRefresh = false,
  }) async {
    _cleanupExpiredPayrollCache();
    final key = '${employee.id}_${month}_$year';
    if (!forceRefresh) {
      final cached = _payrollCalcCache[key];
      if (cached != null) {
        return cached.future;
      }
    }

    final future = _calculatePayrollPreviewInternal(employee, month, year);
    _payrollCalcCache[key] = _PayrollCalcCacheEntry(
      createdAt: DateTime.now(),
      future: future,
    );
    return future;
  }

  void _cleanupExpiredPayrollCache() {
    if (_payrollCalcCache.isEmpty) return;
    final now = DateTime.now();
    _payrollCalcCache.removeWhere(
      (_, entry) => now.difference(entry.createdAt) > _previewCacheTtl,
    );
  }

  Future<List<SystemAlert>> _buildEmployeeAlerts({
    required Employee employee,
    required int month,
    required int year,
    required DateTime startDate,
    required DateTime endDate,
    required Set<String> employeesWithLeaveBalances,
  }) async {
    final alerts = <SystemAlert>[];

    if (!employeesWithLeaveBalances.contains(employee.id)) {
      alerts.add(
        SystemAlert(
          type: AlertType.missingLeaveBalance,
          severity: AlertSeverity.warning,
          title: 'Missing Leave Balance',
          message:
              'No leave balance is initialized for ${employee.fullName} in $year.',
          employeeId: employee.id,
          employeeName: employee.fullName,
        ),
      );
    }

    List<dynamic> attendance = const [];
    try {
      attendance = await _attendanceService.getEmployeeAttendance(
        employee.id,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (_) {
      attendance = const [];
    }
    if (attendance.isEmpty) {
      alerts.add(
        SystemAlert(
          type: AlertType.noAttendance,
          severity: AlertSeverity.warning,
          title: 'No Attendance Records',
          message:
              '${employee.fullName} has no attendance records for ${_monthName(month)} $year.',
          employeeId: employee.id,
          employeeName: employee.fullName,
        ),
      );
    }

    final calculated = await _getPayrollCalculation(employee, month, year);
    final payroll = calculated.payroll;

    if (employee.basicSalary > 0 && payroll.loanDeduction > 0) {
      final ratio = (payroll.loanDeduction / employee.basicSalary) * 100;
      if (ratio > 50) {
        alerts.add(
          SystemAlert(
            type: AlertType.highLoanRatio,
            severity: AlertSeverity.warning,
            title: 'High Loan Ratio',
            message:
                '${employee.fullName} loan deduction is ${ratio.toStringAsFixed(1)}% of basic salary.',
            employeeId: employee.id,
            employeeName: employee.fullName,
            metadata: {
              'ratio': ratio,
              'loanDeduction': payroll.loanDeduction,
              'basicSalary': employee.basicSalary,
            },
          ),
        );
      }
    }

    if (payroll.totalDeductions > payroll.grossSalary) {
      alerts.add(
        SystemAlert(
          type: AlertType.excessiveDeductions,
          severity: AlertSeverity.warning,
          title: 'Excessive Deductions',
          message:
              '${employee.fullName} deductions exceed gross salary by ${(payroll.totalDeductions - payroll.grossSalary).toStringAsFixed(2)}.',
          employeeId: employee.id,
          employeeName: employee.fullName,
          metadata: {
            'grossSalary': payroll.grossSalary,
            'totalDeductions': payroll.totalDeductions,
          },
        ),
      );
    }

    return alerts;
  }

  Future<List<R>> _mapInBatches<T, R>(
    List<T> items, {
    required int batchSize,
    required Future<R> Function(T item) task,
    void Function(int completed, int total)? onProgress,
    bool Function()? shouldStop,
  }) async {
    final results = <R>[];
    for (var i = 0; i < items.length; i += batchSize) {
      if (shouldStop?.call() == true) {
        throw PayrollPreviewCancelledException();
      }
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final chunk = items.sublist(i, end);
      final chunkResults = await Future.wait(chunk.map(task));
      if (shouldStop?.call() == true) {
        throw PayrollPreviewCancelledException();
      }
      results.addAll(chunkResults);
      onProgress?.call(results.length, items.length);
    }
    return results;
  }

  Future<_PayrollCalculationResult> _calculatePayrollPreviewInternal(
    Employee employee,
    int month,
    int year,
  ) async {
    final multiCurrency = await _loadMultiCurrencySettings();
    final payoutCurrency = CurrencyFormatter.normalizeCurrencyCode(
      employee.payoutCurrency,
    );
    final exchangeRateToBase = multiCurrency.exchangeRateFor(payoutCurrency);

    final employmentType = employee.employmentType;
    final ContractRecord? activeContract =
        employmentType == EmploymentType.contract
        ? await _contractService.getActiveContract(employee.id)
        : null;
    final isOnProbation =
        employmentType == EmploymentType.probation &&
        !employee.isProbationConfirmed;
    final includesBonus = activeContract?.includesBonus ?? true;
    final includesPension = activeContract?.includesPension ?? true;
    final allowIncentives = !isOnProbation && includesBonus;
    final allowPension = !isOnProbation && includesPension;

    final basicSalary = activeContract?.contractSalary ?? employee.basicSalary;
    final legacyEnabled = await _allowancesService.isLegacyFallbackEnabled();
    final allowanceCalc = await _allowancesService.calculateEmployeeAllowances(
      employeeId: employee.id,
      basicSalary: basicSalary,
      month: month,
      year: year,
      includeLegacyFallback: legacyEnabled,
    );
    final deductions = await _allowancesService.getDeductions(employee.id);
    final approvedExpenseClaims = await _expenseService
        .getApprovedExpensesForPayroll(employee.id, month, year);
    final expenseReimbursementTotal = approvedExpenseClaims.fold<double>(
      0.0,
      (runningTotal, claim) => runningTotal + claim.amount,
    );
    final includedExpenseClaimIds = approvedExpenseClaims
        .map((claim) => claim.id)
        .toList();
    final approvedIncentiveEntries = await _incentiveService
        .getApprovedIncentivesForPayroll(employee.id, month, year);
    final incentiveTotal = allowIncentives
        ? approvedIncentiveEntries.fold<double>(
            0.0,
            (runningTotal, entry) => runningTotal + entry.amount,
          )
        : 0.0;
    final includedIncentiveEntryIds = allowIncentives
        ? approvedIncentiveEntries.map((entry) => entry.id).toList()
        : <String>[];
    final approvedSalaryAdvances = await _salaryAdvanceService
        .getApprovedUnrecoveredForPayroll(employee.id, month, year);
    final salaryAdvanceTotal = approvedSalaryAdvances.fold<double>(
      0.0,
      (runningTotal, advance) => runningTotal + advance.amount,
    );
    final includedSalaryAdvanceIds = approvedSalaryAdvances
        .map((advance) => advance.id)
        .toList();

    final activeV2Deductions = await _employeeDeductionService
        .getActiveDeductions(employee.id);
    final hasV2LoanDeduction = activeV2Deductions.any(
      (d) => d.category == DeductionCategory.loan,
    );
    final legacyLoanDeduction = hasV2LoanDeduction
        ? 0.0
        : await _loanService.getEmployeeMonthlyLoanDeduction(employee.id);

    final attendanceSummary = await _attendanceSummaryService
        .getOrGenerateSummary(employee, month, year);

    final totalAllowances =
        allowanceCalc.total + expenseReimbursementTotal + incentiveTotal;
    var grossSalary = basicSalary + totalAllowances;
    final attendanceAdjustment = attendanceSummary.netAttendanceAdjustment;
    grossSalary += attendanceAdjustment;

    final basicSalaryBase = basicSalary * exchangeRateToBase;
    final totalAllowancesBase = totalAllowances * exchangeRateToBase;
    final grossSalaryBase = grossSalary * exchangeRateToBase;
    final nonTaxableAllowancesBase =
        allowanceCalc.nonTaxableTotal * exchangeRateToBase;
    final taxableGrossBase = grossSalaryBase - nonTaxableAllowancesBase;

    final calculated = await _payrollDeductionService
        .calculateEmployeeDeductions(
          employee.id,
          grossSalaryBase,
          basicSalaryBase,
          taxableGrossPay: taxableGrossBase,
        );
    final statutoryPayeBase = (calculated['paye'] ?? 0).toDouble();
    var statutoryPensionBase = (calculated['pension'] ?? 0).toDouble();
    final statutoryNhfBase = (calculated['nhf'] ?? 0).toDouble();
    final v2CustomDeductionsBase = (calculated['customTotal'] ?? 0).toDouble();
    var calculatedItems =
        (calculated['items'] as List<CalculatedDeduction>? ??
        <CalculatedDeduction>[]);
    if (!allowPension) {
      statutoryPensionBase = 0.0;
      calculatedItems = calculatedItems
          .where((item) => item.deductionTypeId != 'statutory_pension')
          .toList();
    }
    final statutoryTotalBase =
        statutoryPayeBase + statutoryPensionBase + statutoryNhfBase;
    final v2LoanDeductionBase = calculatedItems
        .where((d) => !d.isStatutory && d.category == DeductionCategory.loan)
        .fold(0.0, (total, d) => total + d.amount);
    final legacyLoanDeductionBase = legacyLoanDeduction * exchangeRateToBase;
    final totalLoanDeductionBase =
        legacyLoanDeductionBase + v2LoanDeductionBase;
    final manualDeductionsBase =
        deductions.totalDeductions * exchangeRateToBase;
    final salaryAdvanceTotalBase = salaryAdvanceTotal * exchangeRateToBase;

    final otherDeductionsBase =
        manualDeductionsBase +
        legacyLoanDeductionBase +
        v2CustomDeductionsBase +
        salaryAdvanceTotalBase;
    final totalDeductionsBase = statutoryTotalBase + otherDeductionsBase;
    final netSalaryBase = grossSalaryBase - totalDeductionsBase;

    final statutoryPaye = statutoryPayeBase / exchangeRateToBase;
    final statutoryPension = statutoryPensionBase / exchangeRateToBase;
    final statutoryNhf = statutoryNhfBase / exchangeRateToBase;
    final totalLoanDeduction = totalLoanDeductionBase / exchangeRateToBase;
    final otherDeductions = otherDeductionsBase / exchangeRateToBase;
    final totalDeductions = totalDeductionsBase / exchangeRateToBase;
    final netSalary = netSalaryBase / exchangeRateToBase;

    final payroll = Payroll(
      id: const Uuid().v4(),
      employeeId: employee.id,
      employeeName: employee.fullName,
      month: month,
      year: year,
      currency: payoutCurrency,
      baseCurrency: multiCurrency.baseCurrency,
      exchangeRateToBase: exchangeRateToBase,
      basicSalary: basicSalary,
      allowances: totalAllowances,
      grossSalary: grossSalary,
      paye: statutoryPaye,
      pension: statutoryPension,
      nhf: statutoryNhf,
      loanDeduction: totalLoanDeduction,
      otherDeductions: otherDeductions,
      totalDeductions: totalDeductions,
      netSalary: netSalary,
      basicSalaryBase: basicSalaryBase,
      allowancesBase: totalAllowancesBase,
      grossSalaryBase: grossSalaryBase,
      payeBase: statutoryPayeBase,
      pensionBase: statutoryPensionBase,
      nhfBase: statutoryNhfBase,
      loanDeductionBase: totalLoanDeductionBase,
      otherDeductionsBase: otherDeductionsBase,
      totalDeductionsBase: totalDeductionsBase,
      netSalaryBase: netSalaryBase,
      processedDate: DateTime.now(),
    );

    return _PayrollCalculationResult(
      payroll: payroll,
      calculatedItems: calculatedItems,
      legacyLoanDeduction: legacyLoanDeduction,
      expenseReimbursementTotal: expenseReimbursementTotal,
      includedExpenseClaimIds: includedExpenseClaimIds,
      incentiveTotal: incentiveTotal,
      includedIncentiveEntryIds: includedIncentiveEntryIds,
      salaryAdvanceTotal: salaryAdvanceTotal,
      includedSalaryAdvanceIds: includedSalaryAdvanceIds,
      appliedOneTimeAllowanceAssignmentIds:
          allowanceCalc.appliedOneTimeAssignmentIds,
    );
  }

  Future<_PayslipDispatchResult> _notifyAndQueuePayslip(
    Employee employee,
    Payroll payroll, {
    required _PayrollAutomationSettings automationSettings,
  }) async {
    var notificationSent = false;
    var notificationFailed = false;
    var emailQueued = false;
    var emailSkippedNoEmail = false;
    var emailFailed = false;

    if (automationSettings.autoSendPayrollNotification) {
      try {
        final userId = await _resolveEmployeeUserId(employee);
        if (userId != null && userId.isNotEmpty) {
          await _notificationService.sendNotification(
            userId: userId,
            title: 'Payroll Processed',
            message:
                'Your payslip for ${_monthName(payroll.month)} ${payroll.year} is now available. Net pay: ${payroll.currency} ${payroll.netSalary.toStringAsFixed(2)}',
            type: NotificationType.general,
            data: {
              'payrollId': payroll.id,
              'employeeId': payroll.employeeId,
              'month': payroll.month,
              'year': payroll.year,
            },
          );
          notificationSent = true;
        }
      } catch (_) {
        notificationFailed = true;
      }
    }

    if (automationSettings.autoSendPayslipEmail) {
      final recipientEmail = employee.email.trim();
      if (recipientEmail.isEmpty) {
        emailSkippedNoEmail = true;
      } else {
        try {
          final pdfBytes = await PdfService.generatePayslipBytes(payroll);
          final base64Pdf = base64Encode(pdfBytes);
          final fileName = _buildPayslipFileName(
            employee.fullName,
            payroll.month,
            payroll.year,
          );

          await firestore.collection('mail').add({
            'to': recipientEmail,
            'message': {
              'subject':
                  'Payslip - ${_monthName(payroll.month)} ${payroll.year}',
              'text':
                  'Hello ${employee.fullName}, your payslip for ${_monthName(payroll.month)} ${payroll.year} is attached.',
              'html':
                  '<p>Hello ${employee.fullName},</p><p>Your payslip for ${_monthName(payroll.month)} ${payroll.year} is attached.</p>',
              'attachments': [
                {
                  'filename': fileName,
                  'content': base64Pdf,
                  'encoding': 'base64',
                  'contentType': 'application/pdf',
                },
              ],
            },
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
            'meta': {
              'type': 'payslip',
              'payrollId': payroll.id,
              'employeeId': payroll.employeeId,
              'employeeName': payroll.employeeName,
              'month': payroll.month,
              'year': payroll.year,
            },
          });
          emailQueued = true;
        } catch (_) {
          emailFailed = true;
        }
      }
    }

    return _PayslipDispatchResult(
      notificationSent: notificationSent,
      notificationFailed: notificationFailed,
      emailQueued: emailQueued,
      emailSkippedNoEmail: emailSkippedNoEmail,
      emailFailed: emailFailed,
    );
  }

  Future<_PayrollAutomationSettings> _loadAutomationSettings() async {
    try {
      final companyId = await getCompanyId();
      final settingsDoc = await firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('general')
          .get();
      final settings = settingsDoc.data() ?? const <String, dynamic>{};

      return _PayrollAutomationSettings(
        autoSendPayslipEmail:
            (settings['autoSendPayslipEmail'] ?? true) as bool,
        autoSendPayrollNotification:
            (settings['autoSendPayrollNotification'] ?? true) as bool,
      );
    } catch (_) {
      return const _PayrollAutomationSettings(
        autoSendPayslipEmail: true,
        autoSendPayrollNotification: true,
      );
    }
  }

  Future<_MultiCurrencySettings> _loadMultiCurrencySettings() async {
    try {
      final companyId = await getCompanyId();
      final settingsDoc = await firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('general')
          .get();
      final settings = settingsDoc.data() ?? const <String, dynamic>{};
      final baseCurrency = CurrencyFormatter.normalizeCurrencyCode(
        settings['currency']?.toString(),
      );
      final rawRates =
          (settings['exchangeRates'] as Map<String, dynamic>?) ??
          const <String, dynamic>{};

      final rates = <String, double>{'NGN': 1.0};
      for (final entry in rawRates.entries) {
        final code = CurrencyFormatter.normalizeCurrencyCode(entry.key);
        final value = _toDouble(entry.value);
        if (value > 0) {
          rates[code] = value;
        }
      }
      rates.putIfAbsent(baseCurrency, () => baseCurrency == 'NGN' ? 1.0 : 1.0);
      rates['NGN'] = 1.0;

      return _MultiCurrencySettings(baseCurrency: baseCurrency, rates: rates);
    } catch (_) {
      return const _MultiCurrencySettings(
        baseCurrency: 'NGN',
        rates: {'NGN': 1.0, 'USD': 1600, 'EUR': 1750, 'GBP': 2050},
      );
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  String _buildPayslipFileName(String fullName, int month, int year) {
    final cleanName = fullName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final normalizedName = cleanName.isEmpty ? 'employee' : cleanName;
    return 'Payslip_${normalizedName}_${month}_$year.pdf';
  }

  Future<PayrollProcessingResult> processAllPayrollsWithSummary(
    List<Employee> employees,
    int month,
    int year,
  ) async {
    await _ensureMonthNotLocked(month, year);
    final automationSettings = await _loadAutomationSettings();
    final payrollRunId = const Uuid().v4();
    final payrolls = <Payroll>[];
    final processingFailures = <PayrollProcessingFailure>[];
    var emailQueuedCount = 0;
    var emailSkippedNoEmailCount = 0;
    var emailFailedCount = 0;
    var notificationSentCount = 0;
    var notificationFailedCount = 0;
    var processingFailedCount = 0;
    var attemptedEmployeeCount = 0;

    for (final employee in employees) {
      if (employee.status != 'active') {
        continue;
      }

      attemptedEmployeeCount++;

      try {
        final processed = await _processEmployeePayrollInternal(
          employee,
          month,
          year,
          automationSettings: automationSettings,
          payrollRunId: payrollRunId,
        );
        payrolls.add(processed.payroll);

        if (processed.dispatchResult.emailQueued) {
          emailQueuedCount++;
        }
        if (processed.dispatchResult.emailSkippedNoEmail) {
          emailSkippedNoEmailCount++;
        }
        if (processed.dispatchResult.emailFailed) {
          emailFailedCount++;
        }
        if (processed.dispatchResult.notificationSent) {
          notificationSentCount++;
        }
        if (processed.dispatchResult.notificationFailed) {
          notificationFailedCount++;
        }
      } catch (e) {
        processingFailedCount++;
        processingFailures.add(
          PayrollProcessingFailure(
            employeeId: employee.id,
            employeeName: employee.fullName,
            message: e.toString(),
          ),
        );
        developer.log(
          'Error processing payroll for ${employee.fullName}',
          name: 'PayrollService',
          error: e,
        );
      }
    }

    return PayrollProcessingResult(
      payrollRunId: payrollRunId,
      payrolls: payrolls,
      attemptedEmployeeCount: attemptedEmployeeCount,
      emailQueuedCount: emailQueuedCount,
      emailSkippedNoEmailCount: emailSkippedNoEmailCount,
      emailFailedCount: emailFailedCount,
      notificationSentCount: notificationSentCount,
      notificationFailedCount: notificationFailedCount,
      processingFailedCount: processingFailedCount,
      processingFailures: processingFailures,
      autoSendPayslipEmailEnabled: automationSettings.autoSendPayslipEmail,
      autoSendPayrollNotificationEnabled:
          automationSettings.autoSendPayrollNotification,
    );
  }

  Future<void> _storePayslipDocumentIfAvailable({
    required Employee employee,
    required Payroll payroll,
    String? payslipPdfUrl,
  }) async {
    final url = payslipPdfUrl?.trim() ?? '';
    if (url.isEmpty) return;
    try {
      final currentUser = await _userService.getCurrentUserProfile();
      await _documentService.storePayslip(
        employeeId: employee.id,
        employeeName: employee.fullName,
        payrollId: payroll.id,
        month: payroll.month,
        year: payroll.year,
        pdfUrl: url,
        uploadedBy: currentUser?.id ?? 'system',
        uploadedByName: currentUser?.name ?? 'System',
      );
    } catch (_) {
      // Avoid blocking payroll processing on document storage failures.
    }
  }

  Future<List<Payroll>> processAllPayrolls(
    List<Employee> employees,
    int month,
    int year,
  ) async {
    final summary = await processAllPayrollsWithSummary(employees, month, year);
    return summary.payrolls;
  }

  Future<String?> _resolveEmployeeUserId(Employee employee) async {
    if (employee.userId != null && employee.userId!.isNotEmpty) {
      return employee.userId;
    }

    try {
      final companyId = await getCompanyId();
      final userByEmployeeId = await firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .where('employeeId', isEqualTo: employee.id)
          .limit(1)
          .get();
      if (userByEmployeeId.docs.isNotEmpty) {
        return userByEmployeeId.docs.first.id;
      }

      if (employee.email.isNotEmpty) {
        final userByEmail = await firestore
            .collection('companies')
            .doc(companyId)
            .collection('users')
            .where('email', isEqualTo: employee.email)
            .limit(1)
            .get();
        if (userByEmail.docs.isNotEmpty) {
          return userByEmail.docs.first.id;
        }
      }
    } catch (_) {}

    return null;
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Unknown';
  }

  Future<void> _processLoanRepayments(
    String employeeId,
    DateTime effectiveDate,
  ) async {
    final loans = await _loanService.getEmployeeLoans(employeeId);
    for (final loan in loans) {
      if (loan.status != LoanStatus.active || loan.monthlyDeduction <= 0) {
        continue;
      }
      final approvalDate = loan.approvalDate;
      if (approvalDate != null && approvalDate.isAfter(effectiveDate)) {
        continue;
      }
      if (approvalDate == null && loan.requestDate.isAfter(effectiveDate)) {
        continue;
      }
      await _loanService.updateLoanRepayment(loan.id, loan.monthlyDeduction);
    }
  }

  Future<void> _applyPayrollLinkedRecords({
    required Payroll payroll,
    required _PayrollCalculationResult calculation,
  }) async {
    if (calculation.calculatedItems.isNotEmpty) {
      await _payrollDeductionService.applyDeductions(
        payroll.id,
        payroll.employeeId,
        calculation.calculatedItems,
      );
    }

    if (calculation.legacyLoanDeduction > 0) {
      await _processLoanRepayments(payroll.employeeId, payroll.processedDate);
    }

    if (calculation.includedExpenseClaimIds.isNotEmpty) {
      await _expenseService.markExpensesPaid(
        calculation.includedExpenseClaimIds,
        payrollId: payroll.id,
        payrollMonth: payroll.month,
        payrollYear: payroll.year,
      );
    }

    if (calculation.includedIncentiveEntryIds.isNotEmpty) {
      await _incentiveService.markIncentivesPaid(
        calculation.includedIncentiveEntryIds,
        payrollId: payroll.id,
        payrollMonth: payroll.month,
        payrollYear: payroll.year,
      );
    }

    if (calculation.appliedOneTimeAllowanceAssignmentIds.isNotEmpty) {
      await _allowancesService.markOneTimeAssignmentsPaid(
        calculation.appliedOneTimeAllowanceAssignmentIds,
        month: payroll.month,
        year: payroll.year,
      );
    }

    if (calculation.includedSalaryAdvanceIds.isNotEmpty) {
      await _salaryAdvanceService.markAdvancesRecovered(
        calculation.includedSalaryAdvanceIds,
        payrollId: payroll.id,
        payrollMonth: payroll.month,
        payrollYear: payroll.year,
      );
    }
  }

  Future<void> _rollbackPayrollLinkedRecords(Payroll payroll) async {
    final transactions = await _deductionTransactionService
        .getPayrollTransactions(payroll.id);
    var hasV2LoanTransactions = false;

    for (final transaction in transactions) {
      if (transaction.isStatutory) {
        continue;
      }

      final deductionId = transaction.employeeDeductionId.trim();
      if (deductionId.isEmpty || deductionId.startsWith('statutory_')) {
        continue;
      }

      await _employeeDeductionService.reverseDeductionProgress(
        deductionId,
        transaction.amount,
      );

      if (transaction.category == DeductionCategory.loan) {
        hasV2LoanTransactions = true;
        final deduction = await _employeeDeductionService.getDeductionById(
          deductionId,
        );
        final loanId = deduction?.referenceNumber?.trim() ?? '';
        if (loanId.isNotEmpty) {
          await _loanService.reverseLoanRepayment(loanId, transaction.amount);
        }
      }
    }

    if (!hasV2LoanTransactions && payroll.loanDeduction > 0) {
      await _reverseLegacyLoanRepayments(payroll);
    }

    await _deductionTransactionService.deleteTransactionsForPayroll(payroll.id);
    await _expenseService.unmarkExpensesPaidForPayroll(payroll.id);
    await _incentiveService.unmarkIncentivesPaidForPayroll(payroll.id);
    await _salaryAdvanceService.unmarkAdvancesRecoveredForPayroll(payroll.id);
    await _allowancesService.clearOneTimeAssignmentsPaidForPeriod(
      payroll.employeeId,
      month: payroll.month,
      year: payroll.year,
    );
  }

  Future<void> _reverseLegacyLoanRepayments(Payroll payroll) async {
    final loans = await _loanService.getEmployeeLoans(payroll.employeeId);
    for (final loan in loans) {
      if (loan.monthlyDeduction <= 0) {
        continue;
      }
      if (loan.status != LoanStatus.active &&
          loan.status != LoanStatus.completed) {
        continue;
      }
      final approvalDate = loan.approvalDate;
      if (approvalDate != null && approvalDate.isAfter(payroll.processedDate)) {
        continue;
      }
      if (approvalDate == null &&
          loan.requestDate.isAfter(payroll.processedDate)) {
        continue;
      }
      await _loanService.reverseLoanRepayment(loan.id, loan.monthlyDeduction);
    }
  }

  Future<List<Payroll>> getPayrollsByMonth(int month, int year) async {
    final payrollsRef = await companyCollection(_collection);
    final snapshot = await payrollsRef
        .where('month', isEqualTo: month)
        .where('year', isEqualTo: year)
        .get();
    return snapshot.docs.map((doc) => Payroll.fromJson(docData(doc))).toList();
  }

  Future<String> exportPayrollReportCsv(int month, int year) async {
    final payrolls = await getPayrollsByMonth(month, year);
    final buffer = StringBuffer();
    buffer.writeln(
      _csvRow([
        'Employee ID',
        'Employee Name',
        'Month',
        'Year',
        'Currency',
        'Base Currency',
        'Exchange Rate To Base',
        'Basic Salary',
        'Allowances',
        'Gross Salary',
        'PAYE',
        'Pension',
        'NHF',
        'Loan Deduction',
        'Other Deductions',
        'Total Deductions',
        'Net Salary',
      ]),
    );

    for (final payroll in payrolls) {
      buffer.writeln(
        _csvRow([
          payroll.employeeId,
          payroll.employeeName,
          payroll.month.toString(),
          payroll.year.toString(),
          payroll.currency,
          payroll.baseCurrency,
          payroll.exchangeRateToBase.toStringAsFixed(4),
          payroll.basicSalary.toStringAsFixed(2),
          payroll.allowances.toStringAsFixed(2),
          payroll.grossSalary.toStringAsFixed(2),
          payroll.paye.toStringAsFixed(2),
          payroll.pension.toStringAsFixed(2),
          payroll.nhf.toStringAsFixed(2),
          payroll.loanDeduction.toStringAsFixed(2),
          payroll.otherDeductions.toStringAsFixed(2),
          payroll.totalDeductions.toStringAsFixed(2),
          payroll.netSalary.toStringAsFixed(2),
        ]),
      );
    }

    return buffer.toString();
  }

  Future<List<Payroll>> getEmployeePayrolls(String employeeId) async {
    final payrollsRef = await companyCollection(_collection);
    final snapshot = await payrollsRef
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('year', descending: true)
        .orderBy('month', descending: true)
        .get();
    return snapshot.docs.map((doc) => Payroll.fromJson(docData(doc))).toList();
  }

  Future<void> updatePayrollStatus(String payrollId, String status) async {
    final existing = await getPayrollById(payrollId);
    if (existing?.isLocked == true) {
      throw PayrollLockedException(
        'Payroll for ${_monthName(existing!.month)} ${existing.year} is locked and cannot be modified.',
      );
    }
    if (status == 'paid' &&
        existing != null &&
        existing.approvalStatus != PayrollApprovalStatus.approved) {
      throw Exception('Payroll must be fully approved before marking as paid.');
    }
    final payrollsRef = await companyCollection(_collection);
    await payrollsRef.doc(payrollId).update({
      'status': status,
      if (status == 'paid')
        'approvalStatus': PayrollApprovalStatus.processed.name,
    });
  }

  Future<Payroll?> getPayrollById(String payrollId) async {
    final payrollsRef = await companyCollection(_collection);
    final doc = await payrollsRef.doc(payrollId).get();
    if (!doc.exists) return null;
    final data = docDataNullable(doc);
    return data == null ? null : Payroll.fromJson(data);
  }

  Future<Payroll> reversePayroll(
    String payrollId,
    String reason,
    String reversedBy,
  ) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Reversal reason is required.');
    }

    final original = await getPayrollById(payrollId);
    if (original == null) {
      throw Exception('Payroll not found.');
    }
    if (original.isReversal) {
      throw Exception('Cannot reverse a reversal entry.');
    }
    if (original.isLocked) {
      throw PayrollLockedException('Locked payroll cannot be reversed.');
    }
    if (original.isReversed) {
      throw Exception('Payroll is already reversed.');
    }

    await _rollbackPayrollLinkedRecords(original);

    final now = DateTime.now();
    final reversal = Payroll(
      id: const Uuid().v4(),
      employeeId: original.employeeId,
      employeeName: original.employeeName,
      month: original.month,
      year: original.year,
      currency: original.currency,
      baseCurrency: original.baseCurrency,
      exchangeRateToBase: original.exchangeRateToBase,
      basicSalary: -original.basicSalary,
      allowances: -original.allowances,
      grossSalary: -original.grossSalary,
      paye: -original.paye,
      pension: -original.pension,
      nhf: -original.nhf,
      loanDeduction: -original.loanDeduction,
      otherDeductions: -original.otherDeductions,
      totalDeductions: -original.totalDeductions,
      netSalary: -original.netSalary,
      basicSalaryBase: -original.basicSalaryBase,
      allowancesBase: -original.allowancesBase,
      grossSalaryBase: -original.grossSalaryBase,
      payeBase: -original.payeBase,
      pensionBase: -original.pensionBase,
      nhfBase: -original.nhfBase,
      loanDeductionBase: -original.loanDeductionBase,
      otherDeductionsBase: -original.otherDeductionsBase,
      totalDeductionsBase: -original.totalDeductionsBase,
      netSalaryBase: -original.netSalaryBase,
      processedDate: now,
      status: 'reversal',
      approvalStatus: PayrollApprovalStatus.processed,
      isReversal: true,
      originalPayrollId: original.id,
      reversalReason: normalizedReason,
      reversedBy: reversedBy,
      reversedAt: now,
    );

    final payrollsRef = await companyCollection(_collection);
    await payrollsRef.doc(reversal.id).set(reversal.toJson());

    await payrollsRef.doc(original.id).update({
      'status': 'reversed',
      'isReversed': true,
      'reversedPayrollId': reversal.id,
      'reversedBy': reversedBy,
      'reversedAt': Timestamp.fromDate(now),
    });
    await _generateReversalFinancialTransactions(
      originalPayroll: original,
      reversalPayroll: reversal,
      payrollRunId: _resolvePayrollRunId(reversal.id),
    );

    await _auditService.logAction(
      action: AuditAction.payrollReversed,
      entityType: 'payroll',
      entityId: original.id,
      entityName:
          '${original.employeeName} ${_monthName(original.month)} ${original.year}',
      before: original.toJson(),
      after: reversal.toJson(),
      userId: reversedBy,
    );

    return reversal;
  }

  Future<Payroll> createCorrectionPayroll(
    String payrollId,
    String reason,
    String correctedBy,
  ) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Correction reason is required.');
    }

    final original = await getPayrollById(payrollId);
    if (original == null) {
      throw Exception('Payroll not found.');
    }
    if (original.isReversal) {
      throw Exception('Cannot correct a reversal entry.');
    }
    if (original.isLocked) {
      throw PayrollLockedException('Locked payroll cannot be corrected.');
    }

    if (!original.isReversed) {
      await reversePayroll(
        payrollId,
        'Auto-reversal for correction',
        correctedBy,
      );
    }

    final employee = await _employeeService.getEmployeeById(
      original.employeeId,
    );
    if (employee == null) {
      throw Exception('Employee no longer exists for this payroll.');
    }
    final recalculated = await _getPayrollCalculation(
      employee,
      original.month,
      original.year,
      forceRefresh: true,
    );
    final now = DateTime.now();
    final calculated = recalculated.payroll;

    final correctedPayroll = Payroll(
      id: const Uuid().v4(),
      employeeId: calculated.employeeId,
      employeeName: calculated.employeeName,
      month: calculated.month,
      year: calculated.year,
      currency: calculated.currency,
      baseCurrency: calculated.baseCurrency,
      exchangeRateToBase: calculated.exchangeRateToBase,
      basicSalary: calculated.basicSalary,
      allowances: calculated.allowances,
      grossSalary: calculated.grossSalary,
      paye: calculated.paye,
      pension: calculated.pension,
      nhf: calculated.nhf,
      loanDeduction: calculated.loanDeduction,
      otherDeductions: calculated.otherDeductions,
      totalDeductions: calculated.totalDeductions,
      netSalary: calculated.netSalary,
      basicSalaryBase: calculated.basicSalaryBase,
      allowancesBase: calculated.allowancesBase,
      grossSalaryBase: calculated.grossSalaryBase,
      payeBase: calculated.payeBase,
      pensionBase: calculated.pensionBase,
      nhfBase: calculated.nhfBase,
      loanDeductionBase: calculated.loanDeductionBase,
      otherDeductionsBase: calculated.otherDeductionsBase,
      totalDeductionsBase: calculated.totalDeductionsBase,
      netSalaryBase: calculated.netSalaryBase,
      processedDate: now,
      status: 'pending',
      approvalStatus: PayrollApprovalStatus.draft,
      correctionOfPayrollId: original.id,
      correctionReason: normalizedReason,
      correctedBy: correctedBy,
      correctedAt: now,
      varianceGross: calculated.grossSalary - original.grossSalary,
      varianceNet: calculated.netSalary - original.netSalary,
      varianceDeductions: calculated.totalDeductions - original.totalDeductions,
      varianceGrossBase: calculated.grossSalaryBase - original.grossSalaryBase,
      varianceNetBase: calculated.netSalaryBase - original.netSalaryBase,
      varianceDeductionsBase:
          calculated.totalDeductionsBase - original.totalDeductionsBase,
    );

    final payrollsRef = await companyCollection(_collection);
    await payrollsRef.doc(correctedPayroll.id).set(correctedPayroll.toJson());
    await _applyPayrollLinkedRecords(
      payroll: correctedPayroll,
      calculation: recalculated,
    );
    await _generateFinancialTransactions(
      payroll: correctedPayroll,
      payrollRunId: _resolvePayrollRunId(correctedPayroll.id),
    );
    await payrollsRef.doc(original.id).update({
      'status': 'corrected',
      'correctionPayrollId': correctedPayroll.id,
    });

    await _auditService.logAction(
      action: AuditAction.payrollCorrected,
      entityType: 'payroll',
      entityId: original.id,
      entityName:
          '${original.employeeName} ${_monthName(original.month)} ${original.year}',
      before: original.toJson(),
      after: correctedPayroll.toJson(),
      userId: correctedBy,
    );

    return correctedPayroll;
  }

  Future<Payroll> processRetroactiveAdjustment({
    required String employeeId,
    required double oldSalary,
    required double newSalary,
    required DateTime effectiveFrom,
    required DateTime processedDate,
  }) async {
    final months = _monthsBetween(effectiveFrom, processedDate);
    if (months <= 0) {
      throw Exception(
        'No retroactive month found between effective date and processed date.',
      );
    }

    final monthlyDifference = newSalary - oldSalary;
    if (monthlyDifference == 0) {
      throw Exception('Old salary and new salary are the same.');
    }

    final employee = await _employeeService.getEmployeeById(employeeId);
    if (employee == null) {
      throw Exception('Employee not found.');
    }

    final multiCurrency = await _loadMultiCurrencySettings();
    final payoutCurrency = CurrencyFormatter.normalizeCurrencyCode(
      employee.payoutCurrency,
    );
    final exchangeRateToBase = multiCurrency.exchangeRateFor(payoutCurrency);
    final totalArrears = monthlyDifference * months;
    final totalArrearsBase = totalArrears * exchangeRateToBase;
    final retroTaxBase = await _calculateRetroactiveTax(
      totalArrearsBase: totalArrearsBase,
      months: months,
    );

    final retroPayeBase = retroTaxBase['paye'] ?? 0.0;
    final retroPensionBase = retroTaxBase['pension'] ?? 0.0;
    final retroNhfBase = retroTaxBase['nhf'] ?? 0.0;
    final retroTotalTaxBase = retroTaxBase['total'] ?? 0.0;

    final retroPaye = retroPayeBase / exchangeRateToBase;
    final retroPension = retroPensionBase / exchangeRateToBase;
    final retroNhf = retroNhfBase / exchangeRateToBase;
    final retroTotalTax = retroTotalTaxBase / exchangeRateToBase;
    final netArrears = totalArrears - retroTotalTax;
    final netArrearsBase = totalArrearsBase - retroTotalTaxBase;

    final retroPayroll = Payroll(
      id: const Uuid().v4(),
      employeeId: employee.id,
      employeeName: employee.fullName,
      month: processedDate.month,
      year: processedDate.year,
      currency: payoutCurrency,
      baseCurrency: multiCurrency.baseCurrency,
      exchangeRateToBase: exchangeRateToBase,
      basicSalary: 0.0,
      allowances: totalArrears,
      grossSalary: totalArrears,
      paye: retroPaye,
      pension: retroPension,
      nhf: retroNhf,
      loanDeduction: 0.0,
      otherDeductions: 0.0,
      totalDeductions: retroTotalTax,
      netSalary: netArrears,
      basicSalaryBase: 0.0,
      allowancesBase: totalArrearsBase,
      grossSalaryBase: totalArrearsBase,
      payeBase: retroPayeBase,
      pensionBase: retroPensionBase,
      nhfBase: retroNhfBase,
      loanDeductionBase: 0.0,
      otherDeductionsBase: 0.0,
      totalDeductionsBase: retroTotalTaxBase,
      netSalaryBase: netArrearsBase,
      processedDate: processedDate,
      status: 'pending',
      approvalStatus: PayrollApprovalStatus.draft,
      isRetroactive: true,
      retroactiveMonths: months,
      retroactiveArrears: totalArrears,
      retroactiveArrearsBase: totalArrearsBase,
      retroactiveOldSalary: oldSalary,
      retroactiveNewSalary: newSalary,
      retroactiveOldSalaryBase: oldSalary * exchangeRateToBase,
      retroactiveNewSalaryBase: newSalary * exchangeRateToBase,
      retroactiveEffectiveFrom: effectiveFrom,
      retroactiveProcessedDate: processedDate,
      retroactiveTax: retroTotalTax,
      retroactiveTaxBase: retroTotalTaxBase,
    );

    final payrollsRef = await companyCollection(_collection);
    await payrollsRef.doc(retroPayroll.id).set(retroPayroll.toJson());
    await _generateFinancialTransactions(
      payroll: retroPayroll,
      payrollRunId: _resolvePayrollRunId(retroPayroll.id),
    );
    await _auditService.logAction(
      action: AuditAction.payrollRetroactiveProcessed,
      entityType: 'payroll',
      entityId: retroPayroll.id,
      entityName:
          '${employee.fullName} Retroactive ${_monthName(processedDate.month)} ${processedDate.year}',
      after: retroPayroll.toJson(),
    );

    return retroPayroll;
  }

  int _monthsBetween(DateTime effectiveFrom, DateTime processedDate) {
    final start = DateTime(effectiveFrom.year, effectiveFrom.month);
    final end = DateTime(processedDate.year, processedDate.month);
    final diff = (end.year - start.year) * 12 + (end.month - start.month);
    if (diff < 0) return 0;
    return diff;
  }

  Future<Map<String, double>> _calculateRetroactiveTax({
    required double totalArrearsBase,
    required int months,
  }) async {
    if (months <= 0 || totalArrearsBase == 0) {
      return {'paye': 0, 'pension': 0, 'nhf': 0, 'total': 0};
    }

    final monthlyArrearsBase = totalArrearsBase / months;
    var totalPaye = 0.0;
    var totalPension = 0.0;
    var totalNhf = 0.0;
    for (var i = 0; i < months; i++) {
      final deduction = _payrollDeductionService.calculateStatutoryDeductions(
        monthlyArrearsBase,
        monthlyArrearsBase,
        taxableGrossPay: monthlyArrearsBase,
      );
      totalPaye += (deduction['paye'] ?? 0.0).toDouble();
      totalPension += (deduction['pension'] ?? 0.0).toDouble();
      totalNhf += (deduction['nhf'] ?? 0.0).toDouble();
    }
    return {
      'paye': totalPaye,
      'pension': totalPension,
      'nhf': totalNhf,
      'total': totalPaye + totalPension + totalNhf,
    };
  }

  Map<String, double> _calculateOffCycleTaxBase({
    required PayrollType payrollType,
    required double amountBase,
  }) {
    switch (payrollType) {
      case PayrollType.bonus:
      case PayrollType.commission:
      case PayrollType.thirteenth:
        final paye = _payrollDeductionService.calculatePAYE(amountBase * 12);
        return {'paye': paye, 'pension': 0.0, 'nhf': 0.0};
      case PayrollType.adhoc:
        final statutory = _payrollDeductionService.calculateStatutoryDeductions(
          amountBase,
          0.0,
          taxableGrossPay: 0.0,
        );
        return {
          'paye': (statutory['paye'] ?? 0).toDouble(),
          'pension': (statutory['pension'] ?? 0).toDouble(),
          'nhf': (statutory['nhf'] ?? 0).toDouble(),
        };
      case PayrollType.regular:
        final statutory = _payrollDeductionService.calculateStatutoryDeductions(
          amountBase,
          amountBase,
          taxableGrossPay: amountBase,
        );
        return {
          'paye': (statutory['paye'] ?? 0).toDouble(),
          'pension': (statutory['pension'] ?? 0).toDouble(),
          'nhf': (statutory['nhf'] ?? 0).toDouble(),
        };
    }
  }

  Future<void> submitForApproval(String payrollId) async {
    final payroll = await getPayrollById(payrollId);
    if (payroll == null) {
      throw Exception('Payroll not found.');
    }
    if (payroll.isLocked) {
      throw PayrollLockedException(
        'This payroll is locked and cannot be submitted for approval.',
      );
    }
    if (payroll.approvalStatus != PayrollApprovalStatus.draft &&
        payroll.approvalStatus != PayrollApprovalStatus.rejected) {
      throw Exception(
        'Only draft or rejected payrolls can be submitted for approval.',
      );
    }

    final currentUser = await _userService.getCurrentUserProfile();
    final approvalEntry = PayrollApproval(
      payrollId: payrollId,
      status: PayrollApprovalStatus.pendingHRReview,
      reviewedBy: currentUser?.id ?? 'system',
      reviewedAt: DateTime.now(),
      comments: 'Submitted for approval',
    );
    final payrollsRef = await companyCollection(_collection);
    await payrollsRef.doc(payrollId).update({
      'approvalStatus': PayrollApprovalStatus.pendingHRReview.name,
      'approvalHistory': FieldValue.arrayUnion([approvalEntry.toJson()]),
      'status': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approvePayroll(String payrollId, String approverId) async {
    final payroll = await getPayrollById(payrollId);
    if (payroll == null) {
      throw Exception('Payroll not found.');
    }
    if (payroll.isLocked) {
      throw PayrollLockedException('This payroll is locked.');
    }

    final approver = await _getUserById(approverId);
    if (approver == null) {
      throw Exception('Approver profile not found.');
    }

    final currentStatus = payroll.approvalStatus;
    final nextStatus = _resolveNextApprovalStatus(currentStatus, approver.role);
    if (nextStatus == null) {
      throw Exception(
        'Approver role ${approver.role.name} cannot approve payroll in status ${currentStatus.name}.',
      );
    }

    final approvalEntry = PayrollApproval(
      payrollId: payrollId,
      status: nextStatus,
      reviewedBy: approver.id,
      reviewedAt: DateTime.now(),
      comments:
          'Approved by ${approver.role.name.toUpperCase()} (${approver.name})',
    );

    final payrollsRef = await companyCollection(_collection);
    await payrollsRef.doc(payrollId).update({
      'approvalStatus': nextStatus.name,
      'approvalHistory': FieldValue.arrayUnion([approvalEntry.toJson()]),
      'status': nextStatus == PayrollApprovalStatus.approved
          ? 'approved'
          : 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectPayroll(
    String payrollId,
    String approverId,
    String reason,
  ) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw Exception('Rejection reason is required.');
    }

    final payroll = await getPayrollById(payrollId);
    if (payroll == null) {
      throw Exception('Payroll not found.');
    }
    if (payroll.isLocked) {
      throw PayrollLockedException('This payroll is locked.');
    }
    if (!_isPendingApprovalStatus(payroll.approvalStatus)) {
      throw Exception(
        'Only pending payrolls can be rejected. Current status: ${payroll.approvalStatus.name}.',
      );
    }

    final approver = await _getUserById(approverId);
    if (approver == null) {
      throw Exception('Approver profile not found.');
    }
    if (!_canRoleActOnStatus(approver.role, payroll.approvalStatus)) {
      throw Exception(
        'Approver role ${approver.role.name} cannot reject payroll in status ${payroll.approvalStatus.name}.',
      );
    }

    final rejectionEntry = PayrollApproval(
      payrollId: payrollId,
      status: PayrollApprovalStatus.rejected,
      reviewedBy: approver.id,
      reviewedAt: DateTime.now(),
      comments:
          'Rejected by ${approver.role.name.toUpperCase()} (${approver.name})',
      rejectionReason: normalizedReason,
    );

    final payrollsRef = await companyCollection(_collection);
    await payrollsRef.doc(payrollId).update({
      'approvalStatus': PayrollApprovalStatus.rejected.name,
      'approvalHistory': FieldValue.arrayUnion([rejectionEntry.toJson()]),
      'status': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Payroll>> getPayrollsPendingApproval() async {
    final payrollsRef = await companyCollection(_collection);
    final snapshot = await payrollsRef
        .where(
          'approvalStatus',
          whereIn: [
            PayrollApprovalStatus.pendingHRReview.name,
            PayrollApprovalStatus.pendingAccountantReview.name,
            PayrollApprovalStatus.pendingAccountantFinalApproval.name,
            // Legacy status values kept for backward-compatible querying.
            'pendingManagerApproval',
            'pendingFinanceApproval',
          ],
        )
        .get();
    return snapshot.docs.map((doc) => Payroll.fromJson(docData(doc))).toList();
  }

  Future<AppUser?> _getUserById(String userId) async {
    final normalizedId = userId.trim();
    if (normalizedId.isEmpty) return null;
    final companyId = await getCompanyId();
    final doc = await firestore
        .collection('companies')
        .doc(companyId)
        .collection('users')
        .doc(normalizedId)
        .get();
    final data = docDataNullable(doc);
    if (data == null) return null;
    return AppUser.fromJsonEncrypted(data);
  }

  PayrollApprovalStatus? _resolveNextApprovalStatus(
    PayrollApprovalStatus currentStatus,
    UserRole approverRole,
  ) {
    switch (currentStatus) {
      case PayrollApprovalStatus.pendingHRReview:
        return (approverRole == UserRole.hr || approverRole == UserRole.admin)
            ? PayrollApprovalStatus.pendingAccountantReview
            : null;
      case PayrollApprovalStatus.pendingAccountantReview:
        // Accountant/admin handles first accountant review stage.
        return (approverRole == UserRole.accountant ||
                approverRole == UserRole.admin)
            ? PayrollApprovalStatus.pendingAccountantFinalApproval
            : null;
      case PayrollApprovalStatus.pendingAccountantFinalApproval:
        // Final accountant approval stage.
        return (approverRole == UserRole.accountant ||
                approverRole == UserRole.admin)
            ? PayrollApprovalStatus.approved
            : null;
      default:
        return null;
    }
  }

  bool _isPendingApprovalStatus(PayrollApprovalStatus status) {
    return status == PayrollApprovalStatus.pendingHRReview ||
        status == PayrollApprovalStatus.pendingAccountantReview ||
        status == PayrollApprovalStatus.pendingAccountantFinalApproval;
  }

  bool _canRoleActOnStatus(UserRole role, PayrollApprovalStatus status) {
    return _resolveNextApprovalStatus(status, role) != null;
  }

  Future<void> deletePayroll(String payrollId) async {
    final payrollsRef = await companyCollection(_collection);
    final existing = await getPayrollById(payrollId);
    if (existing?.isLocked == true) {
      throw PayrollLockedException(
        'This payroll is locked and cannot be deleted.',
      );
    }
    await payrollsRef.doc(payrollId).delete();
    await _auditService.logAction(
      action: AuditAction.payrollDeleted,
      entityType: 'payroll',
      entityId: payrollId,
      entityName: existing == null
          ? null
          : '${existing.employeeName} ${_monthName(existing.month)} ${existing.year}',
      before: existing?.toJson(),
    );
  }

  Future<void> lockPayrollMonth(int month, int year) async {
    final payrolls = await getPayrollsByMonth(month, year);
    if (payrolls.isEmpty) {
      throw Exception(
        'No payroll records found for ${_monthName(month)} $year.',
      );
    }

    final user = await _userService.getCurrentUserProfile();
    final payrollsRef = await companyCollection(_collection);
    final batch = firestore.batch();

    for (final payroll in payrolls) {
      batch.update(payrollsRef.doc(payroll.id), {
        'isLocked': true,
        'lockedAt': Timestamp.now(),
        'lockedBy': user?.id ?? 'system',
      });
    }

    await batch.commit();
    await _auditService.logAction(
      action: AuditAction.payrollLocked,
      entityType: 'payroll_month',
      entityId: '${year}_${month.toString().padLeft(2, '0')}',
      entityName: '${_monthName(month)} $year',
      after: {
        'month': month,
        'year': year,
        'isLocked': true,
        'lockedBy': user?.id ?? 'system',
      },
      userId: user?.id,
      userName: user?.name,
    );
  }

  Future<bool> isPayrollMonthLocked(int month, int year) async {
    final payrolls = await getPayrollsByMonth(month, year);
    return payrolls.any((payroll) => payroll.isLocked);
  }

  Future<void> _ensureMonthNotLocked(int month, int year) async {
    final locked = await isPayrollMonthLocked(month, year);
    if (locked) {
      throw PayrollLockedException(
        'Payroll for ${_monthName(month)} $year is locked and cannot be reprocessed.',
      );
    }
  }

  Future<void> _checkDuplicatePayments(
    String employeeId,
    int month,
    int year,
  ) async {
    final existing = await getPayrollsByMonth(month, year);
    final duplicate = existing.where((p) {
      if (p.employeeId != employeeId) return false;
      if (p.status == 'reversed') return false;
      if (p.isReversal) return false;
      return true;
    }).toList();

    if (duplicate.isNotEmpty) {
      throw DuplicatePaymentException(
        'Employee $employeeId already has payroll entries for $month/$year.',
      );
    }
  }

  String _payrollIdempotencyKey(String employeeId, int month, int year) {
    final normalizedMonth = month.toString().padLeft(2, '0');
    return 'payroll_regular_${employeeId}_$year$normalizedMonth';
  }

  Future<void> _generateFinancialTransactions({
    required Payroll payroll,
    required String payrollRunId,
  }) async {
    try {
      await _payrollTransactionService.generateTransactionsFromPayroll(
        payroll: payroll,
        payrollRunId: payrollRunId,
      );
      developer.log(
        'Generated financial transactions for payroll ${payroll.id}',
        name: 'PayrollService',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to generate financial transactions for payroll ${payroll.id}',
        name: 'PayrollService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _generateReversalFinancialTransactions({
    required Payroll originalPayroll,
    required Payroll reversalPayroll,
    required String payrollRunId,
  }) async {
    try {
      await _payrollTransactionService.generateReversalTransactions(
        originalPayroll: originalPayroll,
        reversalPayroll: reversalPayroll,
        payrollRunId: payrollRunId,
      );
      developer.log(
        'Generated reversal financial transactions for payroll ${reversalPayroll.id}',
        name: 'PayrollService',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to generate reversal financial transactions for payroll ${reversalPayroll.id}',
        name: 'PayrollService',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String _resolvePayrollRunId(String seed) {
    final normalized = seed.trim();
    return normalized.isEmpty ? const Uuid().v4() : normalized;
  }

  Future<List<BankAccountConflict>> detectBankAccountConflicts() async {
    final employees = await _employeeService.getAllEmployees();
    final accountMap = <String, List<Employee>>{};

    for (final employee in employees) {
      final accountNumber = employee.accountNumber?.trim() ?? '';
      if (accountNumber.isEmpty) continue;
      accountMap.putIfAbsent(accountNumber, () => <Employee>[]).add(employee);
    }

    return accountMap.entries
        .where((entry) => entry.value.length > 1)
        .map(
          (entry) => BankAccountConflict(
            accountNumber: entry.key,
            employees: entry.value,
          ),
        )
        .toList();
  }

  Future<double> getTotalMonthlyPayroll(int month, int year) async {
    final payrolls = await getPayrollsByMonth(month, year);
    var total = 0.0;
    for (final payroll in payrolls) {
      total += payroll.netSalaryBase;
    }
    return total;
  }

  Future<Map<String, dynamic>> getPayrollStats(int month, int year) async {
    final payrolls = await getPayrollsByMonth(month, year);

    var totalGross = 0.0;
    var totalNet = 0.0;
    var totalTax = 0.0;
    var totalPension = 0.0;
    var totalOvertimePay = 0.0;
    var totalLateDeductions = 0.0;
    var totalAbsentDeductions = 0.0;

    for (final payroll in payrolls) {
      totalGross += payroll.grossSalaryBase;
      totalNet += payroll.netSalaryBase;
      totalTax += payroll.payeBase;
      totalPension += payroll.pensionBase;
    }

    final summaries = await _attendanceSummaryService.getAllSummariesForMonth(
      month,
      year,
    );
    for (final summary in summaries) {
      totalOvertimePay += summary.totalOvertimePay;
      totalLateDeductions += summary.totalLateDeductions;
      totalAbsentDeductions += summary.totalAbsentDeductions;
    }

    return {
      'employeeCount': payrolls.length,
      'totalGross': totalGross,
      'totalNet': totalNet,
      'totalTax': totalTax,
      'totalPension': totalPension,
      'totalOvertimePay': totalOvertimePay,
      'totalLateDeductions': totalLateDeductions,
      'totalAbsentDeductions': totalAbsentDeductions,
      'averageGross': payrolls.isEmpty ? 0 : totalGross / payrolls.length,
      'averageNet': payrolls.isEmpty ? 0 : totalNet / payrolls.length,
    };
  }

  Future<List<MonthlyPayrollTrend>> getPayrollTrendData({
    int months = 6,
    DateTime? endDate,
  }) async {
    final trends = <MonthlyPayrollTrend>[];
    final now = endDate ?? DateTime.now();

    for (int i = months - 1; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final month = targetDate.month;
      final year = targetDate.year;

      final payrolls = await getPayrollsByMonth(month, year);

      var totalGross = 0.0;
      var totalNet = 0.0;
      var totalDeductions = 0.0;

      for (final payroll in payrolls) {
        totalGross += payroll.grossSalaryBase;
        totalNet += payroll.netSalaryBase;
        totalDeductions += payroll.totalDeductionsBase;
      }

      final employeeCount = payrolls.length;
      final avgSalary = employeeCount > 0 ? totalNet / employeeCount : 0.0;

      var growthPercentage = 0.0;
      if (trends.isNotEmpty) {
        final previousNet = trends.last.totalNet;
        if (previousNet > 0) {
          growthPercentage = ((totalNet - previousNet) / previousNet) * 100;
        }
      }

      trends.add(
        MonthlyPayrollTrend(
          month: month,
          year: year,
          period: '${_shortMonthName(month)} $year',
          totalGross: totalGross,
          totalNet: totalNet,
          totalDeductions: totalDeductions,
          employeeCount: employeeCount,
          avgSalary: avgSalary,
          growthPercentage: growthPercentage,
        ),
      );
    }

    return trends;
  }

  bool detectPayrollAnomalies(
    List<MonthlyPayrollTrend> trends, {
    double thresholdPercentage = 40,
  }) {
    if (trends.length < 2) return false;
    final recent = trends.last;
    return recent.growthPercentage.abs() > thresholdPercentage;
  }

  Future<SystemHealthSummary> getSystemHealth({
    bool includeDeepAlerts = false,
    List<Employee>? preloadedEmployees,
    List<Payroll>? preloadedCurrentPayrolls,
  }) async {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;

    final previousMonthDate = DateTime(now.year, now.month - 1, 1);
    final futures = <Future<dynamic>>[
      getPayrollsByMonth(previousMonthDate.month, previousMonthDate.year),
      _loanService.getActiveLoans(),
    ];
    if (preloadedCurrentPayrolls == null) {
      futures.insert(0, getPayrollsByMonth(currentMonth, currentYear));
    }
    if (preloadedEmployees == null) {
      futures.add(_employeeService.getAllEmployees());
    }

    final results = await Future.wait<dynamic>(futures);

    int idx = 0;
    final currentPayrolls =
        preloadedCurrentPayrolls ?? (results[idx++] as List<Payroll>);
    final previousPayrolls = results[idx++] as List<Payroll>;
    final activeLoans = results[idx++] as List<Loan>;
    final employees = preloadedEmployees ?? (results[idx++] as List<Employee>);

    var growth = 0.0;
    final currentTotalNet = currentPayrolls.fold<double>(
      0,
      (acc, payroll) => acc + payroll.netSalaryBase,
    );
    final previousTotalNet = previousPayrolls.fold<double>(
      0,
      (acc, payroll) => acc + payroll.netSalaryBase,
    );
    if (previousTotalNet > 0) {
      growth = ((currentTotalNet - previousTotalNet) / previousTotalNet) * 100;
    }

    final totalLoanExposure = activeLoans.fold<double>(
      0.0,
      (double acc, Loan loan) => acc + loan.remainingBalance,
    );
    final loanExposure = currentTotalNet > 0
        ? (totalLoanExposure / currentTotalNet) * 100
        : 0.0;

    final avgSalary = currentPayrolls.isEmpty
        ? 0.0
        : currentTotalNet / currentPayrolls.length;

    final activeEmployees = employees
        .where((employee) => employee.status == 'active')
        .toList();
    final employeesByDepartment = <String, int>{};
    for (final employee in activeEmployees) {
      final department = employee.department.trim().isEmpty
          ? 'Unassigned'
          : employee.department.trim();
      employeesByDepartment[department] =
          (employeesByDepartment[department] ?? 0) + 1;
    }

    PayrollStatus status;
    if (currentPayrolls.isEmpty) {
      status = PayrollStatus.notProcessed;
    } else if (currentPayrolls.length < activeEmployees.length) {
      status = PayrollStatus.processing;
    } else {
      status = PayrollStatus.completed;
    }

    final alertCount = includeDeepAlerts
        ? (await generateSystemAlerts(currentMonth, currentYear)).length
        : _estimateQuickAlertCount(
            activeEmployees: activeEmployees,
            currentPayrolls: currentPayrolls,
          );

    return SystemHealthSummary(
      currentMonthNetPayroll: currentTotalNet,
      activeEmployeeCount: activeEmployees.length,
      payrollGrowthPercentage: growth,
      loanExposurePercentage: loanExposure,
      avgSalary: avgSalary,
      status: status,
      alertCount: alertCount,
      employeesByDepartment: employeesByDepartment,
    );
  }

  int _estimateQuickAlertCount({
    required List<Employee> activeEmployees,
    required List<Payroll> currentPayrolls,
  }) {
    var count = 0;

    count += activeEmployees
        .where((employee) => employee.basicSalary <= 0)
        .length;

    final emailUsage = <String, int>{};
    for (final employee in activeEmployees) {
      final email = employee.email.trim().toLowerCase();
      if (email.isEmpty) continue;
      emailUsage[email] = (emailUsage[email] ?? 0) + 1;
    }
    count += emailUsage.values.where((usage) => usage > 1).length;

    if (currentPayrolls.isNotEmpty) {
      count += 1;
    }

    return count;
  }

  String _shortMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : 'Unknown';
  }

  String _csvRow(List<String> values) {
    return values
        .map((value) {
          final escaped = value.replaceAll('"', '""');
          return '"$escaped"';
        })
        .join(',');
  }
}

class PayrollLockedException implements Exception {
  final String message;
  PayrollLockedException(this.message);

  @override
  String toString() => message;
}

class DuplicatePaymentException implements Exception {
  final String message;
  DuplicatePaymentException(this.message);

  @override
  String toString() => message;
}

class BankAccountConflict {
  final String accountNumber;
  final List<Employee> employees;

  const BankAccountConflict({
    required this.accountNumber,
    required this.employees,
  });
}

class PayrollPreviewCancelledException implements Exception {
  @override
  String toString() => 'Payroll preview was cancelled.';
}

class PreviewCancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class _PayrollCalculationResult {
  final Payroll payroll;
  final List<CalculatedDeduction> calculatedItems;
  final double legacyLoanDeduction;
  final double expenseReimbursementTotal;
  final List<String> includedExpenseClaimIds;
  final double incentiveTotal;
  final List<String> includedIncentiveEntryIds;
  final double salaryAdvanceTotal;
  final List<String> includedSalaryAdvanceIds;
  final List<String> appliedOneTimeAllowanceAssignmentIds;

  _PayrollCalculationResult({
    required this.payroll,
    required this.calculatedItems,
    required this.legacyLoanDeduction,
    required this.expenseReimbursementTotal,
    required this.includedExpenseClaimIds,
    required this.incentiveTotal,
    required this.includedIncentiveEntryIds,
    required this.salaryAdvanceTotal,
    required this.includedSalaryAdvanceIds,
    required this.appliedOneTimeAllowanceAssignmentIds,
  });
}

class _ProcessedPayrollResult {
  final Payroll payroll;
  final _PayslipDispatchResult dispatchResult;

  _ProcessedPayrollResult({
    required this.payroll,
    required this.dispatchResult,
  });
}

class _PayslipDispatchResult {
  final bool notificationSent;
  final bool notificationFailed;
  final bool emailQueued;
  final bool emailSkippedNoEmail;
  final bool emailFailed;

  const _PayslipDispatchResult({
    required this.notificationSent,
    required this.notificationFailed,
    required this.emailQueued,
    required this.emailSkippedNoEmail,
    required this.emailFailed,
  });
}

class _PayrollAutomationSettings {
  final bool autoSendPayslipEmail;
  final bool autoSendPayrollNotification;

  const _PayrollAutomationSettings({
    required this.autoSendPayslipEmail,
    required this.autoSendPayrollNotification,
  });
}

class _MultiCurrencySettings {
  final String baseCurrency;
  final Map<String, double> rates;

  const _MultiCurrencySettings({
    required this.baseCurrency,
    required this.rates,
  });

  double exchangeRateFor(String currencyCode) {
    final normalized = CurrencyFormatter.normalizeCurrencyCode(currencyCode);
    final rate = rates[normalized];
    if (rate == null || rate <= 0) return 1.0;
    return rate;
  }
}

class PayrollProcessingResult {
  final String payrollRunId;
  final List<Payroll> payrolls;
  final int attemptedEmployeeCount;
  final int emailQueuedCount;
  final int emailSkippedNoEmailCount;
  final int emailFailedCount;
  final int notificationSentCount;
  final int notificationFailedCount;
  final int processingFailedCount;
  final List<PayrollProcessingFailure> processingFailures;
  final bool autoSendPayslipEmailEnabled;
  final bool autoSendPayrollNotificationEnabled;

  const PayrollProcessingResult({
    required this.payrollRunId,
    required this.payrolls,
    required this.attemptedEmployeeCount,
    required this.emailQueuedCount,
    required this.emailSkippedNoEmailCount,
    required this.emailFailedCount,
    required this.notificationSentCount,
    required this.notificationFailedCount,
    required this.processingFailedCount,
    required this.processingFailures,
    required this.autoSendPayslipEmailEnabled,
    required this.autoSendPayrollNotificationEnabled,
  });
}

class PayrollProcessingFailure {
  final String employeeId;
  final String employeeName;
  final String message;

  const PayrollProcessingFailure({
    required this.employeeId,
    required this.employeeName,
    required this.message,
  });
}

class _PayrollCalcCacheEntry {
  final DateTime createdAt;
  final Future<_PayrollCalculationResult> future;

  _PayrollCalcCacheEntry({required this.createdAt, required this.future});
}
