import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/employee_deduction_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/deduction_type_service.dart';
import 'package:roipayroll/services/employee_deduction_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:uuid/uuid.dart';

class AssignDeductionScreen extends StatefulWidget {
  const AssignDeductionScreen({super.key});

  @override
  State<AssignDeductionScreen> createState() => _AssignDeductionScreenState();
}

class _AssignDeductionScreenState extends State<AssignDeductionScreen> {
  final _employeeService = EmployeeService();
  final _typeService = DeductionTypeService();
  final _userService = UserService();
  late final EmployeeDeductionService _deductionService;
  final _formKey = GlobalKey<FormState>();

  List<Employee> _employees = [];
  List<DeductionType> _types = [];
  Employee? _selectedEmployee;
  DeductionType? _selectedType;
  DeductionFrequency _frequency = DeductionFrequency.monthly;
  DeductionStatus _initialStatus = DeductionStatus.pending;

  bool _requiresApproval = true;
  bool _canManageDeductions = false;
  bool _canActivateDirectly = false;
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;
  String _roleLabel = 'Unknown';

  final _totalAmountCtrl = TextEditingController();
  final _perPayrollCtrl = TextEditingController();
  final _referenceCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _installmentsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _deductionService = EmployeeDeductionService(userService: _userService);
    _load();
  }

  @override
  void dispose() {
    _totalAmountCtrl.dispose();
    _perPayrollCtrl.dispose();
    _referenceCtrl.dispose();
    _descriptionCtrl.dispose();
    _notesCtrl.dispose();
    _installmentsCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final employees = await _employeeService.getAllEmployees();
      final types = await _typeService.getActiveDeductionTypes();
      final user = await _userService.getCurrentUserProfile();
      final canManage =
          user != null &&
          PermissionService.hasPermission(user, Permission.manageDeductions);

      if (!mounted) return;
      setState(() {
        _employees = employees.where((e) => e.status == 'active').toList();
        _types = types;
        _canManageDeductions = canManage;
        _canActivateDirectly = canManage;
        _requiresApproval = true;
        _initialStatus = DeductionStatus.pending;
        _roleLabel = user?.getRoleName() ?? 'Unknown';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_canManageDeductions) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEmployee == null || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an employee and deduction type.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final now = DateTime.now();
      final total = double.tryParse(_totalAmountCtrl.text.trim()) ?? 0;
      final perPayroll = double.tryParse(_perPayrollCtrl.text.trim()) ?? 0;
      final installments = int.tryParse(_installmentsCtrl.text.trim());

      final deduction = EmployeeDeduction(
        id: const Uuid().v4(),
        employeeId: _selectedEmployee!.id,
        employeeName: _selectedEmployee!.fullName,
        deductionTypeId: _selectedType!.id,
        deductionTypeName: _selectedType!.name,
        category: _selectedType!.category,
        calculationMethod: _selectedType!.calculationMethod,
        frequency: _frequency,
        status: _initialStatus,
        totalAmount: total,
        amountPerPayroll: perPayroll,
        percentageRate: _selectedType!.percentageRate ?? 0,
        totalInstallments: installments,
        startDate: now,
        nextDeductionDate: now,
        requiresApproval: _requiresApproval,
        referenceNumber: _referenceCtrl.text.trim().isEmpty
            ? null
            : _referenceCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await _deductionService.assignDeduction(deduction);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _requiresApproval
                ? 'Deduction assigned and pending approval'
                : 'Deduction assigned and activated',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to assign deduction: $e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _discardChanges() async {
    final hasInput =
        _selectedEmployee != null ||
        _selectedType != null ||
        _totalAmountCtrl.text.trim().isNotEmpty ||
        _perPayrollCtrl.text.trim().isNotEmpty ||
        _referenceCtrl.text.trim().isNotEmpty ||
        _descriptionCtrl.text.trim().isNotEmpty ||
        _notesCtrl.text.trim().isNotEmpty ||
        _installmentsCtrl.text.trim().isNotEmpty;

    if (!hasInput) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'Any unsaved deduction details entered here will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    if ((shouldClose ?? false) && mounted) {
      Navigator.pop(context);
    }
  }

  String _frequencyLabel(DeductionFrequency frequency) {
    switch (frequency) {
      case DeductionFrequency.oneTime:
        return 'One-Time';
      case DeductionFrequency.monthly:
        return 'Monthly';
      case DeductionFrequency.biweekly:
        return 'Bi-Weekly';
      case DeductionFrequency.weekly:
        return 'Weekly';
      case DeductionFrequency.custom:
        return 'Custom';
    }
  }

  String _categoryLabel(DeductionCategory category) {
    switch (category) {
      case DeductionCategory.statutory:
        return 'Statutory';
      case DeductionCategory.loan:
        return 'Loan';
      case DeductionCategory.advance:
        return 'Advance';
      case DeductionCategory.garnishment:
        return 'Garnishment';
      case DeductionCategory.insurance:
        return 'Insurance';
      case DeductionCategory.union:
        return 'Union';
      case DeductionCategory.other:
        return 'Other';
    }
  }

  InputDecoration _inputDecoration(String hintText) {
    return InputDecoration(
      hintText: hintText,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primaryDark),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Assign Deduction',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? _buildErrorState()
          : !_canManageDeductions
          ? _buildRestrictedState()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildFormCard(),
                  const SizedBox(height: 18),
                  _buildStatusCards(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 56,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load assignment data',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestrictedState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.error,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only authorized deduction managers can assign new deductions. Current role: $_roleLabel.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'FINANCIAL OPERATION',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: AppColors.infoDark,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Deduction Protocol',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _canActivateDirectly
              ? 'Configure new withholding parameters for an employee profile. Entries can be submitted for approval or activated immediately.'
              : 'Configure new withholding parameters for an employee profile. All entries are logged for audit compliance.',
          style: const TextStyle(
            fontSize: 16,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.infoDark,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'END-TO-END ENCRYPTED FINANCIAL DATA ENTRY',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildEmployeeField()),
                    const SizedBox(width: 20),
                    Expanded(child: _buildTypeField()),
                  ],
                );
              }

              return Column(
                children: [
                  _buildEmployeeField(),
                  const SizedBox(height: 16),
                  _buildTypeField(),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildAmountPanel(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final leftColumn = Column(
                children: [
                  _buildInstallmentsField(),
                  const SizedBox(height: 18),
                  _buildReferenceField(),
                ],
              );
              final rightColumn = _buildDescriptionField();

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: leftColumn),
                    const SizedBox(width: 20),
                    Expanded(child: rightColumn),
                  ],
                );
              }

              return Column(
                children: [leftColumn, const SizedBox(height: 18), rightColumn],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildNotesField(),
          const SizedBox(height: 24),
          const Divider(height: 1),
          const SizedBox(height: 20),
          _buildApprovalSection(),
          const SizedBox(height: 24),
          _buildFooterActions(),
        ],
      ),
    );
  }

  Widget _buildEmployeeField() {
    return _buildFieldBlock(
      label: 'EMPLOYEE',
      icon: Icons.badge_outlined,
      child: DropdownButtonFormField<Employee>(
        initialValue: _selectedEmployee,
        decoration: _inputDecoration('Select an employee'),
        items: _employees
            .map(
              (employee) => DropdownMenuItem(
                value: employee,
                child: Text(employee.fullName),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _selectedEmployee = value),
        validator: (value) => value == null ? 'Select an employee' : null,
      ),
    );
  }

  Widget _buildTypeField() {
    return _buildFieldBlock(
      label: 'DEDUCTION TYPE',
      icon: Icons.account_balance_wallet_outlined,
      child: DropdownButtonFormField<DeductionType>(
        initialValue: _selectedType,
        decoration: _inputDecoration('Select type'),
        items: _types
            .map(
              (type) => DropdownMenuItem(
                value: type,
                child: Text('${type.name} - ${_categoryLabel(type.category)}'),
              ),
            )
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedType = value;
            if (value != null &&
                value.calculationMethod ==
                    DeductionCalculationMethod.percentage) {
              _perPayrollCtrl.text = value.defaultValue.toStringAsFixed(2);
            }
          });
        },
        validator: (value) => value == null ? 'Select deduction type' : null,
      ),
    );
  }

  Widget _buildAmountPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 920;

          if (isWide) {
            return Row(
              children: [
                Expanded(child: _buildTotalAmountField()),
                const SizedBox(width: 16),
                Expanded(child: _buildPerPayrollField()),
                const SizedBox(width: 16),
                Expanded(child: _buildFrequencyField()),
              ],
            );
          }

          return Column(
            children: [
              _buildTotalAmountField(),
              const SizedBox(height: 16),
              _buildPerPayrollField(),
              const SizedBox(height: 16),
              _buildFrequencyField(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTotalAmountField() {
    return _buildFieldBlock(
      label: 'TOTAL AMOUNT',
      child: TextFormField(
        controller: _totalAmountCtrl,
        decoration: _inputDecoration('0.00').copyWith(prefixText: 'NGN '),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
            ? 'Enter valid amount'
            : null,
      ),
    );
  }

  Widget _buildPerPayrollField() {
    return _buildFieldBlock(
      label: 'AMOUNT PER PAYROLL',
      child: TextFormField(
        controller: _perPayrollCtrl,
        decoration: _inputDecoration('0.00').copyWith(prefixText: 'NGN '),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
            ? 'Enter valid amount'
            : null,
      ),
    );
  }

  Widget _buildFrequencyField() {
    return _buildFieldBlock(
      label: 'FREQUENCY',
      child: DropdownButtonFormField<DeductionFrequency>(
        initialValue: _frequency,
        decoration: _inputDecoration('Frequency'),
        items: DeductionFrequency.values
            .map(
              (frequency) => DropdownMenuItem(
                value: frequency,
                child: Text(_frequencyLabel(frequency)),
              ),
            )
            .toList(),
        onChanged: (value) => setState(() => _frequency = value ?? _frequency),
      ),
    );
  }

  Widget _buildInstallmentsField() {
    return _buildFieldBlock(
      label: 'INSTALLMENTS (OPTIONAL)',
      child: TextFormField(
        controller: _installmentsCtrl,
        decoration: _inputDecoration('e.g. 12'),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    );
  }

  Widget _buildReferenceField() {
    return _buildFieldBlock(
      label: 'REFERENCE NUMBER (OPTIONAL)',
      child: TextFormField(
        controller: _referenceCtrl,
        decoration: _inputDecoration('REF-000000'),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return _buildFieldBlock(
      label: 'DESCRIPTION (OPTIONAL)',
      child: TextFormField(
        controller: _descriptionCtrl,
        decoration: _inputDecoration('Brief explanation of the deduction...'),
        minLines: 4,
        maxLines: 5,
      ),
    );
  }

  Widget _buildNotesField() {
    return _buildFieldBlock(
      label: 'NOTES (INTERNAL ONLY)',
      child: TextFormField(
        controller: _notesCtrl,
        decoration: _inputDecoration('Additional audit trail notes...'),
        minLines: 3,
        maxLines: 4,
      ),
    );
  }

  Widget _buildApprovalSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _requiresApproval,
            onChanged: !_canActivateDirectly
                ? null
                : (value) {
                    setState(() {
                      _requiresApproval = value ?? true;
                      _initialStatus = _requiresApproval
                          ? DeductionStatus.pending
                          : DeductionStatus.active;
                    });
                  },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Submit for approval',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _canActivateDirectly
                      ? 'If off, deduction becomes active now and will be included in the next run.'
                      : 'Your role cannot activate deductions directly, so approval is required.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final submitButton = SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Assign Deduction',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        );

        final discardButton = TextButton(
          onPressed: _submitting ? null : _discardChanges,
          child: const Text(
            'Discard Changes',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        );

        if (isWide) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [discardButton, const SizedBox(width: 18), submitButton],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            submitButton,
            const SizedBox(height: 12),
            Center(child: discardButton),
          ],
        );
      },
    );
  }

  Widget _buildStatusCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildStatusCard(
            title: 'OPERATIONAL STATUS',
            value: _requiresApproval
                ? 'Pending approval from Finance Controller'
                : 'Ready for next payroll cycle',
            icon: Icons.rule_folder_outlined,
          ),
          _buildStatusCard(
            title: 'SYSTEM INTEGRITY',
            value: '256-bit encryption verified',
            icon: Icons.lock_outline_rounded,
          ),
        ];

        if (constraints.maxWidth >= 820) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 18),
              Expanded(child: cards[1]),
            ],
          );
        }

        return Column(
          children: [cards[0], const SizedBox(height: 16), cards[1]],
        );
      },
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.infoLight.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.infoDark,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: AppColors.infoDark, size: 28),
        ],
      ),
    );
  }

  Widget _buildFieldBlock({
    required String label,
    IconData? icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
