import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/leave_balance_model.dart';
import 'package:roipayroll/models/leave_request_model.dart';
import 'package:roipayroll/models/leave_type_model.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/services/leave_request_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';
import 'package:uuid/uuid.dart';

class ApplyLeaveScreen extends ConsumerStatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  ConsumerState<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends ConsumerState<ApplyLeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _leaveRequestService = LeaveRequestService();

  final _reasonController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _contactAddressController = TextEditingController();
  final _handoverNotesController = TextEditingController();

  LeaveType? _selectedLeaveType;
  LeaveBalance? _selectedBalance;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _reasonController.dispose();
    _contactPhoneController.dispose();
    _contactAddressController.dispose();
    _handoverNotesController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest(String employeeId, String employeeName) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLeaveType == null || _startDate == null || _endDate == null) {
      NotificationHelper.showError(context, 'Please fill all required fields');
      return;
    }

    NotificationHelper.showLoading(context, message: 'Submitting request...');
    try {
      final request = LeaveRequest(
        id: const Uuid().v4(),
        employeeId: employeeId,
        employeeName: employeeName,
        leaveTypeId: _selectedLeaveType!.id,
        leaveTypeName: _selectedLeaveType!.name,
        startDate: _startDate!,
        endDate: _endDate!,
        numberOfDays: 0,
        durationType: LeaveDurationType.multipleDays,
        reason: _reasonController.text,
        status: LeaveRequestStatus.pending,
        requestedAt: DateTime.now(),
        contactPhone: _contactPhoneController.text,
        contactAddress: _contactAddressController.text,
        handoverNotes: _handoverNotesController.text,
      );

      await _leaveRequestService.submitLeaveRequest(request);
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Leave request submitted successfully!',
      );
      Navigator.pushReplacementNamed(context, AppRoutes.leaveDashboard);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      final msg = e.toString().replaceFirst('Exception: ', '');
      NotificationHelper.showError(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final applyDataAsync = ref.watch(applyLeaveDataProvider);

    return AppScaffold(
      topBar: AppBar(title: const Text('Apply for Leave')),
      body: applyDataAsync.when(
        loading: () => const ModernLoadingState(
          message: 'Loading leave application data...',
        ),
        error: (error, _) => ModernErrorState(
          message: 'Unable to load leave application form',
          subtitle: '$error',
          onRetry: () => ref.invalidate(applyLeaveDataProvider),
        ),
        data: (data) {
          if (data.employeeId == null || data.employeeId!.isEmpty) {
            return const ModernErrorState(
              message: 'Employee profile not found',
              subtitle: 'This account is not linked to an employee record.',
            );
          }

          return ResponsiveLayout(
            mobile:
                _buildFormContent(data, isCompact: true, padding: 12),
            tablet:
                _buildFormContent(data, isCompact: false, padding: 16),
            desktop:
                _buildFormContent(data, isCompact: false, padding: 16),
          );
        },
      ),
    );
  }

  Widget _buildFormContent(
    ApplyLeaveData data, {
    required bool isCompact,
    required double padding,
  }) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(padding),
        children: [
          _buildLeaveTypeDropdown(data.leaveTypes, data.balances),
          const SizedBox(height: 16),
          if (_selectedBalance != null) _buildBalanceInfo(),
          const SizedBox(height: 12),
          _buildAvailableBalanceInfo(),
          const SizedBox(height: 16),
          _buildDatePickers(isCompact: isCompact),
          const SizedBox(height: 16),
          _buildReasonField(),
          const SizedBox(height: 16),
          _buildContactFields(),
          const SizedBox(height: 24),
          _buildSubmitButton(data.employeeId!, data.employeeName),
        ],
      ),
    );
  }

  Widget _buildAvailableBalanceInfo() {
    if (_selectedBalance == null) return const SizedBox.shrink();

    final available = _selectedBalance!.availableBalance;
    final used = _selectedBalance!.usedDays;
    final pending = _selectedBalance!.pendingDays;
    final encashed = _selectedBalance!.encashedDays;

    return Card(
      color: AppColors.info.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.info, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Available Balance',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${available.toStringAsFixed(1)} days available',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used: ${used.toStringAsFixed(1)} | Pending: ${pending.toStringAsFixed(1)} | Encash: ${encashed.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveTypeDropdown(
    List<LeaveType> leaveTypes,
    List<LeaveBalance> balances,
  ) {
    final hasTypes = leaveTypes.isNotEmpty;
    return DropdownButtonFormField<LeaveType>(
      initialValue: _selectedLeaveType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Leave Type',
        border: OutlineInputBorder(),
      ),
      items: leaveTypes.map((type) {
        return DropdownMenuItem(value: type, child: Text(type.name));
      }).toList(),
      onChanged: hasTypes
          ? (value) {
              setState(() {
                _selectedLeaveType = value;
                LeaveBalance? match;
                for (final balance in balances) {
                  if (balance.leaveTypeId == value?.id) {
                    match = balance;
                    break;
                  }
                }
                _selectedBalance = match;
              });
            }
          : null,
      validator: (value) => value == null ? 'Please select leave type' : null,
    );
  }

  Widget _buildBalanceInfo() {
    return Card(
      color: AppColors.info.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Balance',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedBalance!.balance.toStringAsFixed(1)} days',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePickers({required bool isCompact}) {
    final startField = InkWell(
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
    );
    final endField = InkWell(
      onTap: () => _selectDate(false),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'End Date',
          border: OutlineInputBorder(),
        ),
        child: Text(_endDate != null ? _formatDate(_endDate!) : 'Select date'),
      ),
    );

    if (isCompact) {
      return Column(
        children: [startField, const SizedBox(height: 12), endField],
      );
    }

    return Row(
      children: [
        Expanded(child: startField),
        const SizedBox(width: 16),
        Expanded(child: endField),
      ],
    );
  }

  Widget _buildReasonField() {
    return TextFormField(
      controller: _reasonController,
      decoration: const InputDecoration(
        labelText: 'Reason',
        border: OutlineInputBorder(),
      ),
      maxLines: 3,
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter reason' : null,
    );
  }

  Widget _buildContactFields() {
    return Column(
      children: [
        TextFormField(
          controller: _contactPhoneController,
          decoration: const InputDecoration(
            labelText: 'Contact Phone',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contactAddressController,
          decoration: const InputDecoration(
            labelText: 'Contact Address',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(String employeeId, String employeeName) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: () => _submitRequest(employeeId, employeeName),
        style: ElevatedButton.styleFrom(foregroundColor: Colors.white),
        child: const Text(
          'Submit Request',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        if (isStartDate) {
          _startDate = date;
          if (_endDate != null && _endDate!.isBefore(date)) {
            _endDate = null;
          }
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
}
