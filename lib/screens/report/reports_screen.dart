import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/csv_file_helper.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/payroll_trend_model.dart';
import 'package:roipayroll/providers/report_provider.dart';
import 'package:roipayroll/services/accounting_integration_service.dart';
import 'package:roipayroll/services/payroll_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _payrollService = PayrollService();
  final _accountingService = AccountingIntegrationService();
  final _searchController = TextEditingController();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = ReportsPeriod(month: _selectedMonth, year: _selectedYear);
    final summaryAsync = ref.watch(reportsSummaryProvider(period));

    return AppScaffold(
      topBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(reportsSummaryProvider(period)),
          ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildBody(period, summaryAsync, isCompact: true),
        tablet: _buildBody(period, summaryAsync, isCompact: false),
        desktop: _buildBody(period, summaryAsync, isCompact: false),
      ),
    );
  }

  Widget _buildBody(
    ReportsPeriod period,
    AsyncValue<ReportsSummary> summaryAsync, {
    required bool isCompact,
  }) {
    final pagePadding = isCompact ? 12.0 : 18.0;
    return summaryAsync.when(
      loading: () => const ModernLoadingState(message: 'Loading reports...'),
      error: (error, _) => ModernErrorState(
        message: 'Failed to load reports',
        subtitle: error.toString(),
        onRetry: () => ref.invalidate(reportsSummaryProvider(period)),
      ),
      data: (summary) {
        final hasOrgPayroll = summary.payrolls.isNotEmpty;
        final hasPersonalPayroll = summary.personalPayrolls.isNotEmpty;

        if ((summary.scope == ReportsRoleScope.employee &&
                !hasPersonalPayroll) ||
            (summary.scope != ReportsRoleScope.employee && !hasOrgPayroll)) {
          return ListView(
            padding: EdgeInsets.all(pagePadding),
            children: [
              _buildControlBar(context, summary, isCompact: isCompact),
              const SizedBox(height: 18),
              ModernEmptyState(
                icon: Icons.analytics_outlined,
                title: 'No report data for this period',
                subtitle:
                    'Try another month and year or process payroll first.',
              ),
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.all(pagePadding),
          children: [
            _buildControlBar(context, summary, isCompact: isCompact),
            const SizedBox(height: 18),
            switch (summary.scope) {
              ReportsRoleScope.admin => _buildAdminView(context, summary),
              ReportsRoleScope.hr => _buildHrView(context, summary),
              ReportsRoleScope.accountant => _buildFinanceView(
                context,
                summary,
              ),
              ReportsRoleScope.employee => _buildEmployeeView(context, summary),
            },
          ],
        );
      },
    );
  }

  Widget _buildControlBar(
    BuildContext context,
    ReportsSummary summary, {
    required bool isCompact,
  }) {
    final canExport = summary.scope != ReportsRoleScope.employee;
    final canUseAccounting =
        summary.scope == ReportsRoleScope.accountant ||
        summary.scope == ReportsRoleScope.admin;

    final monthField = SizedBox(
      width: isCompact ? double.infinity : 150,
      child: DropdownButtonFormField<int>(
        initialValue: _selectedMonth,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
        items: List.generate(
          12,
          (i) =>
              DropdownMenuItem(value: i + 1, child: Text(_getMonthName(i + 1))),
        ),
        onChanged: (value) => setState(() => _selectedMonth = value!),
      ),
    );

    final yearField = SizedBox(
      width: isCompact ? double.infinity : 120,
      child: DropdownButtonFormField<int>(
        initialValue: _selectedYear,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.event_note_outlined),
        ),
        items: List.generate(5, (i) {
          final year = DateTime.now().year - 2 + i;
          return DropdownMenuItem(value: year, child: Text('$year'));
        }),
        onChanged: (value) => setState(() => _selectedYear = value!),
      ),
    );

    final searchField = SizedBox(
      width: isCompact ? double.infinity : 280,
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search reports...',
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          monthField,
          yearField,
          searchField,
          if (canExport)
            OutlinedButton.icon(
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export CSV'),
              onPressed: _exportCsv,
            ),
          if (canUseAccounting)
            PopupMenuButton<String>(
              tooltip: 'Accounting Exports',
              onSelected: (value) async {
                switch (value) {
                  case 'preview_journal':
                    await _previewJournalEntries();
                    break;
                  case 'export_qb_iif':
                    await _exportQuickBooksIif();
                    break;
                  case 'export_xero_csv':
                    await _exportXeroCsv();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'preview_journal',
                  child: Text('Preview Journal Entries'),
                ),
                PopupMenuItem(
                  value: 'export_qb_iif',
                  child: Text('Export QuickBooks IIF'),
                ),
                PopupMenuItem(
                  value: 'export_xero_csv',
                  child: Text('Export Xero CSV'),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_outlined, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Accounting',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminView(BuildContext context, ReportsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'Executive Payroll Analytics',
          subtitle:
              'Organization-wide payroll performance, deductions, and department movement for the selected period.',
        ),
        const SizedBox(height: 18),
        _buildMetricWrap(context, [
          _MetricSpec(
            title: 'Total Employees',
            value: '${summary.employeeCount}',
            subtitle: '${summary.hiresThisMonth} new joins this month',
            icon: Icons.badge_outlined,
            chip: _trendChip(summary.employeeCount > 0 ? 4 : 0),
          ),
          _MetricSpec(
            title: 'Gross Pay',
            value: CurrencyFormatter.formatNaira(summary.totalGross),
            subtitle: summary.previousGross > 0
                ? 'vs ${CurrencyFormatter.formatNaira(summary.previousGross)} last month'
                : 'No previous payroll baseline',
            icon: Icons.account_balance_wallet_outlined,
            chip: _trendChip(summary.grossGrowthPercentage),
          ),
          _MetricSpec(
            title: 'Total Tax',
            value: CurrencyFormatter.formatNaira(summary.totalTax),
            subtitle: 'Statutory deductions recorded',
            icon: Icons.account_balance_outlined,
            chip: _trendChip(
              summary.totalGross == 0
                  ? 0
                  : -((summary.totalTax / summary.totalGross) * 100),
              negativeTone: true,
            ),
          ),
          _MetricSpec(
            title: 'Net Pay',
            value: CurrencyFormatter.formatNaira(summary.totalNet),
            subtitle: 'Disbursable payroll outcome',
            icon: Icons.payments_outlined,
            chip: _trendChip(summary.netGrowthPercentage),
          ),
        ]),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _panelWidth(context, 760),
              child: _trendPanel(
                title: 'Payroll Trend',
                subtitle: 'Comparative historical analysis',
                summary: summary,
              ),
            ),
            SizedBox(
              width: _panelWidth(context, 360),
              child: _departmentPanel(
                title: 'Department Breakdown',
                subtitle: 'Headcount distribution',
                entries: _filteredHeadcount(summary),
                useCurrency: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _taxSummaryPanel(summary),
        const SizedBox(height: 18),
        _securityBanner(
          title: 'Bank-Grade Encryption Active',
          subtitle:
              'All financial data is secured with AES-256 encryption for this reporting cycle.',
        ),
      ],
    );
  }

  Widget _buildFinanceView(BuildContext context, ReportsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'Finance Reporting Desk',
          subtitle:
              'Monitor payroll totals, tax obligations, and deduction health from a finance-first reporting view.',
        ),
        const SizedBox(height: 18),
        _buildMetricWrap(context, [
          _MetricSpec(
            title: 'Gross Pay',
            value: CurrencyFormatter.formatNaira(summary.totalGross),
            subtitle: 'Total payroll base for the month',
            icon: Icons.savings_outlined,
            chip: _trendChip(summary.grossGrowthPercentage),
          ),
          _MetricSpec(
            title: 'Net Pay',
            value: CurrencyFormatter.formatNaira(summary.totalNet),
            subtitle: 'Amount after deductions',
            icon: Icons.wallet_outlined,
            chip: _trendChip(summary.netGrowthPercentage),
          ),
          _MetricSpec(
            title: 'PAYE + Pension',
            value: CurrencyFormatter.formatNaira(
              summary.totalTax + summary.totalPension,
            ),
            subtitle: 'Core statutory obligations',
            icon: Icons.receipt_long_outlined,
            chip: _trendChip(
              summary.totalGross == 0
                  ? 0
                  : -(((summary.totalTax + summary.totalPension) /
                            summary.totalGross) *
                        100),
              negativeTone: true,
            ),
          ),
          _MetricSpec(
            title: 'Total Deductions',
            value: CurrencyFormatter.formatNaira(summary.totalDeductions),
            subtitle: 'Recorded deductions in payroll',
            icon: Icons.rule_folder_outlined,
            chip: _trendChip(
              summary.totalGross == 0
                  ? 0
                  : -((summary.totalDeductions / summary.totalGross) * 100),
              negativeTone: true,
            ),
          ),
        ]),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _panelWidth(context, 720),
              child: _taxSummaryPanel(summary),
            ),
            SizedBox(
              width: _panelWidth(context, 400),
              child: _departmentPanel(
                title: 'Department Net Pay',
                subtitle: 'Distribution by payroll value',
                entries: _filteredDepartmentTotals(summary),
                useCurrency: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _trendPanel(
          title: 'Payroll Value Trend',
          subtitle: 'Gross versus net performance over six months',
          summary: summary,
        ),
        const SizedBox(height: 18),
        _securityBanner(
          title: 'Financial Audit Trail Active',
          subtitle:
              'Journal exports and payroll calculations are ready for accounting review and downstream posting.',
        ),
      ],
    );
  }

  Widget _buildHrView(BuildContext context, ReportsSummary summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'People Analytics',
          subtitle:
              'Track workforce headcount, payroll coverage, and department distribution with a people-first view.',
        ),
        const SizedBox(height: 18),
        _buildMetricWrap(context, [
          _MetricSpec(
            title: 'Total Employees',
            value: '${summary.employeeCount}',
            subtitle: '${summary.hiresThisMonth} joined this month',
            icon: Icons.groups_outlined,
          ),
          _MetricSpec(
            title: 'Payroll Coverage',
            value: '${summary.payrollEmployeeCount}',
            subtitle: 'Employees included in this payroll cycle',
            icon: Icons.fact_check_outlined,
          ),
          _MetricSpec(
            title: 'Average Net Pay',
            value: CurrencyFormatter.formatNaira(summary.averageNetPay),
            subtitle: 'Average take-home for processed payrolls',
            icon: Icons.bar_chart_outlined,
          ),
          _MetricSpec(
            title: 'Department Count',
            value: '${summary.departmentHeadcount.length}',
            subtitle: 'Active reporting departments',
            icon: Icons.apartment_outlined,
          ),
        ]),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _panelWidth(context, 760),
              child: _trendPanel(
                title: 'Payroll Trend',
                subtitle: 'Trend line for employee payroll outcomes',
                summary: summary,
              ),
            ),
            SizedBox(
              width: _panelWidth(context, 360),
              child: _departmentPanel(
                title: 'Department Breakdown',
                subtitle: 'Headcount distribution',
                entries: _filteredHeadcount(summary),
                useCurrency: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _peopleCoveragePanel(summary),
      ],
    );
  }

  Widget _buildEmployeeView(BuildContext context, ReportsSummary summary) {
    final latestPayroll = summary.latestPersonalPayroll;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(
          title: 'My Payroll Reports',
          subtitle:
              'Review your recent payroll history, deductions, and take-home trend for the selected period.',
        ),
        const SizedBox(height: 18),
        _buildMetricWrap(context, [
          _MetricSpec(
            title: 'Latest Net Pay',
            value: CurrencyFormatter.formatNaira(
              latestPayroll?.netSalaryBase ?? 0.0,
            ),
            subtitle: latestPayroll == null
                ? 'No payroll record yet'
                : '${_getMonthName(latestPayroll.month)} ${latestPayroll.year}',
            icon: Icons.payments_outlined,
          ),
          _MetricSpec(
            title: 'YTD Gross',
            value: CurrencyFormatter.formatNaira(summary.ytdGross),
            subtitle: 'Total gross earnings in your visible history',
            icon: Icons.account_balance_wallet_outlined,
          ),
          _MetricSpec(
            title: 'YTD Deductions',
            value: CurrencyFormatter.formatNaira(summary.ytdDeductions),
            subtitle: 'PAYE, pension, NHF, and other deductions',
            icon: Icons.receipt_long_outlined,
          ),
          _MetricSpec(
            title: 'Payroll Records',
            value: '${summary.personalPayrolls.length}',
            subtitle: 'Personal payrolls in the system',
            icon: Icons.history_outlined,
          ),
        ]),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            SizedBox(
              width: _panelWidth(context, 760),
              child: _personalTrendPanel(summary),
            ),
            SizedBox(
              width: _panelWidth(context, 360),
              child: _personalBreakdownPanel(summary),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _personalHistoryPanel(summary),
      ],
    );
  }

  Widget _buildHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricWrap(BuildContext context, List<_MetricSpec> metrics) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: metrics
          .map(
            (metric) => Container(
              width: _panelWidth(context, 260),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(metric.icon, color: AppColors.primary),
                      ),
                      const Spacer(),
                      if (metric.chip != null) metric.chip!,
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    metric.title.toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    metric.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _trendPanel({
    required String title,
    required String subtitle,
    required ReportsSummary summary,
  }) {
    return _panel(
      title: title,
      subtitle: subtitle,
      trailing: summary.hasAnomaly
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Anomaly Detected',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: _TrendBarsChart(
              trends: summary.payrollTrends,
              highlightAnomaly: summary.hasAnomaly,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: summary.payrollTrends
                .map(
                  (trend) => Expanded(
                    child: Text(
                      trend.period.split(' ').first.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _departmentPanel({
    required String title,
    required String subtitle,
    required Map<String, num> entries,
    required bool useCurrency,
  }) {
    final sorted = entries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _panel(
      title: title,
      subtitle: subtitle,
      child: sorted.isEmpty
          ? const ModernEmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No department data',
              subtitle:
                  'Department values will appear when payroll data exists.',
            )
          : Column(
              children: sorted.map((entry) {
                final maxValue = sorted.first.value == 0
                    ? 1.0
                    : sorted.first.value.toDouble();
                final ratio = entry.value.toDouble() / maxValue;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            useCurrency
                                ? CurrencyFormatter.formatNaira(
                                    entry.value.toDouble(),
                                  )
                                : '${entry.value}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: ratio,
                          minHeight: 10,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _barColorFor(entry.key),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _taxSummaryPanel(ReportsSummary summary) {
    final rows = _filteredTaxRows(summary);
    return _panel(
      title: 'Tax Summary Details',
      subtitle:
          'Statutory deductions recorded for ${_getMonthName(_selectedMonth)} $_selectedYear payroll cycle',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Verified Compliance',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
        ),
      ),
      child: Column(
        children: [
          ...rows.map((row) => _taxRow(row)),
          const Divider(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Monthly Deductions',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ),
              Text(
                CurrencyFormatter.formatNaira(summary.totalDeductions),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _taxRow(_TaxRowData row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: row.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(row.icon, color: row.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              row.label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          Expanded(child: Text(row.basis)),
          Expanded(
            child: Text(
              CurrencyFormatter.formatNaira(row.amount),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: row.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              row.status,
              style: TextStyle(
                color: row.statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _peopleCoveragePanel(ReportsSummary summary) {
    final rows = _filteredDepartmentTotals(summary).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _panel(
      title: 'Department Payroll Coverage',
      subtitle: 'Net payroll value mapped against department headcount',
      child: rows.isEmpty
          ? const ModernEmptyState(
              icon: Icons.groups_outlined,
              title: 'No payroll coverage data',
              subtitle:
                  'Department payroll values will show here when records exist.',
            )
          : Column(
              children: rows.map((entry) {
                final headcount = summary.departmentHeadcount[entry.key] ?? 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '$headcount staff',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        CurrencyFormatter.formatNaira(entry.value.toDouble()),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _personalTrendPanel(ReportsSummary summary) {
    final values = _filteredPersonalPayrolls(
      summary,
    ).take(6).toList().reversed.toList();
    return _panel(
      title: 'Personal Payroll Trend',
      subtitle: 'Your latest payroll history',
      child: values.isEmpty
          ? const ModernEmptyState(
              icon: Icons.show_chart_outlined,
              title: 'No payroll trend yet',
              subtitle: 'Your processed payrolls will appear here.',
            )
          : Column(
              children: [
                SizedBox(
                  height: 220,
                  child: _PersonalTrendChart(payrolls: values),
                ),
                const SizedBox(height: 12),
                Row(
                  children: values
                      .map(
                        (payroll) => Expanded(
                          child: Text(
                            _getMonthName(payroll.month).toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
    );
  }

  Widget _personalBreakdownPanel(ReportsSummary summary) {
    final latest = summary.latestPersonalPayroll;
    return _panel(
      title: 'Current Breakdown',
      subtitle: 'Your latest available payroll breakdown',
      child: latest == null
          ? const ModernEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No payroll breakdown',
              subtitle: 'Your latest payroll values will appear here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _breakdownLine('Gross Salary', latest.grossSalaryBase),
                _breakdownLine('PAYE Tax', latest.payeBase),
                _breakdownLine('Pension', latest.pensionBase),
                _breakdownLine('NHF', latest.nhfBase),
                _breakdownLine('Other Deductions', latest.otherDeductionsBase),
                const Divider(height: 24),
                _breakdownLine(
                  'Net Salary',
                  latest.netSalaryBase,
                  emphasize: true,
                ),
              ],
            ),
    );
  }

  Widget _personalHistoryPanel(ReportsSummary summary) {
    final rows = _filteredPersonalPayrolls(summary);
    return _panel(
      title: 'Payroll History',
      subtitle: 'Recent payroll records in your account',
      child: rows.isEmpty
          ? const ModernEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payroll history',
              subtitle: 'Processed payroll records will appear here.',
            )
          : Column(
              children: rows.take(6).map((payroll) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_getMonthName(payroll.month)} ${payroll.year}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatNaira(payroll.netSalaryBase),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _breakdownLine(String label, double amount, {bool emphasize = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            CurrencyFormatter.formatNaira(amount),
            style: TextStyle(
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              fontSize: emphasize ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _securityBanner({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D4569), Color(0xFF425E84)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trendChip(double percentage, {bool negativeTone = false}) {
    final positive = percentage >= 0;
    final color = negativeTone
        ? (positive ? AppColors.error : AppColors.success)
        : (positive ? AppColors.success : AppColors.error);
    final text = '${positive ? '+' : ''}${percentage.toStringAsFixed(1)}%';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Map<String, num> _filteredDepartmentTotals(ReportsSummary summary) {
    final query = _searchController.text.trim().toLowerCase();
    final source = summary.departmentTotals.map<String, num>(
      (key, value) => MapEntry(key, value),
    );
    if (query.isEmpty) return source;
    return Map.fromEntries(
      source.entries.where((entry) => entry.key.toLowerCase().contains(query)),
    );
  }

  Map<String, num> _filteredHeadcount(ReportsSummary summary) {
    final query = _searchController.text.trim().toLowerCase();
    final source = summary.departmentHeadcount.map<String, num>(
      (key, value) => MapEntry(key, value),
    );
    if (query.isEmpty) return source;
    return Map.fromEntries(
      source.entries.where((entry) => entry.key.toLowerCase().contains(query)),
    );
  }

  List<_TaxRowData> _filteredTaxRows(ReportsSummary summary) {
    final rows = [
      _TaxRowData(
        label: 'PAYE Tax',
        basis: 'Progressive Rate',
        amount: summary.totalTax,
        status: summary.totalTax > 0 ? 'Recorded' : 'No Data',
        statusColor: summary.totalTax > 0
            ? AppColors.success
            : AppColors.warning,
        icon: Icons.account_balance_outlined,
        color: AppColors.error,
      ),
      _TaxRowData(
        label: 'Pension Fund',
        basis: 'Statutory (8.0%)',
        amount: summary.totalPension,
        status: summary.totalPension > 0 ? 'Recorded' : 'No Data',
        statusColor: summary.totalPension > 0
            ? AppColors.success
            : AppColors.warning,
        icon: Icons.savings_outlined,
        color: AppColors.info,
      ),
      _TaxRowData(
        label: 'NHF Contribution',
        basis: 'Statutory (2.5%)',
        amount: summary.totalNhf,
        status: summary.totalNhf > 0 ? 'Recorded' : 'Pending',
        statusColor: summary.totalNhf > 0
            ? AppColors.success
            : AppColors.warning,
        icon: Icons.home_work_outlined,
        color: AppColors.warning,
      ),
    ];

    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows
        .where(
          (row) =>
              row.label.toLowerCase().contains(query) ||
              row.basis.toLowerCase().contains(query),
        )
        .toList();
  }

  List<Payroll> _filteredPersonalPayrolls(ReportsSummary summary) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return summary.personalPayrolls;
    return summary.personalPayrolls.where((payroll) {
      final label = '${_getMonthName(payroll.month)} ${payroll.year}'
          .toLowerCase();
      return label.contains(query);
    }).toList();
  }

  Color _barColorFor(String key) {
    const colors = [
      AppColors.primary,
      AppColors.success,
      AppColors.warning,
      AppColors.info,
      AppColors.error,
      AppColors.accent,
    ];
    return colors[key.hashCode.abs() % colors.length];
  }

  double _panelWidth(BuildContext context, double maxWidth) {
    final available = MediaQuery.of(context).size.width - 56;
    return available < maxWidth ? available : maxWidth;
  }

  String _getMonthName(int month) {
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
    return months[month - 1];
  }

  Future<void> _exportCsv() async {
    try {
      final csv = await _payrollService.exportPayrollReportCsv(
        _selectedMonth,
        _selectedYear,
      );
      await downloadCsvFile(
        fileName:
            'payroll_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv',
        csv: csv,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payroll CSV for ${_getMonthName(_selectedMonth)} $_selectedYear downloaded.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _previewJournalEntries() async {
    try {
      final entries = await _accountingService.generateJournalEntries(
        _selectedMonth,
        _selectedYear,
      );
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Journal Entries - ${_getMonthName(_selectedMonth)} $_selectedYear',
          ),
          content: SizedBox(
            width: 640,
            child: entries.isEmpty
                ? const Text('No accounting entries for this period.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(
                              entry.account,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.accountName ?? 'GL Account'),
                                Text(
                                  entry.description,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            child: Text(
                              entry.debit > 0
                                  ? CurrencyFormatter.formatNaira(entry.debit)
                                  : '-',
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 110,
                            child: Text(
                              entry.credit > 0
                                  ? CurrencyFormatter.formatNaira(entry.credit)
                                  : '-',
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Journal generation failed: $e')));
    }
  }

  Future<void> _exportQuickBooksIif() async {
    try {
      final entries = await _accountingService.generateJournalEntries(
        _selectedMonth,
        _selectedYear,
      );
      final iif = _accountingService.exportToQuickBooksIIF(entries);
      await downloadCsvFile(
        fileName:
            'qb_payroll_journal_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.iif',
        csv: iif,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QuickBooks IIF downloaded.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('IIF export failed: $e')));
    }
  }

  Future<void> _exportXeroCsv() async {
    try {
      final entries = await _accountingService.generateJournalEntries(
        _selectedMonth,
        _selectedYear,
      );
      final csv = _accountingService.exportToXeroCsv(entries);
      await downloadCsvFile(
        fileName:
            'xero_payroll_journal_${_selectedYear}_${_selectedMonth.toString().padLeft(2, '0')}.csv',
        csv: csv,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Xero CSV downloaded.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Xero export failed: $e')));
    }
  }
}

class _MetricSpec {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Widget? chip;

  const _MetricSpec({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    this.chip,
  });
}

class _TaxRowData {
  final String label;
  final String basis;
  final double amount;
  final String status;
  final Color statusColor;
  final IconData icon;
  final Color color;

  const _TaxRowData({
    required this.label,
    required this.basis,
    required this.amount,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.color,
  });
}

class _TrendBarsChart extends StatelessWidget {
  final List<MonthlyPayrollTrend> trends;
  final bool highlightAnomaly;

  const _TrendBarsChart({required this.trends, required this.highlightAnomaly});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TrendBarsPainter(trends, highlightAnomaly: highlightAnomaly),
      child: const SizedBox.expand(),
    );
  }
}

class _TrendBarsPainter extends CustomPainter {
  final List<MonthlyPayrollTrend> trends;
  final bool highlightAnomaly;

  _TrendBarsPainter(this.trends, {required this.highlightAnomaly});

  @override
  void paint(Canvas canvas, Size size) {
    if (trends.isEmpty) return;

    final maxGross = trends
        .map((trend) => trend.totalGross)
        .fold<double>(0.0, (max, value) => value > max ? value : max);
    final barWidth = size.width / (trends.length * 1.4);
    final gap = barWidth * 0.4;

    for (var i = 0; i < trends.length; i++) {
      final trend = trends[i];
      final left = i * (barWidth + gap) + gap / 2;
      final heightRatio = maxGross == 0 ? 0.0 : trend.totalGross / maxGross;
      final barHeight = size.height * 0.75 * heightRatio;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, size.height - barHeight - 12, barWidth, barHeight),
        const Radius.circular(10),
      );

      final isLast = i == trends.length - 1;
      final isAnomalyBar = highlightAnomaly && i == trends.length - 2;
      final color = isLast
          ? AppColors.primary
          : isAnomalyBar
          ? AppColors.error.withValues(alpha: 0.35)
          : AppColors.border;

      canvas.drawRRect(rect, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendBarsPainter oldDelegate) {
    return oldDelegate.trends != trends ||
        oldDelegate.highlightAnomaly != highlightAnomaly;
  }
}

class _PersonalTrendChart extends StatelessWidget {
  final List<Payroll> payrolls;

  const _PersonalTrendChart({required this.payrolls});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PersonalTrendPainter(payrolls),
      child: const SizedBox.expand(),
    );
  }
}

class _PersonalTrendPainter extends CustomPainter {
  final List<Payroll> payrolls;

  _PersonalTrendPainter(this.payrolls);

  @override
  void paint(Canvas canvas, Size size) {
    if (payrolls.isEmpty) return;
    final values = payrolls.map((payroll) => payroll.netSalaryBase).toList();
    final maxValue = values.fold<double>(
      0.0,
      (max, value) => value > max ? value : max,
    );
    final minValue = values.fold<double>(
      values.first,
      (min, value) => value < min ? value : min,
    );
    final range = maxValue == minValue ? 1.0 : maxValue - minValue;

    final path = Path();
    final fillPath = Path();
    final linePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.18),
          AppColors.primary.withValues(alpha: 0.02),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * i / (values.length - 1);
      final y =
          size.height -
          (((values[i] - minValue) / range) * (size.height * 0.72)) -
          20;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _PersonalTrendPainter oldDelegate) {
    return oldDelegate.payrolls != payrolls;
  }
}
