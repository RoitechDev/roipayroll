import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/models/attendance_model.dart';

/// Attendance Status Card showing today's details
class AttendanceStatusCard extends StatelessWidget {
  final Attendance attendance;

  const AttendanceStatusCard({super.key, required this.attendance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.today, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'TODAY\'S SUMMARY',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Status',
            attendance.status.name.toUpperCase(),
            Icons.info,
            _getStatusColor(attendance.status),
          ),
          if (attendance.isClockedOut) ...[
            const Divider(height: 24),
            _buildDetailRow(
              'Work Duration',
              '${attendance.workHoursDecimal.toStringAsFixed(1)} hours',
              Icons.schedule,
              AppColors.primary,
            ),
          ],
          if (attendance.isLate) ...[
            const Divider(height: 24),
            _buildDetailRow(
              'Late Deduction',
              '₦${attendance.lateDeduction.toStringAsFixed(2)}',
              Icons.warning_amber,
              AppColors.warning,
            ),
          ],
          if (attendance.overtimeHours != null &&
              attendance.overtimeHours!.inMinutes > 0) ...[
            const Divider(height: 24),
            _buildDetailRow(
              'Overtime',
              '${attendance.overtimeHoursDecimal.toStringAsFixed(1)} hrs',
              Icons.timer,
              AppColors.success,
            ),
            if (attendance.overtimePay > 0) ...[
              const SizedBox(height: 8),
              _buildDetailRow(
                'Overtime Pay',
                '₦${attendance.overtimePay.toStringAsFixed(2)}',
                Icons.payments,
                AppColors.accent,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppColors.success;
      case AttendanceStatus.late:
        return AppColors.warning;
      case AttendanceStatus.absent:
        return AppColors.error;
      case AttendanceStatus.halfDay:
        return AppColors.info;
      case AttendanceStatus.leave:
        return AppColors.primary;
      case AttendanceStatus.weekend:
        return AppColors.textSecondary;
      case AttendanceStatus.holiday:
        return AppColors.accent;
    }
  }
}
