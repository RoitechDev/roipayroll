import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/models/contract_record_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/contract_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/user_service.dart';

class ContractCreateScreen extends StatefulWidget {
  const ContractCreateScreen({super.key});

  @override
  State<ContractCreateScreen> createState() => _ContractCreateScreenState();
}

class _ContractCreateScreenState extends State<ContractCreateScreen> {
  final _contractService = ContractService();
  final _employeeService = EmployeeService();
  final _userService = UserService();
  final _formKey = GlobalKey<FormState>();
  final _salaryController = TextEditingController();

  List<Employee> _employees = [];
  Employee? _selectedEmployee;
  ContractType _contractType = ContractType.fixedTerm;
  PaymentFrequency _paymentFrequency = PaymentFrequency.monthly;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _includesPension = false;
  bool _includesHealth = false;
  bool _includesLeave = false;
  bool _includesBonus = false;
  bool _isRenewable = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);

    try {
      final employees = await _employeeService.getAllEmployees();
      setState(() {
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createContract() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null || _startDate == null) {
      NotificationHelper.showError(context, 'Please fill all required fields');
      return;
    }

    if (_contractType != ContractType.permanent && _endDate == null) {
      NotificationHelper.showError(
        context,
        'End date required for non-permanent contracts',
      );
      return;
    }

    NotificationHelper.showLoading(context, message: 'Creating contract...');

    try {
      final user = await _userService.getCurrentUserProfile();
      final salary = double.parse(_salaryController.text);

      await _contractService.createContract(
        employeeId: _selectedEmployee!.id,
        employeeName: _selectedEmployee!.fullName,
        contractType: _contractType,
        startDate: _startDate!,
        endDate: _endDate,
        contractSalary: salary,
        createdBy: user!.name,
        paymentFrequency: _paymentFrequency,
        includesPension: _includesPension,
        includesHealthInsurance: _includesHealth,
        includesLeave: _includesLeave,
        includesBonus: _includesBonus,
        isRenewable: _isRenewable,
      );

      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showSuccess(
          context,
          'Contract created successfully',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Contract')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildEmployeeSelector(),
                  const SizedBox(height: 16),
                  _buildContractTypeDropdown(),
                  const SizedBox(height: 16),
                  _buildDatePickers(),
                  const SizedBox(height: 16),
                  _buildFinancialFields(),
                  const SizedBox(height: 16),
                  _buildBenefitsSection(),
                  const SizedBox(height: 24),
                  _buildDocumentModuleCard(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildEmployeeSelector() {
    return DropdownButtonFormField<Employee>(
      initialValue: _selectedEmployee,
      decoration: const InputDecoration(
        labelText: 'Employee',
        border: OutlineInputBorder(),
      ),
      items: _employees.map((employee) {
        return DropdownMenuItem(
          value: employee,
          child: Text(employee.fullName),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedEmployee = value),
      validator: (value) => value == null ? 'Please select employee' : null,
    );
  }

  Widget _buildContractTypeDropdown() {
    return DropdownButtonFormField<ContractType>(
      initialValue: _contractType,
      decoration: const InputDecoration(
        labelText: 'Contract Type',
        border: OutlineInputBorder(),
      ),
      items: ContractType.values.map((type) {
        return DropdownMenuItem(
          value: type,
          child: Text(_formatContractType(type)),
        );
      }).toList(),
      onChanged: (value) => setState(() => _contractType = value!),
    );
  }

  Widget _buildDatePickers() {
    return Column(
      children: [
        InkWell(
          onTap: () => _selectDate(true),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Start Date',
              border: OutlineInputBorder(),
            ),
            child: Text(
              _startDate != null ? _formatDate(_startDate!) : 'Select date',
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_contractType != ContractType.permanent)
          InkWell(
            onTap: () => _selectDate(false),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'End Date',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _endDate != null ? _formatDate(_endDate!) : 'Select date',
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFinancialFields() {
    return Column(
      children: [
        TextFormField(
          controller: _salaryController,
          decoration: const InputDecoration(
            labelText: 'Contract Salary (₦)',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value?.isEmpty ?? true) return 'Required';
            if (double.tryParse(value!) == null) return 'Invalid amount';
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<PaymentFrequency>(
          initialValue: _paymentFrequency,
          decoration: const InputDecoration(
            labelText: 'Payment Frequency',
            border: OutlineInputBorder(),
          ),
          items: PaymentFrequency.values.map((freq) {
            return DropdownMenuItem(
              value: freq,
              child: Text(_formatFrequency(freq)),
            );
          }).toList(),
          onChanged: (value) => setState(() => _paymentFrequency = value!),
        ),
      ],
    );
  }

  Widget _buildBenefitsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Benefits Included',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SwitchListTile(
              title: const Text('Pension'),
              value: _includesPension,
              onChanged: (value) => setState(() => _includesPension = value),
            ),
            SwitchListTile(
              title: const Text('Health Insurance'),
              value: _includesHealth,
              onChanged: (value) => setState(() => _includesHealth = value),
            ),
            SwitchListTile(
              title: const Text('Leave'),
              value: _includesLeave,
              onChanged: (value) => setState(() => _includesLeave = value),
            ),
            SwitchListTile(
              title: const Text('Bonus'),
              value: _includesBonus,
              onChanged: (value) => setState(() => _includesBonus = value),
            ),
            SwitchListTile(
              title: const Text('Renewable'),
              value: _isRenewable,
              onChanged: (value) => setState(() => _isRenewable = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentModuleCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contract Documents',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload or manage contract files in the Document module.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openDocumentModule,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open Document Module'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _createContract,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        child: const Text(
          'Create Contract',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _openDocumentModule() {
    Navigator.pushNamed(context, AppRoutes.documentManagement);
  }

  Future<void> _selectDate(bool isStartDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null) {
      setState(() {
        if (isStartDate) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatContractType(ContractType type) {
    switch (type) {
      case ContractType.fixedTerm:
        return 'Fixed-Term';
      case ContractType.partTime:
        return 'Part-Time';
      default:
        return type.name[0].toUpperCase() + type.name.substring(1);
    }
  }

  String _formatFrequency(PaymentFrequency freq) {
    switch (freq) {
      case PaymentFrequency.biWeekly:
        return 'Bi-Weekly';
      case PaymentFrequency.perProject:
        return 'Per Project';
      default:
        return freq.name[0].toUpperCase() + freq.name.substring(1);
    }
  }
}
