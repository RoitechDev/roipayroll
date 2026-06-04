import 'package:roipayroll/models/deduction_transaction_model.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/expense_claim_model.dart';
import 'package:roipayroll/models/incentive_entry_model.dart';
import 'package:roipayroll/models/ledger_account_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/payroll_transaction_model.dart';
import 'package:roipayroll/models/salary_advance_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/deduction_transaction_service.dart';
import 'package:uuid/uuid.dart';

class PayrollTransactionService extends BaseService {
  static const String collectionName = 'payroll_transactions';
  final DeductionTransactionService _deductionTransactionService =
      DeductionTransactionService();

  Future<List<PayrollTransaction>> generateTransactionsFromPayroll({
    required Payroll payroll,
    required String payrollRunId,
  }) async {
    final existing = await getTransactionsForPayroll(payroll.id);
    if (existing.isNotEmpty) {
      return existing;
    }

    final exchangeRate = payroll.exchangeRateToBase <= 0
        ? 1.0
        : payroll.exchangeRateToBase;
    final now = DateTime.now();
    final transactions = <PayrollTransaction>[];
    final expenseClaims = await _getExpenseClaimsByPayroll(payroll.id);
    final incentives = await _getIncentivesByPayroll(payroll.id);
    final salaryAdvances = await _getSalaryAdvancesByPayroll(payroll.id);
    final deductionTransactions = await _deductionTransactionService
        .getPayrollTransactions(payroll.id);

    final expenseBaseTotal = expenseClaims.fold<double>(
      0.0,
      (sum, claim) => sum + (claim.amount * exchangeRate),
    );
    final incentiveBaseTotal = incentives.fold<double>(
      0.0,
      (sum, entry) => sum + (entry.amount * exchangeRate),
    );
    final salaryExpenseBase =
        payroll.grossSalaryBase - expenseBaseTotal - incentiveBaseTotal;

    _addTransaction(
      transactions,
      payroll: payroll,
      payrollRunId: payrollRunId,
      now: now,
      type: TransactionType.salary,
      description:
          'Salary accrual for ${_monthName(payroll.month)} ${payroll.year}',
      debitAccount: PayrollLedgerChartOfAccounts.salaryExpense,
      creditAccount: PayrollLedgerChartOfAccounts.employeePayable,
      amount: salaryExpenseBase / exchangeRate,
      amountBase: salaryExpenseBase,
      metadata: {
        'payrollType': payroll.payrollType.name,
        'basicSalary': payroll.basicSalary,
        'allowances': payroll.allowances,
      },
    );

    for (final claim in expenseClaims) {
      _addTransaction(
        transactions,
        payroll: payroll,
        payrollRunId: payrollRunId,
        now: now,
        type: TransactionType.reimbursement,
        description: 'Expense reimbursement: ${claim.category.name}',
        debitAccount: PayrollLedgerChartOfAccounts.expenseReimbursementExpense,
        creditAccount: PayrollLedgerChartOfAccounts.employeePayable,
        amount: claim.amount,
        amountBase: claim.amount * exchangeRate,
        metadata: {
          'expenseId': claim.id,
          'expenseCategory': claim.category.name,
          'description': claim.description,
          'isTaxable': claim.isTaxable,
        },
      );
    }

    for (final incentive in incentives) {
      _addTransaction(
        transactions,
        payroll: payroll,
        payrollRunId: payrollRunId,
        now: now,
        type: TransactionType.incentive,
        description: '${_titleCase(incentive.type.name)} incentive payout',
        debitAccount: PayrollLedgerChartOfAccounts.incentiveExpense,
        creditAccount: PayrollLedgerChartOfAccounts.employeePayable,
        amount: incentive.amount,
        amountBase: incentive.amount * exchangeRate,
        metadata: {
          'incentiveId': incentive.id,
          'incentiveType': incentive.type.name,
          'description': incentive.description,
          'isTaxable': incentive.isTaxable,
        },
      );
    }

    _addTransaction(
      transactions,
      payroll: payroll,
      payrollRunId: payrollRunId,
      now: now,
      type: TransactionType.paye,
      description: 'PAYE withholding',
      debitAccount: PayrollLedgerChartOfAccounts.employeePayable,
      creditAccount: PayrollLedgerChartOfAccounts.payePayable,
      amount: payroll.paye,
      amountBase: payroll.payeBase,
    );
    _addTransaction(
      transactions,
      payroll: payroll,
      payrollRunId: payrollRunId,
      now: now,
      type: TransactionType.pension,
      description: 'Pension withholding',
      debitAccount: PayrollLedgerChartOfAccounts.employeePayable,
      creditAccount: PayrollLedgerChartOfAccounts.pensionPayable,
      amount: payroll.pension,
      amountBase: payroll.pensionBase,
    );
    _addTransaction(
      transactions,
      payroll: payroll,
      payrollRunId: payrollRunId,
      now: now,
      type: TransactionType.nhf,
      description: 'NHF withholding',
      debitAccount: PayrollLedgerChartOfAccounts.employeePayable,
      creditAccount: PayrollLedgerChartOfAccounts.nhfPayable,
      amount: payroll.nhf,
      amountBase: payroll.nhfBase,
    );

    double nonStatutoryDeductionBaseTotal = 0.0;
    double v2LoanDeductionBaseTotal = 0.0;
    for (final deduction in deductionTransactions) {
      if (deduction.isStatutory) {
        continue;
      }

      nonStatutoryDeductionBaseTotal += deduction.amount;
      if (deduction.category == DeductionCategory.loan) {
        v2LoanDeductionBaseTotal += deduction.amount;
      }

      _addTransaction(
        transactions,
        payroll: payroll,
        payrollRunId: payrollRunId,
        now: now,
        type: _transactionTypeForDeduction(deduction),
        description: '${deduction.deductionTypeName} deduction',
        debitAccount: PayrollLedgerChartOfAccounts.employeePayable,
        creditAccount: _creditAccountForDeduction(deduction.category),
        amount: deduction.amount / exchangeRate,
        amountBase: deduction.amount,
        metadata: {
          'deductionTransactionId': deduction.id,
          'deductionTypeId': deduction.deductionTypeId,
          'deductionTypeName': deduction.deductionTypeName,
          'deductionCategory': deduction.category.name,
          'employeeDeductionId': deduction.employeeDeductionId,
          'balanceBefore': deduction.balanceBefore,
          'balanceAfter': deduction.balanceAfter,
          'referenceNumber': deduction.metadata?['referenceNumber'],
        },
      );
    }

    final legacyLoanDeductionBase =
        payroll.loanDeductionBase - v2LoanDeductionBaseTotal;
    _addTransaction(
      transactions,
      payroll: payroll,
      payrollRunId: payrollRunId,
      now: now,
      type: TransactionType.loan,
      description: 'Legacy loan deduction',
      debitAccount: PayrollLedgerChartOfAccounts.employeePayable,
      creditAccount: PayrollLedgerChartOfAccounts.loanReceivable,
      amount: legacyLoanDeductionBase / exchangeRate,
      amountBase: legacyLoanDeductionBase,
      metadata: {'legacySource': true},
    );

    double salaryAdvanceBaseTotal = 0.0;
    for (final advance in salaryAdvances) {
      final amountBase = advance.amount * exchangeRate;
      salaryAdvanceBaseTotal += amountBase;
      _addTransaction(
        transactions,
        payroll: payroll,
        payrollRunId: payrollRunId,
        now: now,
        type: TransactionType.advance,
        description: 'Salary advance recovery',
        debitAccount: PayrollLedgerChartOfAccounts.employeePayable,
        creditAccount: PayrollLedgerChartOfAccounts.advanceReceivable,
        amount: advance.amount,
        amountBase: amountBase,
        metadata: {'salaryAdvanceId': advance.id, 'reason': advance.reason},
      );
    }

    final residualDeductionBase =
        payroll.totalDeductionsBase -
        payroll.payeBase -
        payroll.pensionBase -
        payroll.nhfBase -
        nonStatutoryDeductionBaseTotal -
        salaryAdvanceBaseTotal -
        legacyLoanDeductionBase;
    _addTransaction(
      transactions,
      payroll: payroll,
      payrollRunId: payrollRunId,
      now: now,
      type: TransactionType.deduction,
      description: 'Other payroll deductions',
      debitAccount: PayrollLedgerChartOfAccounts.employeePayable,
      creditAccount: PayrollLedgerChartOfAccounts.otherDeductionsPayable,
      amount: residualDeductionBase / exchangeRate,
      amountBase: residualDeductionBase,
      metadata: {'derived': true},
    );

    await _saveTransactions(transactions);
    return getTransactionsForPayroll(payroll.id);
  }

