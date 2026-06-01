import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/models/attendance_model.dart';
import 'dart:async';

/// Quick Stats Row showing Clock In, Clock Out, and Working Time
class QuickStatsRow extends StatefulWidget {
  final Attendance? attendance;

  const QuickStatsRow({super.key, this.attendance});

  @override
  State<QuickStatsRow> createState() => _QuickStatsRowState();
}

class _QuickStatsRowState extends State<QuickStatsRow> {
  Timer? _timer;
  String _workingTime = '0h 0m';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _updateWorkingTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateWorkingTime();
      }
    });
  }

  void _updateWorkingTime() {
    if (widget.attendance?.clockInTime != null &&
        widget.attendance?.clockOutTime == null) {
      final duration = DateTime.now().difference(
        widget.attendance!.clockInTime!,
      );
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      setState(() {
        _workingTime = '${hours}h ${minutes}m';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWorking =
        widget.attendance != null && !widget.attendance!.isClockedOut;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              label: 'Clock In',
              value: widget.attendance?.clockInTime != null
                  ? _formatTime(widget.attendance!.clockInTime!)
                  : '--:--',
              icon: Icons.login,
              color: AppColors.success,
            ),
          ),
          Container(width: 1, height: 40, color: AppColors.divider),
          Expanded(
            child: _buildStatItem(
              label: 'Clock Out',
              value: widget.attendance?.clockOutTime != null
                  ? _formatTime(widget.attendance!.clockOutTime!)
                  : '--:--',
              icon: Icons.logout,
              color: AppColors.error,
            ),
          ),
          if (isWorking) ...[
            Container(width: 1, height: 40, color: AppColors.divider),
            Expanded(
              child: _buildStatItem(
                label: 'Working',
                value: _workingTime,
                icon: Icons.timer,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
