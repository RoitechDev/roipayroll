import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/payroll_transaction_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/payroll_service.dart';
import 'package:roipayroll/services/payroll_transaction_service.dart';
import 'package:roipayroll/services/zoho_books_service.dart';

class AccountingEntry {
  final String account;
  final double debit;
  final double credit;
  final String description;
  final String? accountName;

  const AccountingEntry({
    required this.account,
    required this.debit,
    required this.credit,
    required this.description,
    this.accountName,
  });
}

class AccountingGlCodes {
  final String salaryExpense;
  final String bankAccount;
  final String payePayable;
  final String pensionPayable;
  final String nhfPayable;
  final String loanPayable;
  final String otherDeductionsPayable;

  const AccountingGlCodes({
    this.salaryExpense = '5100',
    this.bankAccount = '1010',
    this.payePayable = '2110',
    this.pensionPayable = '2120',
    this.nhfPayable = '2130',
    this.loanPayable = '2140',
    this.otherDeductionsPayable = '2150',
  });

  factory AccountingGlCodes.fromJson(Map<String, dynamic> json) {
    return AccountingGlCodes(
      salaryExpense: (json['salaryExpense'] ?? '5100').toString(),
      bankAccount: (json['bankAccount'] ?? '1010').toString(),
      payePayable: (json['payePayable'] ?? '2110').toString(),
      pensionPayable: (json['pensionPayable'] ?? '2120').toString(),
      nhfPayable: (json['nhfPayable'] ?? '2130').toString(),
      loanPayable: (json['loanPayable'] ?? '2140').toString(),
      otherDeductionsPayable: (json['otherDeductionsPayable'] ?? '2150')
          .toString(),
    );
  }
}

class AccountingIntegrationService extends BaseService {
  final PayrollService _payrollService = PayrollService();
  final PayrollTransactionService _payrollTransactionService =
      PayrollTransactionService();

  Future<List<AccountingEntry>> generateJournalEntries(
    int month,
    int year,
  ) async {
    final ledgerEntries = await _generateJournalEntriesFromLedger(month, year);
    if (ledgerEntries.isNotEmpty) {
      return ledgerEntries;
    }

    final payrolls = await _payrollService.getPayrollsByMonth(month, year);
    final validPayrolls = payrolls.where(_isAccountingEligible).toList();
    if (validPayrolls.isEmpty) return <AccountingEntry>[];

    final glCodes = await _loadGlCodes();
    double totalGross = 0;
    double totalNet = 0;
    double totalPaye = 0;
    double totalPension = 0;
    double totalNhf = 0;
    double totalLoan = 0;
    double totalOtherWithoutLoan = 0;

    for (final payroll in validPayrolls) {
      totalGross += payroll.grossSalaryBase;
      totalNet += payroll.netSalaryBase;
      totalPaye += payroll.payeBase;
      totalPension += payroll.pensionBase;
      totalNhf += payroll.nhfBase;
      totalLoan += payroll.loanDeductionBase;
      final other = payroll.otherDeductionsBase - payroll.loanDeductionBase;
      totalOtherWithoutLoan += other < 0 ? 0 : other;
    }

    final periodLabel = '${month.toString().padLeft(2, '0')}/$year';
    final entries = <AccountingEntry>[
      AccountingEntry(
        account: glCodes.salaryExpense,
        accountName: 'Salary Expense',
        debit: _round2(totalGross),
        credit: 0,
        description: 'Salary Expense $periodLabel',
      ),
      AccountingEntry(
        account: glCodes.bankAccount,
        accountName: 'Bank',
        debit: 0,
        credit: _round2(totalNet),
        description: 'Salary Payment $periodLabel',
      ),
      AccountingEntry(
        account: glCodes.payePayable,
        accountName: 'PAYE Payable',
        debit: 0,
        credit: _round2(totalPaye),
        description: 'PAYE Withholding $periodLabel',
      ),
      AccountingEntry(
        account: glCodes.pensionPayable,
        accountName: 'Pension Payable',
        debit: 0,
        credit: _round2(totalPension),
        description: 'Pension Liability $periodLabel',
      ),
      AccountingEntry(
        account: glCodes.nhfPayable,
        accountName: 'NHF Payable',
        debit: 0,
        credit: _round2(totalNhf),
        description: 'NHF Liability $periodLabel',
      ),
    ];

    if (totalLoan > 0) {
      entries.add(
        AccountingEntry(
          account: glCodes.loanPayable,
          accountName: 'Loan Deductions Payable',
          debit: 0,
          credit: _round2(totalLoan),
          description: 'Loan Deductions $periodLabel',
        ),
      );
    }

    if (totalOtherWithoutLoan > 0) {
      entries.add(
        AccountingEntry(
          account: glCodes.otherDeductionsPayable,
          accountName: 'Other Deductions Payable',
          debit: 0,
          credit: _round2(totalOtherWithoutLoan),
          description: 'Other Deductions $periodLabel',
        ),
      );
    }

    _validateBalancedJournal(entries, periodLabel);
    return entries;
  }

