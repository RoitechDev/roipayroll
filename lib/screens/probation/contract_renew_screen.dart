import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/models/contract_record_model.dart';
import 'package:roipayroll/services/contract_service.dart';

class ContractRenewScreen extends StatefulWidget {
  final String? contractId;

  const ContractRenewScreen({super.key, this.contractId});

  @override
  State<ContractRenewScreen> createState() => _ContractRenewScreenState();
}

class _ContractRenewScreenState extends State<ContractRenewScreen> {
  final _contractService = ContractService();
  final _formKey = GlobalKey<FormState>();
  final _salaryController = TextEditingController();
  final _permanentSalaryController = TextEditingController();

  ContractRecord? _contract;
  DateTime? _newEndDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContract();
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _permanentSalaryController.dispose();
    super.dispose();
  }

  Future<void> _loadContract() async {
    setState(() => _isLoading = true);

    try {
      if (widget.contractId != null) {
        // Get contract using public method from service
        final contracts = await _contractService.getAllContracts();
        final contract = contracts.firstWhere(
          (c) => c.id == widget.contractId,
          orElse: () => throw 'Contract not found',
        );

        if (mounted) {
          setState(() {
            _contract = contract;
            _salaryController.text = contract.contractSalary.toString();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _renewContract() async {
    if (!_formKey.currentState!.validate() || _newEndDate == null) {
      if (mounted) {
        NotificationHelper.showError(context, 'Please fill all fields');
      }
      return;
    }

    if (mounted) {
      NotificationHelper.showLoading(context, message: 'Renewing contract...');
    }

    try {
      final newSalary = double.parse(_salaryController.text);

      await _contractService.renewContract(
        contractId: _contract!.id,
        newEndDate: _newEndDate!,
        newSalary: newSalary,
      );

      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showSuccess(context, 'Contract renewed');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showError(context, e.toString());
      }
    }
  }

  Future<void> _convertToPermanent() async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Convert to Permanent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Convert ${_contract!.employeeName} to permanent employee?'),
            const SizedBox(height: 16),
            TextField(
              controller: _permanentSalaryController,
              decoration: const InputDecoration(
                labelText: 'Permanent Salary (₦)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    NotificationHelper.showLoading(context, message: 'Converting...');

    try {
      final salary = double.parse(_permanentSalaryController.text);

      await _contractService.convertToPermanent(
        contractId: _contract!.id,
        permanentSalary: salary,
      );

      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showSuccess(context, 'Converted to permanent!');
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
      appBar: AppBar(title: const Text('Renew/Convert Contract')),
      body: _isLoading || _contract == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildContractInfo(),
                  const SizedBox(height: 16),
                  _buildDocumentModuleCard(),
                  const SizedBox(height: 24),
                  _buildRenewForm(),
                  const SizedBox(height: 24),
                  _buildConvertButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildContractInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _contract!.employeeName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Text('Type: ${_contract!.contractType.name}'),
            Text('Salary: ₦${_contract!.contractSalary}'),
            Text('End Date: ${_formatDate(_contract!.endDate!)}'),
            Text('Days Left: ${_contract!.daysRemaining}'),
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
              'Open the Document module to upload or review contract files.',
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

  Widget _buildRenewForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Renew Contract',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectEndDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'New End Date',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _newEndDate != null
                      ? _formatDate(_newEndDate!)
                      : 'Select date',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _salaryController,
              decoration: const InputDecoration(
                labelText: 'New Salary (₦)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _renewContract,
                child: const Text('Renew Contract'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConvertButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _convertToPermanent,
        icon: const Icon(Icons.upgrade),
        label: const Text('Convert to Permanent'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _contract!.endDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (date != null && mounted) {
      setState(() => _newEndDate = date);
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

  void _openDocumentModule() {
    Navigator.pushNamed(context, AppRoutes.documentManagement);
  }
}
