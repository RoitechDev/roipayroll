import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';

/// Policy Information Card showing attendance rules
class PolicyInfoCard extends StatelessWidget {
  const PolicyInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.policy,
                  color: AppColors.accent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Attendance Policy',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPolicyItem('📅 Working Hours', '9:00 AM - 5:00 PM (8 hours)'),
          _buildPolicyItem('⏰ Grace Period', '15 minutes (until 9:15 AM)'),
          _buildPolicyItem(
            '💰 Late Penalty',
            '₦500 deduction after grace period',
          ),
          _buildPolicyItem(
            '⚡ Overtime Pay',
            '1.5x weekdays, 2x weekends/holidays',
          ),
          _buildPolicyItem('🏖️ Absence', 'Deducted from monthly salary'),
        ],
      ),
    );
  }

  Widget _buildPolicyItem(String title, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary,
                ),
                children: [
                  TextSpan(
                    text: title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: '\n$detail',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
