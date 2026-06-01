import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/payroll_trend_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/payroll_service.dart';

class ReportsPeriod {
  final int month;
  final int year;

  const ReportsPeriod({required this.month, required this.year});

  @override
  bool operator ==(Object other) {
    return other is ReportsPeriod && other.month == month && other.year == year;
  }

  @override
  int get hashCode => Object.hash(month, year);
}

enum ReportsRoleScope { admin, hr, accountant, employee }

class ReportsSummary {
  final AppUser? user;
  final ReportsRoleScope scope;
  final List<Employee> employees;
  final List<Payroll> payrolls;
  final List<Payroll> personalPayrolls;
  final Map<String, double> departmentTotals;
  final Map<String, int> departmentHeadcount;
  final double totalGross;
  final double totalTax;
  final double totalPension;
  final double totalNhf;
  final double totalNet;
  final double totalDeductions;
  final List<MonthlyPayrollTrend> payrollTrends;
  final int hiresThisMonth;
  final double previousGross;
  final double previousNet;
  final bool hasAnomaly;

  const ReportsSummary({
    required this.user,
    required this.scope,
    required this.employees,
    required this.payrolls,
    required this.personalPayrolls,
    required this.departmentTotals,
    required this.departmentHeadcount,
    required this.totalGross,
    required this.totalTax,
    required this.totalPension,
    required this.totalNhf,
    required this.totalNet,
    required this.totalDeductions,
    required this.payrollTrends,
    required this.hiresThisMonth,
    required this.previousGross,
    required this.previousNet,
    required this.hasAnomaly,
  });

  Payroll? get latestPersonalPayroll =>
      personalPayrolls.isEmpty ? null : personalPayrolls.first;

  int get employeeCount => employees.length;

  int get payrollEmployeeCount => payrolls.length;

  double get averageNetPay =>
      payrolls.isEmpty ? 0.0 : totalNet / payrolls.length;

  double get averageGrossPay =>
      payrolls.isEmpty ? 0.0 : totalGross / payrolls.length;

  double get grossGrowthPercentage {
    if (previousGross == 0) return 0.0;
    return ((totalGross - previousGross) / previousGross) * 100;
  }

  double get netGrowthPercentage {
    if (previousNet == 0) return 0.0;
    return ((totalNet - previousNet) / previousNet) * 100;
  }

  double get ytdGross {
    return personalPayrolls.fold<double>(
      0.0,
      (sum, payroll) => sum + payroll.grossSalaryBase,
    );
  }

  double get ytdNet {
    return personalPayrolls.fold<double>(
      0.0,
      (sum, payroll) => sum + payroll.netSalaryBase,
    );
  }

  double get ytdDeductions {
    return personalPayrolls.fold<double>(
      0.0,
      (sum, payroll) => sum + payroll.totalDeductionsBase,
    );
  }
}

final reportsSummaryProvider =
    FutureProvider.family<ReportsSummary, ReportsPeriod>((ref, period) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);

      final user = await ref.watch(currentUserProvider.future);
      final employeeService = EmployeeService();
      final payrollService = PayrollService();

      final employees = await employeeService.getAllEmployees();
      final payrolls = await payrollService.getPayrollsByMonth(
        period.month,
        period.year,
      );
      final payrollTrends = await payrollService.getPayrollTrendData(
        months: 6,
        endDate: DateTime(period.year, period.month, 1),
      );

      final isEmployeeScope = user?.role == UserRole.employee;
      final personalPayrolls =
          isEmployeeScope && user?.employeeId?.trim().isNotEmpty == true
          ? await payrollService.getEmployeePayrolls(user!.employeeId!.trim())
          : <Payroll>[];

      personalPayrolls.sort((a, b) {
        final left = DateTime(a.year, a.month);
        final right = DateTime(b.year, b.month);
        return right.compareTo(left);
      });

      final departmentTotals = <String, double>{};
      final departmentHeadcount = <String, int>{};
      final employeeById = {
        for (final employee in employees) employee.id: employee,
      };

      var gross = 0.0;
      var tax = 0.0;
      var pension = 0.0;
      var nhf = 0.0;
      var net = 0.0;
      var deductions = 0.0;

      for (final employee in employees) {
        departmentHeadcount[employee.department] =
            (departmentHeadcount[employee.department] ?? 0) + 1;
      }

      for (final payroll in payrolls) {
        final employee = employeeById[payroll.employeeId];
        final department = employee?.department ?? 'Unassigned';
        departmentTotals[department] =
            (departmentTotals[department] ?? 0.0) + payroll.netSalaryBase;

        gross += payroll.grossSalaryBase;
        tax += payroll.payeBase;
        pension += payroll.pensionBase;
        nhf += payroll.nhfBase;
        net += payroll.netSalaryBase;
        deductions += payroll.totalDeductionsBase;
      }

      final hiresThisMonth = employees.where((employee) {
        return employee.hireDate.month == period.month &&
            employee.hireDate.year == period.year;
      }).length;

      final previousTrend = payrollTrends.length >= 2
          ? payrollTrends[payrollTrends.length - 2]
          : null;

      return ReportsSummary(
        user: user,
        scope: switch (user?.role) {
          UserRole.admin => ReportsRoleScope.admin,
          UserRole.hr => ReportsRoleScope.hr,
          UserRole.accountant => ReportsRoleScope.accountant,
          UserRole.employee || null => ReportsRoleScope.employee,
        },
        employees: employees,
        payrolls: payrolls,
        personalPayrolls: personalPayrolls,
        departmentTotals: departmentTotals,
        departmentHeadcount: departmentHeadcount,
        totalGross: gross,
        totalTax: tax,
        totalPension: pension,
        totalNhf: nhf,
        totalNet: net,
        totalDeductions: deductions,
        payrollTrends: payrollTrends,
        hiresThisMonth: hiresThisMonth,
        previousGross: previousTrend?.totalGross ?? 0.0,
        previousNet: previousTrend?.totalNet ?? 0.0,
        hasAnomaly: payrollService.detectPayrollAnomalies(payrollTrends),
      );
    });
