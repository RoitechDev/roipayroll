import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/constants/app_routes.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/payroll_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/payroll_provider.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/screens/accounting/transaction_list_screen.dart';
import 'package:roipayroll/services/payroll_service.dart';
import 'package:roipayroll/services/pdf_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';

class PayrollHistoryScreen extends ConsumerStatefulWidget {
  const PayrollHistoryScreen({super.key});

  @override
  ConsumerState<PayrollHistoryScreen> createState() =>
      _PayrollHistoryScreenState();
}

class _PayrollHistoryScreenState extends ConsumerState<PayrollHistoryScreen> {
  static final DateFormat _processedDateFormat = DateFormat('MMM d, y');
  final _payrollService = PayrollService();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  PayrollType? _selectedPayrollType;
  bool _isLocking = false;
  bool _isApprovingAll = false;

  @override
  Widget build(BuildContext context) {
    final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
    final historyAsync = ref.watch(payrollHistoryProvider(period));
    final currentUser = ref.watch(currentUserProvider).asData?.value;
    final isMonthLocked = historyAsync.asData?.value.isMonthLocked ?? false;

    return AppScaffold(
      topBar: AppBar(
        title: const Text('Payroll History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Payment Operations',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.paymentOperations),
          ),
          IconButton(
            icon: Icon(
              isMonthLocked ? Icons.lock : Icons.lock_open,
              color: isMonthLocked ? AppColors.warning : null,
            ),
            tooltip: isMonthLocked ? 'Month Locked' : 'Lock This Month',
            onPressed: isMonthLocked || _isLocking ? null : _lockSelectedMonth,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildResponsiveFilters(currentUser),
          if (isMonthLocked)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                'This payroll month is locked. Records cannot be modified.',
                style: TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: historyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Error: $error')),
              data: (history) {
                final payrolls = _selectedPayrollType == null
                    ? history.payrolls
                    : history.payrolls
                          .where(
                            (payroll) =>
                                payroll.payrollType == _selectedPayrollType,
                          )
                          .toList();
                if (payrolls.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedPayrollType == null
                          ? 'No payroll found for this period'
                          : 'No ${_payrollTypeLabel(_selectedPayrollType!)} payroll found for this period',
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: payrolls.length,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemBuilder: (context, index) {
                    final payroll = payrolls[index];
                    return _buildPayrollHistoryCard(
                      payroll: payroll,
                      currentUser: currentUser,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveFilters(AppUser? currentUser) {
    return ResponsiveLayout(
      mobile: _buildFilters(mobile: true, currentUser: currentUser),
      tablet: _buildFilters(mobile: false, currentUser: currentUser),
      desktop: _buildFilters(mobile: false, currentUser: currentUser),
    );
  }

  Widget _buildFilters({required bool mobile, required AppUser? currentUser}) {
    final monthField = DropdownButtonFormField<int>(
      initialValue: _selectedMonth,
      decoration: const InputDecoration(labelText: 'Month'),
      items: List.generate(12, (i) {
        return DropdownMenuItem(
          value: i + 1,
          child: Text(_getMonthName(i + 1)),
        );
      }),
      onChanged: (v) {
        setState(() => _selectedMonth = v!);
      },
    );

    final yearField = DropdownButtonFormField<int>(
      initialValue: _selectedYear,
      decoration: const InputDecoration(labelText: 'Year'),
      items: List.generate(5, (i) {
        final year = DateTime.now().year - 2 + i;
        return DropdownMenuItem(value: year, child: Text('$year'));
      }),
      onChanged: (v) {
        setState(() => _selectedYear = v!);
      },
    );

    final payrollTypeField = DropdownButtonFormField<PayrollType?>(
      initialValue: _selectedPayrollType,
      decoration: const InputDecoration(labelText: 'Payroll Type'),
      items: [
        const DropdownMenuItem<PayrollType?>(
          value: null,
          child: Text('All Types'),
        ),
        ...PayrollType.values.map(
          (type) => DropdownMenuItem<PayrollType?>(
            value: type,
            child: Text(_payrollTypeLabel(type)),
          ),
        ),
      ],
      onChanged: (value) {
        setState(() => _selectedPayrollType = value);
      },
    );
    final canApproveAll =
        currentUser != null &&
        PermissionService.hasPermission(currentUser, Permission.approvePayroll);
    final approveAllButton = ElevatedButton.icon(
      onPressed: !canApproveAll || _isApprovingAll
          ? null
          : () => _approveAllPayrolls(currentUser),
      icon: _isApprovingAll
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.done_all_outlined),
      label: Text(
        _isApprovingAll
            ? 'Approving...'
            : 'Approve All (${_getMonthName(_selectedMonth)} $_selectedYear)',
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: mobile
          ? Column(
              children: [
                monthField,
                const SizedBox(height: 12),
                yearField,
                const SizedBox(height: 12),
                payrollTypeField,
                if (canApproveAll) ...[
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: approveAllButton),
                ],
              ],
            )
          : Row(
              children: [
                Expanded(child: monthField),
                const SizedBox(width: 16),
                Expanded(child: yearField),
                const SizedBox(width: 16),
                Expanded(child: payrollTypeField),
                if (canApproveAll) ...[
                  const SizedBox(width: 16),
                  approveAllButton,
                ],
              ],
            ),
    );
  }

  Widget _buildPayrollHistoryCard({
    required Payroll payroll,
    required AppUser? currentUser,
  }) {
    final canSubmit = _canSubmitForApproval(currentUser, payroll);
    final canApprove = _canApprove(currentUser, payroll);
    final canReject = _canReject(currentUser, payroll);
    final canReverse = _canReverse(currentUser, payroll);
    final canCorrect = _canCorrect(currentUser, payroll);
    final statusColor = _approvalStatusColor(payroll.approvalStatus);
    final note = _buildPayrollNote(payroll);
    final timelineLabel =
        '${_getMonthName(payroll.month)} ${payroll.year} | ${_payrollTypeLabel(payroll.payrollType)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: statusColor.withValues(alpha: 0.14),
                  foregroundColor: statusColor,
                  child: Text(
                    _initialFor(payroll.employeeName),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payroll.employeeName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timelineLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Net: ${CurrencyFormatter.formatCurrency(payroll.netSalary, currencyCode: payroll.currency)}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusBadge(payroll),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetaChip(
                  icon: Icons.schedule_outlined,
                  label:
                      'Processed ${_processedDateFormat.format(payroll.processedDate)}',
                ),
                if (payroll.isLocked)
                  _buildMetaChip(
                    icon: Icons.lock_outline,
                    label: 'Locked',
                    color: AppColors.warning,
                  ),
                if (payroll.isReversal)
                  _buildMetaChip(
                    icon: Icons.swap_horiz,
                    label: 'Reversal Entry',
                    color: AppColors.error,
                  ),
                if (payroll.isReversed)
                  _buildMetaChip(
                    icon: Icons.undo,
                    label: 'Already Reversed',
                    color: AppColors.error,
                  ),
                if (payroll.correctionOfPayrollId?.trim().isNotEmpty ?? false)
                  _buildMetaChip(
                    icon: Icons.edit_note,
                    label: 'Correction Entry',
                    color: AppColors.info,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildAmountPanel(
                    label: 'Gross',
                    amount: payroll.grossSalary,
                    currencyCode: payroll.currency,
                    color: AppColors.primary,
                    icon: Icons.trending_up,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAmountPanel(
                    label: 'Deductions',
                    amount: payroll.totalDeductions,
                    currencyCode: payroll.currency,
                    color: AppColors.error,
                    icon: Icons.remove_circle_outline,
                  ),
                ),
              ],
            ),
            if (note != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  note,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showApprovalHistory(payroll),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Approval Trail'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => PdfService.generatePayslip(payroll),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Payslip'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showMoreActions(
                    payroll: payroll,
                    currentUser: currentUser,
                  ),
                  tooltip: 'More actions',
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
            if (canSubmit ||
                canApprove ||
                canReject ||
                canCorrect ||
                canReverse) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canSubmit)
                    OutlinedButton.icon(
                      onPressed: () => _submitForApproval(payroll),
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Submit'),
                    ),
                  if (canApprove)
                    ElevatedButton.icon(
                      onPressed: () => _approvePayroll(payroll, currentUser!),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Approve'),
                    ),
                  if (canReject)
                    TextButton.icon(
                      onPressed: () => _rejectPayroll(payroll, currentUser!),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Reject'),
                    ),
                  if (canCorrect)
                    TextButton.icon(
                      onPressed: () => _correctPayroll(payroll, currentUser!),
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Correct'),
                    ),
                  if (canReverse)
                    TextButton.icon(
                      onPressed: () => _reversePayroll(payroll, currentUser!),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      icon: const Icon(Icons.undo),
                      label: const Text('Reverse'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Payroll payroll) {
    final color = _approvalStatusColor(payroll.approvalStatus);
    final icon = switch (payroll.approvalStatus) {
      PayrollApprovalStatus.draft => Icons.edit_outlined,
      PayrollApprovalStatus.pendingHRReview ||
      PayrollApprovalStatus.pendingAccountantReview ||
      PayrollApprovalStatus.pendingAccountantFinalApproval =>
        Icons.hourglass_top_rounded,
      PayrollApprovalStatus.approved => Icons.check_circle_outline,
      PayrollApprovalStatus.rejected => Icons.cancel_outlined,
      PayrollApprovalStatus.processed => Icons.verified_outlined,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            _approvalStatusLabel(payroll.approvalStatus),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    Color color = AppColors.info,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountPanel({
    required String label,
    required double amount,
    required String currencyCode,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.formatCurrency(
              amount,
              currencyCode: currencyCode,
            ),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _initialFor(String employeeName) {
    final trimmed = employeeName.trim();
    if (trimmed.isEmpty) {
      return '?';
    }
    return trimmed.substring(0, 1).toUpperCase();
  }

  String? _buildPayrollNote(Payroll payroll) {
    if (payroll.isReversal) {
      final reason = payroll.reversalReason?.trim();
      return reason == null || reason.isEmpty
          ? 'This record was created as a payroll reversal entry.'
          : 'Reversal reason: $reason';
    }

    if (payroll.isReversed) {
      final reason = payroll.reversalReason?.trim();
      return reason == null || reason.isEmpty
          ? 'This payroll has already been reversed.'
          : 'This payroll has already been reversed. Reason: $reason';
    }

    final correctionReason = payroll.correctionReason?.trim();
    if (correctionReason != null && correctionReason.isNotEmpty) {
      return 'Correction note: $correctionReason';
    }

    final offCycleReason = payroll.offCycleReason?.trim();
    if (offCycleReason != null && offCycleReason.isNotEmpty) {
      return 'Off-cycle note: $offCycleReason';
    }

    return null;
  }

  Future<void> _showMoreActions({
    required Payroll payroll,
    required AppUser? currentUser,
  }) async {
    final canSubmit = _canSubmitForApproval(currentUser, payroll);
    final canApprove = _canApprove(currentUser, payroll);
    final canReject = _canReject(currentUser, payroll);
    final canReverse = _canReverse(currentUser, payroll);
    final canCorrect = _canCorrect(currentUser, payroll);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('View Financial Transactions'),
                  subtitle: Text(
                    '${_getMonthName(payroll.month)} ${payroll.year} accounting entries',
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TransactionListScreen(
                          month: _selectedMonth,
                          year: _selectedYear,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_outlined),
                  title: const Text('Download Payslip'),
                  subtitle: const Text('Generate the payslip PDF'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    PdfService.generatePayslip(payroll);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.history_outlined),
                  title: const Text('View Approval History'),
                  subtitle: const Text('See review trail and comments'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showApprovalHistory(payroll);
                  },
                ),
                if (canSubmit || canApprove || canReject || canCorrect) ...[
                  const Divider(height: 1),
                  if (canSubmit)
                    ListTile(
                      leading: const Icon(Icons.send_outlined),
                      title: const Text('Submit For Approval'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _submitForApproval(payroll);
                      },
                    ),
                  if (canApprove)
                    ListTile(
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                      title: const Text('Approve Payroll'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _approvePayroll(payroll, currentUser!);
                      },
                    ),
                  if (canReject)
                    ListTile(
                      leading: const Icon(
                        Icons.cancel_outlined,
                        color: AppColors.error,
                      ),
                      title: const Text('Reject Payroll'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _rejectPayroll(payroll, currentUser!);
                      },
                    ),
                  if (canCorrect)
                    ListTile(
                      leading: const Icon(
                        Icons.edit_note,
                        color: AppColors.warning,
                      ),
                      title: const Text('Create Adjustment'),
                      subtitle: const Text('Create a correction payroll entry'),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _correctPayroll(payroll, currentUser!);
                      },
                    ),
                ],
                if (canReverse) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.undo, color: AppColors.error),
                    title: const Text(
                      'Reverse Payroll',
                      style: TextStyle(color: AppColors.error),
                    ),
                    subtitle: const Text('This action cannot be undone'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _reversePayroll(payroll, currentUser!);
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int m) {
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
    return months[m - 1];
  }

  String _payrollTypeLabel(PayrollType type) {
    switch (type) {
      case PayrollType.regular:
        return 'Regular';
      case PayrollType.bonus:
        return 'Bonus';
      case PayrollType.commission:
        return 'Commission';
      case PayrollType.thirteenth:
        return '13th Month';
      case PayrollType.adhoc:
        return 'Ad-hoc';
    }
  }

  String _approvalStatusLabel(PayrollApprovalStatus status) {
    switch (status) {
      case PayrollApprovalStatus.draft:
        return 'Draft';
      case PayrollApprovalStatus.pendingHRReview:
        return 'Pending HR';
      case PayrollApprovalStatus.pendingAccountantReview:
        return 'Pending Accountant Review';
      case PayrollApprovalStatus.pendingAccountantFinalApproval:
        return 'Pending Final Accountant Approval';
      case PayrollApprovalStatus.approved:
        return 'Approved';
      case PayrollApprovalStatus.rejected:
        return 'Rejected';
      case PayrollApprovalStatus.processed:
        return 'Processed';
    }
  }

  Color _approvalStatusColor(PayrollApprovalStatus status) {
    switch (status) {
      case PayrollApprovalStatus.draft:
        return Colors.blueGrey;
      case PayrollApprovalStatus.pendingHRReview:
      case PayrollApprovalStatus.pendingAccountantReview:
      case PayrollApprovalStatus.pendingAccountantFinalApproval:
        return Colors.orange;
      case PayrollApprovalStatus.approved:
      case PayrollApprovalStatus.processed:
        return AppColors.success;
      case PayrollApprovalStatus.rejected:
        return AppColors.error;
    }
  }

  bool _canSubmitForApproval(AppUser? user, Payroll payroll) {
    if (user == null || payroll.isLocked) return false;
    if (payroll.approvalStatus == PayrollApprovalStatus.approved ||
        payroll.approvalStatus == PayrollApprovalStatus.processed) {
      return false;
    }
    return payroll.approvalStatus == PayrollApprovalStatus.draft ||
        payroll.approvalStatus == PayrollApprovalStatus.rejected;
  }

  bool _canApprove(AppUser? user, Payroll payroll) {
    if (user == null || payroll.isLocked) return false;
    switch (payroll.approvalStatus) {
      case PayrollApprovalStatus.pendingHRReview:
        return user.role == UserRole.hr || user.role == UserRole.admin;
      case PayrollApprovalStatus.pendingAccountantReview:
      case PayrollApprovalStatus.pendingAccountantFinalApproval:
        return user.role == UserRole.accountant || user.role == UserRole.admin;
      default:
        return false;
    }
  }

  bool _canReject(AppUser? user, Payroll payroll) {
    return _canApprove(user, payroll);
  }

  bool _canReverse(AppUser? user, Payroll payroll) {
    if (user == null) return false;
    if (payroll.isLocked || payroll.isReversal || payroll.isReversed) {
      return false;
    }
    return user.role == UserRole.admin || user.role == UserRole.accountant;
  }

  bool _canCorrect(AppUser? user, Payroll payroll) {
    if (user == null) return false;
    if (payroll.isLocked || payroll.isReversal) return false;
    return user.role == UserRole.admin || user.role == UserRole.accountant;
  }

  Future<void> _submitForApproval(Payroll payroll) async {
    try {
      await _payrollService.submitForApproval(payroll.id);
      if (!mounted) return;
      final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
      ref.invalidate(payrollHistoryProvider(period));
      ref
          .read(appManualRefreshControllerProvider)
          .add(DateTime.now().millisecondsSinceEpoch);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Submitted for approval.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  Future<void> _approvePayroll(Payroll payroll, AppUser user) async {
    try {
      await _payrollService.approvePayroll(payroll.id, user.id);
      if (!mounted) return;
      final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
      ref.invalidate(payrollHistoryProvider(period));
      ref
          .read(appManualRefreshControllerProvider)
          .add(DateTime.now().millisecondsSinceEpoch);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payroll approved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Approval failed: $e')));
    }
  }

  Future<void> _approveAllPayrolls(AppUser currentUser) async {
    final monthLabel = _getMonthName(_selectedMonth);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve All Payrolls'),
          content: Text(
            'Approve all eligible payrolls for $monthLabel $_selectedYear? '
            'This will generate accounting entries and cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Approve All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isApprovingAll = true);
    try {
      final result = await _payrollService.fastTrackApproveMonth(
        month: _selectedMonth,
        year: _selectedYear,
        approverId: currentUser.id,
      );
      if (!mounted) return;

      final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
      ref.invalidate(payrollHistoryProvider(period));
      ref
          .read(appManualRefreshControllerProvider)
          .add(DateTime.now().millisecondsSinceEpoch);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Approved ${result.approved}, skipped ${result.skipped}, failed ${result.failed}.',
          ),
          action: result.failed > 0
              ? SnackBarAction(
                  label: 'Details',
                  onPressed: () => _showBulkApprovalErrors(result.errors),
                )
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Approve all failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _isApprovingAll = false);
      }
    }
  }

  Future<void> _showBulkApprovalErrors(List<String> errors) async {
    if (errors.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Approve All Failures'),
          content: SizedBox(
            width: 520,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: errors.length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, index) => Text(errors[index]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _rejectPayroll(Payroll payroll, AppUser user) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reject Payroll'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Reason',
              hintText: 'Enter rejection reason',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    try {
      await _payrollService.rejectPayroll(payroll.id, user.id, reason);
      if (!mounted) return;
      final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
      ref.invalidate(payrollHistoryProvider(period));
      ref
          .read(appManualRefreshControllerProvider)
          .add(DateTime.now().millisecondsSinceEpoch);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payroll rejected.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Rejection failed: $e')));
    }
  }

  Future<void> _showApprovalHistory(Payroll payroll) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final history = payroll.approvalHistory;
        return AlertDialog(
          title: const Text('Approval History'),
          content: SizedBox(
            width: 520,
            child: history.isEmpty
                ? const Text('No approval history yet.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: history.length,
                    separatorBuilder: (_, _) => const Divider(height: 16),
                    itemBuilder: (context, index) {
                      final entry = history[index];
                      final when = entry.reviewedAt == null
                          ? '-'
                          : '${entry.reviewedAt!.day}/${entry.reviewedAt!.month}/${entry.reviewedAt!.year} '
                                '${entry.reviewedAt!.hour.toString().padLeft(2, '0')}:'
                                '${entry.reviewedAt!.minute.toString().padLeft(2, '0')}';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _approvalStatusLabel(entry.status),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text('By: ${entry.reviewedBy ?? '-'}'),
                          Text('At: $when'),
                          if ((entry.comments ?? '').trim().isNotEmpty)
                            Text('Comment: ${entry.comments}'),
                          if ((entry.rejectionReason ?? '').trim().isNotEmpty)
                            Text('Reason: ${entry.rejectionReason}'),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _reversePayroll(Payroll payroll, AppUser user) async {
    final reason = await _showReverseConfirmation(payroll);
    if (reason == null || reason.isEmpty) return;

    try {
      await _payrollService.reversePayroll(payroll.id, reason, user.id);
      if (!mounted) return;
      final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
      ref.invalidate(payrollHistoryProvider(period));
      ref
          .read(appManualRefreshControllerProvider)
          .add(DateTime.now().millisecondsSinceEpoch);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payroll reversed.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reversal failed: $e')));
    }
  }

  Future<String?> _showReverseConfirmation(Payroll payroll) async {
    final controller = TextEditingController();
    String? validationError;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  SizedBox(width: 12),
                  Expanded(child: Text('Reverse Payroll?')),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${payroll.employeeName} | ${_getMonthName(payroll.month)} ${payroll.year}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'This will:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text('- Reverse related financial transactions'),
                    const Text('- Restore linked deductions and recoveries'),
                    const Text('- Mark the payroll record as reversed'),
                    const Text('- Write an audit trail entry'),
                    const SizedBox(height: 16),
                    const Text(
                      'This action cannot be undone.',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Reason for reversal',
                        hintText: 'Required for the audit trail',
                        errorText: validationError,
                      ),
                      onChanged: (_) {
                        if (validationError != null) {
                          setDialogState(() => validationError = null);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    final reason = controller.text.trim();
                    if (reason.isEmpty) {
                      setDialogState(() {
                        validationError = 'Reason is required';
                      });
                      return;
                    }
                    Navigator.of(dialogContext).pop(reason);
                  },
                  child: const Text('Confirm Reversal'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _correctPayroll(Payroll payroll, AppUser user) async {
    final reason = await _askReason(
      title: 'Create Correction Payroll',
      hint: 'Enter correction reason',
    );
    if (reason == null || reason.isEmpty) return;

    try {
      await _payrollService.createCorrectionPayroll(
        payroll.id,
        reason,
        user.id,
      );
      if (!mounted) return;
      final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
      ref.invalidate(payrollHistoryProvider(period));
      ref
          .read(appManualRefreshControllerProvider)
          .add(DateTime.now().millisecondsSinceEpoch);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correction payroll created.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Correction failed: $e')));
    }
  }

  Future<String?> _askReason({
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: InputDecoration(labelText: 'Reason', hintText: hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _lockSelectedMonth() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lock Payroll Month'),
          content: Text(
            'Lock ${_getMonthName(_selectedMonth)} $_selectedYear payroll?\n\n'
            'After locking, payroll for this month cannot be changed or reprocessed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Lock Month'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLocking = true);
    try {
      await _payrollService.lockPayrollMonth(_selectedMonth, _selectedYear);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Locked ${_getMonthName(_selectedMonth)} $_selectedYear payroll.',
          ),
        ),
      );
      final period = PayrollPeriod(month: _selectedMonth, year: _selectedYear);
      ref.invalidate(payrollHistoryProvider(period));
      ref
          .read(appManualRefreshControllerProvider)
          .add(DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to lock month: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLocking = false);
      }
    }
  }
}
