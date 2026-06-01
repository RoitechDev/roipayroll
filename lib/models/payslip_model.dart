class Payslip {
  final String employeeName;
  final String employeeId;
  final String department;
  final String position;
  final String month;
  final int year;
  final double basicSalary;
  final double allowances;
  final double grossSalary;
  final double paye;
  final double pension;
  final double nhf;
  final double totalDeductions;
  final double netSalary;
  final DateTime generatedDate;

  Payslip({
    required this.employeeName,
    required this.employeeId,
    required this.department,
    required this.position,
    required this.month,
    required this.year,
    required this.basicSalary,
    required this.allowances,
    required this.grossSalary,
    required this.paye,
    required this.pension,
    required this.nhf,
    required this.totalDeductions,
    required this.netSalary,
    required this.generatedDate,
  });
}
