import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/models/probation_record_model.dart';
import 'package:roipayroll/models/contract_record_model.dart';
import 'package:roipayroll/services/probation_service.dart';
import 'package:roipayroll/services/contract_service.dart';
import 'package:intl/intl.dart';

class ProbationDashboardScreen extends StatefulWidget {
  const ProbationDashboardScreen({super.key});

  @override
  State<ProbationDashboardScreen> createState() =>
      _ProbationDashboardScreenState();
}

class _ProbationDashboardScreenState extends State<ProbationDashboardScreen> {
  final _probationService = ProbationService();
  final _contractService = ContractService();

  List<ProbationRecord> _expiringProbations = [];
  List<ContractRecord> _expiringContracts = [];
  bool _isLoading = true;

  int get _probationCount => _expiringProbations.length;
  int get _contractCount => _expiringContracts.length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final probations = await _probationService.getExpiringProbations(30);
      final contracts = await _contractService.getExpiringContracts(30);

      setState(() {
        _expiringProbations = probations;
        _expiringContracts = contracts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        NotificationHelper.showError(context, 'Failed to load data: $e');
      }
    }
  }

  Future<void> _sendReminders() async {
    NotificationHelper.showLoading(context, message: 'Sending reminders...');

    try {
      await _probationService.sendExpiryAlerts();
      await _contractService.sendExpiryAlerts();

      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showSuccess(context, 'Reminders sent successfully!');
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.hideLoading(context);
        NotificationHelper.showError(context, 'Failed to send reminders: $e');
      }
    }
  }

  void _navigateToCreateContract() {
    Navigator.pushNamed(context, AppRoutes.contractCreate);
  }

  void _navigateToReviewProbation([String? probationId]) {
    Navigator.pushNamed(
      context,
      AppRoutes.probationReview,
      arguments: probationId,
    );
  }

  void _navigateToRenewContract(String contractId) {
    Navigator.pushNamed(
      context,
      AppRoutes.contractRenew,
      arguments: contractId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Probation & Contracts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildQuickActions(),
                  const SizedBox(height: 24),
                  _buildMetricsCards(),
                  const SizedBox(height: 24),
                  _buildExpiringProbations(),
                  const SizedBox(height: 24),
                  _buildExpiringContracts(),
                ],
              ),
            ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Create Contract',
                Icons.add_business,
                AppColors.primary,
                _navigateToCreateContract,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Review Probation',
                Icons.rate_review,
                AppColors.success,
                () => _navigateToReviewProbation(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                'Import Employees',
                Icons.upload_file,
                AppColors.info,
                () => Navigator.pushNamed(
                  context,
                  AppRoutes.employeeImport,
                  arguments: {'returnRoute': AppRoutes.probation},
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Probations Expiring',
            _probationCount.toString(),
            Icons.hourglass_bottom,
            AppColors.warning,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Contracts Expiring',
            _contractCount.toString(),
            Icons.event_busy,
            AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringProbations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Expiring Probations (Next 30 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_expiringProbations.isNotEmpty)
              TextButton.icon(
                onPressed: _sendReminders,
                icon: const Icon(Icons.notifications_active, size: 18),
                label: const Text('Send Reminders'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_expiringProbations.isEmpty)
          _buildEmptyState(
            'No probations expiring soon',
            Icons.assignment_turned_in,
          )
        else
          ..._expiringProbations.map(
            (probation) => _buildProbationCard(probation),
          ),
      ],
    );
  }

  Widget _buildExpiringContracts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Expiring Contracts (Next 30 Days)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (_expiringContracts.isEmpty)
          _buildEmptyState('No contracts expiring soon', Icons.assignment_late)
        else
          ..._expiringContracts.map((contract) => _buildContractCard(contract)),
      ],
    );
  }

  Widget _buildProbationCard(ProbationRecord probation) {
    final daysLeft = probation.daysRemaining;
    final isUrgent = daysLeft <= 7;
    final color = isUrgent ? AppColors.error : AppColors.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _navigateToReviewProbation(probation.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.person_outline, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      probation.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.email,
                          size: 14,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          probation.employeeEmail ?? 'No email',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'End Date: ${_formatDate(probation.endDate)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Duration: ${probation.durationMonths} months',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.person, size: 20),
                tooltip: 'View Employee Details',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.employeeDetails,
                    arguments: probation.employeeId,
                  );
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  daysLeft <= 0 ? 'DUE' : '$daysLeft days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContractCard(ContractRecord contract) {
    final daysLeft = contract.daysRemaining;
    final isUrgent = daysLeft != null && daysLeft <= 7;
    final color = isUrgent ? AppColors.error : AppColors.warning;
    final statusLabel = daysLeft == null
        ? 'N/A'
        : (daysLeft <= 0 ? 'EXPIRED' : '$daysLeft days');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        onTap: () => _navigateToRenewContract(contract.id),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_outlined, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contract.employeeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Type: ${_contractTypeLabel(contract.contractType)}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'End Date: ${contract.endDate == null ? 'N/A' : _formatDate(contract.endDate!)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
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
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }

  String _contractTypeLabel(ContractType type) {
    switch (type) {
      case ContractType.permanent:
        return 'Permanent';
      case ContractType.fixedTerm:
        return 'Fixed Term';
      case ContractType.freelance:
        return 'Freelance';
      case ContractType.consultant:
        return 'Consultant';
      case ContractType.intern:
        return 'Intern';
      case ContractType.partTime:
        return 'Part-Time';
      // ignore: unreachable_switch_default
      default:
        return type.name;
    }
  }
}
