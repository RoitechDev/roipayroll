import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/expense_claim_model.dart';
import 'package:roipayroll/models/exit_management_model.dart';
import 'package:roipayroll/models/incentive_entry_model.dart';
import 'package:roipayroll/models/leave_request_model.dart';
import 'package:roipayroll/models/loan_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/payroll_trend_model.dart';
import 'package:roipayroll/models/salary_advance_model.dart';
import 'package:roipayroll/models/system_alert_model.dart';
import 'package:roipayroll/models/system_health_summary_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/expense_service.dart';
import 'package:roipayroll/services/exit_management_service.dart';
import 'package:roipayroll/services/incentive_service.dart';
import 'package:roipayroll/services/leave_request_service.dart';
import 'package:roipayroll/services/loan_service.dart';
import 'package:roipayroll/services/payroll_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/salary_advance_service.dart';

class DashboardSummary {
  final AppUser? user;
  final int totalEmployees;
  final double currentMonthPayroll;
  final double myLoans;
  final int pendingLoans;
  final double pendingLoanAmount;
  final int pendingExpenses;
  final double pendingExpenseAmount;
  final SystemHealthSummary systemHealth;

  const DashboardSummary({
    required this.user,
    required this.totalEmployees,
    required this.currentMonthPayroll,
    required this.myLoans,
    required this.pendingLoans,
    required this.pendingLoanAmount,
    required this.pendingExpenses,
    required this.pendingExpenseAmount,
    required this.systemHealth,
  });
}

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  Future<T> safeValue<T>(
    Future<T> future,
    T fallback, {
    required String label,
  }) async {
    try {
      return await future;
    } catch (e) {
      debugPrint('Dashboard summary fallback for $label: $e');
      return fallback;
    }
  }

  ref.watch(appRefreshProvider); // Manual refresh only

  final user = await ref.watch(currentUserProvider.future);
  final employeeService = EmployeeService();
  final expenseService = ExpenseService();
  final payrollService = PayrollService();
  final loanService = LoanService();

  if (user?.role == UserRole.employee) {
    final myLoans = await safeValue<double>(
      (user?.employeeId != null)
          ? loanService.getEmployeeOutstandingLoans(user!.employeeId!)
          : Future.value(0.0),
      0.0,
      label: 'employeeMyLoans',
    );

    return DashboardSummary(
      user: user,
      totalEmployees: 0,
      currentMonthPayroll: 0.0,
      myLoans: myLoans,
      pendingLoans: 0,
      pendingLoanAmount: 0.0,
      pendingExpenses: 0,
      pendingExpenseAmount: 0.0,
      systemHealth: const SystemHealthSummary(
        currentMonthNetPayroll: 0,
        activeEmployeeCount: 0,
        payrollGrowthPercentage: 0,
        loanExposurePercentage: 0,
        avgSalary: 0,
        status: PayrollStatus.notProcessed,
        alertCount: 0,
        employeesByDepartment: <String, int>{},
      ),
    );
  }

  final now = DateTime.now();
  final employees = await safeValue<List<Employee>>(
    employeeService.getAllEmployees(),
    <Employee>[],
    label: 'employees',
  );
  final payrolls = await safeValue<List<Payroll>>(
    payrollService.getPayrollsByMonth(now.month, now.year),
    <Payroll>[],
    label: 'payrolls',
  );

  final currentMonthPayroll = payrolls.fold<double>(
    0.0,
    (double acc, Payroll payroll) => acc + payroll.netSalaryBase,
  );

  final myLoans = await safeValue<double>(
    (user?.employeeId != null)
        ? loanService.getEmployeeOutstandingLoans(user!.employeeId!)
        : Future.value(0.0),
    0.0,
    label: 'myLoans',
  );

  final canApproveLoans =
      user != null &&
      PermissionService.hasPermission(user, Permission.approveLoan);
  final canApproveExpenses =
      user != null &&
      PermissionService.hasPermission(user, Permission.approveExpenses);

  final pendingLoanItems = await safeValue<List<Loan>>(
    canApproveLoans ? loanService.getPendingLoans() : Future.value(<Loan>[]),
    <Loan>[],
    label: 'pendingLoanItems',
  );
  final pendingExpenseItems = await safeValue<List<ExpenseClaim>>(
    canApproveExpenses
        ? expenseService.getPendingExpenses()
        : Future.value(<ExpenseClaim>[]),
    <ExpenseClaim>[],
    label: 'pendingExpenseItems',
  );

  final pendingLoanAmount = pendingLoanItems.fold<double>(
    0.0,
    (total, loan) => total + loan.amount,
  );
  final pendingExpenseAmount = pendingExpenseItems.fold<double>(
    0.0,
    (total, expense) => total + expense.amount,
  );

  final averageSalary = employees.isEmpty
      ? 0.0
      : employees
              .map((employee) => employee.basicSalary)
              .fold<double>(0.0, (sum, salary) => sum + salary) /
          employees.length;

  final health = await safeValue<SystemHealthSummary>(
    payrollService.getSystemHealth(
      includeDeepAlerts: false,
      preloadedEmployees: employees,
      preloadedCurrentPayrolls: payrolls,
    ),
    SystemHealthSummary(
      currentMonthNetPayroll: currentMonthPayroll,
      activeEmployeeCount: employees.where((e) => e.status == 'active').length,
      payrollGrowthPercentage: 0,
      loanExposurePercentage: 0,
      avgSalary: averageSalary,
      status: payrolls.isEmpty
          ? PayrollStatus.notProcessed
          : PayrollStatus.completed,
      alertCount: 0,
      employeesByDepartment: const <String, int>{},
    ),
    label: 'systemHealth',
  );

  return DashboardSummary(
    user: user,
    totalEmployees: employees.length,
    currentMonthPayroll: currentMonthPayroll,
    myLoans: myLoans,
    pendingLoans: pendingLoanItems.length,
    pendingLoanAmount: pendingLoanAmount,
    pendingExpenses: pendingExpenseItems.length,
    pendingExpenseAmount: pendingExpenseAmount,
    systemHealth: health,
  );
});

