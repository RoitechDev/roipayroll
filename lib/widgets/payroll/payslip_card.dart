import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:intl/intl.dart';

class PayslipCard extends StatelessWidget {
  final Payroll payroll;
  final VoidCallback? onTap;
  final VoidCallback? onDownload;

  const PayslipCard({
    super.key,
    required this.payroll,
    this.onTap,
    this.onDownload,
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
                  // Month/Year Icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Employee Name and Period
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payroll.employeeName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_getMonthName(payroll.month)} ${payroll.year}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Net Salary Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'NET PAY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          '₦${NumberFormat('#,##0.00').format(payroll.netSalary)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Salary Breakdown
              Row(
                children: [
                  Expanded(
                    child: _buildAmountItem(
                      label: 'Basic Salary',
                      amount: payroll.basicSalary,
                      icon: Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAmountItem(
                      label: 'Allowances',
                      amount: payroll.allowances,
                      icon: Icons.add_circle_outline,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildAmountItem(
                      label: 'Gross Salary',
                      amount: payroll.grossSalary,
                      icon: Icons.trending_up,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildAmountItem(
                      label: 'Total Deductions',
                      amount: payroll.totalDeductions,
                      icon: Icons.remove_circle_outline,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Deductions Breakdown (Expandable)
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text(
                    'Deduction Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  children: [
                    _buildDeductionRow('PAYE Tax', payroll.paye),
                    _buildDeductionRow('Pension (8%)', payroll.pension),
                    _buildDeductionRow('NHF (2.5%)', payroll.nhf),
                    if (payroll.loanDeduction > 0)
                      _buildDeductionRow(
                        'Loan Deduction',
                        payroll.loanDeduction,
                      ),
                    if (payroll.otherDeductions - payroll.loanDeduction > 0)
                      _buildDeductionRow(
                        'Other Deductions',
                        payroll.otherDeductions - payroll.loanDeduction,
                      ),
                  ],
                ),
              ),

              // Process Date
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Processed on ${DateFormat('MMM d, y').format(payroll.processedDate)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),

              // Download Button
              if (onDownload != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download Payslip'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountItem({
    required String label,
    required double amount,
    required IconData icon,
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (color ?? AppColors.textSecondary).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color ?? AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '₦${NumberFormat('#,##0.00').format(amount)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            '₦${NumberFormat('#,##0.00').format(amount)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }
}
