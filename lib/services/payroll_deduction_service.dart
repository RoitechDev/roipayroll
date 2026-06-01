import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_transaction_model.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/employee_deduction_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/loan_model.dart';
import 'package:roipayroll/services/allowances_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/employee_deduction_service.dart';
import 'package:roipayroll/services/transaction_service.dart';
import 'package:roipayroll/services/user_service.dart';

class CalculatedDeduction {
  final String deductionTypeId;
  final String deductionTypeName;
  final String? employeeDeductionId;
  final DeductionCategory category;
  final double amount;
  final bool isStatutory;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? referenceNumber;

  CalculatedDeduction({
    required this.deductionTypeId,
    required this.deductionTypeName,
    required this.employeeDeductionId,
    required this.category,
    required this.amount,
    required this.isStatutory,
    this.balanceBefore,
    this.balanceAfter,
    this.referenceNumber,
  });
}

class PayrollDeductionService extends BaseService {
  static const String _employeeDeductionCollection = 'employee_deductions';
  static const String _loanCollection = 'loans';
  static const String _transactionCollection = 'deduction_transactions';
  final _allowancesService = AllowancesService();
  final _transactionService = TransactionService();
  late final EmployeeDeductionService _employeeDeductionService;

  PayrollDeductionService() {
    final userService = UserService();
    _employeeDeductionService = EmployeeDeductionService(
      userService: userService,
    );
  }

  Future<Map<String, dynamic>> calculateEmployeeDeductions(
    String employeeId,
    double grossPay,
    double basicPay, {
    double? taxableGrossPay,
  }) async {
    final statutory = calculateStatutoryDeductions(
      grossPay,
      basicPay,
      taxableGrossPay: taxableGrossPay,
    );
    final activeDeductions = await getDeductionsForPayroll(employeeId);
    final items = <CalculatedDeduction>[
      ...((statutory['items'] as List<CalculatedDeduction>)),
    ];

    double customTotal = 0;
    for (final deduction in activeDeductions) {
      final amount = _calculateEmployeeDeductionAmount(deduction, grossPay);
      if (amount <= 0) continue;

      final cappedAmount = amount > deduction.balance
          ? deduction.balance
          : amount;
      customTotal += cappedAmount;
      items.add(
        CalculatedDeduction(
          deductionTypeId: deduction.deductionTypeId,
          deductionTypeName: deduction.deductionTypeName,
          employeeDeductionId: deduction.id,
          category: deduction.category,
          amount: cappedAmount,
          isStatutory: false,
          balanceBefore: deduction.balance,
          balanceAfter: deduction.balance - cappedAmount,
          referenceNumber: deduction.referenceNumber,
        ),
      );
    }

    final statutoryTotal = (statutory['total'] ?? 0).toDouble();
    return {
      'items': items,
      'statutoryTotal': statutoryTotal,
      'customTotal': customTotal,
      'total': statutoryTotal + customTotal,
      'paye': (statutory['paye'] ?? 0).toDouble(),
      'pension': (statutory['pension'] ?? 0).toDouble(),
      'nhf': (statutory['nhf'] ?? 0).toDouble(),
    };
  }

