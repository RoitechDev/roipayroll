import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/csv_file_helper.dart';
import 'package:roipayroll/core/utils/date_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/audit_log_model.dart';
import 'package:roipayroll/services/audit_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _userService = UserService();
  late final AuditService _auditService;
  final _searchController = TextEditingController();

  List<AuditLog> _logs = [];
  List<AuditLog> _filteredLogs = [];
  bool _isLoading = true;
  String? _errorMessage;
  AuditAction? _selectedAction;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _auditService = AuditService(userService: _userService);
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _auditService.getRecentLogs(limit: 300);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _errorMessage = null;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = _logs.where((log) {
      if (_selectedAction != null && log.action != _selectedAction) {
        return false;
      }

      if (_fromDate != null) {
        final from = DateTime(
          _fromDate!.year,
          _fromDate!.month,
          _fromDate!.day,
        );
        if (log.timestamp.isBefore(from)) return false;
      }

      if (_toDate != null) {
        final to = DateTime(
          _toDate!.year,
          _toDate!.month,
          _toDate!.day,
          23,
          59,
          59,
        );
        if (log.timestamp.isAfter(to)) return false;
      }

      if (query.isEmpty) return true;
      final haystack =
          '${log.userName} ${log.entityType} ${log.entityName ?? ''} ${log.action.name}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();

    setState(() => _filteredLogs = filtered);
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = isFrom ? (_fromDate ?? now) : (_toDate ?? now);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
    );
    if (selected == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = selected;
      } else {
        _toDate = selected;
      }
    });
    _applyFilters();
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
    _applyFilters();
  }

  Future<void> _exportCsv() async {
    final header = [
      'Timestamp',
      'Action',
      'User',
      'Entity Type',
      'Entity ID',
      'Entity Name',
      'Before',
      'After',
    ];

    final rows = _filteredLogs.map((log) {
      return [
        log.timestamp.toIso8601String(),
        log.action.name,
        log.userName,
        log.entityType,
        log.entityId,
        log.entityName ?? '',
        log.before == null ? '' : jsonEncode(log.before),
        log.after == null ? '' : jsonEncode(log.after),
      ];
    }).toList();

    final csv = StringBuffer();
    csv.writeln(_csvRow(header));
    for (final row in rows) {
      csv.writeln(_csvRow(row));
    }

    try {
      await downloadCsvFile(
        fileName:
            'audit_logs_${DateTime.now().toIso8601String().split('T').first}.csv',
        csv: csv.toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Audit logs CSV downloaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _csvRow(List<String> values) {
    return values.map((value) => '"${value.replaceAll('"', '""')}"').join(',');
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppBar(
        title: const Text('Audit Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _filteredLogs.isEmpty ? null : _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildBody(isCompact: true),
        tablet: _buildBody(isCompact: false),
        desktop: _buildBody(isCompact: false),
      ),
    );
  }

  Widget _buildBody({required bool isCompact}) {
    final pagePadding = isCompact ? 12.0 : 16.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(pagePadding),
          child: Column(
            children: [
              if (isCompact)
                Column(
                  children: [
                    _buildActionDropdown(),
                    const SizedBox(height: 10),
                    _buildSearchField(),
                  ],
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(width: 280, child: _buildActionDropdown()),
                    SizedBox(width: 360, child: _buildSearchField()),
                  ],
                ),
              const SizedBox(height: 10),
              if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: true),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _fromDate == null
                                  ? 'From'
                                  : 'From: ${DateFormatter.formatShort(_fromDate!)}',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: false),
                            icon: const Icon(Icons.date_range),
                            label: Text(
                              _toDate == null
                                  ? 'To'
                                  : 'To: ${DateFormatter.formatShort(_toDate!)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _clearDateFilter,
                          child: const Text('Clear dates'),
                        ),
                        const Spacer(),
                        StatusBadge(
                          status: '${_filteredLogs.length} records',
                          color: AppColors.info,
                        ),
                      ],
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: true),
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _fromDate == null
                            ? 'From'
                            : 'From: ${DateFormatter.formatShort(_fromDate!)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _pickDate(isFrom: false),
                      icon: const Icon(Icons.date_range),
                      label: Text(
                        _toDate == null
                            ? 'To'
                            : 'To: ${DateFormatter.formatShort(_toDate!)}',
                      ),
                    ),
                    TextButton(
                      onPressed: _clearDateFilter,
                      child: const Text('Clear dates'),
                    ),
                    StatusBadge(
                      status: '${_filteredLogs.length} records',
                      color: AppColors.info,
                    ),
                  ],
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const ModernLoadingState(message: 'Loading audit logs...')
              : _errorMessage != null
              ? ModernErrorState(
                  message: 'Failed to load audit logs',
                  subtitle: _errorMessage,
                  onRetry: _loadLogs,
                )
              : _filteredLogs.isEmpty
              ? const ModernEmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'No audit logs found',
                  subtitle: 'Try adjusting search, action, or date filters.',
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    pagePadding,
                    0,
                    pagePadding,
                    pagePadding,
                  ),
                  itemCount: _filteredLogs.length,
                  itemBuilder: (context, index) {
                    final log = _filteredLogs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          '${log.action.name} - ${log.entityType}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'By: ${log.userName} | ${DateFormatter.formatStandard(log.timestamp)}',
                            ),
                            if (log.entityName != null &&
                                log.entityName!.trim().isNotEmpty)
                              Text('Entity: ${log.entityName}'),
                            Text(
                              'ID: ${log.entityId}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        trailing: StatusBadge(
                          status: log.action.name.toUpperCase(),
                          color: AppColors.primary,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActionDropdown() {
    return DropdownButtonFormField<AuditAction?>(
      initialValue: _selectedAction,
      decoration: const InputDecoration(
        labelText: 'Action',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<AuditAction?>(
          value: null,
          child: Text('All actions'),
        ),
        ...AuditAction.values.map(
          (action) => DropdownMenuItem<AuditAction?>(
            value: action,
            child: Text(action.name),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() => _selectedAction = value);
        _applyFilters();
      },
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (_) => _applyFilters(),
      decoration: const InputDecoration(
        labelText: 'Search user/entity',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}
