import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/leave_type_model.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/services/leave_type_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class LeaveTypesScreen extends ConsumerStatefulWidget {
  const LeaveTypesScreen({super.key});

  @override
  ConsumerState<LeaveTypesScreen> createState() => _LeaveTypesScreenState();
}

class _LeaveTypesScreenState extends ConsumerState<LeaveTypesScreen> {
  final _leaveTypeService = LeaveTypeService();

  Future<void> _initializeDefaults() async {
    NotificationHelper.showLoading(context, message: 'Initializing...');
    try {
      await _leaveTypeService.initializeDefaultLeaveTypes();
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Default leave types initialized successfully!',
      );
      ref.invalidate(leaveTypesProvider);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Error: $e');
    }
  }

  Future<void> _toggleActiveStatus(LeaveType leaveType) async {
    try {
      await _leaveTypeService.updateLeaveTypeFields(leaveType.id, {
        'isActive': !leaveType.isActive,
      });
      if (!mounted) return;
      NotificationHelper.showSuccess(
        context,
        '${leaveType.name} ${!leaveType.isActive ? "activated" : "deactivated"}',
      );
      ref.invalidate(leaveTypesProvider);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.showError(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final leaveTypesAsync = ref.watch(leaveTypesProvider);

    return leaveTypesAsync.when(
      loading: () => const AppScaffold(
        topBar: null,
        body: ModernLoadingState(message: 'Loading leave types...'),
      ),
      error: (error, _) => AppScaffold(
        topBar: AppBar(title: const Text('Leave Types')),
        body: ModernErrorState(
          message: 'Failed to load leave types',
          subtitle: '$error',
        ),
      ),
      data: (data) {
        if (!data.canManage) {
          return AppScaffold(
            topBar: AppBar(title: const Text('Leave Types')),
            body: const ModernErrorState(
              message: 'Access denied',
              subtitle: 'Only admins can manage leave types.',
            ),
          );
        }

        final leaveTypes = data.leaveTypes;
        return AppScaffold(
          topBar: AppBar(
            title: const Text('Leave Type Configuration'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(leaveTypesProvider),
                tooltip: 'Refresh',
              ),
              if (leaveTypes.isEmpty)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _initializeDefaults,
                  tooltip: 'Initialize Defaults',
                ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(leaveTypesProvider);
              await ref.read(leaveTypesProvider.future);
            },
            child: ResponsiveLayout(
              mobile: _buildContent(leaveTypes, 12),
              tablet: _buildContent(leaveTypes, 16),
              desktop: _buildContent(leaveTypes, 16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(List<LeaveType> leaveTypes, double padding) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(padding),
      children: [
        _buildMetrics(leaveTypes),
        const SizedBox(height: 16),
        if (leaveTypes.isEmpty) ...[
          _buildEmptyState(),
          const SizedBox(height: 12),
          _buildInitializeDefaultsButton(),
        ] else
          ...leaveTypes.map(_buildLeaveTypeCard),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const SizedBox(
      height: 300,
      child: ModernEmptyState(
        icon: Icons.category_outlined,
        title: 'No leave types configured',
        subtitle: 'Initialize default leave types to start configuration.',
      ),
    );
  }

  Widget _buildMetrics(List<LeaveType> leaveTypes) {
    final activeCount = leaveTypes.where((item) => item.isActive).length;
    final paidCount = leaveTypes.where((item) => item.isPaid).length;
    final encashableCount = leaveTypes.where((item) => item.encashable).length;

    return ModernMetricsGrid(
      metrics: [
        ModernMetricCard(
          title: 'Total Types',
          value: leaveTypes.length.toString(),
          icon: Icons.category_outlined,
          color: AppColors.primary,
        ),
        ModernMetricCard(
          title: 'Active Types',
          value: activeCount.toString(),
          icon: Icons.check_circle_outline,
          color: AppColors.success,
        ),
        ModernMetricCard(
          title: 'Paid Types',
          value: paidCount.toString(),
          icon: Icons.payments_outlined,
          color: AppColors.info,
        ),
        ModernMetricCard(
          title: 'Encashable',
          value: encashableCount.toString(),
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.warning,
        ),
      ],
    );
  }

  Widget _buildInitializeDefaultsButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ElevatedButton.icon(
        onPressed: _initializeDefaults,
        icon: const Icon(Icons.add),
        label: const Text('Initialize Default Leave Types'),
      ),
    );
  }

  Widget _buildLeaveTypeCard(LeaveType leaveType) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: leaveType.isActive
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(leaveType.category),
            color: leaveType.isActive ? AppColors.primary : Colors.grey,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                leaveType.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: leaveType.isActive ? Colors.black : Colors.grey,
                ),
              ),
            ),
            Switch(
              value: leaveType.isActive,
              onChanged: (value) => _toggleActiveStatus(leaveType),
              activeThumbColor: AppColors.success,
            ),
          ],
        ),
        subtitle: Text(
          '${leaveType.daysPerYear} days/year - ${leaveType.isPaid ? "Paid" : "Unpaid"}',
          style: TextStyle(
            color: leaveType.isActive ? AppColors.textSecondary : Colors.grey,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Description', leaveType.description),
                const Divider(height: 24),
                const Text(
                  'Allocation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Days per year',
                  '${leaveType.daysPerYear} days',
                ),
                _buildDetailRow(
                  'Carry forward',
                  leaveType.carryForward
                      ? 'Yes (max ${leaveType.maxCarryForward} days)'
                      : 'No',
                ),
                _buildDetailRow(
                  'Max accumulation',
                  '${leaveType.maxAccumulation} days',
                ),
                const Divider(height: 24),
                const Text(
                  'Rules',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Requires approval',
                  leaveType.requiresApproval ? 'Yes' : 'No',
                ),
                _buildDetailRow(
                  'Requires documents',
                  leaveType.requiresDocuments ? 'Yes' : 'No',
                ),
                _buildDetailRow(
                  'Minimum notice',
                  '${leaveType.minNoticeDays} days',
                ),
                _buildDetailRow(
                  'Max consecutive days',
                  '${leaveType.maxConsecutiveDays} days',
                ),
                _buildDetailRow(
                  'Days per request',
                  '${leaveType.minDaysPerRequest} - ${leaveType.maxDaysPerRequest} days',
                ),
                const Divider(height: 24),
                const Text(
                  'Payment',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Paid',
                  leaveType.isPaid ? 'Yes (${leaveType.payPercentage}%)' : 'No',
                ),
                _buildDetailRow(
                  'Encashable',
                  leaveType.encashable
                      ? 'Yes (${leaveType.encashmentPercentage}%)'
                      : 'No',
                ),
                const Divider(height: 24),
                const Text(
                  'Eligibility',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Applicable to',
                  leaveType.applicableToAll
                      ? 'All employees'
                      : 'Specific groups',
                ),
                if (leaveType.applicableGenders != null)
                  _buildDetailRow(
                    'Gender',
                    leaveType.applicableGenders!.join(', '),
                  ),
                if (leaveType.minServiceMonths != null)
                  _buildDetailRow(
                    'Min service',
                    '${leaveType.minServiceMonths} months',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(LeaveCategory category) {
    return switch (category) {
      LeaveCategory.annual => Icons.beach_access,
      LeaveCategory.sick => Icons.medical_services,
      LeaveCategory.casual => Icons.event,
      LeaveCategory.maternity => Icons.pregnant_woman,
      LeaveCategory.paternity => Icons.family_restroom,
      LeaveCategory.bereavement => Icons.church,
      LeaveCategory.study => Icons.school,
      LeaveCategory.unpaid => Icons.money_off,
      LeaveCategory.compensatory => Icons.swap_horiz,
    };
  }
}