  Future<void> applyDeductions(
    String payrollId,
    String employeeId,
    List<CalculatedDeduction> deductions,
  ) async {
    final now = DateTime.now();
    final companyId = await getCompanyId();
    final deductionsRef = companyCollectionRef(
      companyId,
      _employeeDeductionCollection,
    );
    final loansRef = companyCollectionRef(companyId, _loanCollection);
    final transactionsRef = companyCollectionRef(
      companyId,
      _transactionCollection,
    );
    final employeeName = await _resolveEmployeeName(employeeId);

    for (final deduction in deductions) {
      final transactionId = deduction.employeeDeductionId != null
          ? '${payrollId}_${deduction.employeeDeductionId}'
          : '${payrollId}_${deduction.deductionTypeId}';

      await _transactionService.runTransaction<void>((transaction) async {
        final transactionRef = transactionsRef.doc(transactionId);
        final existingTransaction = await transaction.get(transactionRef);
        if (existingTransaction.exists) {
          return;
        }

        if (!deduction.isStatutory && deduction.employeeDeductionId != null) {
          final deductionRef = deductionsRef.doc(
            deduction.employeeDeductionId!,
          );
          final deductionDoc = await transaction.get(deductionRef);
          if (!deductionDoc.exists) {
            throw Exception(
              'Employee deduction not found: ${deduction.employeeDeductionId}',
            );
          }

          final deductionData = docDataNullable(deductionDoc);
          if (deductionData == null) {
            throw Exception(
              'Employee deduction not found: ${deduction.employeeDeductionId}',
            );
          }

          final employeeDeduction = EmployeeDeduction.fromJson(deductionData);
          final newTotalDeducted =
              (employeeDeduction.totalDeducted + deduction.amount)
                  .clamp(0.0, employeeDeduction.totalAmount)
                  .toDouble();
          final newBalance = (employeeDeduction.totalAmount - newTotalDeducted)
              .clamp(0.0, employeeDeduction.totalAmount)
              .toDouble();
          final newInstallmentsPaid = employeeDeduction.installmentsPaid + 1;
          final isComplete = newBalance <= 0.01;

          _transactionService.updateWithVersion(transaction, deductionRef, {
            'amountDeducted': newTotalDeducted,
            'totalDeducted': newTotalDeducted,
            'balance': newBalance,
            'installmentsPaid': newInstallmentsPaid,
            'status': isComplete
                ? DeductionStatus.completed.name
                : DeductionStatus.active.name,
            'completedAt': isComplete ? FieldValue.serverTimestamp() : null,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final referenceNumber = deduction.referenceNumber?.trim() ?? '';
          if (deduction.category == DeductionCategory.loan &&
              referenceNumber.isNotEmpty) {
            final loanRef = loansRef.doc(referenceNumber);
            final loanDoc = await transaction.get(loanRef);
            if (!loanDoc.exists) {
              throw Exception('Loan not found: $referenceNumber');
            }

            final loanData = docDataNullable(loanDoc);
            if (loanData == null) {
              throw Exception('Loan not found: $referenceNumber');
            }

            final loan = Loan.fromJson(loanData);
            final newTotalRepaid = (loan.totalRepaid + deduction.amount)
                .clamp(0.0, loan.amount)
                .toDouble();
            final updatedLoan = loan.copyWith(
              totalRepaid: newTotalRepaid,
              status: newTotalRepaid >= loan.amount
                  ? LoanStatus.completed
                  : LoanStatus.active,
            );
            _transactionService.updateWithVersion(
              transaction,
              loanRef,
              updatedLoan.toJson(),
            );
          }
        }

        final deductionTransaction = DeductionTransaction(
          id: transactionId,
          payrollId: payrollId,
          payrollMonth: now.month,
          payrollYear: now.year,
          employeeId: employeeId,
          employeeName: employeeName,
          employeeDeductionId:
              deduction.employeeDeductionId ??
              'statutory_${deduction.deductionTypeId}',
          deductionTypeId: deduction.deductionTypeId,
          deductionTypeName: deduction.deductionTypeName,
          category: deduction.category,
          amount: deduction.amount,
          balanceBefore: deduction.balanceBefore ?? 0,
          balanceAfter: deduction.balanceAfter ?? 0,
          processedAt: now,
          processedBy: getCurrentUserId(),
          isStatutory: deduction.isStatutory,
          metadata: deduction.referenceNumber == null
              ? null
              : {'referenceNumber': deduction.referenceNumber},
        );
        _transactionService.setDoc(
          transaction,
          transactionRef,
          deductionTransaction.toJson(),
        );
      });
    }
  }

  Map<String, dynamic> calculateStatutoryDeductions(
    double grossPay,
    double basicPay, {
    double? taxableGrossPay,
  }) {
    final taxBase = taxableGrossPay ?? grossPay;
    final taxableIncome = taxBase * 12;
    final paye = calculatePAYE(taxableIncome);
    final pension = grossPay * 0.08;
    final nhf = basicPay * 0.025;
    final items = <CalculatedDeduction>[
      CalculatedDeduction(
        deductionTypeId: 'statutory_paye',
        deductionTypeName: 'PAYE',
        employeeDeductionId: null,
        category: DeductionCategory.statutory,
        amount: paye,
        isStatutory: true,
      ),
      CalculatedDeduction(
        deductionTypeId: 'statutory_pension',
        deductionTypeName: 'Pension',
        employeeDeductionId: null,
        category: DeductionCategory.statutory,
        amount: pension,
        isStatutory: true,
      ),
      CalculatedDeduction(
        deductionTypeId: 'statutory_nhf',
        deductionTypeName: 'NHF',
        employeeDeductionId: null,
        category: DeductionCategory.statutory,
        amount: nhf,
        isStatutory: true,
      ),
    ];

    return {
      'items': items,
      'paye': paye,
      'pension': pension,
      'nhf': nhf,
      'total': paye + pension + nhf,
    };
  }

  double calculatePAYE(double taxableIncome) {
    double relief =
        300000 + (taxableIncome * 0.01).clamp(200000, double.infinity);
    double chargeable = (taxableIncome - relief).clamp(0, double.infinity);
    double annualTax = 0;

    if (chargeable <= 300000) {
      annualTax = chargeable * 0.07;
    } else if (chargeable <= 600000) {
      annualTax = (300000 * 0.07) + ((chargeable - 300000) * 0.11);
    } else if (chargeable <= 1100000) {
      annualTax =
          (300000 * 0.07) + (300000 * 0.11) + ((chargeable - 600000) * 0.15);
    } else if (chargeable <= 1600000) {
      annualTax =
          (300000 * 0.07) +
          (300000 * 0.11) +
          (500000 * 0.15) +
          ((chargeable - 1100000) * 0.19);
    } else if (chargeable <= 3200000) {
      annualTax =
          (300000 * 0.07) +
          (300000 * 0.11) +
          (500000 * 0.15) +
          (500000 * 0.19) +
          ((chargeable - 1600000) * 0.21);
    } else {
      annualTax =
          (300000 * 0.07) +
          (300000 * 0.11) +
          (500000 * 0.15) +
          (500000 * 0.19) +
          (1600000 * 0.21) +
          ((chargeable - 3200000) * 0.24);
    }

    return annualTax / 12;
  }

  Future<double> getPensionBase(Employee employee) async {
    final allowances = await _allowancesService.getAllowances(employee.id);
    return employee.basicSalary +
        allowances.housingAllowance +
        allowances.transportAllowance;
  }

  Future<List<EmployeeDeduction>> getDeductionsForPayroll(
    String employeeId,
  ) async {
    return _employeeDeductionService.getActiveDeductions(employeeId);
  }

  double _calculateEmployeeDeductionAmount(
    EmployeeDeduction deduction,
    double grossPay,
  ) {
    switch (deduction.calculationMethod) {
      case DeductionCalculationMethod.fixedAmount:
        return deduction.amountPerPayroll;
      case DeductionCalculationMethod.percentage:
        final rate = deduction.percentageRate;
        return grossPay * (rate / 100);
      case DeductionCalculationMethod.formula:
        return deduction.amountPerPayroll;
    }
  }

  Future<String> _resolveEmployeeName(String employeeId) async {
    final employeesRef = await companyCollection('employees');
    final doc = await employeesRef.doc(employeeId).get();
    if (!doc.exists) return '';
    final data = docDataNullable(doc) ?? {};
    final firstName = data['firstName'] ?? '';
    final lastName = data['lastName'] ?? '';
    return '$firstName $lastName'.trim();
  }
}
