import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/exit_clearance_model.dart';
import 'package:roipayroll/models/exit_management_model.dart';
import 'package:roipayroll/providers/exit_management_provider.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';

class ExitManagementScreen extends ConsumerWidget {
  const ExitManagementScreen({super.key});

  static const List<ExitType> _employeeExitTypes = [
    ExitType.resignation,
    ExitType.mutualAgreement,
    ExitType.retirement,
    ExitType.endOfInternship,
    ExitType.contractExpiry,
  ];

  static const List<ExitType> _hrExitTypes = [
    ExitType.termination,
    ExitType.contractExpiry,
    ExitType.retirement,
    ExitType.endOfInternship,
    ExitType.mutualAgreement,
    ExitType.absconding,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(exitManagementDataProvider);

    return AppScaffold(
      topBar: AppBar(
        title: Text(_titleFor(dataAsync.asData?.value)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(exitManagementActionsProvider).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: dataAsync.when(
        loading: () =>
            const ModernLoadingState(message: 'Loading exit desk...'),
        error: (error, _) => ModernErrorState(
          message: 'Failed to load exit desk',
          subtitle: error.toString(),
          onRetry: () => ref.read(exitManagementActionsProvider).refresh(),
        ),
        data: (data) => ResponsiveLayout(
          mobile: _buildPage(context, ref, data, padding: 12, compact: true),
          tablet: _buildPage(context, ref, data, padding: 16, compact: false),
          desktop: _buildPage(context, ref, data, padding: 20, compact: false),
        ),
      ),
    );
  }

  String _titleFor(ExitManagementData? data) {
    return switch (data?.scope) {
      ExitRoleScope.reviewer => 'Exit Command Deck',
      ExitRoleScope.finance => 'Settlement Ledger',
      ExitRoleScope.employee => 'Departure Studio',
      null => 'Exit Management',
    };
  }

  Widget _buildPage(
    BuildContext context,
    WidgetRef ref,
    ExitManagementData data, {
    required double padding,
    required bool compact,
  }) {
    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        _buildHero(context, ref, data, compact: compact),
        const SizedBox(height: 18),
        _buildSignalStrip(data, compact: compact),
        const SizedBox(height: 18),
        switch (data.scope) {
          ExitRoleScope.employee => _buildEmployeeView(context, ref, data),
          ExitRoleScope.reviewer => _buildReviewerView(context, ref, data),
          ExitRoleScope.finance => _buildFinanceView(data),
        },
      ],
    );
  }

