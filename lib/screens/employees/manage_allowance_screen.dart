import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/allowance_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/allowances_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';

class ManageAllowancesScreen extends StatefulWidget {
  final Employee employee;
  const ManageAllowancesScreen({super.key, required this.employee});

  @override
  State<ManageAllowancesScreen> createState() => _ManageAllowancesScreenState();
}

class _ManageAllowancesScreenState extends State<ManageAllowancesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _allowancesService = AllowancesService();

  final _housingController = TextEditingController();
  final _transportController = TextEditingController();
  final _medicalController = TextEditingController();
  final _mealController = TextEditingController();

  final _loanController = TextEditingController();
  final _advanceController = TextEditingController();
  final _unionController = TextEditingController();
  final _coopController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final allowances = await _allowancesService.getAllowances(
        widget.employee.id,
      );
      final deductions = await _allowancesService.getDeductions(
        widget.employee.id,
      );

      setState(() {
        _housingController.text = allowances.housingAllowance > 0
            ? allowances.housingAllowance.toString()
            : '';
        _transportController.text = allowances.transportAllowance > 0
            ? allowances.transportAllowance.toString()
            : '';
        _medicalController.text = allowances.medicalAllowance > 0
            ? allowances.medicalAllowance.toString()
            : '';
        _mealController.text = allowances.mealAllowance > 0
            ? allowances.mealAllowance.toString()
            : '';

        _loanController.text = deductions.loanDeduction > 0
            ? deductions.loanDeduction.toString()
            : '';
        _advanceController.text = deductions.advanceDeduction > 0
            ? deductions.advanceDeduction.toString()
            : '';
        _unionController.text = deductions.unionDues > 0
            ? deductions.unionDues.toString()
            : '';
        _coopController.text = deductions.cooperativeContribution > 0
            ? deductions.cooperativeContribution.toString()
            : '';

        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final allowances = EmployeeAllowances(
        employeeId: widget.employee.id,
        housingAllowance: _parseDouble(_housingController.text),
        transportAllowance: _parseDouble(_transportController.text),
        medicalAllowance: _parseDouble(_medicalController.text),
        mealAllowance: _parseDouble(_mealController.text),
      );

      final deductions = EmployeeDeductions(
        employeeId: widget.employee.id,
        loanDeduction: _parseDouble(_loanController.text),
        advanceDeduction: _parseDouble(_advanceController.text),
        unionDues: _parseDouble(_unionController.text),
        cooperativeContribution: _parseDouble(_coopController.text),
      );

      await _allowancesService.saveAllowances(allowances);
      await _allowancesService.saveDeductions(deductions);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Saved successfully!')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _parseDouble(String value) {
    if (value.isEmpty) return 0;
    return double.tryParse(value.replaceAll(',', '')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppBar(title: const Text('Allowances & Deductions')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveLayout(
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
          Text(
            'Employee: ${widget.employee.fullName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text(
            'ALLOWANCES',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 12),
          _moneyField(_housingController, 'Housing Allowance'),
          const SizedBox(height: 12),
          _moneyField(_transportController, 'Transport Allowance'),
          const SizedBox(height: 12),
          _moneyField(_medicalController, 'Medical Allowance'),
          const SizedBox(height: 12),
          _moneyField(_mealController, 'Meal Allowance'),
          const SizedBox(height: 32),
          const Text(
            'DEDUCTIONS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 12),
          _moneyField(_loanController, 'Loan Deduction'),
          const SizedBox(height: 12),
          _moneyField(_advanceController, 'Advance Recovery'),
          const SizedBox(height: 12),
          _moneyField(_unionController, 'Union Dues'),
          const SizedBox(height: 12),
          _moneyField(_coopController, 'Cooperative Contribution'),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(onPressed: _save, child: const Text('SAVE')),
          ),
        ],
      ),
    );
  }

  Widget _moneyField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label, prefixText: 'NGN '),
      keyboardType: TextInputType.number,
    );
  }

  @override
  void dispose() {
    _housingController.dispose();
    _transportController.dispose();
    _medicalController.dispose();
    _mealController.dispose();
    _loanController.dispose();
    _advanceController.dispose();
    _unionController.dispose();
    _coopController.dispose();
    super.dispose();
  }
}
