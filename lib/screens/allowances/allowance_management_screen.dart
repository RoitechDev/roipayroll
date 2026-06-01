import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/allowance_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/allowances_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:uuid/uuid.dart';

class AllowanceManagementScreen extends StatefulWidget {
  const AllowanceManagementScreen({super.key});

  @override
  State<AllowanceManagementScreen> createState() =>
      _AllowanceManagementScreenState();
}

class _AllowanceManagementScreenState extends State<AllowanceManagementScreen>
    with SingleTickerProviderStateMixin {
  final _allowancesService = AllowancesService();
  final _employeeService = EmployeeService();
  final _typeFormKey = GlobalKey<FormState>();
  final _assignmentFormKey = GlobalKey<FormState>();

  late final TabController _tabController;
  bool _isLoading = true;

  List<AllowanceDefinition> _allowanceTypes = [];
  List<Employee> _employees = [];
  List<EmployeeAllowanceAssignment> _assignments = [];

  final _typeNameController = TextEditingController();
  final _typeAmountController = TextEditingController();
  AllowanceValueType _typeValue = AllowanceValueType.fixed;
  AllowanceFrequency _typeFrequency = AllowanceFrequency.recurring;
  AllowancePercentageBase _typeBase = AllowancePercentageBase.basicSalary;
  bool _typeTaxable = true;

  Employee? _selectedEmployee;
  AllowanceDefinition? _selectedAllowanceType;
  DateTime? _assignmentStart;
  DateTime? _assignmentEnd;
  bool _assignmentActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _typeNameController.dispose();
    _typeAmountController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _allowancesService.ensureDefaultAllowanceTypes();
      final types = await _allowancesService.getAllowanceTypes(
        activeOnly: false,
      );
      final employees = await _employeeService.getAllEmployees();
      await _allowancesService.ensureDefaultAssignmentsForEmployees(
        employees.map((employee) => employee.id).toList(),
      );
      setState(() {
        _allowanceTypes = types;
        _employees = employees;
        _selectedEmployee ??= employees.isNotEmpty ? employees.first : null;
      });
      await _loadAssignments();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAssignments() async {
    if (_selectedEmployee == null) {
      setState(() => _assignments = []);
      return;
    }
    final assignments = await _allowancesService
        .getEmployeeAllowanceAssignments(_selectedEmployee!.id);
    if (mounted) {
      setState(() => _assignments = assignments);
    }
  }

  Future<void> _createAllowanceType() async {
    if (!_typeFormKey.currentState!.validate()) return;

    final amount = double.tryParse(
      _typeAmountController.text.replaceAll(',', ''),
    );
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount.');
      return;
    }

    final definition = AllowanceDefinition(
      id: const Uuid().v4(),
      name: _typeNameController.text.trim(),
      valueType: _typeValue,
      amount: amount,
      taxable: _typeTaxable,
      frequency: _typeFrequency,
      percentageBase: _typeBase,
      isActive: true,
    );

    await _allowancesService.saveAllowanceType(definition);
    _typeNameController.clear();
    _typeAmountController.clear();
    if (mounted) {
      setState(() {
        _allowanceTypes = [..._allowanceTypes, definition];
      });
    }
    _showMessage('Allowance type created.');
  }

  Future<void> _toggleTypeActive(AllowanceDefinition type, bool value) async {
    final updated = AllowanceDefinition(
      id: type.id,
      name: type.name,
      valueType: type.valueType,
      amount: type.amount,
      taxable: type.taxable,
      frequency: type.frequency,
      percentageBase: type.percentageBase,
      isActive: value,
      createdAt: type.createdAt,
      updatedAt: DateTime.now(),
    );
    await _allowancesService.saveAllowanceType(updated);
    if (!mounted) return;
    setState(() {
      _allowanceTypes = _allowanceTypes
          .map((t) => t.id == type.id ? updated : t)
          .toList();
    });
  }

  Future<void> _assignAllowance() async {
    if (!_assignmentFormKey.currentState!.validate()) return;
    if (_selectedEmployee == null || _selectedAllowanceType == null) {
      _showMessage('Select employee and allowance type.');
      return;
    }

    await _allowancesService.assignAllowanceToEmployee(
      employeeId: _selectedEmployee!.id,
      allowanceId: _selectedAllowanceType!.id,
      startDate: _assignmentStart,
      endDate: _assignmentEnd,
      isActive: _assignmentActive,
    );

    await _loadAssignments();
    _showMessage('Allowance assigned.');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: PreferredSize(
        preferredSize: const Size.fromHeight(
          kToolbarHeight + kTextTabBarHeight,
        ),
        child: AppBar(
          title: const Text('Allowance Management'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Allowance Types'),
              Tab(text: 'Assignments'),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildAllowanceTypesTab(), _buildAssignmentsTab()],
            ),
    );
  }

  Widget _buildAllowanceTypesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAllowanceTypeForm(),
        const SizedBox(height: 24),
        const Text(
          'Existing Allowance Types',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_allowanceTypes.isEmpty)
          const Text('No allowance types created yet.')
        else
          ..._allowanceTypes.map(_buildAllowanceTypeCard),
      ],
    );
  }

  Widget _buildAllowanceTypeForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _typeFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Allowance Type',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _typeNameController,
                decoration: const InputDecoration(
                  labelText: 'Allowance Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AllowanceValueType>(
                initialValue: _typeValue,
                decoration: const InputDecoration(
                  labelText: 'Value Type',
                  border: OutlineInputBorder(),
                ),
                items: AllowanceValueType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _typeValue = value ?? _typeValue),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _typeAmountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              if (_typeValue == AllowanceValueType.percentage)
                DropdownButtonFormField<AllowancePercentageBase>(
                  initialValue: _typeBase,
                  decoration: const InputDecoration(
                    labelText: 'Percentage Base',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: AllowancePercentageBase.basicSalary,
                      child: Text('BASIC SALARY'),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _typeBase =
                        value ?? AllowancePercentageBase.basicSalary,
                  ),
                ),
              if (_typeValue == AllowanceValueType.percentage)
                const SizedBox(height: 12),
              DropdownButtonFormField<AllowanceFrequency>(
                initialValue: _typeFrequency,
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  border: OutlineInputBorder(),
                ),
                items: AllowanceFrequency.values
                    .map(
                      (freq) => DropdownMenuItem(
                        value: freq,
                        child: Text(freq.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _typeFrequency = value ?? _typeFrequency),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Taxable'),
                value: _typeTaxable,
                onChanged: (value) => setState(() => _typeTaxable = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _createAllowanceType,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Create Type'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllowanceTypeCard(AllowanceDefinition type) {
    final subtitle = type.valueType == AllowanceValueType.percentage
        ? '${type.amount.toStringAsFixed(2)}% (${type.percentageBase.name})'
        : type.amount.toStringAsFixed(2);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(type.name),
        subtitle: Text(
          '${type.frequency.name.toUpperCase()} | ${type.taxable ? 'TAXABLE' : 'NON-TAXABLE'} | $subtitle',
        ),
        onTap: () => _editAllowanceType(type),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit),
              onPressed: () => _editAllowanceType(type),
            ),
            Switch(
              value: type.isActive,
              onChanged: (value) => _toggleTypeActive(type, value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editAllowanceType(AllowanceDefinition type) async {
    final amountController = TextEditingController(
      text: type.amount.toStringAsFixed(2),
    );
    var valueType = type.valueType;
    var frequency = type.frequency;
    var taxable = type.taxable;
    var base = type.percentageBase;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: Text('Edit ${type.name}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<AllowanceValueType>(
                      initialValue: valueType,
                      decoration: const InputDecoration(
                        labelText: 'Value Type',
                        border: OutlineInputBorder(),
                      ),
                      items: AllowanceValueType.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => valueType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    if (valueType == AllowanceValueType.percentage)
                      DropdownButtonFormField<AllowancePercentageBase>(
                        initialValue: base,
                        decoration: const InputDecoration(
                          labelText: 'Percentage Base',
                          border: OutlineInputBorder(),
                        ),
                        items: AllowancePercentageBase.values
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.name.toUpperCase()),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setLocalState(() => base = value);
                        },
                      ),
                    if (valueType == AllowanceValueType.percentage)
                      const SizedBox(height: 12),
                    DropdownButtonFormField<AllowanceFrequency>(
                      initialValue: frequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                        border: OutlineInputBorder(),
                      ),
                      items: AllowanceFrequency.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value.name.toUpperCase()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setLocalState(() => frequency = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Taxable'),
                      value: taxable,
                      onChanged: (value) =>
                          setLocalState(() => taxable = value),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;
    final amount = double.tryParse(amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showMessage('Enter a valid amount.');
      return;
    }

    final updated = AllowanceDefinition(
      id: type.id,
      name: type.name,
      valueType: valueType,
      amount: amount,
      taxable: taxable,
      frequency: frequency,
      percentageBase: base,
      isActive: type.isActive,
      createdAt: type.createdAt,
      updatedAt: DateTime.now(),
    );

    await _allowancesService.saveAllowanceType(updated);
    if (!mounted) return;
    setState(() {
      _allowanceTypes = _allowanceTypes
          .map((t) => t.id == updated.id ? updated : t)
          .toList();
    });
    _showMessage('Allowance type updated.');
  }

  Widget _buildAssignmentsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAssignmentForm(),
        const SizedBox(height: 24),
        const Text(
          'Assigned Allowances',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_assignments.isEmpty)
          const Text('No assignments for this employee.')
        else
          ..._assignments.map(_buildAssignmentCard),
      ],
    );
  }

  Widget _buildAssignmentForm() {
    final selectedEmployeeValue = _findSelectedEmployee();
    final selectedAllowanceValue = _findSelectedAllowanceType();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _assignmentFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Allowance',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Employee>(
                initialValue: selectedEmployeeValue,
                decoration: const InputDecoration(
                  labelText: 'Employee',
                  border: OutlineInputBorder(),
                ),
                items: _employees
                    .map(
                      (employee) => DropdownMenuItem(
                        value: employee,
                        child: Text(employee.fullName),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  setState(() => _selectedEmployee = value);
                  await _loadAssignments();
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AllowanceDefinition>(
                initialValue: selectedAllowanceValue,
                decoration: const InputDecoration(
                  labelText: 'Allowance Type',
                  border: OutlineInputBorder(),
                ),
                items: _allowanceTypes
                    .where((type) => type.isActive)
                    .map(
                      (type) =>
                          DropdownMenuItem(value: type, child: Text(type.name)),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedAllowanceType = value),
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      label: 'Start Date',
                      value: _assignmentStart,
                      onPick: () => _pickDate((date) {
                        setState(() => _assignmentStart = date);
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _dateField(
                      label: 'End Date',
                      value: _assignmentEnd,
                      onPick: () => _pickDate((date) {
                        setState(() => _assignmentEnd = date);
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                value: _assignmentActive,
                onChanged: (value) => setState(() => _assignmentActive = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _assignAllowance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Assign Allowance'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Employee? _findSelectedEmployee() {
    for (final employee in _employees) {
      if (employee.id == _selectedEmployee?.id) {
        return employee;
      }
    }
    return null;
  }

  AllowanceDefinition? _findSelectedAllowanceType() {
    for (final type in _allowanceTypes) {
      if (type.id == _selectedAllowanceType?.id && type.isActive) {
        return type;
      }
    }
    return null;
  }

  Widget _buildAssignmentCard(EmployeeAllowanceAssignment assignment) {
    final type = _allowanceTypes.firstWhere(
      (t) => t.id == assignment.allowanceId,
      orElse: () => AllowanceDefinition(
        id: assignment.allowanceId,
        name: 'Unknown Allowance',
        valueType: AllowanceValueType.fixed,
        amount: 0,
        taxable: true,
        frequency: AllowanceFrequency.recurring,
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(type.name),
        subtitle: Text(
          '${type.frequency.name.toUpperCase()} | ${assignment.isActive ? 'ACTIVE' : 'INACTIVE'}'
          '${assignment.startDate != null ? ' | Start: ${_formatDate(assignment.startDate!)}' : ''}'
          '${assignment.endDate != null ? ' | End: ${_formatDate(assignment.endDate!)}' : ''}',
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onPick,
  }) {
    return InkWell(
      onTap: onPick,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value == null ? 'Select date' : _formatDate(value)),
      ),
    );
  }

  Future<void> _pickDate(ValueChanged<DateTime> onPicked) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) onPicked(date);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
}
