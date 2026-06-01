import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/providers/probation_provider.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class ProbationContractManagementScreen extends ConsumerWidget {
  const ProbationContractManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(probationDashboardProvider);

    return AppScaffold(
      topBar: AppBar(
        title: const Text('Probation & Contract'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(probationDashboardProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () => const ModernLoadingState(
          message: 'Loading probation and contract data...',
        ),
        error: (e, _) => ModernErrorState(
          message: 'Failed to load probation dashboard',
          subtitle: e.toString(),
          onRetry: () => ref.invalidate(probationDashboardProvider),
        ),
        data: (data) {
          if (!data.canManage) {
            return const ModernEmptyState(
              icon: Icons.lock_outline,
              title: 'Access Restricted',
              subtitle: 'Only HR/Admin can manage this module.',
            );
          }

          final probationCount = data.dueProbationEmployees.length;
          final contractCount = data.expiringContractEmployees.length;
          final total = probationCount + contractCount;

          return ResponsiveLayout(
            mobile: _buildContent(context, ref, data, total, padding: 12),
            tablet: _buildContent(context, ref, data, total, padding: 16),
            desktop: _buildContent(context, ref, data, total, padding: 16),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    ProbationDashboardData data,
    int total, {
    required double padding,
  }) {
    final probationCount = data.dueProbationEmployees.length;
    final contractCount = data.expiringContractEmployees.length;

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        ModernMetricsGrid(
          metrics: [
            ModernMetricCard(
              title: 'Probation Due',
              value: probationCount.toString(),
              icon: Icons.hourglass_top_outlined,
              color: AppColors.warning,
            ),
            ModernMetricCard(
              title: 'Contracts Expiring',
              value: contractCount.toString(),
              icon: Icons.event_busy_outlined,
              color: AppColors.error,
            ),
            ModernMetricCard(
              title: 'Total Action Needed',
              value: total.toString(),
              icon: Icons.pending_actions_outlined,
              color: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: () => _runReminders(context, ref),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Send Reminders'),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Probation Due Within 30 Days',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (data.dueProbationEmployees.isEmpty)
          const SizedBox(
            height: 160,
            child: ModernEmptyState(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No employees with probation due soon',
            ),
          )
        else
          ...data.dueProbationEmployees.map(
            (employee) => _buildEmployeeCard(
              employee,
              targetDate: employee.probationEndDate,
              mode: 'Probation',
              highlightColor: AppColors.warning,
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          'Contracts Expiring Within 30 Days',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (data.expiringContractEmployees.isEmpty)
          const SizedBox(
            height: 160,
            child: ModernEmptyState(
              icon: Icons.assignment_late_outlined,
              title: 'No contracts expiring soon',
            ),
          )
        else
          ...data.expiringContractEmployees.map(
            (employee) => _buildEmployeeCard(
              employee,
              targetDate: employee.contractEndDate,
              mode: 'Contract',
              highlightColor: AppColors.error,
            ),
          ),
      ],
    );
  }

  Widget _buildEmployeeCard(
    Employee employee, {
    required DateTime? targetDate,
    required String mode,
    required Color highlightColor,
  }) {
    final safeDate = targetDate ?? DateTime.now();
    final dueDateLabel = DateFormat('dd MMM yyyy').format(safeDate);
    final daysLeft = _daysUntil(safeDate);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.badge_outlined),
        title: Text(employee.fullName),
        subtitle: Text(
          '$mode End: $dueDateLabel\nDepartment: ${employee.department} | Position: ${employee.position}',
        ),
        isThreeLine: true,
        trailing: StatusBadge(
          status: daysLeft <= 0 ? 'DUE' : '${daysLeft}d',
          color: highlightColor,
        ),
      ),
    );
  }

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(start).inDays;
  }

  Future<void> _runReminders(BuildContext context, WidgetRef ref) async {
    NotificationHelper.showLoading(context, message: 'Sending reminders...');
    try {
      final result = await ref
          .read(probationActionsProvider)
          .sendLifecycleReminders(withinDays: 30);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Reminders sent for ${result['total'] ?? 0} employee(s) '
        '(Probation: ${result['probationDue'] ?? 0}, Contracts: ${result['contractDue'] ?? 0}).',
      );
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Reminder run failed: $e');
    }
  }
}
