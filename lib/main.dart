import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

// Import theme and constants
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_routes.dart';

// Import screens
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/users/create_user.dart';
import 'screens/loan/request_loan_screen.dart';
import 'screens/loan/loans_list_screen.dart';
import 'screens/attendance/clock_in_screen.dart';
import 'screens/attendance/attendance_list_screen.dart';
import 'screens/compliance/compliance_screen.dart';
import 'screens/employees/add_employee_screen.dart';
import 'screens/employees/employee_list_screen.dart';
import 'screens/employees/employee_import_screen.dart';
import 'screens/allowances/allowance_management_screen.dart';
import 'screens/payroll/process_payroll_screen.dart';
import 'screens/payroll/off_cycle_payroll_screen.dart';
import 'screens/payroll/payroll_history_screen.dart';
import 'screens/payroll/payment_operations_screen.dart';
import 'screens/accounting/transaction_list_screen.dart';
import 'screens/report/reports_screen.dart';
import 'screens/audit/audit_logs_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/leave/leave_dashboard_screen.dart';
import 'screens/leave/apply_leave_screen.dart';
import 'screens/leave/my_leave_screen.dart';
import 'screens/leave/leave_approval_screen.dart';
import 'screens/leave/leave_balances_screen.dart';
import 'screens/leave/leave_types_screen.dart';
import 'screens/leave/leave_encashment_screen.dart';
import 'screens/leave/public_holidays_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/deductions/deduction_types_screen.dart';
import 'screens/deductions/employee_deductions_screen.dart';
import 'screens/deductions/assign_deduction_screen.dart';
import 'screens/deductions/my_deductions_screen.dart';
import 'screens/deductions/deduction_history_screen.dart';
import 'package:roipayroll/screens/expense/expense_reimbursement_screen.dart';
import 'screens/incentives/commission_bonus_screen.dart';
import 'screens/documents/document_management_screen.dart';
import 'screens/probation/probation_dashboard_screen.dart';
import 'screens/probation/probation_review_screen.dart';
import 'screens/probation/contract_create_screen.dart';
import 'screens/probation/contract_renew_screen.dart';
import 'screens/probation/employment_history_screen.dart';
import 'screens/salary_advance/salary_advance_screen.dart';
import 'screens/exit/exit_management_screen.dart';
import 'services/permission_service.dart';
import 'services/encryption_service.dart';
import 'widgets/common/permission_guarded_route.dart';
import 'core/utils/global_error_state.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try {
    await EncryptionService.initialize();
  } catch (e) {
    debugPrint('Failed to initialize encryption service: $e');
  }

  // Web defaults to in-memory cache already. Enable long-polling auto-detect
  // to reduce flaky watch-stream crashes seen as ca9/b815 on some browsers.
  try {
    FirebaseFirestore.instance.settings = kIsWeb
        ? const Settings(
            persistenceEnabled: false,
            webExperimentalForceLongPolling: true,
            webExperimentalLongPollingOptions:
                WebExperimentalLongPollingOptions(
                  timeoutDuration: Duration(seconds: 20),
                ),
          )
        : const Settings(persistenceEnabled: false);
  } catch (e) {
    // Settings already configured
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    final exception = details.exception;
    globalErrorState.report(exception, details.stack);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    globalErrorState.report(error, stack);
    return false;
  };

  // Run the app
  runApp(const ProviderScope(child: RoipayrollApp()));
}

class RoipayrollApp extends StatelessWidget {
  const RoipayrollApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // App Details
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,

      // Modern Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,

      // Initial Route (Start with Login)
      initialRoute: AppRoutes.login,

