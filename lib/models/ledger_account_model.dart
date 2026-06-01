enum AccountType { asset, liability, equity, revenue, expense }

class LedgerAccount {
  final String id;
  final String code;
  final String name;
  final AccountType type;
  final String? parentAccountCode;
  final bool isActive;

  const LedgerAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.parentAccountCode,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'type': type.name,
      'parentAccountCode': parentAccountCode,
      'isActive': isActive,
    };
  }

  factory LedgerAccount.fromJson(Map<String, dynamic> json) {
    return LedgerAccount(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      type: AccountType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => AccountType.expense,
      ),
      parentAccountCode: json['parentAccountCode']?.toString(),
      isActive: json['isActive'] != false,
    );
  }
}

class PayrollLedgerChartOfAccounts {
  static const salaryExpense = LedgerAccount(
    id: 'acc_salary_expense',
    code: '5100',
    name: 'Salary Expense',
    type: AccountType.expense,
  );

  static const expenseReimbursementExpense = LedgerAccount(
    id: 'acc_expense_reimbursement_expense',
    code: '5110',
    name: 'Expense Reimbursement Expense',
    type: AccountType.expense,
  );

  static const incentiveExpense = LedgerAccount(
    id: 'acc_incentive_expense',
    code: '5120',
    name: 'Incentive Expense',
    type: AccountType.expense,
  );

  static const employeePayable = LedgerAccount(
    id: 'acc_employee_payable',
    code: '2100',
    name: 'Employee Payable',
    type: AccountType.liability,
  );

  static const payePayable = LedgerAccount(
    id: 'acc_paye_payable',
    code: '2110',
    name: 'PAYE Tax Payable',
    type: AccountType.liability,
  );

  static const pensionPayable = LedgerAccount(
    id: 'acc_pension_payable',
    code: '2120',
    name: 'Pension Payable',
    type: AccountType.liability,
  );

  static const nhfPayable = LedgerAccount(
    id: 'acc_nhf_payable',
    code: '2130',
    name: 'NHF Payable',
    type: AccountType.liability,
  );

  static const otherDeductionsPayable = LedgerAccount(
    id: 'acc_other_deductions_payable',
    code: '2150',
    name: 'Other Deductions Payable',
    type: AccountType.liability,
  );

  static const bankAccount = LedgerAccount(
    id: 'acc_bank',
    code: '1010',
    name: 'Bank Account',
    type: AccountType.asset,
  );

  static const loanReceivable = LedgerAccount(
    id: 'acc_loan_receivable',
    code: '1200',
    name: 'Employee Loan Receivable',
    type: AccountType.asset,
  );

  static const advanceReceivable = LedgerAccount(
    id: 'acc_advance_receivable',
    code: '1210',
    name: 'Salary Advance Receivable',
    type: AccountType.asset,
  );

  static const List<LedgerAccount> all = [
    salaryExpense,
    expenseReimbursementExpense,
    incentiveExpense,
    employeePayable,
    payePayable,
    pensionPayable,
    nhfPayable,
    otherDeductionsPayable,
    bankAccount,
    loanReceivable,
    advanceReceivable,
  ];

  static LedgerAccount? byCode(String code) {
    final normalizedCode = code.trim();
    for (final account in all) {
      if (account.code == normalizedCode) {
        return account;
      }
    }
    return null;
  }
}
