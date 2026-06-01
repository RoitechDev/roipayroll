import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/attendance_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/attendance_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/widgets/attendance/analog_clock_widget.dart';

class ClockInScreen extends StatefulWidget {
  const ClockInScreen({super.key});

  @override
  State<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends State<ClockInScreen> {
  static final NumberFormat _moneyFormat = NumberFormat.currency(
    symbol: 'NGN ',
    decimalDigits: 0,
  );

  final AttendanceService _attendanceService = AttendanceService();
  final UserService _userService = UserService();
  final NotificationService _notificationService = NotificationService();

  AppUser? _currentUser;
  Attendance? _todayAttendance;
  bool _isLoading = true;
  bool _isActing = false;
  DateTime _currentTime = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _startClock();
    _loadClockWorkspace();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _currentTime = DateTime.now());
    });
  }

  Future<void> _loadClockWorkspace() async {
    setState(() => _isLoading = true);

    try {
      final user = await _userService.getCurrentUserProfile();
      Attendance? attendance;
      final employeeId = user?.employeeId?.trim();
      if (employeeId != null && employeeId.isNotEmpty) {
        attendance = await _attendanceService.getTodayAttendance(employeeId);
      }

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _todayAttendance = attendance;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleClockIn() async {
    final user = _currentUser;
    final employeeId = user?.employeeId?.trim();
    if (user == null || employeeId == null || employeeId.isEmpty) {
      NotificationHelper.showError(
        context,
        'Clock in is only available for users linked to an employee profile.',
      );
      return;
    }

    setState(() => _isActing = true);
    NotificationHelper.showLoading(context, message: 'Clocking in...');

    try {
      final attendance = await _attendanceService.clockIn(
        employeeId: employeeId,
        employeeName: user.name,
      );

      if (!mounted) return;
      NotificationHelper.hideLoading(context);

      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Clock In',
        message: '${user.name} clocked in at ${_formatTime(_currentTime)}',
        type: NotificationType.attendance,
        data: {'employeeId': employeeId, 'attendanceId': attendance.id},
      );

      final message = attendance.isLate
          ? 'Clocked in. You are ${attendance.lateMinutes} minutes late. Deduction: ${_moneyFormat.format(attendance.lateDeduction)}.'
          : 'Clocked in successfully.';

      await _loadClockWorkspace();
      if (!mounted) return;
      NotificationHelper.showSuccess(context, message);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  Future<void> _handleClockOut() async {
    final user = _currentUser;
    final attendance = _todayAttendance;
    if (user == null || attendance == null) {
      NotificationHelper.showError(
        context,
        'No clock-in record found for today.',
      );
      return;
    }

    setState(() => _isActing = true);
    NotificationHelper.showLoading(context, message: 'Clocking out...');

    try {
      final updatedAttendance = await _attendanceService.clockOut(
        attendanceId: attendance.id,
      );

      if (!mounted) return;
      NotificationHelper.hideLoading(context);

      await _notificationService.sendNotification(
        userId: user.id,
        title: 'Clock Out',
        message: 'You clocked out at ${_formatTime(_currentTime)}',
        type: NotificationType.attendance,
        data: {
          'employeeId': user.employeeId,
          'attendanceId': updatedAttendance.id,
        },
      );

      final buffer = StringBuffer(
        'Clocked out successfully. Work duration: ${updatedAttendance.workHoursDecimal.toStringAsFixed(1)} hours.',
      );
      if (updatedAttendance.overtimeHours != null &&
          updatedAttendance.overtimeHours!.inMinutes > 0) {
        buffer.write(
          ' Overtime: ${updatedAttendance.overtimeHoursDecimal.toStringAsFixed(1)} hours (${_moneyFormat.format(updatedAttendance.overtimePay)}).',
        );
      }

      await _loadClockWorkspace();
      if (!mounted) return;
      NotificationHelper.showSuccess(context, buffer.toString());
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _isActing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Attendance',
      padding: EdgeInsets.zero,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadClockWorkspace,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 1100;
                      final left = _buildClockPanel();
                      final right = Column(
                        children: [
                          _buildActionPanel(),
                          const SizedBox(height: 16),
                          _buildStatusPanel(),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: left),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: right),
                          ],
                        );
                      }

                      return Column(
                        children: [left, const SizedBox(height: 16), right],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildPolicyPanel(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  Widget _buildClockPanel() {
    final hour = _currentTime.hour > 12
        ? _currentTime.hour - 12
        : (_currentTime.hour == 0 ? 12 : _currentTime.hour);
    final minute = _currentTime.minute.toString().padLeft(2, '0');
    final period = _currentTime.hour >= 12 ? 'PM' : 'AM';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Attendance Workspace',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 320,
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.surfaceVariant,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: AnalogClockWidget(dateTime: _currentTime, size: 220),
              ),
            ),
          ),
          const SizedBox(height: 24),
          RichText(
            text: TextSpan(
              style: const TextStyle(color: AppColors.textPrimary),
              children: [
                TextSpan(
                  text: '${hour.toString().padLeft(2, '0')}:$minute',
                  style: const TextStyle(
                    fontSize: 58,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.5,
                    color: AppColors.primaryDark,
                  ),
                ),
                TextSpan(
                  text: period,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, MMMM d, y').format(_currentTime),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel() {
    final user = _currentUser;
    final canViewTeam =
        user != null &&
        PermissionService.hasPermission(user, Permission.viewEmployees);
    final hasEmployeeProfile = user?.employeeId?.trim().isNotEmpty ?? false;
    final canClockIn =
        !_isActing && hasEmployeeProfile && _todayAttendance == null;
    final canClockOut =
        !_isActing &&
        hasEmployeeProfile &&
        _todayAttendance != null &&
        !_todayAttendance!.isClockedOut;
    final statusColor = _statusColor(_todayAttendance);

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
            'Welcome, ${_firstName(user?.name ?? '')}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasEmployeeProfile
                ? canViewTeam
                      ? 'Track your own session and review team attendance from the history screen.'
                      : 'Ready to begin your session?'
                : 'This account can view attendance, but clock actions need a linked employee profile.',
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _statusIcon(_todayAttendance),
                  color: statusColor,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _statusText(_todayAttendance),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.play_arrow_rounded,
                  label: 'Clock In',
                  color: AppColors.primaryDark,
                  enabled: canClockIn,
                  onTap: _handleClockIn,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.stop_rounded,
                  label: 'Clock Out',
                  color: AppColors.error,
                  enabled: canClockOut,
                  onTap: _handleClockOut,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _locationText(),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPanel() {
    final clockInText = _todayAttendance?.clockInTime != null
        ? _formatTime(_todayAttendance!.clockInTime!)
        : '--:--';
    final clockOutText = _todayAttendance?.clockOutTime != null
        ? _formatTime(_todayAttendance!.clockOutTime!)
        : '--:--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STATUS TODAY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusText(_todayAttendance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Clock in: $clockInText    Clock out: $clockOutText',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyPanel() {
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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.policy_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Attendance Policy',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: const [
              _PolicyMetric(
                icon: Icons.work_outline,
                color: AppColors.info,
                label: 'WORKING HOURS',
                value: '9:00 AM - 5:00 PM',
                detail: 'Total: 8 hours/day',
              ),
              _PolicyMetric(
                icon: Icons.timer_outlined,
                color: AppColors.info,
                label: 'GRACE PERIOD',
                value: '15 minutes',
                detail: 'Until 9:15 AM',
              ),
              _PolicyMetric(
                icon: Icons.warning_amber_rounded,
                color: AppColors.error,
                label: 'LATE PENALTY',
                value: 'NGN 500',
                detail: 'Per late check-in',
              ),
              _PolicyMetric(
                icon: Icons.trending_up_outlined,
                color: AppColors.info,
                label: 'OVERTIME PAY',
                value: '1.5x - 2.0x',
                detail: 'Weekdays and weekends',
              ),
              _PolicyMetric(
                icon: Icons.event_busy_outlined,
                color: AppColors.textSecondary,
                label: 'ABSENCE',
                value: 'Salary Deduction',
                detail: 'Monthly adjustment',
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All attendance logs are encrypted and timestamped. Any attempt to tamper with time or location data is flagged for internal review.',
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 34, color: color),
                ),
                const SizedBox(height: 16),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(Attendance? attendance) {
    if (attendance == null) return Colors.teal;
    if (attendance.status == AttendanceStatus.absent) return AppColors.error;
    if (attendance.isClockedOut) return AppColors.success;
    if (attendance.isLate) return AppColors.warning;
    return Colors.teal;
  }

  IconData _statusIcon(Attendance? attendance) {
    if (attendance == null) return Icons.play_circle_outline;
    if (attendance.status == AttendanceStatus.absent) {
      return Icons.cancel_outlined;
    }
    if (attendance.isClockedOut) return Icons.check_circle_outline;
    if (attendance.isLate) return Icons.schedule_outlined;
    return Icons.verified_outlined;
  }

  String _statusText(Attendance? attendance) {
    if (_currentUser?.employeeId?.trim().isEmpty ?? true) {
      return 'View Only';
    }
    if (attendance == null) return 'Ready';
    if (attendance.status == AttendanceStatus.absent) return 'Absent';
    if (attendance.isClockedOut) return 'Completed';
    if (attendance.isLate) return 'Late';
    return 'On Time';
  }

  String _locationText() {
    final location = _todayAttendance?.clockInLocation?.trim();
    if (location != null && location.isNotEmpty) {
      return 'Verified Location: $location';
    }
    if (_currentUser?.employeeId?.trim().isEmpty ?? true) {
      return 'Verified Location: Clock actions are unavailable for this profile';
    }
    return 'Verified Location: Location will be captured at check-in';
  }

  String _firstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'there';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }
}

class _PolicyMetric extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;

  const _PolicyMetric({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color == AppColors.textSecondary
                  ? AppColors.textPrimary
                  : color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