  Future<List<PayrollTransaction>> generateReversalTransactions({
    required Payroll originalPayroll,
    required Payroll reversalPayroll,
    required String payrollRunId,
  }) async {
    final existing = await getTransactionsForPayroll(reversalPayroll.id);
    if (existing.isNotEmpty) {
      return existing;
    }

    final originalTransactions = await getTransactionsForPayroll(
      originalPayroll.id,
    );
    if (originalTransactions.isEmpty) {
      return generateTransactionsFromPayroll(
        payroll: reversalPayroll,
        payrollRunId: payrollRunId,
      );
    }

    final now = DateTime.now();
    final mirrored = originalTransactions
        .map(
          (transaction) => PayrollTransaction(
            id: const Uuid().v4(),
            payrollId: reversalPayroll.id,
            payrollRunId: payrollRunId,
            employeeId: reversalPayroll.employeeId,
            employeeName: reversalPayroll.employeeName,
            type: transaction.type,
            description: 'Reversal of ${transaction.description}',
            debitAccount: transaction.creditAccount,
            debitAccountName: transaction.creditAccountName,
            creditAccount: transaction.debitAccount,
            creditAccountName: transaction.debitAccountName,
            amount: transaction.amount,
            currency: reversalPayroll.currency,
            exchangeRate: reversalPayroll.exchangeRateToBase <= 0
                ? 1.0
                : reversalPayroll.exchangeRateToBase,
            amountBase: transaction.amountBase,
            transactionMonth: reversalPayroll.processedDate.month,
            transactionYear: reversalPayroll.processedDate.year,
            transactionDate: reversalPayroll.processedDate,
            createdAt: now,
            isReversal: true,
            metadata: {
              ...?transaction.metadata,
              'reversalOfPayrollId': originalPayroll.id,
              'reversalOfTransactionId': transaction.id,
            },
          ),
        )
        .toList();

    await _saveTransactions(mirrored);
    return getTransactionsForPayroll(reversalPayroll.id);
  }