class ApprovalInboxSummary {
  final bool canApproveLeave;
  final bool canApproveLoan;
  final bool canApproveSalaryAdvance;
  final bool canApproveExpenses;
  final bool canApproveExitManagement;
  final bool canApproveIncentives;
  final int pendingLeaveRequests;
  final int pendingLoans;
  final int pendingSalaryAdvances;
  final int pendingExpenses;
  final int pendingExitRequests;
  final int pendingIncentives;

  const ApprovalInboxSummary({
    required this.canApproveLeave,
    required this.canApproveLoan,
    required this.canApproveSalaryAdvance,
    required this.canApproveExpenses,
    required this.canApproveExitManagement,
    required this.canApproveIncentives,
    required this.pendingLeaveRequests,
    required this.pendingLoans,
    required this.pendingSalaryAdvances,
    required this.pendingExpenses,
    required this.pendingExitRequests,
    required this.pendingIncentives,
  });

  int get totalPending =>
      pendingLeaveRequests +
      pendingLoans +
      pendingSalaryAdvances +
      pendingExpenses +
      pendingExitRequests +
      pendingIncentives;

  bool get hasVisibleModules =>
      canApproveLeave ||
      canApproveLoan ||
      canApproveSalaryAdvance ||
      canApproveExpenses ||
      canApproveExitManagement ||
      canApproveIncentives;
}