  Widget _buildHero(
    BuildContext context,
    WidgetRef ref,
    ExitManagementData data, {
    required bool compact,
  }) {
    final colors = switch (data.scope) {
      ExitRoleScope.employee => [
        const Color(0xFF143642),
        const Color(0xFF1F6E6D),
      ],
      ExitRoleScope.reviewer => [
        const Color(0xFF2E294E),
        const Color(0xFF541388),
      ],
      ExitRoleScope.finance => [
        const Color(0xFF263238),
        const Color(0xFF44624A),
      ],
    };

    final title = switch (data.scope) {
      ExitRoleScope.employee => 'Plan Your Exit Journey',
      ExitRoleScope.reviewer => 'Orchestrate Offboarding Flow',
      ExitRoleScope.finance => 'Track Final Settlement Readiness',
    };

    final subtitle = switch (data.scope) {
      ExitRoleScope.employee =>
        'Submit a personal exit request, review notice timing, and follow each stage through approval and settlement.',
      ExitRoleScope.reviewer =>
        'Review pending cases, initiate employer-led exits, and only close records once the full clearance checklist is done.',
      ExitRoleScope.finance =>
        'Monitor approved exits, inspect net settlement breakdowns, and follow completed offboarding records in one ledger.',
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
      ),
      padding: EdgeInsets.all(compact ? 18 : 24),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -10,
            child: _heroOrb(110, Colors.white.withValues(alpha: 0.08)),
          ),
          Positioned(
            bottom: -40,
            left: -10,
            child: _heroOrb(140, Colors.white.withValues(alpha: 0.06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _titleFor(data).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 26 : 32,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: compact ? 13 : 15,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _heroFact(
                    'Pending',
                    data.pendingRequests.length.toString(),
                    Icons.pending_actions_outlined,
                  ),
                  _heroFact(
                    'Approved',
                    data.approvedRequests.length.toString(),
                    Icons.verified_outlined,
                  ),
                  _heroFact(
                    'Completed',
                    data.completedRequests.length.toString(),
                    Icons.task_alt_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (data.canRequest)
                    FilledButton.icon(
                      onPressed: data.hasEmployeeProfile
                          ? () => _showRequestSheet(context, ref)
                          : null,
                      icon: const Icon(Icons.logout_outlined),
                      label: const Text('Submit Exit Request'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  if (data.canInitiateTermination)
                    OutlinedButton.icon(
                      onPressed: () => _showTerminationSheet(context, ref),
                      icon: const Icon(Icons.person_off_outlined),
                      label: const Text('Initiate Employer Exit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  if (data.scope == ExitRoleScope.finance)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Read-only settlement visibility',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroOrb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _heroFact(String label, String value, IconData icon) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalStrip(ExitManagementData data, {required bool compact}) {
    final signals = switch (data.scope) {
      ExitRoleScope.employee => [
        _SignalData(
          title: 'My requests',
          value: data.myRequests.length.toString(),
          subtitle: 'All personal submissions',
          color: AppColors.primary,
        ),
        _SignalData(
          title: 'Notice gaps',
          value: data.myRequests
              .where((request) => request.isShortNotice)
              .length
              .toString(),
          subtitle: 'Requests with short notice',
          color: AppColors.warning,
        ),
        _SignalData(
          title: 'Settlement preview',
          value: CurrencyFormatter.formatNaira(
            data.myRequests.fold<double>(
              0,
              (sum, request) =>
                  sum + (request.finalSettlement?.netSettlement ?? 0),
            ),
          ),
          subtitle: 'Combined estimated net',
          color: AppColors.success,
        ),
      ],
      ExitRoleScope.reviewer => [
        _SignalData(
          title: 'Review queue',
          value: data.pendingRequests.length.toString(),
          subtitle: 'Requires HR/Admin decision',
          color: AppColors.warning,
        ),
        _SignalData(
          title: 'Clearance blockers',
          value: data.approvedRequests
              .where((request) => !data.isFullyCleared(request.id))
              .length
              .toString(),
          subtitle: 'Approved but not fully cleared',
          color: AppColors.error,
        ),
        _SignalData(
          title: 'Exit exposure',
          value: CurrencyFormatter.formatNaira(
            data.visibleRequests.fold<double>(
              0,
              (sum, request) =>
                  sum + (request.finalSettlement?.netSettlement ?? 0),
            ),
          ),
          subtitle: 'Estimated total settlements',
          color: AppColors.info,
        ),
      ],
      ExitRoleScope.finance => [
        _SignalData(
          title: 'Ready for settlement',
          value: data.approvedRequests.length.toString(),
          subtitle: 'Approved exits in motion',
          color: AppColors.info,
        ),
        _SignalData(
          title: 'Archived',
          value: data.completedRequests.length.toString(),
          subtitle: 'Completed offboarding records',
          color: AppColors.success,
        ),
        _SignalData(
          title: 'Net exposure',
          value: CurrencyFormatter.formatNaira(
            data.visibleRequests.fold<double>(
              0,
              (sum, request) =>
                  sum + (request.finalSettlement?.netSettlement ?? 0),
            ),
          ),
          subtitle: 'Total visible settlements',
          color: AppColors.primary,
        ),
      ],
    };

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: signals
          .map(
            (signal) => Container(
              width: compact ? double.infinity : 250,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: signal.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    signal.title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signal.value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signal.subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildEmployeeView(
    BuildContext context,
    WidgetRef ref,
    ExitManagementData data,
  ) {
    if (!data.hasEmployeeProfile) {
      return _buildNoticePanel(
        icon: Icons.badge_outlined,
        title: 'Employee profile required',
        subtitle:
            'Your account must be linked to an employee record before you can submit an exit request.',
        color: AppColors.warning,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildJourneyMap(),
        const SizedBox(height: 18),
        _buildSectionTitle(
          'My Exit Timeline',
          'Every request appears here with notice, settlement, and review progress.',
        ),
        const SizedBox(height: 12),
        if (data.myRequests.isEmpty)
          _buildNoticePanel(
            icon: Icons.route_outlined,
            title: 'No exit requests yet',
            subtitle:
                'Use the action button above to begin a formal exit request when needed.',
            color: AppColors.info,
          )
        else
          ...data.myRequests.map((request) => _buildJourneyCard(request)),
      ],
    );
  }

  Widget _buildJourneyMap() {
    final steps = [
      ('Submit', 'Create the request and confirm your dates.'),
      ('Review', 'HR/Admin review notice, reason, and rehire notes.'),
      ('Clearance', 'Settlement and clearance wrap up the process.'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F7),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: List.generate(steps.length, (index) {
          final step = steps[index];
          return SizedBox(
            width: 220,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        step.$2,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildJourneyCard(ExitRequest request) {
    final settlement = request.finalSettlement;
    final statusColor = _statusColor(request.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_statusIcon(request.status), color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _exitTypeLabel(request.exitType),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last working day ${DateFormat('dd MMM yyyy').format(request.lastWorkingDate)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _statusPill(request.status),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metaPill(
                'Submitted',
                DateFormat('dd MMM yyyy').format(request.createdAt),
              ),
              _metaPill(
                'Notice',
                '${request.noticePeriodDays} day${request.noticePeriodDays == 1 ? '' : 's'}',
              ),
              if (request.isShortNotice)
                _metaPill(
                  'Gap',
                  '${request.shortNoticeDays} day short',
                  tone: AppColors.warning,
                ),
            ],
          ),
          const SizedBox(height: 16),
          _softBlock(
            title: 'Reason',
            child: Text(request.reason, style: const TextStyle(height: 1.45)),
          ),
          if (settlement != null) ...[
            const SizedBox(height: 14),
            _settlementRibbon(settlement),
          ],
          if ((request.rejectionReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            _softBlock(
              title: 'Rejection reason',
              tone: AppColors.error,
              child: Text(request.rejectionReason!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewerView(
    BuildContext context,
    WidgetRef ref,
    ExitManagementData data,
  ) {
    final closedRequests = [...data.rejectedRequests, ...data.completedRequests]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Workflow Board',
          'Three lanes keep the offboarding pipeline visible from intake to closure.',
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLane(
                title: 'Incoming Review',
                subtitle: 'Pending decisions',
                tone: AppColors.warning,
                width: 340,
                child: data.pendingRequests.isEmpty
                    ? _laneEmpty('No pending requests')
                    : Column(
                        children: data.pendingRequests
                            .map(
                              (request) =>
                                  _buildReviewCard(context, ref, request),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(width: 14),
              _buildLane(
                title: 'Clearance & Completion',
                subtitle: 'Approved cases waiting for final close',
                tone: AppColors.info,
                width: 340,
                child: data.approvedRequests.isEmpty
                    ? _laneEmpty('No approved requests in motion')
                    : Column(
                        children: data.approvedRequests
                            .map(
                              (request) => _buildCompletionCard(
                                context,
                                ref,
                                request,
                                data,
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(width: 14),
              _buildLane(
                title: 'Closed Cases',
                subtitle: 'Rejected and completed history',
                tone: AppColors.success,
                width: 340,
                child: closedRequests.isEmpty
                    ? _laneEmpty('No closed cases yet')
                    : Column(
                        children: closedRequests
                            .map((request) => _buildArchiveCard(request))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFinanceView(ExitManagementData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Settlement Stream',
          'Finance sees approved and completed records only, with a full breakdown for payout review.',
        ),
        const SizedBox(height: 14),
        if (data.visibleRequests.isEmpty)
          _buildNoticePanel(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No settlement records',
            subtitle:
                'Approved or completed exit records will appear here once they reach finance visibility.',
            color: AppColors.info,
          )
        else ...[
          if (data.approvedRequests.isNotEmpty) ...[
            _buildSubsectionLabel('Ready For Settlement'),
            const SizedBox(height: 10),
            ...data.approvedRequests.map(
              (request) => _buildFinanceCard(request, data),
            ),
            const SizedBox(height: 18),
          ],
          if (data.completedRequests.isNotEmpty) ...[
            _buildSubsectionLabel('Archived Settlements'),
            const SizedBox(height: 10),
            ...data.completedRequests.map(
              (request) => _buildFinanceCard(request, data),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.45),
        ),
      ],
    );
  }

  Widget _buildSubsectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildLane({
    required String title,
    required String subtitle,
    required Color tone,
    required double width,
    required Widget child,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: tone,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _laneEmpty(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildReviewCard(
    BuildContext context,
    WidgetRef ref,
    ExitRequest request,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.warningLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              _statusPill(request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_exitTypeLabel(request.exitType)} • ${DateFormat('dd MMM yyyy').format(request.lastWorkingDate)} last day',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Text(request.reason, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill(
                'Notice',
                '${request.noticePeriodDays} days',
                tone: request.isShortNotice ? AppColors.warning : null,
              ),
              if (request.isShortNotice)
                _metaPill(
                  'Gap',
                  '${request.shortNoticeDays} short',
                  tone: AppColors.warning,
                ),
              _metaPill(
                'Net settlement',
                CurrencyFormatter.formatNaira(
                  request.finalSettlement?.netSettlement ?? 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reject(context, ref, request),
                  icon: const Icon(Icons.close, color: AppColors.error),
                  label: const Text(
                    'Reject',
                    style: TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _approve(context, ref, request),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionCard(
    BuildContext context,
    WidgetRef ref,
    ExitRequest request,
    ExitManagementData data,
  ) {
    final items = data.clearanceFor(request.id);
    final completed = data.clearanceCompletedCount(request.id);
    final total = items.length;
    final fullyCleared = data.isFullyCleared(request.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8FB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.infoLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              _statusPill(request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Net settlement ${CurrencyFormatter.formatNaira(request.finalSettlement?.netSettlement ?? 0)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clearance progress: $completed / $total',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items.isEmpty
                      ? const [
                          Text(
                            'Checklist will appear once the approval stage has created it.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ]
                      : items
                            .map(
                              (item) =>
                                  _clearanceTag(item.department, item.status),
                            )
                            .toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: fullyCleared
                ? () => _complete(context, ref, request)
                : null,
            icon: const Icon(Icons.task_alt_outlined),
            label: Text(
              fullyCleared ? 'Mark Exit Completed' : 'Waiting For Clearance',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveCard(ExitRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.employeeName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              _statusPill(request.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_exitTypeLabel(request.exitType)} • ${DateFormat('dd MMM yyyy').format(request.updatedAt)}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          if ((request.rejectionReason ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.rejectionReason!,
              style: const TextStyle(color: AppColors.error),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Settlement ${CurrencyFormatter.formatNaira(request.finalSettlement?.netSettlement ?? 0)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinanceCard(ExitRequest request, ExitManagementData data) {
    final settlement = request.finalSettlement;
    final items = data.clearanceFor(request.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
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
                      request.employeeName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_exitTypeLabel(request.exitType)} • last day ${DateFormat('dd MMM yyyy').format(request.lastWorkingDate)}',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _statusPill(request.status),
            ],
          ),
          const SizedBox(height: 14),
          _settlementRibbon(
            settlement ??
                const FinalSettlement(
                  proratedSalary: 0,
                  unusedLeaveValue: 0,
                  gratuity: 0,
                  pendingReimbursements: 0,
                  outstandingLoans: 0,
                  netSettlement: 0,
                ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items
                  .map((item) => _clearanceTag(item.department, item.status))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoticePanel({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
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
        ],
      ),
    );
  }

  Widget _statusPill(ExitStatus status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _metaPill(String label, String value, {Color? tone}) {
    final color = tone ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _softBlock({
    required String title,
    required Widget child,
    Color tone = AppColors.primary,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: tone, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _settlementRibbon(FinalSettlement settlement) {
    final items = [
      ('Prorated', settlement.proratedSalary),
      ('Leave', settlement.unusedLeaveValue),
      ('Gratuity', settlement.gratuity),
      ('Expenses', settlement.pendingReimbursements),
      ('Loans', -settlement.outstandingLoans),
      ('Net', settlement.netSettlement),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3F8ED), Color(0xFFE8F3F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: items.map((item) {
          final isNet = item.$1 == 'Net';
          final value = item.$2;
          return Container(
            width: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isNet ? 0.98 : 0.74),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.$1,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.formatNaira(value),
                  style: TextStyle(
                    color: isNet
                        ? AppColors.successDark
                        : value < 0
                        ? AppColors.error
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _clearanceTag(ClearanceDepartment department, ClearanceStatus status) {
    final color = switch (status) {
      ClearanceStatus.pending => AppColors.warning,
      ClearanceStatus.cleared => AppColors.success,
      ClearanceStatus.notApplicable => AppColors.info,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${department.name.toUpperCase()} • ${status.name.toUpperCase()}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  IconData _statusIcon(ExitStatus status) {
    return switch (status) {
      ExitStatus.pending => Icons.schedule_outlined,
      ExitStatus.underReview => Icons.fact_check_outlined,
      ExitStatus.approved => Icons.verified_outlined,
      ExitStatus.rejected => Icons.block_outlined,
      ExitStatus.completed => Icons.task_alt_outlined,
      ExitStatus.cancelled => Icons.close_outlined,
    };
  }

  Color _statusColor(ExitStatus status) {
    return switch (status) {
      ExitStatus.pending => AppColors.warning,
      ExitStatus.underReview => AppColors.info,
      ExitStatus.approved => AppColors.success,
      ExitStatus.rejected => AppColors.error,
      ExitStatus.completed => AppColors.primary,
      ExitStatus.cancelled => AppColors.textSecondary,
    };
  }

  String _exitTypeLabel(ExitType type) {
    return switch (type) {
      ExitType.resignation => 'Resignation',
      ExitType.termination => 'Termination',
      ExitType.contractExpiry => 'Contract Expiry',
      ExitType.retirement => 'Retirement',
      ExitType.endOfInternship => 'End of Internship',
      ExitType.mutualAgreement => 'Mutual Agreement',
      ExitType.absconding => 'Absconding',
    };
  }

  Future<void> _showRequestSheet(BuildContext context, WidgetRef ref) async {
    final data = ref.read(exitManagementDataProvider).value;
    final employeeId = data?.employeeId;
    if (employeeId == null) {
      NotificationHelper.showError(
        context,
        'Employee profile not found. Contact HR.',
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    final noticeDaysController = TextEditingController(text: '30');

    DateTime resignationDate = DateTime.now();
    DateTime lastWorkingDate = DateTime.now().add(const Duration(days: 30));
    ExitType exitType = ExitType.resignation;

    final submit = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final givenNoticeDays = lastWorkingDate
                .difference(resignationDate)
                .inDays;
            final configuredNotice =
                int.tryParse(noticeDaysController.text.trim()) ?? 0;
            final shortNoticeDays = configuredNotice > givenNoticeDays
                ? configuredNotice - givenNoticeDays
                : 0;

            return _sheetShell(
              context,
              title: 'Submit Exit Request',
              subtitle:
                  'Capture your timeline, notice period, and reason in one formal request.',
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<ExitType>(
                      initialValue: exitType,
                      decoration: const InputDecoration(labelText: 'Exit Type'),
                      items: _employeeExitTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(_exitTypeLabel(type)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => exitType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _dateField(
                      context,
                      label: 'Resignation Date',
                      value: resignationDate,
                      onPicked: (picked) {
                        setState(() => resignationDate = picked);
                      },
                    ),
                    const SizedBox(height: 12),
                    _dateField(
                      context,
                      label: 'Last Working Date',
                      value: lastWorkingDate,
                      onPicked: (picked) {
                        setState(() => lastWorkingDate = picked);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: noticeDaysController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Notice Period (days)',
                      ),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed < 0) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                    if (shortNoticeDays > 0) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Short notice by $shortNoticeDays day(s).',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      minLines: 4,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText: 'Describe the context for your exit request',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Reason is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              primaryActionLabel: 'Submit Request',
              onPrimaryAction: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(context, true);
              },
            );
          },
        );
      },
    );

    if (submit != true || !context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Submitting request...');
    try {
      await ref
          .read(exitManagementActionsProvider)
          .submit(
            employeeId: employeeId,
            resignationDate: resignationDate,
            lastWorkingDate: lastWorkingDate,
            reason: reasonController.text.trim(),
            exitType: exitType,
            noticePeriodDays: int.tryParse(noticeDaysController.text.trim()),
          );
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Exit request submitted.');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Submission failed: $e');
    }
  }

  Future<void> _showTerminationSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final formKey = GlobalKey<FormState>();
    final reasonController = TextEditingController();
    final remarkController = TextEditingController();
    final employeeService = EmployeeService();

    DateTime terminationDate = DateTime.now();
    ExitType exitType = ExitType.termination;
    bool eligibleForRehire = false;
    String? selectedEmployeeId;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return _sheetShell(
              context,
              title: 'Initiate Employer Exit',
              subtitle:
                  'Create an HR/admin-led exit record for terminations or company-initiated departures.',
              child: Form(
                key: formKey,
                child: Column(
                  children: [
                    FutureBuilder<List<Employee>>(
                      future: employeeService.getAllEmployees(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: LinearProgressIndicator(),
                          );
                        }
                        final employees = snapshot.data ?? [];
                        return DropdownButtonFormField<String>(
                          initialValue: selectedEmployeeId,
                          decoration: const InputDecoration(
                            labelText: 'Employee',
                          ),
                          items: employees
                              .map(
                                (employee) => DropdownMenuItem(
                                  value: employee.id,
                                  child: Text(
                                    '${employee.fullName} (${employee.email})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() => selectedEmployeeId = value);
                          },
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Select an employee';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ExitType>(
                      initialValue: exitType,
                      decoration: const InputDecoration(labelText: 'Exit Type'),
                      items: _hrExitTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(_exitTypeLabel(type)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => exitType = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    _dateField(
                      context,
                      label: 'Termination Date',
                      value: terminationDate,
                      onPicked: (picked) {
                        setState(() => terminationDate = picked);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: reasonController,
                      minLines: 4,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Reason',
                        hintText:
                            'Explain why this employer-led exit is being initiated',
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Reason is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: eligibleForRehire,
                      onChanged: (value) {
                        setState(() => eligibleForRehire = value);
                      },
                      title: const Text('Eligible for rehire'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    TextField(
                      controller: remarkController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Rehire remarks (optional)',
                      ),
                    ),
                  ],
                ),
              ),
              primaryActionLabel: 'Create Exit Record',
              onPrimaryAction: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(context, true);
              },
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Creating exit record...');
    try {
      await ref
          .read(exitManagementActionsProvider)
          .initiateTermination(
            employeeId: selectedEmployeeId!,
            terminationDate: terminationDate,
            reason: reasonController.text.trim(),
            exitType: exitType,
            eligibleForRehire: eligibleForRehire,
            rehireRemarks: remarkController.text.trim(),
          );
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Employer exit created.');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Failed: $e');
    }
  }

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    ExitRequest request,
  ) async {
    final remarkController = TextEditingController(
      text: request.rehireRemarks ?? '',
    );
    final ratingController = TextEditingController(
      text: request.performanceRating ?? '',
    );
    bool eligibleForRehire = request.eligibleForRehire;

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return _sheetShell(
              context,
              title: 'Approve Exit Request',
              subtitle:
                  'Capture optional rehire and performance notes before approval.',
              child: Column(
                children: [
                  SwitchListTile(
                    value: eligibleForRehire,
                    onChanged: (value) {
                      setState(() => eligibleForRehire = value);
                    },
                    title: const Text('Eligible for rehire'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  TextField(
                    controller: remarkController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Rehire remarks (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ratingController,
                    decoration: const InputDecoration(
                      labelText: 'Performance rating (optional)',
                      hintText: 'Excellent, Good, Average...',
                    ),
                  ),
                ],
              ),
              primaryActionLabel: 'Approve',
              onPrimaryAction: () => Navigator.pop(context, true),
            );
          },
        );
      },
    );

    if (confirm != true || !context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Approving...');
    try {
      await ref
          .read(exitManagementActionsProvider)
          .approve(
            request,
            eligibleForRehire: eligibleForRehire,
            rehireRemarks: remarkController.text.trim(),
            performanceRating: ratingController.text.trim(),
          );
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Exit request approved.');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Approval failed: $e');
    }
  }

  Future<void> _reject(
    BuildContext context,
    WidgetRef ref,
    ExitRequest request,
  ) async {
    final reasonController = TextEditingController();

    final reject = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _sheetShell(
          context,
          title: 'Reject Exit Request',
          subtitle:
              'A rejection reason is required and will be visible in the record.',
          child: TextField(
            controller: reasonController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Rejection Reason'),
          ),
          primaryActionLabel: 'Reject Request',
          primaryTone: AppColors.error,
          onPrimaryAction: () => Navigator.pop(context, true),
        );
      },
    );

    if (reject != true || !context.mounted) return;
    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      NotificationHelper.showError(context, 'Rejection reason is required.');
      return;
    }

    NotificationHelper.showLoading(context, message: 'Rejecting...');
    try {
      await ref.read(exitManagementActionsProvider).reject(request, reason);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Exit request rejected.');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Rejection failed: $e');
    }
  }

  Future<void> _complete(
    BuildContext context,
    WidgetRef ref,
    ExitRequest request,
  ) async {
    final confirm = await NotificationHelper.showConfirmDialog(
      context,
      title: 'Complete Exit',
      message:
          'Mark ${request.employeeName} as fully offboarded now that clearance is complete?',
      confirmText: 'Complete',
    );
    if (confirm != true || !context.mounted) return;

    NotificationHelper.showLoading(context, message: 'Completing exit...');
    try {
      await ref.read(exitManagementActionsProvider).complete(request);
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(context, 'Exit request completed.');
    } catch (e) {
      if (!context.mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Completion failed: $e');
    }
  }

  Widget _sheetShell(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget child,
    required String primaryActionLabel,
    required VoidCallback onPrimaryAction,
    Color primaryTone = AppColors.primary,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        top: 24,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
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
                      IconButton(
                        onPressed: () => Navigator.pop(context, false),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  child,
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: onPrimaryAction,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryTone,
                          ),
                          child: Text(primaryActionLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField(
    BuildContext context, {
    required String label,
    required DateTime value,
    required ValueChanged<DateTime> onPicked,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(DateTime.now().year - 2, 1, 1),
          lastDate: DateTime(DateTime.now().year + 3, 12, 31),
        );
        if (picked != null) {
          onPicked(picked);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(child: Text(DateFormat('dd MMM yyyy').format(value))),
            const Icon(Icons.calendar_today_outlined, size: 18),
          ],
        ),
      ),
    );
  }
}

class _SignalData {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _SignalData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}
