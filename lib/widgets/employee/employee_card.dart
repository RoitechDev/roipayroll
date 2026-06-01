import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:intl/intl.dart';

class EmployeeCard extends StatelessWidget {
  final Employee employee;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EmployeeCard({
    super.key,
    required this.employee,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      employee.firstName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name and Position
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          employee.position,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        employee.status,
                      ).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(employee.status),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      employee.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(employee.status),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Employee Details Grid
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.business,
                      label: 'Department',
                      value: employee.department,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: employee.email,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.phone_outlined,
                      label: 'Phone',
                      value: employee.phone,
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Salary',
                      value:
                          '₦${NumberFormat('#,##0.00').format(employee.basicSalary)}',
                      valueColor: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.calendar_today_outlined,
                      label: 'Hire Date',
                      value: DateFormat('MMM d, y').format(employee.hireDate),
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      icon: Icons.work_history_outlined,
                      label: 'Tenure',
                      value: _calculateTenure(employee.hireDate),
                    ),
                  ),
                ],
              ),

              // Action Buttons
              if (onEdit != null || onDelete != null) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (onEdit != null)
                      TextButton.icon(
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.success;
      case 'inactive':
        return AppColors.textSecondary;
      case 'on leave':
        return AppColors.warning;
      case 'suspended':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _calculateTenure(DateTime hireDate) {
    final now = DateTime.now();
    final years = now.year - hireDate.year;
    final months = now.month - hireDate.month;

    if (years > 0) {
      if (months > 0) {
        return '$years yr${years > 1 ? 's' : ''}, $months mo${months > 1 ? 's' : ''}';
      }
      return '$years year${years > 1 ? 's' : ''}';
    } else if (months > 0) {
      return '$months month${months > 1 ? 's' : ''}';
    } else {
      final days = now.difference(hireDate).inDays;
      return '$days day${days > 1 ? 's' : ''}';
    }
  }
}
