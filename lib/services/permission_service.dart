import 'package:roipayroll/models/user_model.dart';

enum Permission {
  // Dashboard
  viewDashboard,

  // Employees
  viewEmployees,
  createEmployee,
  editEmployee,
  deleteEmployee,

  // Payroll
  viewPayroll,
  processPayroll,
  deletePayroll,
  approvePayroll,

  // Attendance
  viewAttendance,
  manageAttendance,

  // Leave
  viewLeave,
  approveLeave,
  manageLeaveTypes,

  // Loans
  viewLoans,
  approveLoan,

  // Salary Advance
  viewSalaryAdvance,
  approveSalaryAdvance,

  // Deductions
  viewDeductions,
  manageDeductions,

  // Allowances
  viewAllowances,
  manageAllowances,

  // Incentives
  viewIncentives,
  manageIncentives,

  // Expenses
  viewExpenses,
  approveExpenses,

  // Documents
  viewDocuments,
  uploadDocuments,
  manageDocuments,

  // Probation & Contract
  viewProbation,
  manageProbation,
  approveContract,

  // Exit Management
  viewExitManagement,
  approveExitManagement,

  // Compliance
  viewCompliance,
  manageCompliance,

  // Reports & Audit
  manageUsers,
  viewReports,
  viewAuditLogs,

  // Users & System
  viewSettings,
  manageSettings,
  manageModules,
}

class PermissionDeniedException implements Exception {
  final String message;
  PermissionDeniedException(this.message);

  @override
  String toString() => message;
}

class PermissionService {
  static const Map<UserRole, List<Permission>> rolePermissions = {
    UserRole.admin: Permission.values,
    UserRole.hr: [
      Permission.viewDashboard,

      // Employees
      Permission.viewEmployees,
      Permission.createEmployee,
      Permission.editEmployee,

      // Payroll
      Permission.viewPayroll,

      // Attendance
      Permission.viewAttendance,
      Permission.manageAttendance,

      // Leave
      Permission.viewLeave,
      Permission.approveLeave,
      Permission.manageLeaveTypes,

      // Loans
      Permission.viewLoans,

      // Salary Advance
      Permission.viewSalaryAdvance,
      Permission.approveSalaryAdvance,

      // Deductions & Allowances (view only)
      Permission.viewDeductions,
      Permission.viewAllowances,

      // Incentives (view only)
      Permission.viewIncentives,

      // Expenses (view only)
      Permission.viewExpenses,

      // Documents
      Permission.viewDocuments,
      Permission.uploadDocuments,

      // Probation & Contract
      Permission.viewProbation,
      Permission.manageProbation,
      Permission.approveContract,

      // Exit Management
      Permission.viewExitManagement,
      Permission.approveExitManagement,

      // Compliance
      Permission.viewCompliance,

      // Reports & Audit
      Permission.viewReports,
      Permission.viewAuditLogs,

      // Settings (view only)
      Permission.viewSettings,
    ],
    UserRole.accountant: [
      Permission.viewDashboard,

      // Employees (view only)
      Permission.viewEmployees,

      // Payroll
      Permission.viewPayroll,
      Permission.processPayroll,
      Permission.approvePayroll,

      // Attendance (view only)
      Permission.viewAttendance,

      // Leave (view only)
      Permission.viewLeave,

      // Loans
      Permission.viewLoans,
      Permission.approveLoan,

      // Salary Advance
      Permission.viewSalaryAdvance,
      Permission.approveSalaryAdvance,

      // Deductions & Allowances (full control)
      Permission.viewDeductions,
      Permission.manageDeductions,
      Permission.viewAllowances,
      Permission.manageAllowances,

      // Incentives (full control)
      Permission.viewIncentives,
      Permission.manageIncentives,

      // Expenses
      Permission.viewExpenses,
      Permission.approveExpenses,

      // Documents (view only)
      Permission.viewDocuments,

      // Probation
      Permission.viewProbation,

      // Exit Management
      Permission.viewExitManagement,
      // Accountants can view exit data but not approve exits.

      // Compliance (full access)
      Permission.viewCompliance,
      Permission.manageCompliance,

      // Reports & Audit
      Permission.viewReports,
      Permission.viewAuditLogs,

      // Settings (view only)
      Permission.viewSettings,
    ],
    UserRole.employee: [
      Permission.viewDashboard,

      // Attendance (own only)
      Permission.viewAttendance,

      // Leave (own only)
      Permission.viewLeave,

      // Loans (own only)
      Permission.viewLoans,

      // Salary Advance (own only)
      Permission.viewSalaryAdvance,

      // Deductions (own only)
      Permission.viewDeductions,

      // Expenses (own only)
      Permission.viewExpenses,

      // Documents (own only)
      Permission.viewDocuments,

      // Exit Management
      Permission.viewExitManagement,

      // Settings (profile only)
      Permission.viewSettings,
    ],
  };

  static bool hasPermission(AppUser user, Permission permission) {
    return hasRolePermission(user.role, permission);
  }

  static bool hasRolePermission(UserRole role, Permission permission) {
    final permissions = rolePermissions[role] ?? const <Permission>[];
    return permissions.contains(permission);
  }

  static void requirePermission(AppUser user, Permission permission) {
    if (!hasPermission(user, permission)) {
      throw PermissionDeniedException(
        'User ${user.name} (${user.role.name}) does not have permission: ${permission.name}',
      );
    }
  }
}
