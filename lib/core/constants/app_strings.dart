/// All text strings used throughout the app
/// Makes it easy to change text or add translations later
class AppStrings {
  // App Name
  static const String appName = 'Roipayroll';
  static const String appTagline = 'Simplifying Payroll Management';
  
  // Authentication
  static const String login = 'Login';
  static const String register = 'Register';
  static const String logout = 'Logout';
  static const String email = 'Email Address';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String forgotPassword = 'Forgot Password?';
  static const String dontHaveAccount = "Don't have an account?";
  static const String alreadyHaveAccount = 'Already have an account?';
  static const String signUp = 'Sign Up';
  static const String signIn = 'Sign In';
  static const String welcomeBack = 'Welcome Back!';
  static const String createAccount = 'Create Account';
  static const String fullName = 'Full Name';
  static const String rememberMe = 'Remember Me';
  
  // Dashboard
  static const String dashboard = 'Dashboard';
  static const String overview = 'Overview';
  static const String totalEmployees = 'Total Employees';
  static const String monthlyPayroll = 'Monthly Payroll';
  static const String pendingPayments = 'Pending Payments';
  static const String recentActivities = 'Recent Activities';
  static const String quickActions = 'Quick Actions';
  
  // Employee Management
  static const String employees = 'Employees';
  static const String addEmployee = 'Add Employee';
  static const String editEmployee = 'Edit Employee';
  static const String deleteEmployee = 'Delete Employee';
  static const String employeeDetails = 'Employee Details';
  static const String firstName = 'First Name';
  static const String lastName = 'Last Name';
  static const String phoneNumber = 'Phone Number';
  static const String department = 'Department';
  static const String position = 'Position';
  static const String hireDate = 'Hire Date';
  static const String employeeId = 'Employee ID';
  static const String status = 'Status';
  static const String active = 'Active';
  static const String inactive = 'Inactive';
  static const String searchEmployee = 'Search employees...';
  static const String noEmployeesFound = 'No employees found';
  static const String employeeAdded = 'Employee added successfully';
  static const String employeeUpdated = 'Employee updated successfully';
  static const String employeeDeleted = 'Employee deleted successfully';
  
  // Payroll
  static const String payroll = 'Payroll';
  static const String processPayroll = 'Process Payroll';
  static const String payrollHistory = 'Payroll History';
  static const String basicSalary = 'Basic Salary';
  static const String grossSalary = 'Gross Salary';
  static const String netSalary = 'Net Salary';
  static const String allowances = 'Allowances';
  static const String deductions = 'Deductions';
  static const String tax = 'Tax';
  static const String pension = 'Pension';
  static const String payslip = 'Payslip';
  static const String viewPayslip = 'View Payslip';
  static const String downloadPayslip = 'Download Payslip';
  static const String payrollMonth = 'Payroll Month';
  static const String payrollYear = 'Payroll Year';
  static const String calculatePayroll = 'Calculate Payroll';
  static const String approvePayroll = 'Approve Payroll';
  static const String payrollProcessed = 'Payroll processed successfully';
  
  // Salary Components
  static const String salary = 'Salary';
  static const String housingAllowance = 'Housing Allowance';
  static const String transportAllowance = 'Transport Allowance';
  static const String medicalAllowance = 'Medical Allowance';
  static const String bonus = 'Bonus';
  static const String overtime = 'Overtime';
  static const String commission = 'Commission';
  static const String incomeTax = 'Income Tax (PAYE)';
  static const String pensionContribution = 'Pension Contribution';
  static const String nhf = 'National Housing Fund (NHF)';
  static const String nsitf = 'NSITF Contribution';
  static const String itf = 'ITF Contribution';
  static const String loan = 'Loan Deduction';
  
  // Reports
  static const String reports = 'Reports';
  static const String generateReport = 'Generate Report';
  static const String payrollReport = 'Payroll Report';
  static const String employeeReport = 'Employee Report';
  static const String taxReport = 'Tax Report';
  static const String exportToPdf = 'Export to PDF';
  static const String exportToExcel = 'Export to Excel';
  
  // Settings & Profile
  static const String settings = 'Settings';
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String changePassword = 'Change Password';
  static const String notifications = 'Notifications';
  static const String companySettings = 'Company Settings';
  static const String companyName = 'Company Name';
  static const String companyAddress = 'Company Address';
  static const String companyEmail = 'Company Email';
  static const String companyPhone = 'Company Phone';
  
  // Actions
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String view = 'View';
  static const String add = 'Add';
  static const String update = 'Update';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String sort = 'Sort';
  static const String refresh = 'Refresh';
  static const String submit = 'Submit';
  static const String close = 'Close';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String ok = 'OK';
  static const String confirm = 'Confirm';
  
  // Messages
  static const String loading = 'Loading...';
  static const String pleaseWait = 'Please wait...';
  static const String success = 'Success!';
  static const String error = 'Error!';
  static const String warning = 'Warning!';
  static const String info = 'Info';
  static const String noDataAvailable = 'No data available';
  static const String somethingWentWrong = 'Something went wrong. Please try again.';
  static const String checkInternetConnection = 'Please check your internet connection';
  static const String sessionExpired = 'Session expired. Please login again.';
  
  // Validation Messages
  static const String fieldRequired = 'This field is required';
  static const String invalidEmail = 'Please enter a valid email address';
  static const String invalidPhone = 'Please enter a valid phone number';
  static const String passwordTooShort = 'Password must be at least 6 characters';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String invalidAmount = 'Please enter a valid amount';
  static const String invalidDate = 'Please select a valid date';
  
  // Confirmation Messages
  static const String deleteConfirmation = 'Are you sure you want to delete this?';
  static const String logoutConfirmation = 'Are you sure you want to logout?';
  static const String unsavedChanges = 'You have unsaved changes. Do you want to discard them?';
  
  // Time & Date
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String thisMonth = 'This Month';
  static const String lastMonth = 'Last Month';
  static const String thisYear = 'This Year';
  static const String selectDate = 'Select Date';
  static const String selectMonth = 'Select Month';
  
  // Currency
  static const String naira = '₦';
  static const String currency = 'NGN';
  
  // Departments (Common Nigerian company departments)
  static const List<String> departments = [
    'Administration',
    'Accounts/Finance',
    'Human Resources',
    'Sales & Marketing',
    'Operations',
    'IT/Technology',
    'Customer Service',
    'Legal',
    'Security',
    'Procurement',
  ];
  
  // User Roles
  static const String admin = 'Admin';
  static const String manager = 'Manager';
  static const String employee = 'Employee';
  static const String hr = 'HR Personnel';
  static const String accountant = 'Accountant';
  
  // Empty States
  static const String noEmployees = 'No employees yet. Add your first employee to get started!';
  static const String noPayrolls = 'No payroll records found.';
  static const String noReports = 'No reports available.';
  
  // Help Text
  static const String emailHelp = 'Enter your company email address';
  static const String passwordHelp = 'Must be at least 6 characters';
  static const String salaryHelp = 'Enter basic monthly salary in Naira';
  static const String taxHelp = 'PAYE tax will be calculated automatically';
}