  Future<ZohoJournalEntryResponse> syncPayrollRunToZoho({
    required String payrollRunId,
    required ZohoBooksService zohoBooksService,
    String? referenceNumber,
    String? notes,
  }) async {
    final transactions = await _payrollTransactionService
        .getTransactionsByPayrollRun(payrollRunId);
    if (transactions.isEmpty) {
      return const ZohoJournalEntryResponse(
        success: false,
        error: 'No payroll transactions found for the requested payroll run.',
      );
    }

    final response = await zohoBooksService.createJournalEntry(
      referenceNumber:
          referenceNumber ??
          _buildRunReferenceNumber(payrollRunId, transactions),
      journalDate: transactions.first.transactionDate,
      transactions: transactions,
      notes: notes ?? _buildRunNotes(payrollRunId, transactions),
    );

    if (response.success) {
      final companyId = await getCompanyId();
      await _updateLastSyncedTimestamp(companyId);
    }

    return response;
  }

  Future<ZohoJournalEntryResponse> syncPeriodToZoho({
    required int month,
    required int year,
    required ZohoBooksService zohoBooksService,
    String? referenceNumber,
    String? notes,
  }) async {
    final transactions = await _payrollTransactionService
        .getTransactionsForPeriod(month: month, year: year);
    if (transactions.isEmpty) {
      return const ZohoJournalEntryResponse(
        success: false,
        error: 'No payroll transactions found for the requested period.',
      );
    }

    return zohoBooksService.createJournalEntry(
      referenceNumber:
          referenceNumber ??
          'PAYROLL-${year.toString()}-${month.toString().padLeft(2, '0')}',
      journalDate: DateTime(year, month, 1),
      transactions: transactions,
      notes: notes ?? 'Payroll journal sync for ${_monthName(month)} $year',
    );
  }

  Future<List<AccountingEntry>> _generateJournalEntriesFromLedger(
    int month,
    int year,
  ) async {
    final transactions = await _payrollTransactionService
        .getTransactionsForPeriod(month: month, year: year);
    if (transactions.isEmpty) {
      return <AccountingEntry>[];
    }

    final periodLabel = '${month.toString().padLeft(2, '0')}/$year';
    final accountTotals = <String, _AccountTotals>{};

    void accumulate({
      required String accountCode,
      required String accountName,
      required double debit,
      required double credit,
    }) {
      final current = accountTotals.putIfAbsent(
        accountCode,
        () =>
            _AccountTotals(accountCode: accountCode, accountName: accountName),
      );
      current.debit += debit;
      current.credit += credit;
    }

    for (final transaction in transactions) {
      accumulate(
        accountCode: transaction.debitAccount,
        accountName: transaction.debitAccountName,
        debit: transaction.amountBase,
        credit: 0,
      );
      accumulate(
        accountCode: transaction.creditAccount,
        accountName: transaction.creditAccountName,
        debit: 0,
        credit: transaction.amountBase,
      );
    }

    final entries =
        accountTotals.values
            .map(
              (entry) => AccountingEntry(
                account: entry.accountCode,
                accountName: entry.accountName,
                debit: _round2(entry.debit),
                credit: _round2(entry.credit),
                description: 'Payroll Journal $periodLabel',
              ),
            )
            .toList()
          ..sort((a, b) => a.account.compareTo(b.account));

    _validateBalancedJournal(entries, periodLabel);
    return entries;
  }

  String exportJournalEntriesCsv(List<AccountingEntry> entries) {
    final buffer = StringBuffer();
    buffer.writeln(
      _csvRow(['Account', 'Account Name', 'Debit', 'Credit', 'Description']),
    );
    for (final entry in entries) {
      buffer.writeln(
        _csvRow([
          entry.account,
          entry.accountName ?? '',
          entry.debit.toStringAsFixed(2),
          entry.credit.toStringAsFixed(2),
          entry.description,
        ]),
      );
    }
    return buffer.toString();
  }

