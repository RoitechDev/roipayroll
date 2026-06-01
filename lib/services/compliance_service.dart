import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/tax_compliance_model.dart';
import 'package:roipayroll/models/payroll_audit_model.dart';
import 'package:uuid/uuid.dart';

/// Complete Nigerian Compliance Service
class ComplianceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nigerian Tax Brackets (2024)
  static const Map<String, Map<String, dynamic>> taxBrackets = {
    '7%': {'min': 0.0, 'max': 300000.0, 'rate': 0.07},
    '11%': {'min': 300000.0, 'max': 600000.0, 'rate': 0.11},
    '15%': {'min': 600000.0, 'max': 1100000.0, 'rate': 0.15},
    '19%': {'min': 1100000.0, 'max': 1600000.0, 'rate': 0.19},
    '21%': {'min': 1600000.0, 'max': 3200000.0, 'rate': 0.21},
    '24%': {'min': 3200000.0, 'max': double.infinity, 'rate': 0.24},
  };

  /// Calculate Nigerian PAYE Tax with full breakdown
  TaxCompliance calculateTaxCompliance({
    required String employeeId,
    required String employeeName,
    required int month,
    required int year,
    required double basicSalary,
    required double allowances,
  }) {
    final grossSalary = basicSalary + allowances;
    final annualGross = grossSalary * 12;

    // CRA: 20% of gross or ₦200k (whichever is higher) + 1% of gross
    final craOption1 = annualGross * 0.20;
    final craOption2 = 200000.0;
    final cra = craOption1 > craOption2 ? craOption1 : craOption2;
    final additionalRelief = annualGross * 0.01;
    final consolidatedReliefAllowance = cra + additionalRelief;

    // Tax-free income
    final taxFreeIncome = 300000.0 + consolidatedReliefAllowance;
    final taxableAmount = (annualGross - taxFreeIncome).clamp(
      0.0,
      double.infinity,
    );

    // Calculate tax by bracket
    final taxByBracket = <String, double>{};
    double totalTax = 0;
    double remainingIncome = taxableAmount;

    for (var entry in taxBrackets.entries) {
      final bracket = entry.value;
      final min = (bracket['min'] as num).toDouble();
      final max = (bracket['max'] as num).toDouble();
      final rate = (bracket['rate'] as num).toDouble();

      if (remainingIncome <= 0) break;

      final bracketRange = max - min;
      final taxableInBracket = remainingIncome > bracketRange
          ? bracketRange
          : remainingIncome;
      final taxForBracket = taxableInBracket * rate;

      if (taxForBracket > 0) {
        taxByBracket[entry.key] = taxForBracket;
        totalTax += taxForBracket;
        remainingIncome -= taxableInBracket;
      }
    }

    final monthlyPaye = totalTax / 12;

    // Statutory deductions
    final pensionEmployee = grossSalary * 0.08;
    final pensionEmployer = grossSalary * 0.10;
    final nhf = basicSalary * 0.025;
    final totalStatutory = monthlyPaye + pensionEmployee + nhf;

    // Compliance check
    final violations = <String>[];
    if (basicSalary < LaborLawCompliance.minimumWageNigeria) {
      violations.add(
        'Salary below minimum wage (₦${LaborLawCompliance.minimumWageNigeria})',
      );
    }

    return TaxCompliance(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      month: month,
      year: year,
      grossSalary: grossSalary,
      basicSalary: basicSalary,
      allowances: allowances,
      taxableIncome: annualGross,
      consolidatedReliefAllowance: consolidatedReliefAllowance,
      taxFreeIncome: taxFreeIncome,
      taxableAmount: taxableAmount,
      payeTax: monthlyPaye,
      annualPaye: totalTax,
      taxByBracket: taxByBracket,
      pensionEmployee: pensionEmployee,
      pensionEmployer: pensionEmployer,
      nhf: nhf,
      totalStatutoryDeductions: totalStatutory,
      isCompliant: violations.isEmpty,
      violations: violations,
    );
  }

  /// Validate labor law compliance
  LaborLawCompliance validateLaborLaw({
    required String employeeId,
    required String employeeName,
    required double monthlySalary,
    required int workHoursPerWeek,
  }) {
    return LaborLawCompliance.validate(
      employeeId: employeeId,
      employeeName: employeeName,
      monthlySalary: monthlySalary,
      workHoursPerWeek: workHoursPerWeek,
    );
  }

  /// Create audit log
  Future<void> createAuditLog(PayrollAuditLog log) async {
    await _firestore
        .collection('payroll_audit_logs')
        .doc(log.id)
        .set(log.toJson());
  }

  /// Get audit logs for employee
  Future<List<PayrollAuditLog>> getAuditLogs(String employeeId) async {
    final snapshot = await _firestore
        .collection('payroll_audit_logs')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('performedAt', descending: true)
        .limit(50)
        .get();

    return snapshot.docs
        .map((doc) => PayrollAuditLog.fromJson(doc.data()))
        .toList();
  }

  /// Create payroll approval record
  Future<PayrollApprovalRecord> createApprovalRecord({
    required String payrollBatchId,
    required int month,
    required int year,
    required int totalEmployees,
    required double totalGrossPay,
    required double totalDeductions,
    required double totalNetPay,
    required List<TaxCompliance> employeeTaxRecords,
  }) async {
    // Check compliance
    final violations = <String>[];
    for (var tax in employeeTaxRecords) {
      violations.addAll(tax.violations);
    }

    final record = PayrollApprovalRecord(
      id: const Uuid().v4(),
      payrollBatchId: payrollBatchId,
      month: month,
      year: year,
      totalEmployees: totalEmployees,
      totalGrossPay: totalGrossPay,
      totalDeductions: totalDeductions,
      totalNetPay: totalNetPay,
      complianceViolations: violations,
      taxCompliant: violations.isEmpty,
      laborLawCompliant: violations.isEmpty,
      minimumWageCompliant: violations.isEmpty,
    );

    await _firestore
        .collection('payroll_approvals')
        .doc(record.id)
        .set(record.toJson());

    return record;
  }

  /// Approve payroll
  Future<void> approvePayroll({
    required String approvalId,
    required String approvedBy,
    required String approvedByName,
  }) async {
    await _firestore.collection('payroll_approvals').doc(approvalId).update({
      'status': PayrollApprovalStatus.approved.name,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Reject payroll
  Future<void> rejectPayroll({
    required String approvalId,
    required String approvedBy,
    required String approvedByName,
    required String reason,
  }) async {
    await _firestore.collection('payroll_approvals').doc(approvalId).update({
      'status': PayrollApprovalStatus.rejected.name,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'approvedAt': Timestamp.fromDate(DateTime.now()),
      'rejectionReason': reason,
    });
  }

  /// Generate regulatory report (CSV export)
  Map<String, dynamic> generateTaxReport({
    required List<TaxCompliance> taxRecords,
    required int month,
    required int year,
  }) {
    double totalGross = 0;
    double totalPaye = 0;
    double totalPension = 0;
    double totalNhf = 0;

    for (var record in taxRecords) {
      totalGross += record.grossSalary;
      totalPaye += record.payeTax;
      totalPension += record.pensionEmployee;
      totalNhf += record.nhf;
    }

    return {
      'month': month,
      'year': year,
      'totalEmployees': taxRecords.length,
      'totalGrossIncome': totalGross,
      'totalPayeTax': totalPaye,
      'totalPensionContributions': totalPension,
      'totalNhfContributions': totalNhf,
      'totalStatutoryRemittance': totalPaye + totalPension + totalNhf,
      'records': taxRecords.map((r) => r.toJson()).toList(),
    };
  }
}
