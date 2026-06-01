import 'package:cloud_firestore/cloud_firestore.dart';

/// Nigerian Tax Compliance Model
class TaxCompliance {
  final String id;
  final String employeeId;
  final String employeeName;
  final int month;
  final int year;

  // Income Details
  final double grossSalary;
  final double basicSalary;
  final double allowances;
  final double taxableIncome;

  // Tax Calculation
  final double
  consolidatedReliefAllowance; // CRA: 20% of gross or ₦200k (higher)
  final double taxFreeIncome; // First ₦300k + CRA
  final double taxableAmount; // After relief
  final double payeTax; // Monthly PAYE
  final double annualPaye; // Annual PAYE

  // Tax Breakdown by Bracket
  final Map<String, double> taxByBracket; // e.g. {'7%': 21000, '11%': 33000}

  // Statutory Deductions
  final double pensionEmployee; // 8%
  final double pensionEmployer; // 10%
  final double nhf; // 2.5% of basic
  final double totalStatutoryDeductions;

  // Compliance Status
  final bool isCompliant;
  final List<String> violations; // e.g. ['Below minimum wage']

  // Metadata
  final DateTime calculatedAt;

  TaxCompliance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.year,
    required this.grossSalary,
    required this.basicSalary,
    required this.allowances,
    required this.taxableIncome,
    required this.consolidatedReliefAllowance,
    required this.taxFreeIncome,
    required this.taxableAmount,
    required this.payeTax,
    required this.annualPaye,
    required this.taxByBracket,
    required this.pensionEmployee,
    required this.pensionEmployer,
    required this.nhf,
    required this.totalStatutoryDeductions,
    this.isCompliant = true,
    this.violations = const [],
    DateTime? calculatedAt,
  }) : calculatedAt = calculatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'month': month,
      'year': year,
      'grossSalary': grossSalary,
      'basicSalary': basicSalary,
      'allowances': allowances,
      'taxableIncome': taxableIncome,
      'consolidatedReliefAllowance': consolidatedReliefAllowance,
      'taxFreeIncome': taxFreeIncome,
      'taxableAmount': taxableAmount,
      'payeTax': payeTax,
      'annualPaye': annualPaye,
      'taxByBracket': taxByBracket,
      'pensionEmployee': pensionEmployee,
      'pensionEmployer': pensionEmployer,
      'nhf': nhf,
      'totalStatutoryDeductions': totalStatutoryDeductions,
      'isCompliant': isCompliant,
      'violations': violations,
      'calculatedAt': Timestamp.fromDate(calculatedAt),
    };
  }

  factory TaxCompliance.fromJson(Map<String, dynamic> json) {
    return TaxCompliance(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      month: json['month'],
      year: json['year'],
      grossSalary: (json['grossSalary'] ?? 0).toDouble(),
      basicSalary: (json['basicSalary'] ?? 0).toDouble(),
      allowances: (json['allowances'] ?? 0).toDouble(),
      taxableIncome: (json['taxableIncome'] ?? 0).toDouble(),
      consolidatedReliefAllowance: (json['consolidatedReliefAllowance'] ?? 0)
          .toDouble(),
      taxFreeIncome: (json['taxFreeIncome'] ?? 0).toDouble(),
      taxableAmount: (json['taxableAmount'] ?? 0).toDouble(),
      payeTax: (json['payeTax'] ?? 0).toDouble(),
      annualPaye: (json['annualPaye'] ?? 0).toDouble(),
      taxByBracket: Map<String, double>.from(json['taxByBracket'] ?? {}),
      pensionEmployee: (json['pensionEmployee'] ?? 0).toDouble(),
      pensionEmployer: (json['pensionEmployer'] ?? 0).toDouble(),
      nhf: (json['nhf'] ?? 0).toDouble(),
      totalStatutoryDeductions: (json['totalStatutoryDeductions'] ?? 0)
          .toDouble(),
      isCompliant: json['isCompliant'] ?? true,
      violations: List<String>.from(json['violations'] ?? []),
      calculatedAt: (json['calculatedAt'] as Timestamp).toDate(),
    );
  }
}

/// Nigerian Minimum Wage Compliance
class LaborLawCompliance {
  static const double minimumWageNigeria = 70000.0; // New minimum wage 2024
  static const int maxWorkHoursPerWeek = 40;
  static const int maxOvertimeHoursPerWeek = 12;
  static const double overtimeRateWeekday = 1.5;
  static const double overtimeRateWeekend = 2.0;
  static const int annualLeaveDays = 21; // Nigerian Labor Act

  final String employeeId;
  final String employeeName;
  final double monthlySalary;
  final int workHoursPerWeek;
  final bool isCompliant;
  final List<String> violations;

  LaborLawCompliance({
    required this.employeeId,
    required this.employeeName,
    required this.monthlySalary,
    required this.workHoursPerWeek,
    required this.isCompliant,
    required this.violations,
  });

  static LaborLawCompliance validate({
    required String employeeId,
    required String employeeName,
    required double monthlySalary,
    required int workHoursPerWeek,
  }) {
    final violations = <String>[];

    // Check minimum wage
    if (monthlySalary < minimumWageNigeria) {
      violations.add(
        'Salary (₦${monthlySalary.toStringAsFixed(2)}) below minimum wage (₦$minimumWageNigeria)',
      );
    }

    // Check maximum work hours
    if (workHoursPerWeek > maxWorkHoursPerWeek) {
      violations.add(
        'Work hours ($workHoursPerWeek hrs/week) exceed legal maximum ($maxWorkHoursPerWeek hrs/week)',
      );
    }

    return LaborLawCompliance(
      employeeId: employeeId,
      employeeName: employeeName,
      monthlySalary: monthlySalary,
      workHoursPerWeek: workHoursPerWeek,
      isCompliant: violations.isEmpty,
      violations: violations,
    );
  }
}
