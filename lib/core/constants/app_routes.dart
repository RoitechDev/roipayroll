/// All route paths used for navigation in the app
/// Using named routes makes navigation easier and prevents typos
class AppRoutes {
  // Root
  static const String root = '/';

  // Authentication Routes
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Main Routes
  static const String dashboard = '/dashboard';
  static const String home = '/home';
  static const String notifications = '/notifications';

  // Employee Routes
  static const String employees = '/employees';
  static const String employeeList = '/employees/list';
  static const String employeeDetails = '/employees/details';
  static const String addEmployee = '/employees/add';
  static const String editEmployee = '/employees/edit';
  static const String employeeImport = '/employees/import';
  static const String allowanceManagement = '/allowances';

  // Payroll Routes
  static const String payroll = '/payroll';
  static const String payrollList = '/payroll/list';
  static const String processPayroll = '/payroll/process';
  static const String offCyclePayroll = '/payroll/off-cycle';
  static const String payrollHistory = '/payroll/history';
  static const String paymentOperations = '/payroll/payments';
  static const String transactionList = '/payroll/transactions';
  static const String payslip = '/payroll/payslip';
  static const String viewPayslip = '/payroll/view-payslip';

  // Reports Routes
  static const String reports = '/reports';
  static const String auditLogs = '/audit-logs';
  static const String payrollReport = '/reports/payroll';
  static const String employeeReport = '/reports/employee';
  static const String taxReport = '/reports/tax';

  // Settings Routes
  static const String settings = '/settings';
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String changePassword = '/settings/change-password';
  static const String companySettings = '/settings/company';

  // User Management Routes
  static const String createUser = '/users/create';
  static const String usersList = '/users/list';

  // Loan Routes
  static const String requestLoan = '/loans/request';
  static const String loansList = '/loans/list';
  static const String loanDetails = '/loans/details';

  // Attendance Routes
  static const String clockIn = '/attendance/clock-in';
  static const String attendanceList = '/attendance/list';
  static const String attendanceReport = '/attendance/report';

  // Leave Routes
  static const String leaveDashboard = '/leave/dashboard';
  static const String leaveApply = '/leave/apply';
  static const String leaveMy = '/leave/my-leaves';
  static const String leaveApprovals = '/leave/approvals';
  static const String leaveBalances = '/leave/balances';
  static const String leaveTypes = '/leave/types';
  static const String leaveEncashment = '/leave/encashment';
  static const String publicHolidays = '/leave/public-holidays';

  // Compliance Routes
  static const String compliance = '/compliance';
  static const String complianceAlerts = '/compliance/alerts';

  // Deduction Routes
  static const String deductionTypes = '/deductions/types';
  static const String employeeDeductions = '/deductions/employee';
  static const String assignDeduction = '/deductions/assign';
  static const String myDeductions = '/deductions/my';
  static const String deductionHistory = '/deductions/history';

  // Expense Routes
  static const String expenseReimbursements = '/expenses/reimbursements';
  static const String salaryAdvances = '/salary-advances';
  static const String exitManagement = '/exit-management';

  // Incentive Routes
  static const String commissionBonus = '/incentives/commission-bonus';

  // Document Routes
  static const String documentManagement = '/documents/management';

  // Probation / Contract Routes
  static const String probation = '/probation';
  @Deprecated('Use AppRoutes.probation instead')
  static const String probationContractManagement = '/probation';
  static const String probationReview = '/probation/review';
  static const String contractCreate = '/probation/create-contract';
  static const String contractRenew = '/probation/renew-contract';
  static const String employmentHistory = '/probation/history';

  // Helper method to get route with parameters
  static String employeeDetailsWithId(String id) => '$employeeDetails?id=$id';
  static String editEmployeeWithId(String id) => '$editEmployee?id=$id';
  static String payslipWithId(String id) => '$payslip?id=$id';
  static String loanDetailsWithId(String id) => '$loanDetails?id=$id';
  static String probationReviewWithId(String id) => '$probationReview?id=$id';
  static String contractRenewWithId(String id) => '$contractRenew?id=$id';
  static String employmentHistoryWithId(String id) =>
      '$employmentHistory?id=$id';
}