final approvalInboxSummaryProvider =
    FutureProvider.autoDispose<ApprovalInboxSummary>((ref) async {
      ref.watch(appRefreshProvider);

      final user = await ref.watch(currentUserProvider.future);
      if (user == null || user.role == UserRole.employee) {
        return const ApprovalInboxSummary(
          canApproveLeave: false,
          canApproveLoan: false,
          canApproveSalaryAdvance: false,
          canApproveExpenses: false,
          canApproveExitManagement: false,
          canApproveIncentives: false,
          pendingLeaveRequests: 0,
          pendingLoans: 0,
          pendingSalaryAdvances: 0,
          pendingExpenses: 0,
          pendingExitRequests: 0,
          pendingIncentives: 0,
        );
      }

      final canApproveLeave = PermissionService.hasPermission(
        user,
        Permission.approveLeave,
      );
      final canApproveLoan = PermissionService.hasPermission(
        user,
        Permission.approveLoan,
      );
      final canApproveSalaryAdvance = PermissionService.hasPermission(
        user,
        Permission.approveSalaryAdvance,
      );
      final canApproveExpenses = PermissionService.hasPermission(
        user,
        Permission.approveExpenses,
      );
      final canApproveExitManagement = PermissionService.hasPermission(
        user,
        Permission.approveExitManagement,
      );
      final canApproveIncentives =
          user.role == UserRole.admin ||
          user.role == UserRole.hr ||
          user.role == UserRole.accountant;

      final leaveService = LeaveRequestService();
      final loanService = LoanService();
      final salaryAdvanceService = SalaryAdvanceService();
      final expenseService = ExpenseService();
      final exitManagementService = ExitManagementService();
      final incentiveService = IncentiveService();

      final results = await Future.wait<dynamic>([
        canApproveLeave
            ? leaveService.getPendingLeaveRequests().then((list) => list.length)
            : Future.value(0),
        canApproveLoan
            ? loanService.getPendingLoans().then((list) => list.length)
            : Future.value(0),
        canApproveSalaryAdvance
            ? salaryAdvanceService.getPendingAdvances().then(
                (list) => list.length,
              )
            : Future.value(0),
        canApproveExpenses
            ? expenseService.getPendingExpenses().then((list) => list.length)
            : Future.value(0),
        canApproveExitManagement
            ? exitManagementService
                  .getExitRequestsByStatus(ExitStatus.pending)
                  .then((list) => list.length)
            : Future.value(0),
        canApproveIncentives
            ? incentiveService.getPendingIncentives().then(
                (list) => list.length,
              )
            : Future.value(0),
      ]);

      return ApprovalInboxSummary(
        canApproveLeave: canApproveLeave,
        canApproveLoan: canApproveLoan,
        canApproveSalaryAdvance: canApproveSalaryAdvance,
        canApproveExpenses: canApproveExpenses,
        canApproveExitManagement: canApproveExitManagement,
        canApproveIncentives: canApproveIncentives,
        pendingLeaveRequests: results[0] as int,
        pendingLoans: results[1] as int,
        pendingSalaryAdvances: results[2] as int,
        pendingExpenses: results[3] as int,
        pendingExitRequests: results[4] as int,
        pendingIncentives: results[5] as int,
      );
    });

enum DashboardApprovalModule {
  leave,
  loan,
  salaryAdvance,
  expense,
  exit,
  incentive,
}

class DashboardApprovalPreviewItem {
  final DashboardApprovalModule module;
  final String title;
  final String subtitle;
  final DateTime createdAt;
  final double? amount;

  const DashboardApprovalPreviewItem({
    required this.module,
    required this.title,
    required this.subtitle,
    required this.createdAt,
    this.amount,
  });
}

