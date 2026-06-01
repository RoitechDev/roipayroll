import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/models/contract_record_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/contract_service.dart';
import 'package:roipayroll/services/employee_service.dart';

class EmploymentHistoryScreen extends StatefulWidget {
  final String? employeeId;

  const EmploymentHistoryScreen({super.key, this.employeeId});

  @override
  State<EmploymentHistoryScreen> createState() =>
      _EmploymentHistoryScreenState();
}

class _EmploymentHistoryScreenState extends State<EmploymentHistoryScreen> {
  final _contractService = ContractService();
  final _employeeService = EmployeeService();

  List<Employee> _employees = [];
  List<ContractRecord> _history = [];
  Employee? _selectedEmployee;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);

    try {
      final employees = await _employeeService.getAllEmployees();
      setState(() {
        _employees = employees;
        if (widget.employeeId != null) {
          _selectedEmployee = employees.firstWhere(
            (e) => e.id == widget.employeeId,
            orElse: () => employees.first,
          );
          _loadHistory(_selectedEmployee!.id);
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadHistory(String employeeId) async {
    setState(() => _isLoading = true);

    try {
      final history = await _contractService.getEmploymentHistory(employeeId);
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employment History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildEmployeeSelector(),
                const SizedBox(height: 24),
                if (_selectedEmployee != null) ...[
                  _buildEmployeeInfo(),
                  const SizedBox(height: 24),
                  _buildHistoryList(),
                ],
              ],
            ),
    );
  }

  Widget _buildEmployeeSelector() {
    return DropdownButtonFormField<Employee>(
      initialValue: _selectedEmployee,
      decoration: const InputDecoration(
        labelText: 'Select Employee',
        border: OutlineInputBorder(),
      ),
      items: _employees.map((employee) {
        return DropdownMenuItem(
          value: employee,
          child: Text(employee.fullName),
        );
      }).toList(),
      onChanged: (value) {
        setState(() => _selectedEmployee = value);
        if (value != null) _loadHistory(value.id);
      },
    );
  }

  Widget _buildEmployeeInfo() {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedEmployee!.fullName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Department: ${_selectedEmployee!.department}'),
            Text('Position: ${_selectedEmployee!.position}'),
            Text('Total Contracts: ${_history.length}'),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contract History',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No contract history')),
            ),
          )
        else
          ..._history.asMap().entries.map((entry) {
            final index = entry.key;
            final contract = entry.value;
            return _buildContractCard(contract, index);
          }),
      ],
    );
  }

  Widget _buildContractCard(ContractRecord contract, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_formatContractType(contract.contractType)} #${_history.length - index}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(contract.status),
              ],
            ),
            const Divider(height: 24),
            Text(
              'Period: ${_formatDate(contract.startDate)} - ${contract.endDate != null ? _formatDate(contract.endDate!) : 'Present'}',
            ),
            Text('Salary: ₦${contract.contractSalary.toStringAsFixed(2)}'),
            Text('Payment: ${contract.paymentFrequency.name}'),
            if (contract.renewalCount != null && contract.renewalCount! > 0)
              Text('Renewed: ${contract.renewalCount} times'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ContractStatus status) {
    Color color;
    switch (status) {
      case ContractStatus.active:
        color = AppColors.success;
        break;
      case ContractStatus.expired:
        color = AppColors.error;
        break;
      case ContractStatus.renewed:
        color = AppColors.info;
        break;
      case ContractStatus.terminated:
        color = AppColors.textSecondary;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
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
}
