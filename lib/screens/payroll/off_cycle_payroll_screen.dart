import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/payroll_provider.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/payroll_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';

class OffCyclePayrollScreen extends ConsumerStatefulWidget {
  const OffCyclePayrollScreen({super.key});

  @override
  ConsumerState<OffCyclePayrollScreen> createState() =>
      _OffCyclePayrollScreenState();
}

class _OffCyclePayrollScreenState
    extends ConsumerState<OffCyclePayrollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _employeeService = EmployeeService();
  final _payrollService = PayrollService();

  bool _isLoadingEmployees = true;
  bool _isProcessing = false;
  List<Employee> _employees = const [];
  String? _selectedEmployeeId;
  PayrollType _selectedType = PayrollType.adhoc;
  DateTime _paymentDate = DateTime.now();
  Payroll? _lastProcessedPayroll;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoadingEmployees = true);
    try {
      final employees = await _employeeService.getAllEmployees();
      final active =
          employees.where((employee) => employee.status == 'active').toList()
            ..sort(
              (a, b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );
      if (!mounted) return;
      setState(() {
        _employees = active;
        if (active.isNotEmpty) {
          _selectedEmployeeId = active.first.id;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load employees: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoadingEmployees = false);
      }
    }
  }

  Future<void> _processOffCyclePayroll() async {
    if (_formKey.currentState?.validate() != true) return;
    final employeeId = _selectedEmployeeId;
    if (employeeId == null || employeeId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an employee.')));
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid payroll amount.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final payroll = await _payrollService.processOffCyclePayroll(
        employeeId: employeeId,
        type: _selectedType,
        amount: amount,
        reason: _reasonController.text.trim(),
        paymentDate: _paymentDate,
      );
      if (!mounted) return;
      setState(() => _lastProcessedPayroll = payroll);
      _refreshPayrollHistory(payroll);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Off-cycle payroll created.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Processing failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _refreshPayrollHistory(Payroll payroll) {
    final period = PayrollPeriod(
      month: payroll.month,
      year: payroll.year,
    );
    ref.invalidate(payrollHistoryProvider(period));
    ref.read(appManualRefreshControllerProvider).add(DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppBar(
        title: const Text('Off-Cycle Payroll'),
        actions: [
          IconButton(
            tooltip: 'Refresh Employees',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingEmployees ? null : _loadEmployees,
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildContent(pagePadding: 12),
        tablet: _buildContent(pagePadding: 16),
        desktop: _buildContent(pagePadding: 16),
      ),
    );
  }

  Widget _buildContent({required double pagePadding}) {
    return ListView(
      padding: EdgeInsets.all(pagePadding),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Create Off-Cycle Payroll',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingEmployees)
                    const LinearProgressIndicator()
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedEmployeeId,
                      decoration: const InputDecoration(
                        labelText: 'Employee',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: _employees
                          .map(
                            (employee) => DropdownMenuItem(
                              value: employee.id,
                              child: Text(employee.fullName),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedEmployeeId = value);
                      },
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Select employee'
                          : null,
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PayrollType>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Payroll Type',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PayrollType.bonus,
                        child: Text('Bonus'),
                      ),
                      DropdownMenuItem(
                        value: PayrollType.commission,
                        child: Text('Commission'),
                      ),
                      DropdownMenuItem(
                        value: PayrollType.thirteenth,
                        child: Text('13th Month'),
                      ),
                      DropdownMenuItem(
                        value: PayrollType.adhoc,
                        child: Text('Ad-hoc'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixIcon: Icon(Icons.payments_outlined),
                      hintText: 'Enter payout amount in employee currency',
                    ),
                    validator: (value) {
                      final amount = double.tryParse((value ?? '').trim());
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid amount';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reasonController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      prefixIcon: Icon(Icons.description_outlined),
                      hintText: 'Explain why this off-cycle payroll is needed',
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) {
                        return 'Reason is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Payment Date'),
                    subtitle: Text(
                      '${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_month_outlined),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _paymentDate,
                          firstDate: DateTime(DateTime.now().year - 2, 1, 1),
                          lastDate: DateTime(DateTime.now().year + 2, 12, 31),
                        );
                        if (picked != null) {
                          setState(() => _paymentDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _taxHelperText(_selectedType),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _processOffCyclePayroll,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.playlist_add_check_circle_outlined,
                            ),
                      label: Text(
                        _isProcessing
                            ? 'Processing...'
                            : 'Create Off-Cycle Payroll',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_lastProcessedPayroll != null) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Last Created Off-Cycle Entry',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _summaryRow('Employee', _lastProcessedPayroll!.employeeName),
                  _summaryRow(
                    'Type',
                    _lastProcessedPayroll!.payrollType.name.toUpperCase(),
                  ),
                  _summaryRow(
                    'Gross',
                    CurrencyFormatter.formatCurrency(
                      _lastProcessedPayroll!.grossSalary,
                      currencyCode: _lastProcessedPayroll!.currency,
                    ),
                  ),
                  _summaryRow(
                    'Deductions',
                    CurrencyFormatter.formatCurrency(
                      _lastProcessedPayroll!.totalDeductions,
                      currencyCode: _lastProcessedPayroll!.currency,
                    ),
                  ),
                  _summaryRow(
                    'Net',
                    CurrencyFormatter.formatCurrency(
                      _lastProcessedPayroll!.netSalary,
                      currencyCode: _lastProcessedPayroll!.currency,
                    ),
                  ),
                  _summaryRow(
                    'Reason',
                    _lastProcessedPayroll!.offCycleReason ?? '-',
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.payrollHistory);
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('Open Payroll History'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _taxHelperText(PayrollType type) {
    switch (type) {
      case PayrollType.bonus:
      case PayrollType.commission:
      case PayrollType.thirteenth:
        return 'Tax mode: PAYE only. Pension and NHF are excluded for this type.';
      case PayrollType.adhoc:
        return 'Tax mode: Standard statutory deductions (PAYE, pension, NHF).';
      case PayrollType.regular:
        return 'Regular monthly payroll should be processed in Process Payroll.';
    }
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