  Future<List<PayrollTransaction>> getTransactionsForPayroll(
    String payrollId,
  ) async {
    final transactionsRef = await companyCollection(collectionName);
    final snapshot = await transactionsRef
        .where('payrollId', isEqualTo: payrollId)
        .get();
    final transactions = snapshot.docs
        .map((doc) => PayrollTransaction.fromJson(docData(doc)))
        .toList();
    transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return transactions;
  }

  Future<List<PayrollTransaction>> getTransactionsByPayrollRun(
    String payrollRunId,
  ) async {
    final transactionsRef = await companyCollection(collectionName);
    final snapshot = await transactionsRef
        .where('payrollRunId', isEqualTo: payrollRunId)
        .get();
    final transactions = snapshot.docs
        .map((doc) => PayrollTransaction.fromJson(docData(doc)))
        .toList();
    transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return transactions;
  }

  Future<List<PayrollTransaction>> getTransactionsForPeriod({
    required int month,
    required int year,
  }) async {
    final transactionsRef = await companyCollection(collectionName);
    final snapshot = await transactionsRef
        .where('transactionMonth', isEqualTo: month)
        .where('transactionYear', isEqualTo: year)
        .get();
    final transactions = snapshot.docs
        .map((doc) => PayrollTransaction.fromJson(docData(doc)))
        .toList();
    transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return transactions;
  }

