import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/leave_request_model.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class MyLeavesScreen extends ConsumerStatefulWidget {
  const MyLeavesScreen({super.key});

  @override
  ConsumerState<MyLeavesScreen> createState() => _MyLeavesScreenState();
}

class _MyLeavesScreenState extends ConsumerState<MyLeavesScreen> {
  String _filterStatus = 'All';

  List<LeaveRequest> _filteredRequests(List<LeaveRequest> all) {
    if (_filterStatus == 'All') return all;
    return all
        .where((r) => r.status.name == _filterStatus.toLowerCase())
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final myLeavesAsync = ref.watch(myLeavesProvider);

    return AppScaffold(
      topBar: AppBar(
        title: const Text('My Leaves'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myLeavesProvider),
          ),
        ],
      ),
      body: myLeavesAsync.when(
        loading: () => const ModernLoadingState(message: 'Loading leave data...'),
        error: (error, _) => ModernErrorState(
          message: 'Failed to load leave requests',
          subtitle: '$error',
          onRetry: () => ref.invalidate(myLeavesProvider),
        ),
        data: (data) {
          if (data.employeeId == null) {
            return const ModernErrorState(
              message: 'Employee profile not linked',
              subtitle: 'This account is not connected to an employee record.',
            );
          }

          final allRequests = data.requests;
          final requests = _filteredRequests(allRequests);
          final pendingCount = allRequests
              .where((request) => request.status == LeaveRequestStatus.pending)
              .length;
          final approvedCount = allRequests
              .where((request) => request.status == LeaveRequestStatus.approved)
              .length;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(myLeavesProvider);
              await ref.read(myLeavesProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                ModernMetricsGrid(
                  metrics: [
                    ModernMetricCard(
                      title: 'Total Requests',
                      value: allRequests.length.toString(),
                      icon: Icons.request_page_outlined,
                      color: AppColors.primary,
                    ),
                    ModernMetricCard(
                      title: 'Pending',
                      value: pendingCount.toString(),
                      icon: Icons.schedule_outlined,
                      color: AppColors.warning,
                    ),
                    ModernMetricCard(
                      title: 'Approved',
                      value: approvedCount.toString(),
                      icon: Icons.verified_outlined,
                      color: AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 8),
                if (requests.isEmpty)
                  const SizedBox(
                    height: 220,
                    child: ModernEmptyState(
                      icon: Icons.event_busy_outlined,
                      title: 'No leave requests found',
                      subtitle: 'Submit a leave request to see it here.',
                    ),
                  )
                else
                  ...requests.map(_buildRequestCard),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/leave/apply'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ['All', 'Pending', 'Approved', 'Rejected'].map((status) {
            final isSelected = _filterStatus == status;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(status),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() => _filterStatus = status);
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRequestCard(LeaveRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request.leaveTypeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                _buildStatusChip(request.status),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              'Period',
              '${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}',
            ),
            _buildInfoRow(
              'Duration',
              '${request.numberOfDays} day${request.numberOfDays > 1 ? 's' : ''}',
            ),
            _buildInfoRow('Reason', request.reason),
            if (request.remarks != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remarks',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(request.remarks!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(LeaveRequestStatus status) {
    Color color;
    String label;

    switch (status) {
      case LeaveRequestStatus.pending:
        color = AppColors.warning;
        label = 'PENDING';
        break;
      case LeaveRequestStatus.approved:
        color = AppColors.success;
        label = 'APPROVED';
        break;
      case LeaveRequestStatus.rejected:
        color = AppColors.error;
        label = 'REJECTED';
        break;
      case LeaveRequestStatus.cancelled:
        color = AppColors.textSecondary;
        label = 'CANCELLED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
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
