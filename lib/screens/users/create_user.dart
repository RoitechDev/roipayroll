import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_strings.dart';
import 'package:roipayroll/core/utils/validators.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:uuid/uuid.dart';

class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});

  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  final _userService = UserService();
  final _employeeService = EmployeeService();

  // User Account Fields
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Employee Details Fields
  final _positionController = TextEditingController();
  final _salaryController = TextEditingController();

  UserRole _selectedRole = UserRole.employee;
  String _selectedDepartment = AppStrings.departments[0];
  DateTime _hireDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _hireDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _hireDate) {
      setState(() => _hireDate = picked);
    }
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    NotificationHelper.showLoading(context, message: 'Creating user...');

    try {
      // 1. Check if email already exists
      final existingEmployees = await _employeeService.getAllEmployees();
      final emailExists = existingEmployees.any(
        (e) =>
            e.email.toLowerCase() == _emailController.text.trim().toLowerCase(),
      );
      if (emailExists) {
        throw 'Email already exists in employee records';
      }

      // Get creator company before auth context switches to new user
      final creatorProfile = await _userService.getCurrentUserProfile();
      final companyId = creatorProfile?.companyId ?? 'original_company';

      // 2. Register with Firebase Auth
      final userCredential = await _authService.register(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (userCredential?.user == null) {
        throw 'Firebase Auth registration failed';
      }

      final userId = userCredential!.user!.uid;

      // 3. Generate employee ID
      final employeeId = const Uuid().v4();

      // 4. Parse name
      final nameParts = _nameController.text.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';

      // 5. Parse salary
      final salary =
          double.tryParse(_salaryController.text.replaceAll(',', '')) ?? 0.0;

      // 6. Create Employee with FULL details
      final employee = Employee(
        id: employeeId,
        userId: userId,
        hasLogin: true,
        invitationStatus: InvitationStatus.active,
        invitedAt: DateTime.now(),
        lastInviteSentAt: DateTime.now(),
        passwordChangedAt: DateTime.now(),
        lastLoginAt: DateTime.now(),
        inviteAttempts: 1,
        firstName: firstName,
        lastName: lastName,
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        department: _selectedDepartment,
        position: _positionController.text.trim(),
        basicSalary: salary,
        hireDate: _hireDate,
        status: 'active',
        companyId: companyId,
      );

      // 7. Save employee to Firestore
      await _employeeService.addEmployee(
        employee,
        companyIdOverride: companyId,
      );
      // 8. Create user profile
      await _userService.createUserProfile(
        uid: userId,
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        companyId: companyId,
        role: _selectedRole,
        employeeId: employeeId,
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );

      final email = _emailController.text.trim();

      // Send Firebase password reset email as invitation
      // (user clicks link to set their own password)
      try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      } catch (e) {
        debugPrint('Invitation email failed (non-fatal): $e');
      }

      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showSuccess(
          context,
          'User created. An invitation email has been sent to $email with instructions to set their password.',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.hideLoading(context);

        String errorMessage = e.toString();
        if (errorMessage.contains('email-already-in-use')) {
          errorMessage = 'Email already registered in Firebase Auth';
        } else if (errorMessage.contains('already exists in employee')) {
          errorMessage = 'Email already exists in employee records';
        }

        NotificationHelper.showError(context, errorMessage);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppBar(title: const Text('Users & Roles - Provisioning Studio')),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1050;
            final formContent = _buildFormContent();

            if (!isWide) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeroCard(),
                  const SizedBox(height: 16),
                  formContent,
                  const SizedBox(height: 16),
                  _buildRolePreviewPanel(),
                  const SizedBox(height: 12),
                  _buildPermissionMatrixPanel(),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                    children: [
                      _buildHeroCard(),
                      const SizedBox(height: 16),
                      formContent,
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
                    children: [
                      _buildRolePreviewPanel(),
                      const SizedBox(height: 12),
                      _buildPermissionMatrixPanel(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      children: [
        _buildSectionShell(
          title: 'Identity & Access',
          subtitle: 'Account credentials and contact details',
          icon: Icons.verified_user_outlined,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                helperText: 'First and last name',
              ),
              validator: (v) => Validators.validateName(v, fieldName: 'Name'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: Validators.validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: Validators.validatePhone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock),
                helperText: 'User will use this to login',
              ),
              obscureText: true,
              validator: Validators.validatePassword,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionShell(
          title: 'Employment Profile',
          subtitle: 'Department, role in company, and compensation',
          icon: Icons.badge_outlined,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedDepartment,
              decoration: const InputDecoration(labelText: 'Department'),
              items: AppStrings.departments.map((dept) {
                return DropdownMenuItem(value: dept, child: Text(dept));
              }).toList(),
              onChanged: (value) =>
                  setState(() => _selectedDepartment = value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _positionController,
              decoration: const InputDecoration(
                labelText: 'Position',
                prefixIcon: Icon(Icons.work),
              ),
              validator: (v) =>
                  Validators.validateRequired(v, fieldName: 'Position'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _salaryController,
              decoration: const InputDecoration(
                labelText: 'Basic Salary',
                prefixText: 'NGN ',
                prefixIcon: Icon(Icons.attach_money),
                helperText: 'Monthly basic salary',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Salary is required';
                final amount = double.tryParse(v.replaceAll(',', ''));
                if (amount == null || amount < 0) return 'Invalid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('Hire Date'),
              subtitle: Text(
                '${_hireDate.day}/${_hireDate.month}/${_hireDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionShell(
          title: 'Role Assignment',
          subtitle: 'Select system permission profile',
          icon: Icons.security_outlined,
          children: [
            _buildRoleCard(
              UserRole.admin,
              'Administrator',
              'Full system access',
              Icons.admin_panel_settings,
            ),
            _buildRoleCard(
              UserRole.hr,
              'HR Manager',
              'Manage employees and leave',
              Icons.groups_2_outlined,
            ),
            _buildRoleCard(
              UserRole.accountant,
              'Accountant',
              'Manage payroll and finance',
              Icons.account_balance_outlined,
            ),
            _buildRoleCard(
              UserRole.employee,
              'Employee',
              'Basic self-service access',
              Icons.person_outline,
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _createUser,
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('CREATE USER & EMPLOYEE'),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.info.withValues(alpha: 0.08),
          ],
        ),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.manage_accounts, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create User + Employee Record',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Provision access rights and employee profile in one workflow.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionShell({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRolePreviewPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Role Access Summary',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(_roleIcon(_selectedRole), color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  _roleTitle(_selectedRole),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._roleCapabilities(_selectedRole).map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionMatrixPanel() {
    final allPermissions = Permission.values;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.grid_view_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Permission Matrix',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Highlighted entries indicate access for selected role.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 14,
              headingRowHeight: 42,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 44,
              columns: const [
                DataColumn(label: Text('Permission')),
                DataColumn(label: Text('Access')),
              ],
              rows: allPermissions.map((permission) {
                final hasAccess = PermissionService.hasRolePermission(
                  _selectedRole,
                  permission,
                );
                return DataRow(
                  color: WidgetStateProperty.resolveWith<Color?>((states) {
                    if (hasAccess) {
                      return AppColors.success.withValues(alpha: 0.08);
                    }
                    return null;
                  }),
                  cells: [
                    DataCell(
                      Text(
                        _permissionLabel(permission),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Icon(
                            hasAccess
                                ? Icons.check_circle
                                : Icons.remove_circle,
                            size: 16,
                            color: hasAccess
                                ? AppColors.success
                                : AppColors.textTertiary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasAccess ? 'Allowed' : 'Blocked',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: hasAccess
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    UserRole role,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _selectedRole == role;

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _roleIcon(UserRole role) {
    return switch (role) {
      UserRole.admin => Icons.admin_panel_settings,
      UserRole.hr => Icons.groups_2_outlined,
      UserRole.accountant => Icons.account_balance_outlined,
      UserRole.employee => Icons.person_outline,
    };
  }

  String _roleTitle(UserRole role) {
    return switch (role) {
      UserRole.admin => 'Administrator',
      UserRole.hr => 'HR Manager',
      UserRole.accountant => 'Accountant',
      UserRole.employee => 'Employee',
    };
  }

  List<String> _roleCapabilities(UserRole role) {
    return switch (role) {
      UserRole.admin => const [
        'Manage all users, payroll, reports, and system settings',
        'Approve high-level workflows and access controls',
        'View all company modules and audit activities',
      ],
      UserRole.hr => const [
        'Manage employee records, leave, and attendance workflows',
        'Approve HR-related requests and profile updates',
        'Access staffing reports and employee lifecycle modules',
      ],
      UserRole.accountant => const [
        'Process payroll and manage financial records',
        'Handle deductions, loans, and compensation operations',
        'Generate payroll history and accounting reports',
      ],
      UserRole.employee => const [
        'Access personal profile, payslips, and leave requests',
        'Submit self-service requests (leave/attendance related)',
        'View permitted personal dashboards and updates',
      ],
    };
  }

  String _permissionLabel(Permission permission) {
    final raw = permission.name;
    final withSpaces = raw.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }
}