  Future<double> getAccountBalance(String accountCode) async {
    final account = PayrollLedgerChartOfAccounts.byCode(accountCode);
    final transactionsRef = await companyCollection(collectionName);
    final snapshot = await transactionsRef.get();
    final transactions = snapshot.docs
        .map((doc) => PayrollTransaction.fromJson(docData(doc)))
        .toList();

    final debitTotal = transactions
        .where((transaction) => transaction.debitAccount == accountCode)
        .fold<double>(0.0, (sum, transaction) => sum + transaction.amountBase);
    final creditTotal = transactions
        .where((transaction) => transaction.creditAccount == accountCode)
        .fold<double>(0.0, (sum, transaction) => sum + transaction.amountBase);

    switch (account?.type) {
      case AccountType.asset:
      case AccountType.expense:
        return debitTotal - creditTotal;
      case AccountType.liability:
      case AccountType.equity:
      case AccountType.revenue:
      case null:
        return creditTotal - debitTotal;
    }
  }

  Future<void> _saveTransactions(List<PayrollTransaction> transactions) async {
    if (transactions.isEmpty) {
      return;
    }
    final transactionsRef = await companyCollection(collectionName);
    final batch = firestore.batch();
    for (final transaction in transactions) {
      batch.set(transactionsRef.doc(transaction.id), transaction.toJson());
    }
    await batch.commit();
  }

  String salarySettlementTransactionId(String paymentId) {
    return 'salary_settlement_$paymentId';
  }

  PayrollTransaction buildSalarySettlementTransaction({
    required Payroll payroll,
    required String payrollRunId,
    required String paymentId,
    required double amount,
    required DateTime settledAt,
    String? gatewayReference,
  }) {
    final exchangeRate = payroll.exchangeRateToBase <= 0
        ? 1.0
        : payroll.exchangeRateToBase;
    final amountBase = amount * exchangeRate;

    return PayrollTransaction(
      id: salarySettlementTransactionId(paymentId),
      payrollId: payroll.id,
      payrollRunId: payrollRunId,
      employeeId: payroll.employeeId,
      employeeName: payroll.employeeName,
      type: TransactionType.salaryPayment,
      description: 'Salary payment settlement',
      debitAccount: PayrollLedgerChartOfAccounts.employeePayable.code,
      debitAccountName: PayrollLedgerChartOfAccounts.employeePayable.name,
      creditAccount: PayrollLedgerChartOfAccounts.bankAccount.code,
      creditAccountName: PayrollLedgerChartOfAccounts.bankAccount.name,
      amount: amount.abs(),
      currency: payroll.currency,
      exchangeRate: exchangeRate,
      amountBase: amountBase.abs(),
      transactionMonth: settledAt.month,
      transactionYear: settledAt.year,
      transactionDate: settledAt,
      createdAt: settledAt,
      isReversal: payroll.isReversal,
      metadata: {
        'employeePaymentId': paymentId,
        if (gatewayReference != null && gatewayReference.trim().isNotEmpty)
          'gatewayReference': gatewayReference.trim(),
        'source': 'salary_payment_batch',
        'payrollMonth': payroll.month,
        'payrollYear': payroll.year,
      },
    );
  }

  Future<List<ExpenseClaim>> _getExpenseClaimsByPayroll(
    String payrollId,
  ) async {
    final expensesRef = await companyCollection('expenses');
    final snapshot = await expensesRef
        .where('payrollId', isEqualTo: payrollId)
        .get();
    return snapshot.docs
        .map((doc) => ExpenseClaim.fromJson(docData(doc)))
        .toList();
  }

