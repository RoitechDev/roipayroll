enum PayrollStatus { notProcessed, processing, completed }

class SystemHealthSummary {
  final double currentMonthNetPayroll;
  final int activeEmployeeCount;
  final double payrollGrowthPercentage;
  final double loanExposurePercentage;
  final double avgSalary;
  final PayrollStatus status;
  final int alertCount;
  final Map<String, int> employeesByDepartment;

  const SystemHealthSummary({
    required this.currentMonthNetPayroll,
    required this.activeEmployeeCount,
    required this.payrollGrowthPercentage,
    required this.loanExposurePercentage,
    required this.avgSalary,
    required this.status,
    required this.alertCount,
    required this.employeesByDepartment,
  });
}