      // Routes
      routes: {
        // Auth Routes
        AppRoutes.login: (context) => const LoginScreen(),
        AppRoutes.register: (context) => const RegisterScreen(),
        AppRoutes.forgotPassword: (context) => const LoginScreen(),
        AppRoutes.changePassword: (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final isFirstLogin = args?['isFirstLogin'] == true;
          return ChangePasswordScreen(isFirstLogin: isFirstLogin);
        },

        // Main Routes
        AppRoutes.dashboard: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewDashboard,
          child: DashboardScreen(),
        ),
        AppRoutes.notifications: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewDashboard,
          child: NotificationsScreen(),
        ),

        // User Management Routes
        AppRoutes.createUser: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageUsers,
          child: CreateUserScreen(),
        ),

        // Employee Routes
        AppRoutes.addEmployee: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.createEmployee,
          child: AddEmployeeScreen(),
        ),
        AppRoutes.employeeList: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewEmployees,
          child: EmployeeListScreen(),
        ),
        AppRoutes.employeeDetails: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewEmployees,
          child: EmployeeListScreen(),
        ),
        AppRoutes.editEmployee: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.editEmployee,
          child: EmployeeListScreen(),
        ),
        AppRoutes.employeeImport: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.createEmployee,
          child: EmployeeImportScreen(),
        ),
        AppRoutes.allowanceManagement: (context) =>
            const PermissionGuardedRoute(
              requiredPermission: Permission.viewEmployees,
              child: AllowanceManagementScreen(),
            ),

        // Payroll Routes
        AppRoutes.processPayroll: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.processPayroll,
          child: ProcessPayrollScreen(),
        ),
        AppRoutes.offCyclePayroll: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.processPayroll,
          child: OffCyclePayrollScreen(),
        ),
        AppRoutes.payrollHistory: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewPayroll,
          child: PayrollHistoryScreen(),
        ),
        AppRoutes.paymentOperations: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.processPayroll,
          child: PaymentOperationsScreen(),
        ),
        AppRoutes.transactionList: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewPayroll,
          child: TransactionListScreen(),
        ),

        // Loan Routes
        AppRoutes.requestLoan: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewLoans,
          child: RequestLoanScreen(),
        ),
        AppRoutes.loansList: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewLoans,
          child: LoansListScreen(),
        ),
        AppRoutes.loanDetails: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewLoans,
          child: LoansListScreen(),
        ),

        // Attendance Routes
        AppRoutes.clockIn: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewAttendance,
          child: ClockInScreen(),
        ),
        AppRoutes.attendanceList: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewAttendance,
          child: AttendanceListScreen(),
        ),
        AppRoutes.attendanceReport: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewAttendance,
          child: AttendanceListScreen(),
        ),

        // Leave Routes
        AppRoutes.leaveDashboard: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewLeave,
          child: LeaveDashboardScreen(),
        ),
        AppRoutes.leaveApply: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewLeave,
          child: ApplyLeaveScreen(),
        ),
        AppRoutes.leaveMy: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewLeave,
          child: MyLeavesScreen(),
        ),
        AppRoutes.leaveApprovals: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.approveLeave,
          child: LeaveApprovalsScreen(),
        ),
        AppRoutes.leaveBalances: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.approveLeave,
          child: LeaveBalancesScreen(),
        ),
        AppRoutes.leaveTypes: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageLeaveTypes,
          child: LeaveTypesScreen(),
        ),
        AppRoutes.leaveEncashment: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.approveLeave,
          child: LeaveEncashmentScreen(),
        ),
        AppRoutes.publicHolidays: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageLeaveTypes,
          child: PublicHolidaysScreen(),
        ),
        AppRoutes.deductionTypes: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageDeductions,
          child: DeductionTypesScreen(),
        ),
        AppRoutes.employeeDeductions: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageDeductions,
          child: EmployeeDeductionsScreen(),
        ),
        AppRoutes.assignDeduction: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageDeductions,
          child: AssignDeductionScreen(),
        ),
        AppRoutes.myDeductions: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewDeductions,
          child: MyDeductionsScreen(),
        ),
        AppRoutes.deductionHistory: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewDeductions,
          child: DeductionHistoryScreen(),
        ),
        AppRoutes.expenseReimbursements: (context) =>
            const PermissionGuardedRoute(
              requiredPermission: Permission.viewExpenses,
              child: ExpenseReimbursementScreen(),
            ),
        AppRoutes.salaryAdvances: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewSalaryAdvance,
          child: SalaryAdvanceScreen(),
        ),
        AppRoutes.exitManagement: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewExitManagement,
          child: ExitManagementScreen(),
        ),
        AppRoutes.commissionBonus: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewIncentives,
          child: CommissionBonusScreen(),
        ),
        AppRoutes.documentManagement: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewDocuments,
          child: DocumentManagementScreen(),
        ),
        AppRoutes.probation: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewProbation,
          child: ProbationDashboardScreen(),
        ),

        AppRoutes.probationReview: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          return PermissionGuardedRoute(
            requiredPermission: Permission.manageProbation,
            child: ProbationReviewScreen(probationId: args),
          );
        },

        AppRoutes.contractCreate: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageProbation,
          child: ContractCreateScreen(),
        ),

        AppRoutes.contractRenew: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          return PermissionGuardedRoute(
            requiredPermission: Permission.manageProbation,
            child: ContractRenewScreen(contractId: args),
          );
        },

        AppRoutes.employmentHistory: (context) {
          final args = ModalRoute.of(context)?.settings.arguments as String?;
          return PermissionGuardedRoute(
            requiredPermission: Permission.viewProbation,
            child: EmploymentHistoryScreen(employeeId: args),
          );
        },

        // Reports Routes
        AppRoutes.reports: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewReports,
          child: ReportsScreen(),
        ),
        AppRoutes.auditLogs: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewAuditLogs,
          child: AuditLogsScreen(),
        ),

        // Compliance Routes
        AppRoutes.compliance: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewCompliance,
          child: ComplianceScreen(),
        ),

        // Settings Routes
        AppRoutes.settings: (context) => const SettingsScreen(),
        AppRoutes.usersList: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageUsers,
          child: SettingsScreen(),
        ),
        AppRoutes.profile: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewDashboard,
          child: SettingsScreen(),
        ),
        AppRoutes.editProfile: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.viewDashboard,
          child: SettingsScreen(),
        ),
        AppRoutes.companySettings: (context) => const PermissionGuardedRoute(
          requiredPermission: Permission.manageSettings,
          child: SettingsScreen(),
        ),
      },

      // Handle unknown routes
      onUnknownRoute: (settings) {
        debugPrint('Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Unknown Route')),
            body: Center(
              child: Text(
                'No route defined for: ${settings.name}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
