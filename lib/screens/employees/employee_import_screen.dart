import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:uuid/uuid.dart';

class EmployeeImportScreen extends StatefulWidget {
  const EmployeeImportScreen({super.key});

  @override
  State<EmployeeImportScreen> createState() => _EmployeeImportScreenState();
}

class _EmployeeImportScreenState extends State<EmployeeImportScreen> {
  final _employeeService = EmployeeService();

  EmploymentType _employmentType = EmploymentType.probation;
  int _durationMonths = 3;
  bool _isLoading = false;

  List<_PreviewEmployee> _previewData = [];
  List<String> _missingColumns = [];

  @override
  Widget build(BuildContext context) {
    final previewCount = _previewData.length;
    final validCount = _previewData
        .where((employee) => employee.isValid)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Employees'),
        actions: [
          if (previewCount > 0)
            TextButton(
              onPressed: _isLoading ? null : _importEmployees,
              child: const Text(
                'Import All',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildSettingsSection(),
          Expanded(
            child: previewCount == 0
                ? _buildUploadSection()
                : _buildPreviewSection(validCount),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Import Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildEmploymentTypeDropdown()),
              if (_employmentType != EmploymentType.permanent)
                const SizedBox(width: 12),
              if (_employmentType != EmploymentType.permanent)
                Expanded(child: _buildDurationDropdown()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmploymentTypeDropdown() {
    return DropdownButtonFormField<EmploymentType>(
      initialValue: _employmentType,
      decoration: const InputDecoration(
        labelText: 'Employment Type',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(
          value: EmploymentType.permanent,
          child: Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text('Permanent'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: EmploymentType.contract,
          child: Row(
            children: [
              Icon(Icons.description, color: AppColors.info, size: 18),
              SizedBox(width: 8),
              Text('Contract'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: EmploymentType.probation,
          child: Row(
            children: [
              Icon(Icons.hourglass_bottom, color: AppColors.warning, size: 18),
              SizedBox(width: 8),
              Text('Probation'),
            ],
          ),
        ),
      ],
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _employmentType = value;
          if (_employmentType == EmploymentType.probation &&
              !_probationDurations.contains(_durationMonths)) {
            _durationMonths = 3;
          }
          if (_employmentType == EmploymentType.contract &&
              !_contractDurations.contains(_durationMonths)) {
            _durationMonths = 6;
          }
        });
      },
    );
  }

  Widget _buildDurationDropdown() {
    final options = _employmentType == EmploymentType.probation
        ? _probationDurations
        : _contractDurations;
    final label = _employmentType == EmploymentType.probation
        ? 'Probation Duration'
        : 'Contract Duration';

    return DropdownButtonFormField<int>(
      initialValue: _durationMonths,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: options
          .map(
            (value) =>
                DropdownMenuItem(value: value, child: Text('$value months')),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _durationMonths = value);
      },
    );
  }

  Widget _buildUploadSection() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.upload_file, size: 80, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Upload CSV File',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select a CSV file containing employee data',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _pickFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
              ),
              child: const Text('Choose CSV File'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _showTemplateInfo,
              child: const Text('Download CSV Template'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection(int validCount) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$validCount employees ready to import',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _isLoading ? null : _clearPreview,
                child: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _importEmployees,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text('Import $validCount Employees'),
              ),
            ],
          ),
        ),
        if (_missingColumns.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Missing required columns: ${_missingColumns.join(', ')}',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _previewData.length,
            itemBuilder: (context, index) {
              final employee = _previewData[index];
              return _PreviewCard(
                index: index + 1,
                employee: employee,
                employmentType: _employmentType,
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );

      if (!mounted) return;

      if (result == null || result.files.isEmpty) {
        NotificationHelper.showWarning(context, 'No file selected');
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        NotificationHelper.showError(context, 'CSV file is empty');
        return;
      }

      final csvString = utf8.decode(bytes);
      final rows = const CsvDecoder().convert(csvString);

      if (!mounted) return;
      if (rows.isEmpty) {
        NotificationHelper.showError(context, 'CSV file is empty');
        return;
      }

      final headerRow = rows.first.map((cell) => '$cell').toList();
      final headers = headerRow.map((h) => h.trim()).toList();
      final requiredColumns = _requiredColumns;

      _missingColumns = requiredColumns
          .where(
            (col) => !headers
                .map((h) => h.toLowerCase())
                .contains(col.toLowerCase()),
          )
          .toList();

      if (_missingColumns.isNotEmpty) {
        _previewData = [];
        NotificationHelper.showError(context, 'Missing required columns');
        return;
      }

      final preview = <_PreviewEmployee>[];
      final csvEmails = <String>{};

      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row.every((value) => '$value'.trim().isEmpty)) {
          continue;
        }

        final data = <String, String>{};
        for (var j = 0; j < headers.length; j++) {
          data[headers[j]] = j < row.length ? '${row[j]}' : '';
        }

        final email = _normalize(data['email'] ?? '');
        final basicSalaryRaw = _normalize(data['basicSalary'] ?? '');
        final salary = double.tryParse(basicSalaryRaw.replaceAll(',', ''));

        String? error;
        if (!_isValidEmail(email)) {
          error = 'Invalid email format';
        } else if (salary == null) {
          error = 'Invalid basic salary';
        } else if (csvEmails.contains(email.toLowerCase())) {
          error = 'Duplicate email in CSV';
        } else {
          final existing = await _employeeService.findByEmail(email);
          if (existing != null) {
            error = 'Email already exists';
          }
        }

        if (error == null) {
          csvEmails.add(email.toLowerCase());
        }

        preview.add(
          _PreviewEmployee(
            firstName: _normalize(data['firstName'] ?? ''),
            lastName: _normalize(data['lastName'] ?? ''),
            email: email,
            phone: _normalize(data['phone'] ?? ''),
            department: _normalize(data['department'] ?? ''),
            position: _normalize(data['position'] ?? ''),
            basicSalary: salary ?? 0,
            bankName: _normalize(data['bankName'] ?? ''),
            accountNumber: _normalize(data['accountNumber'] ?? ''),
            isValid: error == null,
            error: error,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _previewData = preview;
      });

      if (!mounted) return;
      NotificationHelper.showSuccess(
        context,
        '${preview.length} employees loaded',
      );
    } catch (e) {
      if (mounted) {
        NotificationHelper.showError(context, 'Invalid CSV format');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importEmployees() async {
    final validEmployees = _previewData
        .where((employee) => employee.isValid)
        .toList();
    if (validEmployees.isEmpty) {
      NotificationHelper.showError(context, 'No valid employees to import');
      return;
    }

    NotificationHelper.showLoading(context, message: 'Importing employees...');
    var success = 0;
    var failed = 0;

    for (final preview in validEmployees) {
      try {
        final now = DateTime.now();
        DateTime? probationEndDate;
        DateTime? contractEndDate;

        if (_employmentType == EmploymentType.probation) {
          probationEndDate = now.add(Duration(days: _durationMonths * 30));
        }

        if (_employmentType == EmploymentType.contract) {
          contractEndDate = now.add(Duration(days: _durationMonths * 30));
        }

        final employee = Employee(
          id: const Uuid().v4(),
          firstName: preview.firstName,
          lastName: preview.lastName,
          email: preview.email,
          phone: preview.phone,
          department: preview.department,
          position: preview.position,
          basicSalary: preview.basicSalary,
          hireDate: now,
          employmentType: _employmentType,
          probationEndDate: probationEndDate,
          contractEndDate: contractEndDate,
          bankName: preview.bankName.isEmpty ? null : preview.bankName,
          accountNumber: preview.accountNumber.isEmpty
              ? null
              : preview.accountNumber,
        );

        await _employeeService.createEmployee(employee);
        success++;
      } catch (e) {
        failed++;
      }
    }

    if (!mounted) return;

    NotificationHelper.hideLoading(context);

    if (success > 0) {
      NotificationHelper.showSuccess(
        context,
        '$success succeeded, $failed failed',
      );
      Navigator.pop(context, true);
    } else {
      NotificationHelper.showError(context, 'Failed to import employees');
    }
  }

  void _showTemplateInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSV Template'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Required:'),
            SizedBox(height: 4),
            Text(
              'firstName,lastName,email,phone,department,position,basicSalary',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 12),
            Text('Optional:'),
            SizedBox(height: 4),
            Text('bankName,accountNumber', style: TextStyle(fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _clearPreview() {
    setState(() {
      _previewData = [];
      _missingColumns = [];
    });
  }

  bool _isValidEmail(String email) {
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return regex.hasMatch(email);
  }

  String _normalize(String value) => value.trim();

  List<String> get _requiredColumns => const [
    'firstName',
    'lastName',
    'email',
    'phone',
    'department',
    'position',
    'basicSalary',
  ];

  List<int> get _probationDurations => const [1, 2, 3, 6];
  List<int> get _contractDurations => const [3, 6, 12, 24];
}

class _PreviewEmployee {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String department;
  final String position;
  final double basicSalary;
  final String bankName;
  final String accountNumber;
  final bool isValid;
  final String? error;

  const _PreviewEmployee({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.department,
    required this.position,
    required this.basicSalary,
    required this.bankName,
    required this.accountNumber,
    required this.isValid,
    this.error,
  });

  String get fullName => '$firstName $lastName';
}

class _PreviewCard extends StatelessWidget {
  final int index;
  final _PreviewEmployee employee;
  final EmploymentType employmentType;

  const _PreviewCard({
    required this.index,
    required this.employee,
    required this.employmentType,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getEmploymentTypeColor(employmentType);
    final icon = _getEmploymentTypeIcon(employmentType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  employee.fullName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${employee.position} • ${employee.department}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  employee.email,
                  style: TextStyle(
                    color: employee.isValid
                        ? AppColors.textSecondary
                        : AppColors.error,
                    fontSize: 12,
                  ),
                ),
                if (!employee.isValid && employee.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      employee.error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Text(
                  employmentType.name.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getEmploymentTypeColor(EmploymentType type) {
    switch (type) {
      case EmploymentType.permanent:
        return AppColors.success;
      case EmploymentType.contract:
        return AppColors.info;
      case EmploymentType.probation:
        return AppColors.warning;
    }
  }

  IconData _getEmploymentTypeIcon(EmploymentType type) {
    switch (type) {
      case EmploymentType.permanent:
        return Icons.check_circle;
      case EmploymentType.contract:
        return Icons.description;
      case EmploymentType.probation:
        return Icons.hourglass_bottom;
    }
  }
}
