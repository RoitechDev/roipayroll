import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/leave_request_model.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class LeaveApprovalsScreen extends ConsumerWidget {
  const LeaveApprovalsScreen({super.key});

  Future<void> _approveRequest(
    BuildContext context,
    WidgetRef ref,
    LeaveRequest request,
  ) async {
    NotificationHelper.showLoading(context, message: 'Approving...');
    try {
      await ref.read(leaveApprovalActionsProvider).approve(request);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Request approved successfully');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Approval failed: $e');
    }
  }

  Future<void> _rejectRequest(
    BuildContext context,
    WidgetRef ref,
    LeaveRequest request,
  ) async {
    final remarksController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Leave Request'),
        content: TextField(
          controller: remarksController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Please provide a reason...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != true) return;
    if (!context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Rejecting...');
    try {
      await ref
          .read(leaveApprovalActionsProvider)
          .reject(
            request,
            remarksController.text.trim().isEmpty
                ? 'No reason provided'
                : remarksController.text.trim(),
          );
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Request rejected');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Rejection failed: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingRequestsAsync = ref.watch(pendingLeaveRequestsProvider);

    return AppScaffold(
      topBar: AppBar(title: const Text('Leave Approvals')),
      body: pendingRequestsAsync.when(
        loading: () =>
            const ModernLoadingState(message: 'Loading leave approvals...'),
        error: (error, _) => ModernErrorState(
          message: 'Could not load leave requests',
          subtitle: '$error',
          onRetry: () => ref.invalidate(pendingLeaveRequestsProvider),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return const ModernEmptyState(
              icon: Icons.check_circle_outline,
              title: 'No pending leave requests',
              subtitle: 'All requests have been processed.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pendingLeaveRequestsProvider);
              await ref.read(pendingLeaveRequestsProvider.future);
            },
            child: ResponsiveLayout(
              mobile: _buildContent(context, ref, requests, true, 12),
              tablet: _buildContent(context, ref, requests, false, 16),
              desktop: _buildContent(context, ref, requests, false, 16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<LeaveRequest> requests,
    bool isCompact,
    double padding,
  ) {
    return ListView(
      padding: EdgeInsets.all(padding),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ModernMetricsGrid(
          metrics: [
            ModernMetricCard(
              title: 'Pending Approvals',
              value: requests.length.toString(),
              icon: Icons.pending_actions_outlined,
              color: AppColors.warning,
            ),
            ModernMetricCard(
              title: 'Unique Employees',
              value: requests
                  .map((item) => item.employeeId)
                  .toSet()
                  .length
                  .toString(),
              icon: Icons.people_outline,
              color: AppColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...requests.map(
          (item) => _buildRequestCard(context, ref, item, isCompact),
        ),
      ],
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    WidgetRef ref,
    LeaveRequest request,
    bool isCompact,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    request.employeeName.isNotEmpty
                        ? request.employeeName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        request.leaveTypeName,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.date_range_outlined,
              'Period',
              '${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}',
            ),
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.hourglass_top_outlined,
              'Duration',
              '${request.numberOfDays.toStringAsFixed(1)} day${request.numberOfDays == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 6),
            _buildInfoRow(Icons.notes_outlined, 'Reason', request.reason),
            const SizedBox(height: 6),
            _buildInfoRow(
              Icons.access_time_outlined,
              'Requested',
              _formatDate(request.requestedAt),
            ),
            const SizedBox(height: 16),
            isCompact
                ? Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _rejectRequest(context, ref, request),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _approveRequest(context, ref, request),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _rejectRequest(context, ref, request),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Reject'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _approveRequest(context, ref, request),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
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
}
