import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/incentive_entry_model.dart';
import 'package:roipayroll/providers/incentive_provider.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class CommissionBonusScreen extends ConsumerWidget {
  const CommissionBonusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(incentiveDataProvider);

    return AppScaffold(
      topBar: AppBar(
        title: const Text('Commission & Bonus'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(incentiveDataProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSubmitDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add Entry'),
      ),
      body: dataAsync.when(
        loading: () =>
            const ModernLoadingState(message: 'Loading incentives...'),
        error: (e, _) => ModernErrorState(
          message: 'Failed to load incentives',
          subtitle: e.toString(),
          onRetry: () => ref.invalidate(incentiveDataProvider),
        ),
        data: (data) {
          return ResponsiveLayout(
            mobile: _buildPageContent(context, ref, data, padding: 12),
            tablet: _buildPageContent(context, ref, data, padding: 16),
            desktop: _buildPageContent(context, ref, data, padding: 16),
          );
        },
      ),
    );
  }

  Widget _buildPageContent(
    BuildContext context,
    WidgetRef ref,
    IncentiveData data, {
    required double padding,
  }) {
    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        _buildSummaryMetrics(data.myEntries),
        const SizedBox(height: 16),
        const Text(
          'My Incentive Entries',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (data.myEntries.isEmpty)
          const SizedBox(
            height: 180,
            child: ModernEmptyState(
              icon: Icons.workspace_premium_outlined,
              title: 'No entries yet',
            ),
          )
        else
          ...data.myEntries.map(_buildEntryCard),
        if (data.canApprove) ...[
          const SizedBox(height: 20),
          const Text(
            'Pending Approvals',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (data.pendingEntries.isEmpty)
            const SizedBox(
              height: 120,
              child: ModernEmptyState(
                icon: Icons.pending_actions_outlined,
                title: 'No pending approvals',
              ),
            )
          else
            ...data.pendingEntries.map(
              (entry) => _buildApprovalCard(context, ref, entry),
            ),
        ],
      ],
    );
  }

  Widget _buildSummaryMetrics(List<IncentiveEntry> entries) {
    final pending = entries
        .where((e) => e.status == IncentiveStatus.pending)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final approved = entries
        .where((e) => e.status == IncentiveStatus.approved)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final paid = entries
        .where((e) => e.status == IncentiveStatus.paid)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final commissions = entries
        .where((e) => e.type == IncentiveType.commission)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final bonuses = entries
        .where((e) => e.type == IncentiveType.bonus)
        .fold<double>(0, (sum, e) => sum + e.amount);

    return ModernMetricsGrid(
      metrics: [
        ModernMetricCard(
          title: 'Commissions',
          value: CurrencyFormatter.formatNaira(commissions),
          icon: Icons.trending_up,
          color: AppColors.primary,
        ),
        ModernMetricCard(
          title: 'Bonuses',
          value: CurrencyFormatter.formatNaira(bonuses),
          icon: Icons.workspace_premium_outlined,
          color: AppColors.info,
        ),
        ModernMetricCard(
          title: 'Pending',
          value: CurrencyFormatter.formatNaira(pending),
          icon: Icons.pending_actions_outlined,
          color: AppColors.warning,
        ),
        ModernMetricCard(
          title: 'Approved',
          value: CurrencyFormatter.formatNaira(approved),
          icon: Icons.check_circle_outline,
          color: AppColors.approved,
        ),
        ModernMetricCard(
          title: 'Paid',
          value: CurrencyFormatter.formatNaira(paid),
          icon: Icons.paid_outlined,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildEntryCard(IncentiveEntry entry) {
    return Card(
      child: ListTile(
        leading: Icon(
          entry.type == IncentiveType.commission
              ? Icons.trending_up
              : Icons.workspace_premium,
        ),
        title: Text(
          '${entry.type.name.toUpperCase()} - ${CurrencyFormatter.formatNaira(entry.amount)}',
        ),
        subtitle: Text(
          '${DateFormat('dd MMM yyyy').format(entry.incentiveDate)} | ${entry.description}',
        ),
        trailing: _statusChip(entry.status),
      ),
    );
  }

  Widget _buildApprovalCard(
    BuildContext context,
    WidgetRef ref,
    IncentiveEntry entry,
  ) {
    final hasTier =
        (entry.tierName ?? '').isNotEmpty ||
        entry.salesAmount != null ||
        entry.commissionRatePercent != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.employeeName} - ${entry.type.name.toUpperCase()}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${CurrencyFormatter.formatNaira(entry.amount)} - ${DateFormat('dd MMM yyyy').format(entry.incentiveDate)}',
            ),
            const SizedBox(height: 4),
            Text(entry.description),
            if (hasTier)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tier: ${entry.tierName ?? '-'} | Sales: ${entry.salesAmount?.toStringAsFixed(2) ?? '-'} | Rate: ${entry.commissionRatePercent?.toStringAsFixed(2) ?? '-'}%',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            if ((entry.performancePeriod ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Period: ${entry.performancePeriod}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _reject(context, ref, entry),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approve(context, ref, entry),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(IncentiveStatus status) {
    Color color;
    switch (status) {
      case IncentiveStatus.pending:
        color = AppColors.warning;
        break;
      case IncentiveStatus.approved:
        color = AppColors.approved;
        break;
      case IncentiveStatus.rejected:
        color = AppColors.error;
        break;
      case IncentiveStatus.paid:
        color = AppColors.success;
        break;
    }

    return StatusBadge(status: status.name.toUpperCase(), color: color);
  }

  Future<void> _showSubmitDialog(BuildContext context, WidgetRef ref) async {
    final data = ref.read(incentiveDataProvider).value;
    final user = data?.user;
    final employeeId = user?.employeeId;
    if (user == null || employeeId == null || employeeId.trim().isEmpty) {
      NotificationHelper.showError(
        context,
        'Employee profile not found. Contact HR.',
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    final salesAmountController = TextEditingController();
    final rateController = TextEditingController();
    final tierController = TextEditingController();
    final periodController = TextEditingController();
    var type = IncentiveType.commission;
    var incentiveDate = DateTime.now();

    final submit = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final isCommission = type == IncentiveType.commission;
            return AlertDialog(
              title: const Text('Add Commission / Bonus'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<IncentiveType>(
                          initialValue: type,
                          decoration: const InputDecoration(labelText: 'Type'),
                          items: IncentiveType.values
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.name.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(
                            () => type = v ?? IncentiveType.commission,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount (NGN)',
                          ),
                          validator: (v) {
                            final amount = double.tryParse((v ?? '').trim());
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            hintText:
                                'Commission payout, performance bonus, etc.',
                          ),
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Description is required'
                              : null,
                        ),
                        if (isCommission) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: salesAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Sales Amount (optional)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: rateController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Commission Rate % (optional)',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: tierController,
                            decoration: const InputDecoration(
                              labelText: 'Tier Name (optional)',
                              hintText: 'Tier A, Gold, Platinum...',
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: periodController,
                          decoration: const InputDecoration(
                            labelText: 'Performance Period (optional)',
                            hintText: 'Q1 2026, Jan 2026...',
                          ),
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Incentive Date'),
                          subtitle: Text(
                            DateFormat('dd MMM yyyy').format(incentiveDate),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: incentiveDate,
                                firstDate: DateTime(
                                  DateTime.now().year - 2,
                                  1,
                                  1,
                                ),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() => incentiveDate = picked);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState?.validate() != true) return;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );

    if (submit != true) return;
    if (!context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Submitting entry...');
    try {
      await ref
          .read(incentiveActionsProvider)
          .submit(
            employeeId: employeeId,
            employeeName: user.name,
            type: type,
            amount: double.parse(amountController.text.trim()),
            description: descriptionController.text.trim(),
            incentiveDate: incentiveDate,
            salesAmount: double.tryParse(salesAmountController.text.trim()),
            commissionRatePercent: double.tryParse(rateController.text.trim()),
            tierName: tierController.text.trim(),
            performancePeriod: periodController.text.trim(),
          );
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Entry submitted for approval');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Submission failed: $e');
    }
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    IncentiveEntry entry,
  ) async {
    NotificationHelper.showLoading(context, message: 'Approving...');
    try {
      await ref.read(incentiveActionsProvider).approve(entry);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Entry approved');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Approval failed: $e');
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    IncentiveEntry entry,
  ) async {
    final reasonController = TextEditingController();
    final reject = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Entry'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            border: OutlineInputBorder(),
          ),
          minLines: 2,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reject != true) return;
    if (!context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Rejecting...');
    try {
      await ref
          .read(incentiveActionsProvider)
          .reject(
            entry,
            reasonController.text.trim().isEmpty
                ? 'No reason provided'
                : reasonController.text.trim(),
          );
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Entry rejected');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Rejection failed: $e');
    }
  }
}
