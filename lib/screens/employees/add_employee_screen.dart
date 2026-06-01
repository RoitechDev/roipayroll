import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_strings.dart';
import 'package:roipayroll/core/utils/validators.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/leave_balance_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:uuid/uuid.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeService = EmployeeService();
  final _leaveBalanceService = LeaveBalanceService();
  final _userService = UserService();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _positionController = TextEditingController();
  final _salaryController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();

  String _selectedDepartment = AppStrings.departments[0];
  String _selectedPayoutCurrency = 'NGN';
  EmploymentType _selectedEmploymentType = EmploymentType.permanent;
  DateTime _hireDate = DateTime.now();
  DateTime? _probationEndDate;
  DateTime? _contractEndDate;
  bool _isProbationConfirmed = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
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

  Future<void> _selectProbationEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _probationEndDate ?? _hireDate,
      firstDate: _hireDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _probationEndDate = picked);
    }
  }

  Future<void> _selectContractEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _contractEndDate ?? _hireDate,
      firstDate: _hireDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _contractEndDate = picked);
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final companyId = await _userService.getCurrentCompanyId();
      final employee = Employee(
        id: const Uuid().v4(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        department: _selectedDepartment,
        position: _positionController.text.trim(),
        basicSalary: double.parse(_salaryController.text.replaceAll(',', '')),
        payoutCurrency: _selectedPayoutCurrency,
        hireDate: _hireDate,
        employmentType: _selectedEmploymentType,
        probationEndDate: _probationEndDate,
        contractEndDate: _contractEndDate,
        isProbationConfirmed: _isProbationConfirmed,
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim().isEmpty
            ? null
            : _accountNumberController.text.trim(),
        companyId: companyId,
      );

      await _employeeService.addEmployee(employee);
      await _leaveBalanceService.initializeEmployeeBalances(
        employee.id,
        employee.fullName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee added successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppBar(title: const Text(AppStrings.addEmployee)),
      body: ResponsiveLayout(
        mobile: _buildFormContent(padding: 12),
        tablet: _buildFormContent(padding: 16),
        desktop: _buildFormContent(padding: 16),
      ),
    );
  }

  Widget _buildFormContent({required double padding}) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(padding),
        children: [
          TextFormField(
            controller: _firstNameController,
            decoration: const InputDecoration(labelText: AppStrings.firstName),
            validator: (v) =>
                Validators.validateName(v, fieldName: 'First name'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _lastNameController,
            decoration: const InputDecoration(labelText: AppStrings.lastName),
            validator: (v) =>
                Validators.validateName(v, fieldName: 'Last name'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: AppStrings.email),
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: AppStrings.phoneNumber,
            ),
            keyboardType: TextInputType.phone,
            validator: Validators.validatePhone,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedDepartment,
            decoration: const InputDecoration(labelText: AppStrings.department),
            items: AppStrings.departments.map((dept) {
              return DropdownMenuItem(value: dept, child: Text(dept));
            }).toList(),
            onChanged: (value) => setState(() => _selectedDepartment = value!),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _positionController,
            decoration: const InputDecoration(labelText: AppStrings.position),
            validator: (v) =>
                Validators.validateRequired(v, fieldName: 'Position'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<EmploymentType>(
            initialValue: _selectedEmploymentType,
            decoration: const InputDecoration(labelText: 'Employment Type'),
            items: EmploymentType.values
                .map(
                  (type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.name.toUpperCase()),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectedEmploymentType = value);
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _salaryController,
            decoration: InputDecoration(
              labelText: AppStrings.basicSalary,
              prefixText: '$_selectedPayoutCurrency ',
            ),
            keyboardType: TextInputType.number,
            validator: Validators.validateAmount,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedPayoutCurrency,
            decoration: const InputDecoration(labelText: 'Payout Currency'),
            items: const [
              DropdownMenuItem(value: 'NGN', child: Text('NGN')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'EUR', child: Text('EUR')),
              DropdownMenuItem(value: 'GBP', child: Text('GBP')),
            ],
            onChanged: (value) {
              setState(() => _selectedPayoutCurrency = value ?? 'NGN');
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text(AppStrings.hireDate),
            subtitle: Text(
              '${_hireDate.day}/${_hireDate.month}/${_hireDate.year}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _selectDate,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Probation End Date'),
            subtitle: Text(
              _probationEndDate == null
                  ? 'Not set'
                  : '${_probationEndDate!.day}/${_probationEndDate!.month}/${_probationEndDate!.year}',
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (_probationEndDate != null)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () => setState(() => _probationEndDate = null),
                    icon: const Icon(Icons.clear),
                  ),
                IconButton(
                  tooltip: 'Select Date',
                  onPressed: _selectProbationEndDate,
                  icon: const Icon(Icons.calendar_today),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Contract End Date'),
            subtitle: Text(
              _contractEndDate == null
                  ? 'Not set'
                  : '${_contractEndDate!.day}/${_contractEndDate!.month}/${_contractEndDate!.year}',
            ),
            trailing: Wrap(
              spacing: 4,
              children: [
                if (_contractEndDate != null)
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () => setState(() => _contractEndDate = null),
                    icon: const Icon(Icons.clear),
                  ),
                IconButton(
                  tooltip: 'Select Date',
                  onPressed: _selectContractEndDate,
                  icon: const Icon(Icons.calendar_today),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _isProbationConfirmed,
            onChanged: (value) {
              setState(() => _isProbationConfirmed = value);
            },
            title: const Text('Probation Confirmed'),
            subtitle: const Text(
              'Turn on when employee is confirmed after probation review.',
            ),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),
          const Text(
            'BANK DETAILS (Optional)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _bankNameController,
            decoration: const InputDecoration(labelText: 'Bank Name'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accountNumberController,
            decoration: const InputDecoration(labelText: 'Account Number'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveEmployee,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(AppStrings.save),
            ),
          ),
        ],
      ),
    );
  }
}