  String exportToQuickBooksIIF(
    List<AccountingEntry> entries, {
    DateTime? journalDate,
    String documentNumber = '',
    String narration = 'Payroll Journal',
  }) {
    if (entries.isEmpty) return '';
    final date = _formatMmDdYyyy(journalDate ?? DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('!TRNS\tTRNSTYPE\tDATE\tACCNT\tAMOUNT\tDOCNUM\tMEMO');
    buffer.writeln('!SPL\tTRNSTYPE\tDATE\tACCNT\tAMOUNT\tDOCNUM\tMEMO');
    buffer.writeln('!ENDTRNS');

    final first = entries.first;
    final firstAmount = first.debit > 0 ? first.debit : -first.credit;
    buffer.writeln(
      'TRNS\tGENERAL JOURNAL\t$date\t${first.account}\t${firstAmount.toStringAsFixed(2)}\t$documentNumber\t$narration',
    );

    for (var i = 1; i < entries.length; i++) {
      final entry = entries[i];
      final amount = entry.debit > 0 ? -entry.debit : entry.credit;
      buffer.writeln(
        'SPL\tGENERAL JOURNAL\t$date\t${entry.account}\t${amount.toStringAsFixed(2)}\t$documentNumber\t${entry.description}',
      );
    }
    buffer.writeln('ENDTRNS');
    return buffer.toString();
  }

  String exportToXeroCsv(
    List<AccountingEntry> entries, {
    DateTime? journalDate,
    String narration = 'Payroll Journal',
    String taxType = 'NONE',
  }) {
    if (entries.isEmpty) return '';
    final date = _formatIsoDate(journalDate ?? DateTime.now());
    final buffer = StringBuffer();
    buffer.writeln(
      _csvRow([
        'Date',
        'Narration',
        'AccountCode',
        'AccountName',
        'Description',
        'TaxType',
        'DebitAmount',
        'CreditAmount',
      ]),
    );
    for (final entry in entries) {
      buffer.writeln(
        _csvRow([
          date,
          narration,
          entry.account,
          entry.accountName ?? '',
          entry.description,
          taxType,
          entry.debit.toStringAsFixed(2),
          entry.credit.toStringAsFixed(2),
        ]),
      );
    }
    return buffer.toString();
  }

  Future<AccountingGlCodes> _loadGlCodes() async {
    try {
      final companyId = await getCompanyId();
      final doc = await firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('accounting')
          .get();
      final data = doc.data();
      if (data == null) return const AccountingGlCodes();
      return AccountingGlCodes.fromJson(data);
    } catch (_) {
      return const AccountingGlCodes();
    }
  }

  Future<void> _updateLastSyncedTimestamp(String companyId) async {
    try {
      final settingsRef = companyCollectionRef(companyId, 'settings');
      final doc = await settingsRef.doc('zoho_books').get();
      if (!doc.exists) {
        return;
      }

      await settingsRef.doc('zoho_books').update({
        'lastSyncedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Failed to update Zoho last synced timestamp: $error');
    }
  }

  bool _isAccountingEligible(Payroll payroll) {
    if (payroll.isReversal) return false;
    if (payroll.status == 'reversed') return false;
    return true;
  }

  void _validateBalancedJournal(
    List<AccountingEntry> entries,
    String periodLabel,
  ) {
    final totalDebits = entries.fold<double>(
      0,
      (runningTotal, e) => runningTotal + e.debit,
    );
    final totalCredits = entries.fold<double>(
      0,
      (runningTotal, e) => runningTotal + e.credit,
    );
    final diff = (totalDebits - totalCredits).abs();
    if (diff > 0.01) {
      throw Exception(
        'Generated journal for $periodLabel is not balanced. Debits=${totalDebits.toStringAsFixed(2)}, Credits=${totalCredits.toStringAsFixed(2)}.',
      );
    }
  }

  String _csvRow(List<String> values) {
    return values
        .map((value) {
          final escaped = value.replaceAll('"', '""');
          return '"$escaped"';
        })
        .join(',');
  }

  String _formatMmDdYyyy(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  String _formatIsoDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  String _buildRunReferenceNumber(
    String payrollRunId,
    List<PayrollTransaction> transactions,
  ) {
    final period = transactions.first;
    return 'PAYRUN-${period.transactionYear}-${period.transactionMonth.toString().padLeft(2, '0')}-${_compactRunId(payrollRunId)}';
  }

  String _buildRunNotes(
    String payrollRunId,
    List<PayrollTransaction> transactions,
  ) {
    final employeeCount = transactions
        .map((transaction) => transaction.employeeId)
        .toSet()
        .length;
    final period = transactions.first;
    return 'Payroll journal sync for ${_monthName(period.transactionMonth)} ${period.transactionYear} (run: ${_compactRunId(payrollRunId)}, employees: $employeeCount)';
  }

  String _compactRunId(String payrollRunId) {
    final normalized = payrollRunId.trim();
    if (normalized.length <= 8) {
      return normalized;
    }
    return normalized.substring(0, 8).toUpperCase();
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
}

class _AccountTotals {
  final String accountCode;
  final String accountName;
  double debit = 0;
  double credit = 0;

  _AccountTotals({required this.accountCode, required this.accountName});
}
