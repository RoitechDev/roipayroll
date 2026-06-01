import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/core/utils/notification_helper.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/loan_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/auth_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/loan_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';
import 'package:roipayroll/widgets/modern/index.dart';
import 'package:uuid/uuid.dart';

class RequestLoanScreen extends StatefulWidget {
  const RequestLoanScreen({super.key});

  @override
  State<RequestLoanScreen> createState() => _RequestLoanScreenState();
}

class _RequestLoanScreenState extends State<RequestLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loanService = LoanService();
  final _userService = UserService();
  final _employeeService = EmployeeService();
  final _authService = AuthService();
  final _notificationService = NotificationService();

  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  AppUser? _currentUser;
  String? _employeeId;
  String _employeeName = '';
  String _position = 'Employee';
  double _basicSalary = 0;
  double _outstandingLoans = 0;

  int _selectedMonths = 6;
  bool _isLoading = false;
  bool _isContextLoading = true;
  double _monthlyDeduction = 0;
  LoanRiskAssessment? _riskAssessment;
  bool _isRiskLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadEmployeeContext();
    _amountController.addListener(_calculateMonthlyDeduction);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  bool get _canRequest => (_employeeId ?? '').trim().isNotEmpty;

  Future<void> _loadEmployeeContext() async {
    try {
      final user = await _userService.getCurrentUserProfile();
      if (user == null) {
        throw Exception('No active user profile found.');
      }

      final authUser = _authService.currentUser;
      if (authUser == null) {
        throw Exception('User not authenticated.');
      }

      final employee = await _employeeService.getEmployeeByUserId(authUser.uid);
      final employeeId = employee?.id ?? user.employeeId?.trim();
      final outstanding = employeeId == null || employeeId.isEmpty
          ? 0.0
          : await _loanService.getEmployeeOutstandingLoans(employeeId);

      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _employeeId = employeeId;
        _employeeName = employee?.fullName ?? user.name;
        _position = employee?.position ?? 'Employee';
        _basicSalary = employee?.basicSalary ?? 0;
        _outstandingLoans = outstanding;
        _loadError = null;
        _isContextLoading = false;
      });

      _refreshRiskAssessment();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isContextLoading = false;
      });
    }
  }

  void _calculateMonthlyDeduction() {
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    setState(() {
      _monthlyDeduction = _selectedMonths > 0 ? amount / _selectedMonths : 0;
    });
    _refreshRiskAssessment();
  }

  Future<void> _refreshRiskAssessment() async {
    final employeeId = _employeeId;
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (employeeId == null || employeeId.isEmpty || amount <= 0) {
      if (mounted) {
        setState(() => _riskAssessment = null);
      }
      return;
    }

    setState(() => _isRiskLoading = true);
    try {
      final risk = await _loanService.calculateLoanRisk(
        employeeId: employeeId,
        requestedAmount: amount,
      );
      if (mounted) {
        setState(() => _riskAssessment = risk);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _riskAssessment = null);
      }
    } finally {
      if (mounted) {
        setState(() => _isRiskLoading = false);
      }
    }
  }

  Future<void> _submitLoanRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final authUser = _authService.currentUser;
    final employeeId = _employeeId;
    if (authUser == null || employeeId == null || employeeId.isEmpty) {
      NotificationHelper.showError(
        context,
        'Your account is not linked to an employee profile.',
      );
      return;
    }

    setState(() => _isLoading = true);
    NotificationHelper.showLoading(
      context,
      message: 'Submitting loan request...',
    );

    try {
      final loanAmount = double.parse(
        _amountController.text.replaceAll(',', ''),
      );

      final loan = Loan(
        id: const Uuid().v4(),
        employeeId: employeeId,
        employeeName: _employeeName,
        amount: loanAmount,
        durationMonths: _selectedMonths,
        monthlyDeduction: _monthlyDeduction,
        status: LoanStatus.pending,
        reason: _reasonController.text.trim(),
        requestDate: DateTime.now(),
      );

      await _loanService.requestLoan(loan);

      await _notificationService.sendNotification(
        userId: authUser.uid,
        title: 'Loan Request Submitted',
        message:
            'Your loan request for ${CurrencyFormatter.formatNaira(loanAmount)} has been submitted and is being processed.',
        type: NotificationType.loanRequest,
        data: {'loanId': loan.id, 'amount': loanAmount},
      );

      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.accountant],
        title: 'New Loan Request',
        message:
            '$_employeeName requested a loan of ${CurrencyFormatter.formatNaira(loanAmount)} for $_selectedMonths months.',
        type: NotificationType.loanRequest,
        data: {
          'loanId': loan.id,
          'employeeId': employeeId,
          'amount': loanAmount,
        },
      );

      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showSuccess(
        context,
        'Loan request submitted successfully. You will be notified once it is reviewed.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.hideLoading(context);
      NotificationHelper.showError(context, 'Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      topBar: AppBar(title: const Text('Loan Request')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isContextLoading) {
      return const ModernLoadingState(message: 'Preparing loan request...');
    }

    if (_loadError != null) {
      return ModernErrorState(
        message: 'Unable to open loan request',
        subtitle: _loadError!,
        onRetry: _loadEmployeeContext,
      );
    }

    if (!_canRequest) {
      return const ModernEmptyState(
        icon: Icons.badge_outlined,
        title: 'Employee profile required',
        subtitle:
            'Loan requests are only available for users linked to an employee record.',
      );
    }

    return ResponsiveLayout(
      mobile: _buildRequestPage(padding: 12),
      tablet: _buildRequestPage(padding: 16),
      desktop: _buildRequestPage(padding: 20),
    );
  }

  Widget _buildRequestPage({required double padding}) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(padding),
            children: [
              _buildHeroCard(),
              const SizedBox(height: 16),
              if (_currentUser != null &&
                  _currentUser!.role != UserRole.employee)
                _buildReviewerReminder(),
              if (_currentUser != null &&
                  _currentUser!.role != UserRole.employee)
                const SizedBox(height: 16),
              _buildProfileSnapshot(),
              const SizedBox(height: 16),
              _buildRequestFormCard(),
              const SizedBox(height: 16),
              _buildGuidanceCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.info],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personal Loan Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit a request, preview repayment, and review the risk signal before sending it for approval.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _heroMetric(
                'Outstanding',
                CurrencyFormatter.formatNaira(_outstandingLoans),
              ),
              _heroMetric(
                'Monthly Preview',
                CurrencyFormatter.formatNaira(_monthlyDeduction),
              ),
              _heroMetric('Tenure', '$_selectedMonths months'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewerReminder() {
    final roleLabel = _currentUser?.getRoleName() ?? 'User';
    return Card(
      color: AppColors.infoLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.info),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'You are signed in as $roleLabel. This screen only creates a personal loan request tied to your own employee record.',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSnapshot() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _infoTile('Employee', _employeeName, Icons.person_outline),
            _infoTile('Role', _position, Icons.work_outline),
            _infoTile(
              'Basic Salary',
              _basicSalary <= 0
                  ? 'Not configured'
                  : CurrencyFormatter.formatNaira(_basicSalary),
              Icons.payments_outlined,
            ),
            _infoTile(
              'Open Balance',
              CurrencyFormatter.formatNaira(_outstandingLoans),
              Icons.receipt_long_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return SizedBox(
      width: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Set the amount, choose a repayment period, and explain what the loan is for.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Loan Amount',
                prefixText: 'NGN ',
                helperText: 'Minimum NGN 10,000. Maximum NGN 5,000,000.',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Amount is required';
                }
                final amount = double.tryParse(value.replaceAll(',', ''));
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount';
                }
                if (amount < 10000) return 'Minimum loan amount is NGN 10,000';
                if (amount > 5000000) {
                  return 'Maximum loan amount is NGN 5,000,000';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Repayment Duration',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [3, 6, 9, 12, 18, 24].map((months) {
                final selected = _selectedMonths == months;
                return ChoiceChip(
                  label: Text('$months months'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedMonths = months;
                      _calculateMonthlyDeduction();
                    });
                  },
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            if (_isRiskLoading) const LinearProgressIndicator(minHeight: 2),
            if (_riskAssessment != null) ...[
              const SizedBox(height: 14),
              _buildRiskCard(),
            ],
            if (_monthlyDeduction > 0) ...[
              const SizedBox(height: 14),
              _buildRepaymentPreview(),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _reasonController,
              minLines: 4,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Reason for Loan',
                hintText:
                    'Share the purpose and any context the reviewer should know.',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Please provide a reason';
                if (text.length < 10) {
                  return 'Please provide more details (at least 10 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitLoanRequest,
                icon: const Icon(Icons.send_outlined),
                label: const Text('Submit Loan Request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskCard() {
    final risk = _riskAssessment!;
    final color = _riskColor(risk.level);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk signal: ${risk.label}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  risk.reason,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepaymentPreview() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Repayment Preview',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Monthly deduction'),
              Text(
                CurrencyFormatter.formatNaira(_monthlyDeduction),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This amount will be deducted from your salary for $_selectedMonths months.',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidanceCard() {
    return Card(
      color: AppColors.warningLight.withValues(alpha: 0.5),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Before you submit',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text(
              'Requests are reviewed by the loan approver team. Keep the reason specific, choose a realistic tenure, and make sure your salary profile is up to date for a better risk assessment.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Color _riskColor(LoanRiskLevel level) {
    switch (level) {
      case LoanRiskLevel.low:
        return AppColors.success;
      case LoanRiskLevel.medium:
        return AppColors.warning;
      case LoanRiskLevel.high:
        return AppColors.error;
    }
  }
}