final dashboardApprovalPreviewProvider =
    FutureProvider.autoDispose<List<DashboardApprovalPreviewItem>>((
      ref,
    ) async {
      ref.watch(appRefreshProvider);

      final user = await ref.watch(currentUserProvider.future);
      if (user == null || user.role == UserRole.employee) {
        return const <DashboardApprovalPreviewItem>[];
      }

      final canApproveLeave = PermissionService.hasPermission(
        user,
        Permission.approveLeave,
      );
      final canApproveLoan = PermissionService.hasPermission(
        user,
        Permission.approveLoan,
      );
      final canApproveSalaryAdvance = PermissionService.hasPermission(
        user,
        Permission.approveSalaryAdvance,
      );
      final canApproveExpenses = PermissionService.hasPermission(
        user,
        Permission.approveExpenses,
      );
      final canApproveExitManagement = PermissionService.hasPermission(
        user,
        Permission.approveExitManagement,
      );
      final canApproveIncentives =
          user.role == UserRole.admin ||
          user.role == UserRole.hr ||
          user.role == UserRole.accountant;

      final leaveService = LeaveRequestService();
      final loanService = LoanService();
      final salaryAdvanceService = SalaryAdvanceService();
      final expenseService = ExpenseService();
      final exitManagementService = ExitManagementService();
      final incentiveService = IncentiveService();

      final results = await Future.wait<dynamic>([
        canApproveLeave
            ? leaveService.getPendingLeaveRequests()
            : Future.value(<LeaveRequest>[]),
        canApproveLoan
            ? loanService.getPendingLoans()
            : Future.value(<Loan>[]),
        canApproveSalaryAdvance
            ? salaryAdvanceService.getPendingAdvances()
            : Future.value(<SalaryAdvance>[]),
        canApproveExpenses
            ? expenseService.getPendingExpenses()
            : Future.value(<ExpenseClaim>[]),
        canApproveExitManagement
            ? exitManagementService.getExitRequestsByStatus(ExitStatus.pending)
            : Future.value(<ExitRequest>[]),
        canApproveIncentives
            ? incentiveService.getPendingIncentives()
            : Future.value(<IncentiveEntry>[]),
      ]);

      final items = <DashboardApprovalPreviewItem>[
        ...(results[0] as List<LeaveRequest>).map(
          (request) => DashboardApprovalPreviewItem(
            module: DashboardApprovalModule.leave,
            title: '${request.leaveTypeName} Request - ${request.employeeName}',
            subtitle:
                '${request.numberOfDays.toStringAsFixed(request.numberOfDays == request.numberOfDays.roundToDouble() ? 0 : 1)} day(s)',
            createdAt: request.requestedAt,
          ),
        ),
        ...(results[1] as List<Loan>).map(
          (loan) => DashboardApprovalPreviewItem(
            module: DashboardApprovalModule.loan,
            title: 'Loan Request - ${loan.employeeName}',
            subtitle: '${loan.durationMonths} month repayment plan',
            createdAt: loan.requestDate,
            amount: loan.amount,
          ),
        ),
        ...(results[2] as List<SalaryAdvance>).map(
          (advance) => DashboardApprovalPreviewItem(
            module: DashboardApprovalModule.salaryAdvance,
            title: 'Salary Advance - ${advance.employeeName}',
            subtitle: advance.reason.trim().isEmpty
                ? 'Advance request awaiting approval'
                : advance.reason,
            createdAt: advance.requestDate,
            amount: advance.amount,
          ),
        ),
        ...(results[3] as List<ExpenseClaim>).map(
          (expense) => DashboardApprovalPreviewItem(
            module: DashboardApprovalModule.expense,
            title: '${expense.category.name.toUpperCase()} Expense - ${expense.employeeName}',
            subtitle: expense.description.trim().isEmpty
                ? 'Expense claim awaiting approval'
                : expense.description,
            createdAt: expense.submittedAt,
            amount: expense.amount,
          ),
        ),
        ...(results[4] as List<ExitRequest>).map(
          (exitRequest) => DashboardApprovalPreviewItem(
            module: DashboardApprovalModule.exit,
            title: 'Exit Review - ${exitRequest.employeeName}',
            subtitle: exitRequest.reason.trim().isEmpty
                ? exitRequest.exitType.name
                : exitRequest.reason,
            createdAt: exitRequest.createdAt,
            amount: exitRequest.finalSettlement?.netSettlement,
          ),
        ),
        ...(results[5] as List<IncentiveEntry>).map(
          (entry) => DashboardApprovalPreviewItem(
            module: DashboardApprovalModule.incentive,
            title:
                '${entry.type.name.toUpperCase()} Entry - ${entry.employeeName}',
            subtitle: entry.description.trim().isEmpty
                ? 'Incentive awaiting approval'
                : entry.description,
            createdAt: entry.submittedAt,
            amount: entry.amount,
          ),
        ),
      ];

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items.take(5).toList(growable: false);
    });

final dashboardPayrollTrendProvider =
    FutureProvider.autoDispose<List<MonthlyPayrollTrend>>((ref) async {
      ref.watch(appRefreshProvider);
      return PayrollService().getPayrollTrendData(months: 6);
    });

final dashboardCriticalAlertsProvider =
    FutureProvider.autoDispose<List<SystemAlert>>((ref) async {
      ref.watch(appRefreshProvider);
      final now = DateTime.now();
      final alerts = await PayrollService().generateSystemAlerts(
        now.month,
        now.year,
      );
      return alerts.take(4).toList(growable: false);
    });