  Future<List<IncentiveEntry>> _getIncentivesByPayroll(String payrollId) async {
    final incentivesRef = await companyCollection('incentives');
    final snapshot = await incentivesRef
        .where('payrollId', isEqualTo: payrollId)
        .get();
    return snapshot.docs
        .map((doc) => IncentiveEntry.fromJson(docData(doc)))
        .toList();
  }

  Future<List<SalaryAdvance>> _getSalaryAdvancesByPayroll(
    String payrollId,
  ) async {
    final advancesRef = await companyCollection('salary_advances');
    final snapshot = await advancesRef
        .where('payrollId', isEqualTo: payrollId)
        .get();
    return snapshot.docs
        .map((doc) => SalaryAdvance.fromJson(docData(doc)))
        .toList();
  }

  void _addTransaction(
    List<PayrollTransaction> transactions, {
    required Payroll payroll,
    required String payrollRunId,
    required DateTime now,
    required TransactionType type,
    required String description,
    required LedgerAccount debitAccount,
    required LedgerAccount creditAccount,
    required double amount,
    required double amountBase,
    Map<String, dynamic>? metadata,
  }) {
    if (_isZero(amountBase)) {
      return;
    }

    var normalizedDebitAccount = debitAccount;
    var normalizedCreditAccount = creditAccount;
    var normalizedAmount = amount;
    var normalizedAmountBase = amountBase;

    if (normalizedAmountBase < 0) {
      normalizedDebitAccount = creditAccount;
      normalizedCreditAccount = debitAccount;
      normalizedAmount = -normalizedAmount;
      normalizedAmountBase = -normalizedAmountBase;
    }

    transactions.add(
      PayrollTransaction(
        id: const Uuid().v4(),
        payrollId: payroll.id,
        payrollRunId: payrollRunId,
        employeeId: payroll.employeeId,
        employeeName: payroll.employeeName,
        type: type,
        description: description,
        debitAccount: normalizedDebitAccount.code,
        debitAccountName: normalizedDebitAccount.name,
        creditAccount: normalizedCreditAccount.code,
        creditAccountName: normalizedCreditAccount.name,
        amount: normalizedAmount.abs(),
        currency: payroll.currency,
        exchangeRate: payroll.exchangeRateToBase <= 0
            ? 1.0
            : payroll.exchangeRateToBase,
        amountBase: normalizedAmountBase.abs(),
        transactionMonth: payroll.processedDate.month,
        transactionYear: payroll.processedDate.year,
        transactionDate: payroll.processedDate,
        createdAt: now,
        isReversal: payroll.isReversal,
        metadata: metadata,
      ),
    );
  }

  LedgerAccount _creditAccountForDeduction(DeductionCategory category) {
    switch (category) {
      case DeductionCategory.loan:
        return PayrollLedgerChartOfAccounts.loanReceivable;
      case DeductionCategory.advance:
        return PayrollLedgerChartOfAccounts.advanceReceivable;
      case DeductionCategory.statutory:
      case DeductionCategory.garnishment:
      case DeductionCategory.insurance:
      case DeductionCategory.union:
      case DeductionCategory.other:
        return PayrollLedgerChartOfAccounts.otherDeductionsPayable;
    }
  }

  TransactionType _transactionTypeForDeduction(DeductionTransaction deduction) {
    switch (deduction.category) {
      case DeductionCategory.loan:
        return TransactionType.loan;
      case DeductionCategory.advance:
        return TransactionType.advance;
      case DeductionCategory.statutory:
      case DeductionCategory.garnishment:
      case DeductionCategory.insurance:
      case DeductionCategory.union:
      case DeductionCategory.other:
        return TransactionType.deduction;
    }
  }

  bool _isZero(double value) => value.abs() < 0.01;

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

  String _titleCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}
