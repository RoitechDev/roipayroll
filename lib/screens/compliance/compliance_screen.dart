import 'package:flutter/material.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/models/payroll_audit_model.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabController;
  final List<PayrollApprovalRecord> _pendingApprovals = [];
  final List<PayrollAuditLog> _recentAudits = [];
  Map<String, dynamic>? _complianceSummary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load pending approvals
      // Load recent audits
      // Calculate compliance summary
      
      setState(() {
        _complianceSummary = {
          'taxCompliant': true,
          'laborLawCompliant': true,
          'pendingApprovals': 0,
          'violations': 0,
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll Compliance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Tax'),
            Tab(text: 'Approvals'),
            Tab(text: 'Audit Trail'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTaxComplianceTab(),
                _buildApprovalsTab(),
                _buildAuditTrailTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildComplianceMetrics(),
          const SizedBox(height: 24),
          _buildQuickStats(),
          const SizedBox(height: 24),
          _buildLaborLawSection(),
          const SizedBox(height: 24),
          _buildRecentViolations(),
        ],
      ),
    );
  }

  Widget _buildComplianceMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Compliance Status',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Tax Compliant',
                _complianceSummary?['taxCompliant'] == true ? 'YES' : 'NO',
                Icons.verified,
                _complianceSummary?['taxCompliant'] == true
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Labor Law',
                _complianceSummary?['laborLawCompliant'] == true ? 'YES' : 'NO',
                Icons.gavel,
                _complianceSummary?['laborLawCompliant'] == true
                    ? AppColors.success
                    : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Stats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Pending Approvals',
                _complianceSummary?['pendingApprovals']?.toString() ?? '0',
                Icons.pending_actions,
                AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Violations',
                _complianceSummary?['violations']?.toString() ?? '0',
                Icons.warning_amber,
                AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaborLawSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Nigerian Labor Law Compliance',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildLaborLawItem('Minimum Wage', '₦70,000', Icons.payments),
            _buildLaborLawItem('Max Work Hours', '40 hrs/week', Icons.schedule),
            _buildLaborLawItem('Annual Leave', '21 days', Icons.event),
            _buildLaborLawItem('Overtime Rate', '1.5x weekday, 2x weekend', Icons.timer),
          ],
        ),
      ),
    );
  }

  Widget _buildLaborLawItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentViolations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Violations',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('No violations found'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaxComplianceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTaxBracketsInfo(),
        const SizedBox(height: 24),
        _buildStatutoryDeductions(),
        const SizedBox(height: 24),
        _buildTaxCalculatorButton(),
      ],
    );
  }

  Widget _buildTaxBracketsInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.account_balance, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Nigerian PAYE Tax Brackets (2024)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildTaxBracketRow('First ₦300,000', '7%'),
            _buildTaxBracketRow('Next ₦300,000', '11%'),
            _buildTaxBracketRow('Next ₦500,000', '15%'),
            _buildTaxBracketRow('Next ₦500,000', '19%'),
            _buildTaxBracketRow('Next ₦1,600,000', '21%'),
            _buildTaxBracketRow('Above ₦3,200,000', '24%'),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxBracketRow(String range, String rate) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(range),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              rate,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatutoryDeductions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.receipt_long, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'Statutory Deductions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildStatutoryRow('Employee Pension', '8% of gross'),
            _buildStatutoryRow('Employer Pension', '10% of gross'),
            _buildStatutoryRow('NHF', '2.5% of basic'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutoryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxCalculatorButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushNamed(context, '/compliance/tax-calculator');
        },
        icon: const Icon(Icons.calculate),
        label: const Text('Open Tax Calculator'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildApprovalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Pending Payroll Approvals',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_pendingApprovals.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No pending approvals')),
            ),
          )
        else
          ..._pendingApprovals.map((approval) => _buildApprovalCard(approval)),
      ],
    );
  }

  Widget _buildApprovalCard(PayrollApprovalRecord approval) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_getMonthName(approval.month)} ${approval.year}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                _buildStatusChip(approval.status),
              ],
            ),
            const Divider(height: 24),
            Text('Employees: ${approval.totalEmployees}'),
            Text('Total Gross: ₦${approval.totalGrossPay.toStringAsFixed(2)}'),
            Text('Total Net: ₦${approval.totalNetPay.toStringAsFixed(2)}'),
            if (approval.complianceViolations.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Violations:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    ...approval.complianceViolations.map((v) => Text('• $v')),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTrailTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Recent Audit Logs',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_recentAudits.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No audit logs')),
            ),
          )
        else
          ..._recentAudits.map((audit) => _buildAuditCard(audit)),
      ],
    );
  }

  Widget _buildAuditCard(PayrollAuditLog audit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: const Icon(Icons.history, color: AppColors.primary),
        ),
        title: Text(audit.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${audit.employeeName}'),
            Text('By: ${audit.performedByName}'),
            Text(_formatDate(audit.performedAt)),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildStatusChip(PayrollApprovalStatus status) {
    Color color;
    String label;

    switch (status) {
      case PayrollApprovalStatus.pending:
        color = AppColors.warning;
        label = 'PENDING';
        break;
      case PayrollApprovalStatus.approved:
        color = AppColors.success;
        label = 'APPROVED';
        break;
      case PayrollApprovalStatus.rejected:
        color = AppColors.error;
        label = 'REJECTED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
