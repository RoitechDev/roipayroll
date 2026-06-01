class MonthlyPayrollTrend {
  final int month;
  final int year;
  final String period;
  final double totalGross;
  final double totalNet;
  final double totalDeductions;
  final int employeeCount;
  final double avgSalary;
  final double growthPercentage;

  MonthlyPayrollTrend({
    required this.month,
    required this.year,
    required this.period,
    required this.totalGross,
    required this.totalNet,
    required this.totalDeductions,
    required this.employeeCount,
    required this.avgSalary,
    required this.growthPercentage,
  });
}
