import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/attendance_model.dart';
import 'package:roipayroll/providers/attendance_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/permission_service.dart';

class AttendanceListScreen extends ConsumerStatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  ConsumerState<AttendanceListScreen> createState() =>
      _AttendanceListScreenState();
}

class _AttendanceListScreenState extends ConsumerState<AttendanceListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'Today';
  String _statusFilter = 'All Statuses';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return AppScaffold(
      title: 'Attendance',
      padding: EdgeInsets.zero,
      child: currentUserAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildErrorState(error.toString()),
        data: (user) {
          if (user == null) {
            return _buildErrorState('Unable to load user profile.');
          }

          final canViewAllRecords = PermissionService.hasPermission(
            user,
            Permission.viewEmployees,
          );
          final query = AttendanceFilterQuery(
            filter: _selectedFilter,
            isAdmin: canViewAllRecords,
            employeeId: user.employeeId,
          );
          final attendanceAsync = ref.watch(filteredAttendanceProvider(query));

          return attendanceAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _buildErrorState(error.toString()),
            data: (attendances) {
              final visibleAttendances = _applyClientFilters(
                attendances,
                canViewAllRecords: canViewAllRecords,
              );
              final stats = _calculateStatistics(visibleAttendances);

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(filteredAttendanceProvider(query));
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildHeader(
                      canViewAllRecords: canViewAllRecords,
                      visibleCount: visibleAttendances.length,
                    ),
                    const SizedBox(height: 18),
                    _buildTopControls(canViewAllRecords: canViewAllRecords),
                    const SizedBox(height: 18),
                    _buildSummaryGrid(
                      attendances: visibleAttendances,
                      stats: stats,
                      canViewAllRecords: canViewAllRecords,
                    ),
                    const SizedBox(height: 18),
                    _buildLogPanel(
                      attendances: visibleAttendances,
                      canViewAllRecords: canViewAllRecords,
                    ),
                    const SizedBox(height: 18),
                    _buildSecurityBanner(canViewAllRecords: canViewAllRecords),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    required bool canViewAllRecords,
    required int visibleCount,
  }) {
    final title = canViewAllRecords
        ? 'Attendance Overview'
        : 'My Attendance Overview';
    final subtitle = canViewAllRecords
        ? 'Real-time tracking of employee presence and punctuality.'
        : 'Track your attendance history, punctuality, and work duration.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          canViewAllRecords
              ? 'MANAGEMENT  >  ATTENDANCE HISTORY'
              : 'SELF SERVICE  >  ATTENDANCE HISTORY',
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Showing ${visibleCount.toString()} attendance ${visibleCount == 1 ? 'record' : 'records'} for $_selectedFilter.',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textTertiary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTopControls({required bool canViewAllRecords}) {
    final filters = ['Today', 'This Week', 'This Month', 'All'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;
        final searchField = Container(
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
              hintText: canViewAllRecords
                  ? 'Search employees or logs...'
                  : 'Search your logs...',
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
        );

        final filterTabs = Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return InkWell(
                onTap: () => setState(() => _selectedFilter = filter),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.surfaceVariant
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(flex: 5, child: searchField),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: filterTabs),
            ],
          );
        }

        return Column(
          children: [searchField, const SizedBox(height: 12), filterTabs],
        );
      },
    );
  }

  Widget _buildSummaryGrid({
    required List<Attendance> attendances,
    required Map<String, int> stats,
    required bool canViewAllRecords,
  }) {
    final workforceCount = attendances
        .map((attendance) => attendance.employeeId)
        .toSet()
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final summaryCards = [
          _buildSummaryCard(
            icon: Icons.assignment_turned_in_outlined,
            iconColor: AppColors.info,
            label: 'PRESENT',
            value: stats['present'].toString(),
            badgeLabel: 'ON TRACK',
            badgeColor: AppColors.success,
            trendText:
                '${_percentageText(stats['present']!, attendances.length)} in view',
            trendColor: AppColors.success,
          ),
          _buildSummaryCard(
            icon: Icons.alarm_on_outlined,
            iconColor: AppColors.warningDark,
            label: 'LATE ARRIVALS',
            value: stats['late'].toString(),
            badgeLabel: 'ATTENTION',
            badgeColor: AppColors.warning,
            trendText:
                '${_percentageText(stats['late']!, attendances.length)} in view',
            trendColor: AppColors.warningDark,
          ),
          _buildSummaryCard(
            icon: Icons.person_off_outlined,
            iconColor: AppColors.error,
            label: 'ABSENT',
            value: stats['absent'].toString(),
            badgeLabel: 'CRITICAL',
            badgeColor: AppColors.error,
            trendText:
                '${_percentageText(stats['absent']!, attendances.length)} in view',
            trendColor: AppColors.error,
          ),
          _buildWorkforceCard(
            title: canViewAllRecords ? 'TOTAL WORKFORCE' : 'MY RECORDS',
            value: canViewAllRecords
                ? workforceCount.toString()
                : attendances.length.toString(),
            subtitle: canViewAllRecords
                ? 'Tracked employees'
                : 'Attendance entries',
          ),
        ];

        if (constraints.maxWidth >= 1180) {
          return Row(
            children: [
              Expanded(child: summaryCards[0]),
              const SizedBox(width: 16),
              Expanded(child: summaryCards[1]),
              const SizedBox(width: 16),
              Expanded(child: summaryCards[2]),
              const SizedBox(width: 16),
              Expanded(child: summaryCards[3]),
            ],
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: summaryCards
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
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String badgeLabel,
    required Color badgeColor,
    required String trendText,
    required Color trendColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
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
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 46,
              height: 1,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            trendText,
            style: TextStyle(color: trendColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkforceCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.groups_2_outlined, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildLogPanel({
    required List<Attendance> attendances,
    required bool canViewAllRecords,
  }) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    canViewAllRecords ? 'Attendance Log' : 'My Attendance Log',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: [
                    _buildStatusMenuButton(),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _exportCsv(attendances, canViewAllRecords),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.divider),
          if (attendances.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: _buildEmptyState(canViewAllRecords: canViewAllRecords),
            )
          else ...[
            if (isWide) _buildDesktopTableHeader(canViewAllRecords),
            ...attendances.map(
              (attendance) => isWide
                  ? _buildDesktopRow(
                      attendance,
                      canViewAllRecords: canViewAllRecords,
                    )
                  : _buildMobileRow(
                      attendance,
                      canViewAllRecords: canViewAllRecords,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing ${attendances.length} ${attendances.length == 1 ? 'entry' : 'entries'}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _buildSimplePager(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusMenuButton() {
    return PopupMenuButton<String>(
      initialValue: _statusFilter,
      onSelected: (value) => setState(() => _statusFilter = value),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'All Statuses', child: Text('All Statuses')),
        PopupMenuItem(value: 'Present', child: Text('Present')),
        PopupMenuItem(value: 'Late', child: Text('Late')),
        PopupMenuItem(value: 'Absent', child: Text('Absent')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.filter_list_rounded,
              size: 18,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Text(
              _statusFilter == 'All Statuses' ? 'Filter By' : _statusFilter,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTableHeader(bool canViewAllRecords) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          Expanded(
            flex: canViewAllRecords ? 4 : 2,
            child: Text(
              canViewAllRecords ? 'EMPLOYEE NAME' : 'DATE',
              style: _tableHeaderStyle,
            ),
          ),
          if (canViewAllRecords)
            Expanded(flex: 3, child: Text('DATE', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('CLOCK-IN', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('CLOCK-OUT', style: _tableHeaderStyle)),
          Expanded(flex: 2, child: Text('STATUS', style: _tableHeaderStyle)),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(
    Attendance attendance, {
    required bool canViewAllRecords,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAttendanceDetails(
          attendance,
          canViewAllRecords: canViewAllRecords,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: canViewAllRecords ? 4 : 2,
                child: canViewAllRecords
                    ? _buildEmployeeCell(attendance)
                    : Text(
                        DateFormat('MMM d, y').format(attendance.date),
                        style: _tableValueStyle,
                      ),
              ),
              if (canViewAllRecords)
                Expanded(
                  flex: 3,
                  child: Text(
                    DateFormat('MMM d, y').format(attendance.date),
                    style: _tableValueStyle,
                  ),
                ),
              Expanded(
                flex: 2,
                child: _buildTimeCell(
                  icon: Icons.login_rounded,
                  value: attendance.clockInTime != null
                      ? _formatTime(attendance.clockInTime!)
                      : '--:--',
                  color: attendance.isLate
                      ? AppColors.warningDark
                      : AppColors.success,
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildTimeCell(
                  icon: Icons.logout_rounded,
                  value: attendance.clockOutTime != null
                      ? _formatTime(attendance.clockOutTime!)
                      : '--:--',
                  color: AppColors.info,
                ),
              ),
              Expanded(
                flex: 2,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _buildStatusChip(attendance),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileRow(
    Attendance attendance, {
    required bool canViewAllRecords,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAttendanceDetails(
          attendance,
          canViewAllRecords: canViewAllRecords,
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canViewAllRecords) _buildEmployeeCell(attendance),
              if (canViewAllRecords) const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMM d, y').format(attendance.date),
                      style: _tableValueStyle,
                    ),
                  ),
                  _buildStatusChip(attendance),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildPill(
                    icon: Icons.login_rounded,
                    label: attendance.clockInTime != null
                        ? _formatTime(attendance.clockInTime!)
                        : '--:--',
                    color: attendance.isLate
                        ? AppColors.warningDark
                        : AppColors.success,
                  ),
                  _buildPill(
                    icon: Icons.logout_rounded,
                    label: attendance.clockOutTime != null
                        ? _formatTime(attendance.clockOutTime!)
                        : '--:--',
                    color: AppColors.info,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeCell(Attendance attendance) {
    final initials = attendance.employeeName.trim().isEmpty
        ? '?'
        : attendance.employeeName.trim().substring(0, 1).toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          foregroundColor: AppColors.primaryDark,
          child: Text(
            initials,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attendance.employeeName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                attendance.clockInLocation?.trim().isNotEmpty == true
                    ? attendance.clockInLocation!
                    : 'Employee ID: ${attendance.employeeId}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeCell({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          value,
          style: _tableValueStyle.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(Attendance attendance) {
    final color = _getStatusColor(attendance);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _getStatusLabel(attendance),
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSimplePager() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pagerButton(Icons.chevron_left, false),
        const SizedBox(width: 8),
        _pageNumber('1', true),
        const SizedBox(width: 8),
        _pageNumber('2', false),
        const SizedBox(width: 8),
        _pageNumber('3', false),
        const SizedBox(width: 8),
        _pagerButton(Icons.chevron_right, false),
      ],
    );
  }

  Widget _pagerButton(IconData icon, bool enabled) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: enabled ? AppColors.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(icon, color: enabled ? Colors.white : AppColors.textPrimary),
    );
  }

  Widget _pageNumber(String text, bool active) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? AppColors.primaryDark : AppColors.border,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityBanner({required bool canViewAllRecords}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: isWide
              ? Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildSecurityText(
                        canViewAllRecords: canViewAllRecords,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildAuditLogsButton(),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildSecurityText(
                            canViewAllRecords: canViewAllRecords,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildAuditLogsButton(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSecurityText({required bool canViewAllRecords}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Secure Data Transmission',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          canViewAllRecords
              ? 'This attendance log is encrypted and access is logged for security auditing.'
              : 'Your attendance records are encrypted and access is logged for security auditing.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildAuditLogsButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audit logs are available from Reports/Audit.'),
          ),
        );
      },
      child: const Text('AUDIT LOGS'),
    );
  }

  List<Attendance> _applyClientFilters(
    List<Attendance> attendances, {
    required bool canViewAllRecords,
  }) {
    final query = _searchController.text.trim().toLowerCase();

    return attendances.where((attendance) {
      final matchesStatus = switch (_statusFilter) {
        'Present' =>
          !attendance.isLate && attendance.status != AttendanceStatus.absent,
        'Late' => attendance.isLate,
        'Absent' => attendance.status == AttendanceStatus.absent,
        _ => true,
      };

      if (!matchesStatus) return false;
      if (query.isEmpty) return true;

      final haystack = <String>[
        if (canViewAllRecords) attendance.employeeName,
        attendance.employeeId,
        _getStatusLabel(attendance),
        DateFormat('MMM d, y').format(attendance.date),
        if (attendance.clockInTime != null)
          _formatTime(attendance.clockInTime!),
        if (attendance.clockOutTime != null)
          _formatTime(attendance.clockOutTime!),
        attendance.clockInLocation ?? '',
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  Future<void> _exportCsv(
    List<Attendance> attendances,
    bool canViewAllRecords,
  ) async {
    final buffer = StringBuffer();
    final headers = <String>[
      if (canViewAllRecords) 'Employee Name',
      'Date',
      'Clock In',
      'Clock Out',
      'Status',
    ];
    buffer.writeln(headers.join(','));

    for (final attendance in attendances) {
      final row = <String>[
        if (canViewAllRecords) _csvField(attendance.employeeName),
        _csvField(DateFormat('yyyy-MM-dd').format(attendance.date)),
        _csvField(
          attendance.clockInTime != null
              ? _formatTime(attendance.clockInTime!)
              : '',
        ),
        _csvField(
          attendance.clockOutTime != null
              ? _formatTime(attendance.clockOutTime!)
              : '',
        ),
        _csvField(_getStatusLabel(attendance)),
      ];
      buffer.writeln(row.join(','));
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Attendance CSV copied to clipboard.')),
    );
  }

  String _csvField(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Widget _buildEmptyState({required bool canViewAllRecords}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.event_busy_outlined,
            size: 34,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          canViewAllRecords
              ? 'No attendance records match this view.'
              : 'No personal attendance records match this view.',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Try a different filter or search term.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            const Text(
              'Failed to load attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAttendanceDetails(
    Attendance attendance, {
    required bool canViewAllRecords,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Attendance Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (canViewAllRecords)
              _buildDetailRow('Employee', attendance.employeeName),
            _buildDetailRow(
              'Date',
              DateFormat('EEEE, MMMM d, y').format(attendance.date),
            ),
            _buildDetailRow('Status', _getStatusLabel(attendance)),
            if (attendance.clockInTime != null)
              _buildDetailRow('Clock In', _formatTime(attendance.clockInTime!)),
            if (attendance.clockOutTime != null)
              _buildDetailRow(
                'Clock Out',
                _formatTime(attendance.clockOutTime!),
              ),
            if (attendance.workHoursDecimal > 0)
              _buildDetailRow(
                'Work Duration',
                '${attendance.workHoursDecimal.toStringAsFixed(2)} hours',
              ),
            if (attendance.clockInLocation?.trim().isNotEmpty ?? false)
              _buildDetailRow('Location', attendance.clockInLocation!),
            if (attendance.isLate)
              _buildDetailRow(
                'Late Deduction',
                'NGN ${attendance.lateDeduction.toStringAsFixed(2)}',
              ),
            if (attendance.overtimeHours != null &&
                attendance.overtimeHours!.inMinutes > 0) ...[
              _buildDetailRow(
                'Overtime Hours',
                '${attendance.overtimeHoursDecimal.toStringAsFixed(2)} hours',
              ),
              _buildDetailRow(
                'Overtime Pay',
                'NGN ${attendance.overtimePay.toStringAsFixed(2)}',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateStatistics(List<Attendance> attendances) {
    int present = 0;
    int late = 0;
    int absent = 0;

    for (final attendance in attendances) {
      if (attendance.status == AttendanceStatus.absent) {
        absent++;
      } else if (attendance.isLate) {
        late++;
      } else if (attendance.status == AttendanceStatus.present ||
          attendance.status == AttendanceStatus.late) {
        present++;
      }
    }

    return {'present': present, 'late': late, 'absent': absent};
  }

  String _percentageText(int value, int total) {
    if (total <= 0) return '0%';
    final percentage = (value / total) * 100;
    return '${percentage.toStringAsFixed(1)}%';
  }

  Color _getStatusColor(Attendance attendance) {
    if (attendance.status == AttendanceStatus.absent) {
      return AppColors.error;
    }
    if (attendance.isLate) {
      return AppColors.warningDark;
    }
    if (attendance.clockInTime != null &&
        attendance.clockInTime!.isBefore(attendance.expectedClockIn)) {
      return AppColors.success;
    }
    return AppColors.info;
  }

  String _getStatusLabel(Attendance attendance) {
    if (attendance.status == AttendanceStatus.absent) {
      return 'Absent';
    }
    if (attendance.isLate) {
      return 'Late';
    }
    if (attendance.clockInTime != null &&
        attendance.clockInTime!.isBefore(attendance.expectedClockIn)) {
      return 'Early';
    }
    return 'On Time';
  }

  String _formatTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  TextStyle get _tableHeaderStyle => const TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.6,
  );

  TextStyle get _tableValueStyle => const TextStyle(
    color: AppColors.primaryDark,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
}
