import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/employee_deduction_model.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/deduction_provider.dart';
import 'package:roipayroll/providers/user_service_provider.dart';
import 'package:roipayroll/screens/deductions/assign_deduction_screen.dart';
import 'package:roipayroll/services/employee_deduction_service.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class EmployeeDeductionsScreen extends ConsumerStatefulWidget {
  const EmployeeDeductionsScreen({super.key});

  @override
  ConsumerState<EmployeeDeductionsScreen> createState() =>
      _EmployeeDeductionsScreenState();
}

class _EmployeeDeductionsScreenState
    extends ConsumerState<EmployeeDeductionsScreen> {
  late final EmployeeDeductionService _service;
  final TextEditingController _searchController = TextEditingController();

  String _search = '';
  DeductionCategory? _categoryFilter;
  DeductionStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    final userService = ref.read(userServiceProvider);
    _service = EmployeeDeductionService(userService: userService);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EmployeeDeduction> _filtered(List<EmployeeDeduction> all) {
    final query = _search.trim().toLowerCase();

    return all.where((d) {
      final matchesSearch =
          query.isEmpty ||
          d.employeeName.toLowerCase().contains(query) ||
          d.deductionTypeName.toLowerCase().contains(query) ||
          (d.referenceNumber?.toLowerCase().contains(query) ?? false) ||
          (d.description?.toLowerCase().contains(query) ?? false);

      if (!matchesSearch) return false;
      if (_categoryFilter != null && d.category != _categoryFilter) {
        return false;
      }
      if (_statusFilter != null && d.status != _statusFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  double _progress(EmployeeDeduction d) {
    if (d.totalAmount <= 0) return 0;
    return (d.totalDeducted / d.totalAmount).clamp(0, 1).toDouble();
  }

  Future<void> _act(EmployeeDeduction d, String action) async {
    final currentUser = ref.read(currentUserProvider).asData?.value;
    final approverId = currentUser?.id ?? 'system';

    if (action == 'cancel') {
      final confirmed = await _confirmAction(
        title: 'Cancel deduction?',
        message:
            'This deduction will be marked as cancelled and removed from active payroll recovery.',
        actionLabel: 'Cancel Deduction',
        color: AppColors.error,
      );
      if (!confirmed) return;
    }

    if (action == 'suspend') {
      final confirmed = await _confirmAction(
        title: 'Suspend deduction?',
        message: 'This pauses recovery until the deduction is resumed.',
        actionLabel: 'Suspend',
        color: AppColors.warningDark,
      );
      if (!confirmed) return;
    }

    if (action == 'approve') await _service.approveDeduction(d.id, approverId);
    if (action == 'suspend') await _service.suspendDeduction(d.id);
    if (action == 'resume') await _service.resumeDeduction(d.id);
    if (action == 'cancel') await _service.cancelDeduction(d.id);

    if (!mounted) return;
    ref.invalidate(employeeDeductionsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${d.deductionTypeName} updated successfully.')),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String actionLabel,
    required Color color,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: color),
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _openAssignScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssignDeductionScreen()),
    );
    ref.invalidate(employeeDeductionsProvider);
  }

  Future<void> _exportCsv(List<EmployeeDeduction> deductions) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'Employee,Deduction Type,Category,Frequency,Status,Total Amount,Deducted,Balance',
    );

    for (final deduction in deductions) {
      buffer.writeln(
        [
          _csvField(deduction.employeeName),
          _csvField(deduction.deductionTypeName),
          _csvField(_categoryLabel(deduction.category)),
          _csvField(_frequencyLabel(deduction.frequency)),
          _csvField(_statusLabel(deduction.status)),
          _csvField(deduction.totalAmount.toStringAsFixed(2)),
          _csvField(deduction.totalDeducted.toStringAsFixed(2)),
          _csvField(deduction.balance.toStringAsFixed(2)),
        ].join(','),
      );
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deductions CSV copied to clipboard.')),
    );
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  @override
  Widget build(BuildContext context) {
    final employeeDeductionsAsync = ref.watch(employeeDeductionsProvider);

    return employeeDeductionsAsync.when(
      loading: () => const AppScaffold(
        title: 'Deductions Management',
        body: ModernLoadingState(message: 'Loading employee deductions...'),
      ),
      error: (error, _) => AppScaffold(
        title: 'Deductions Management',
        body: ModernErrorState(
          message: 'Failed to load employee deductions',
          subtitle: error.toString(),
          onRetry: () => ref.invalidate(employeeDeductionsProvider),
        ),
      ),
      data: (data) {
        if (!data.canManage) {
          return AppScaffold(
            title: 'Deductions Management',
            body: _buildAccessRestricted(data.roleLabel),
          );
        }

        final filtered = _filtered(data.deductions);
        final active = filtered
            .where((d) => d.status == DeductionStatus.active)
            .length;
        final pending = filtered
            .where((d) => d.status == DeductionStatus.pending)
            .length;
        final totalBalance = filtered.fold<double>(
          0,
          (sum, d) => sum + d.balance,
        );

        return AppScaffold(
          title: 'Deductions Management',
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openAssignScreen,
            backgroundColor: AppColors.primaryDark,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('Assign New Deduction'),
          ),
          body: RefreshIndicator(
            onRefresh: () async => ref.invalidate(employeeDeductionsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildSummaryGrid(
                  visibleCount: filtered.length,
                  activeCount: active,
                  pendingCount: pending,
                  totalBalance: totalBalance,
                ),
                const SizedBox(height: 22),
                _buildSectionHeader(filtered),
                const SizedBox(height: 14),
                _buildDeductionList(filtered),
                const SizedBox(height: 96),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccessRestricted(String roleLabel) {
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
                  'Only roles with deduction management access can open this screen. Current role: $roleLabel.',
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final searchField = Container(
          height: 58,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search employee or loan...',
              prefixIcon: const Icon(Icons.search_rounded),
              border: InputBorder.none,
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Deductions Management',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Review deduction balances, approve pending recoveries, and manage employee repayment status.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              SizedBox(width: 380, child: searchField),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deductions Management',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Review deduction balances, approve pending recoveries, and manage employee repayment status.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            searchField,
          ],
        );
      },
    );
  }

  Widget _buildSummaryGrid({
    required int visibleCount,
    required int activeCount,
    required int pendingCount,
    required double totalBalance,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _buildSummaryCard(
            title: 'VISIBLE RECORDS',
            value: visibleCount.toString(),
          ),
          _buildSummaryCard(
            title: 'ACTIVE',
            value: activeCount.toString(),
            pillLabel: activeCount > 0 ? 'Healthy' : 'Idle',
            pillColor: activeCount > 0
                ? AppColors.success
                : AppColors.textSecondary,
          ),
          _buildSummaryCard(title: 'PENDING', value: pendingCount.toString()),
          _buildOutstandingCard(totalBalance),
        ];

        if (constraints.maxWidth >= 1180) {
          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 16),
              Expanded(child: cards[1]),
              const SizedBox(width: 16),
              Expanded(child: cards[2]),
              const SizedBox(width: 16),
              Expanded(child: cards[3]),
            ],
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map(
                (card) => SizedBox(
                  width: constraints.maxWidth >= 760
                      ? (constraints.maxWidth - 16) / 2
                      : constraints.maxWidth,
                  child: card,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    String? pillLabel,
    Color? pillColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                ),
              ),
              if (pillLabel != null && pillColor != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pillLabel,
                    style: TextStyle(
                      color: pillColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutstandingCard(double totalBalance) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'OUTSTANDING TOTAL',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            CurrencyFormatter.formatNaira(totalBalance),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Across all visible employee deductions',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(List<EmployeeDeduction> filtered) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final actions = Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildFilterButton(),
            OutlinedButton.icon(
              onPressed: filtered.isEmpty ? null : () => _exportCsv(filtered),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Export CSV'),
            ),
          ],
        );

        if (isWide) {
          return Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Deductions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              actions,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Deductions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            actions,
          ],
        );
      },
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value.startsWith('status:')) {
          final raw = value.replaceFirst('status:', '');
          setState(() {
            _statusFilter = raw == 'all'
                ? null
                : DeductionStatus.values.firstWhere((s) => s.name == raw);
          });
        } else if (value.startsWith('category:')) {
          final raw = value.replaceFirst('category:', '');
          setState(() {
            _categoryFilter = raw == 'all'
                ? null
                : DeductionCategory.values.firstWhere((c) => c.name == raw);
          });
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          enabled: false,
          value: 'header-status',
          child: Text('Status'),
        ),
        const PopupMenuItem<String>(
          value: 'status:all',
          child: Text('All Statuses'),
        ),
        ...DeductionStatus.values.map(
          (status) => PopupMenuItem<String>(
            value: 'status:${status.name}',
            child: Text(_statusLabel(status)),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          enabled: false,
          value: 'header-category',
          child: Text('Category'),
        ),
        const PopupMenuItem<String>(
          value: 'category:all',
          child: Text('All Categories'),
        ),
        ...DeductionCategory.values.map(
          (category) => PopupMenuItem<String>(
            value: 'category:${category.name}',
            child: Text(_categoryLabel(category)),
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tune_rounded, size: 18),
            const SizedBox(width: 8),
            Text(
              _statusFilter != null
                  ? _statusLabel(_statusFilter!)
                  : _categoryFilter != null
                  ? _categoryLabel(_categoryFilter!)
                  : 'Filters',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeductionList(List<EmployeeDeduction> filtered) {
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: const ModernEmptyState(
          icon: Icons.search_off_outlined,
          title: 'No deductions found',
          subtitle: 'Try adjusting the search term or filters.',
        ),
      );
    }

    return Column(
      children: filtered
          .map(
            (deduction) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildDeductionCard(deduction),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDeductionCard(EmployeeDeduction deduction) {
    final progress = _progress(deduction);
    final isInactive =
        deduction.status == DeductionStatus.cancelled ||
        deduction.status == DeductionStatus.completed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1020;

          final identity = Row(
            children: [
              _buildAvatar(deduction.employeeName, isInactive: isInactive),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${deduction.employeeName} - ${deduction.deductionTypeName}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isInactive
                            ? AppColors.textSecondary
                            : AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildMetaPill(
                          icon: Icons.category_outlined,
                          label: _categoryLabel(deduction.category),
                        ),
                        _buildMetaPill(
                          icon: Icons.sync_rounded,
                          label: _frequencyLabel(deduction.frequency),
                        ),
                        if (deduction.referenceNumber?.trim().isNotEmpty ??
                            false)
                          _buildMetaPill(
                            icon: Icons.tag_rounded,
                            label: deduction.referenceNumber!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final progressBlock = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROGRESS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: progress,
                        backgroundColor: AppColors.surfaceVariant,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isInactive
                              ? AppColors.borderDark
                              : AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${CurrencyFormatter.formatNaira(deduction.totalDeducted)} / ${CurrencyFormatter.formatNaira(deduction.totalAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ],
          );

          final balanceBlock = Column(
            crossAxisAlignment: isWide
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              const Text(
                'BALANCE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyFormatter.formatNaira(deduction.balance),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: isInactive
                      ? AppColors.textSecondary
                      : AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 10),
              _buildStatusBadge(deduction.status),
            ],
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (deduction.status == DeductionStatus.pending)
                _buildActionButton(
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  tooltip: 'Approve deduction',
                  onTap: () => _act(deduction, 'approve'),
                ),
              if (deduction.status == DeductionStatus.active)
                _buildActionButton(
                  icon: Icons.pause_rounded,
                  color: AppColors.warningDark,
                  tooltip: 'Suspend deduction',
                  onTap: () => _act(deduction, 'suspend'),
                ),
              if (deduction.status == DeductionStatus.suspended)
                _buildActionButton(
                  icon: Icons.play_arrow_rounded,
                  color: AppColors.info,
                  tooltip: 'Resume deduction',
                  onTap: () => _act(deduction, 'resume'),
                ),
              if (deduction.status != DeductionStatus.completed &&
                  deduction.status != DeductionStatus.cancelled)
                _buildActionButton(
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  tooltip: 'Cancel deduction',
                  onTap: () => _act(deduction, 'cancel'),
                ),
            ],
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 4, child: identity),
                const SizedBox(width: 20),
                Expanded(flex: 5, child: progressBlock),
                const SizedBox(width: 20),
                Expanded(flex: 2, child: balanceBlock),
                const SizedBox(width: 18),
                actions,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: 18),
              progressBlock,
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: balanceBlock),
                  const SizedBox(width: 16),
                  actions,
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String name, {required bool isInactive}) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();

    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: isInactive
            ? AppColors.surfaceVariant
            : AppColors.infoLight.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w800,
          color: isInactive ? AppColors.textSecondary : AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _buildMetaPill({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(DeductionStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Color _statusColor(DeductionStatus status) {
    switch (status) {
      case DeductionStatus.pending:
        return AppColors.warningDark;
      case DeductionStatus.active:
        return AppColors.success;
      case DeductionStatus.completed:
        return AppColors.info;
      case DeductionStatus.cancelled:
        return AppColors.error;
      case DeductionStatus.suspended:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(DeductionStatus status) {
    switch (status) {
      case DeductionStatus.pending:
        return 'Pending';
      case DeductionStatus.active:
        return 'Active';
      case DeductionStatus.completed:
        return 'Completed';
      case DeductionStatus.cancelled:
        return 'Cancelled';
      case DeductionStatus.suspended:
        return 'Suspended';
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
      case DeductionCategory.union:
        return 'Union';
      case DeductionCategory.insurance:
        return 'Insurance';
      case DeductionCategory.other:
        return 'Other';
    }
  }
}
