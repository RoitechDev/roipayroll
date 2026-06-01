import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/deduction_transaction_model.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/providers/deduction_provider.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class DeductionHistoryScreen extends ConsumerStatefulWidget {
  const DeductionHistoryScreen({super.key});

  @override
  ConsumerState<DeductionHistoryScreen> createState() =>
      _DeductionHistoryScreenState();
}

class _DeductionHistoryScreenState
    extends ConsumerState<DeductionHistoryScreen> {
  DateTime? _from;
  DateTime? _to;
  DeductionCategory? _categoryFilter;
  String _search = '';

  List<DeductionTransaction> _filtered(List<DeductionTransaction> all) {
    return all.where((t) {
      if (_categoryFilter != null && t.category != _categoryFilter) {
        return false;
      }
      if (_search.isNotEmpty) {
        final target = '${t.employeeName} ${t.deductionTypeName}'.toLowerCase();
        if (!target.contains(_search.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList()..sort((a, b) => b.processedAt.compareTo(a.processedAt));
  }

  Future<void> _pickDate({required bool from}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _exportCsv(List<DeductionTransaction> rowsData) async {
    final rows = <List<String>>[
      ['Date', 'Employee', 'Type', 'Category', 'Amount', 'Payroll'],
      ...rowsData.map(
        (t) => [
          t.processedAt.toIso8601String(),
          t.employeeName,
          t.deductionTypeName,
          t.category.name,
          t.amount.toStringAsFixed(2),
          '${t.payrollMonth}/${t.payrollYear}',
        ],
      ),
    ];
    final csv = rows.map((r) => r.map((v) => '"$v"').join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
  }

  Future<void> _exportPdf(List<DeductionTransaction> rowsData) async {
    final total = rowsData.fold(0.0, (sum, t) => sum + t.amount);
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Deduction History'),
          pw.Paragraph(text: 'Total Deducted: ${total.toStringAsFixed(2)}'),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Employee', 'Type', 'Amount'],
            data: rowsData
                .map(
                  (t) => [
                    '${t.processedAt.year}-${t.processedAt.month}-${t.processedAt.day}',
                    t.employeeName,
                    t.deductionTypeName,
                    t.amount.toStringAsFixed(2),
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final query = DeductionHistoryQuery(from: _from, to: _to);
    final historyAsync = ref.watch(deductionHistoryProvider(query));

    return AppScaffold(
      topBar: AppBar(
        title: const Text('Deduction History'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(deductionHistoryProvider(query)),
            icon: const Icon(Icons.refresh),
          ),
          historyAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (data) {
              final filtered = _filtered(data.transactions);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _exportCsv(filtered),
                    icon: const Icon(Icons.table_chart),
                  ),
                  IconButton(
                    onPressed: () => _exportPdf(filtered),
                    icon: const Icon(Icons.picture_as_pdf),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const ModernLoadingState(message: 'Loading history...'),
        error: (error, _) => ModernErrorState(
          message: 'Failed to load deduction history',
          subtitle: error.toString(),
          onRetry: () => ref.invalidate(deductionHistoryProvider(query)),
        ),
        data: (data) {
          if (!data.canViewAll && data.employeeId == null) {
            return const ModernEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Employee profile not linked',
            );
          }

          final filtered = _filtered(data.transactions);
          final total = filtered.fold(0.0, (sum, t) => sum + t.amount);
          final byType = <String, double>{};
          for (final t in filtered) {
            byType[t.deductionTypeName] =
                (byType[t.deductionTypeName] ?? 0) + t.amount;
          }

          return ResponsiveLayout(
            mobile: _buildContent(
              data: data,
              filtered: filtered,
              total: total,
              byType: byType,
              isCompact: true,
              padding: const EdgeInsets.all(12),
            ),
            tablet: _buildContent(
              data: data,
              filtered: filtered,
              total: total,
              byType: byType,
              isCompact: false,
              padding: const EdgeInsets.all(16),
            ),
            desktop: _buildContent(
              data: data,
              filtered: filtered,
              total: total,
              byType: byType,
              isCompact: false,
              padding: const EdgeInsets.all(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required DeductionHistoryData data,
    required List<DeductionTransaction> filtered,
    required double total,
    required Map<String, double> byType,
    required bool isCompact,
    required EdgeInsets padding,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        if (isCompact)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(data),
              const SizedBox(height: 8),
              _buildCategoryDropdown(),
              const SizedBox(height: 8),
              ..._buildDateButtons(isCompact: true),
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(width: 320, child: _buildSearchField(data)),
              SizedBox(width: 220, child: _buildCategoryDropdown()),
              ..._buildDateButtons(isCompact: false),
            ],
          ),
        const SizedBox(height: 12),
        ModernMetricsGrid(
          metrics: [
            ModernMetricCard(
              title: 'Total Deducted',
              value: CurrencyFormatter.formatNaira(total),
              icon: Icons.payments_outlined,
              color: AppColors.error,
            ),
            ModernMetricCard(
              title: 'Transactions',
              value: filtered.length.toString(),
              icon: Icons.receipt_long_outlined,
              color: AppColors.primary,
            ),
            ModernMetricCard(
              title: 'Deduction Types',
              value: byType.length.toString(),
              icon: Icons.category_outlined,
              color: AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          const SizedBox(
            height: 320,
            child: ModernEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No transactions found',
            ),
          )
        else
          ...filtered.map((t) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(
                  data.canViewAll
                      ? '${t.employeeName} - ${t.deductionTypeName}'
                      : t.deductionTypeName,
                ),
                subtitle: Text(
                  '${t.category.name} | ${t.payrollMonth}/${t.payrollYear}',
                ),
                trailing: Text(
                  CurrencyFormatter.formatNaira(t.amount),
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSearchField(DeductionHistoryData data) {
    return TextField(
      decoration: InputDecoration(
        hintText: data.canViewAll ? 'Search employee or type' : 'Search type',
        prefixIcon: const Icon(Icons.search),
      ),
      onChanged: (v) => setState(() => _search = v),
    );
  }

  Widget _buildCategoryDropdown() {
    return DropdownButtonFormField<DeductionCategory?>(
      initialValue: _categoryFilter,
      items: [
        const DropdownMenuItem(value: null, child: Text('All Categories')),
        ...DeductionCategory.values.map(
          (c) => DropdownMenuItem(value: c, child: Text(c.name)),
        ),
      ],
      onChanged: (v) => setState(() => _categoryFilter = v),
    );
  }

  List<Widget> _buildDateButtons({required bool isCompact}) {
    final fromButton = OutlinedButton.icon(
      onPressed: () => _pickDate(from: true),
      icon: const Icon(Icons.date_range),
      label: Text(
        _from == null ? 'From' : '${_from!.day}/${_from!.month}/${_from!.year}',
      ),
    );
    final toButton = OutlinedButton.icon(
      onPressed: () => _pickDate(from: false),
      icon: const Icon(Icons.event),
      label: Text(
        _to == null ? 'To' : '${_to!.day}/${_to!.month}/${_to!.year}',
      ),
    );

    if (isCompact) {
      return [
        Row(
          children: [
            Expanded(child: fromButton),
            const SizedBox(width: 8),
            Expanded(child: toButton),
          ],
        ),
      ];
    }
    return [fromButton, toButton];
  }
}
