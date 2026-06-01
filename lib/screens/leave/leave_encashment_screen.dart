import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/leave_encashment_model.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/services/leave_encashment_service.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class LeaveEncashmentScreen extends ConsumerStatefulWidget {
  const LeaveEncashmentScreen({super.key});

  @override
  ConsumerState<LeaveEncashmentScreen> createState() =>
      _LeaveEncashmentScreenState();
}

class _LeaveEncashmentScreenState extends ConsumerState<LeaveEncashmentScreen>
    with SingleTickerProviderStateMixin {
  final _encashmentService = LeaveEncashmentService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _approveEncashment(LeaveEncashment encashment) async {
    final user = ref.read(currentUserProvider).asData?.value;
    if (user == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Encashment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${encashment.employeeName}'),
            Text('Leave Type: ${encashment.leaveTypeName}'),
            Text('Days: ${encashment.daysToEncash}'),
            Text(
              'Amount: N${NumberFormat('#,###.00').format(encashment.encashmentAmount)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
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
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;
    NotificationHelper.showLoading(context, message: 'Approving...');
    try {
      await _encashmentService.approveEncashment(
        encashment.id,
        user.id,
        user.name,
      );
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Encashment approved successfully!',
      );
      ref.invalidate(leaveEncashmentProvider);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Error: $e');
    }
  }

  Future<void> _rejectEncashment(LeaveEncashment encashment) async {
    final user = ref.read(currentUserProvider).asData?.value;
    if (user == null || !mounted) return;

    final remarks = await showDialog<String>(
      context: context,
      builder: (context) {
        String reason = '';
        return AlertDialog(
          title: const Text('Reject Encashment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Reject encashment request from ${encashment.employeeName}?',
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Reason for rejection',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                onChanged: (value) => reason = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, reason),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (!mounted || remarks == null) return;
    NotificationHelper.showLoading(context, message: 'Rejecting...');
    try {
      await _encashmentService.rejectEncashment(
        encashment.id,
        user.id,
        user.name,
        remarks,
      );
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Encashment rejected');
      ref.invalidate(leaveEncashmentProvider);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final encashmentAsync = ref.watch(leaveEncashmentProvider);

    return encashmentAsync.when(
      loading: () => const AppScaffold(
        topBar: null,
        body: ModernLoadingState(message: 'Loading leave encashments...'),
      ),
      error: (error, _) => AppScaffold(
        topBar: AppBar(title: const Text('Leave Encashment')),
        body: ModernErrorState(
          message: 'Unable to load encashment data',
          subtitle: '$error',
          onRetry: () => ref.invalidate(leaveEncashmentProvider),
        ),
      ),
      data: (data) {
        if (!data.canManage) {
          return AppScaffold(
            topBar: AppBar(title: const Text('Leave Encashment')),
            body: const ModernErrorState(
              message: 'Access denied',
              subtitle: 'Only HR can process encashments.',
            ),
          );
        }

        return AppScaffold(
          topBar: AppBar(
            title: const Text('Leave Encashment'),
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  text: 'Pending (${data.pendingRequests.length})',
                  icon: const Icon(Icons.pending_actions),
                ),
                Tab(
                  text: 'Processed (${data.processedRequests.length})',
                  icon: const Icon(Icons.check_circle),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(leaveEncashmentProvider),
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildPendingTab(data.pendingRequests),
              _buildProcessedTab(data.processedRequests),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPendingTab(List<LeaveEncashment> pendingRequests) {
    if (pendingRequests.isEmpty) {
      return const ModernEmptyState(
        icon: Icons.check_circle_outline,
        title: 'No pending encashment requests',
        subtitle: 'All encashment requests have been reviewed.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaveEncashmentProvider);
        await ref.read(leaveEncashmentProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSummaryCards(pendingRequests),
          const SizedBox(height: 16),
          ...pendingRequests.map(
            (request) => _buildEncashmentCard(request, isPending: true),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessedTab(List<LeaveEncashment> processedRequests) {
    if (processedRequests.isEmpty) {
      return const ModernEmptyState(
        icon: Icons.history,
        title: 'No processed encashments',
        subtitle: 'Processed requests will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(leaveEncashmentProvider);
        await ref.read(leaveEncashmentProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSummaryCards(processedRequests),
          const SizedBox(height: 16),
          ...processedRequests.map(
            (request) => _buildEncashmentCard(request, isPending: false),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<LeaveEncashment> requests) {
    final totalAmount = requests.fold<double>(
      0,
      (sum, item) => sum + item.encashmentAmount,
    );
    final totalDays = requests.fold<double>(
      0,
      (sum, item) => sum + item.daysToEncash,
    );

    return ModernMetricsGrid(
      metrics: [
        ModernMetricCard(
          title: 'Requests',
          value: requests.length.toString(),
          icon: Icons.description_outlined,
          color: AppColors.primary,
        ),
        ModernMetricCard(
          title: 'Days to Encash',
          value: totalDays.toStringAsFixed(1),
          icon: Icons.event_available_outlined,
          color: AppColors.info,
        ),
        ModernMetricCard(
          title: 'Total Amount',
          value: 'NGN ${NumberFormat('#,###.00').format(totalAmount)}',
          icon: Icons.payments_outlined,
          color: AppColors.success,
        ),
      ],
    );
  }

  Widget _buildEncashmentCard(
    LeaveEncashment encashment, {
    required bool isPending,
  }) {
    final statusColor = encashment.status == EncashmentStatus.approved
        ? AppColors.success
        : encashment.status == EncashmentStatus.rejected
        ? AppColors.error
        : encashment.status == EncashmentStatus.processed
        ? AppColors.info
        : AppColors.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        encashment.employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${encashment.leaveTypeName} - Year ${encashment.year}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    encashment.status.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    'Available Days',
                    encashment.availableDays.toString(),
                    Icons.event_available,
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    'Days to Encash',
                    encashment.daysToEncash.toString(),
                    Icons.swap_horiz,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Encashment Amount',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'N${NumberFormat('#,###.00').format(encashment.encashmentAmount)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Requested: ${DateFormat('MMM dd, yyyy').format(encashment.requestedAt)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (encashment.remarks != null) ...[
              const SizedBox(height: 8),
              Text(
                'Remarks: ${encashment.remarks}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectEncashment(encashment),
                      icon: const Icon(Icons.close),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveEncashment(encashment),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
