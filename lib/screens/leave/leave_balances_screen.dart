import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/core/constants/app_colors.dart';
import 'package:roipayroll/layout/app_scaffold.dart';
import 'package:roipayroll/models/leave_balance_model.dart';
import 'package:roipayroll/providers/leave_provider.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/leave_balance_service.dart';
import 'package:roipayroll/widgets/common/responsive_layout.dart';

class LeaveBalancesScreen extends ConsumerStatefulWidget {
  const LeaveBalancesScreen({super.key});

  @override
  ConsumerState<LeaveBalancesScreen> createState() =>
      _LeaveBalancesScreenState();
}

class _LeaveBalancesScreenState extends ConsumerState<LeaveBalancesScreen> {
  final LeaveBalanceService _leaveBalanceService = LeaveBalanceService();
  final EmployeeService _employeeService = EmployeeService();

  bool _isInitializing = false;
  String _selectedYear = DateTime.now().year.toString();
  String? _selectedLeaveTypeName;

  Future<void> _initializeBalancesForAllEmployees() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Initialize Leave Balances'),
            content: const Text(
              'This will create/update leave balances for all employees for the current year. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    setState(() => _isInitializing = true);
    try {
      final employees = await _employeeService.getAllEmployees();
      for (final employee in employees) {
        await _leaveBalanceService.initializeEmployeeBalances(
          employee.id,
          employee.fullName,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Initialized balances for ${employees.length} employees.',
          ),
        ),
      );

      final query = LeaveBalancesQuery(year: int.parse(_selectedYear));
      ref.invalidate(leaveBalancesProvider(query));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = LeaveBalancesQuery(year: int.parse(_selectedYear));
    final balancesAsync = ref.watch(leaveBalancesProvider(query));

    return balancesAsync.when(
      loading: () =>
          const AppScaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => AppScaffold(
        topBar: AppBar(title: const Text('Leave Balances')),
        body: Center(child: Text('Error: $error')),
      ),
      data: (data) {
        if (!data.canViewAll) {
          return AppScaffold(
            topBar: AppBar(title: const Text('Leave Balances')),
            body: const Center(
              child: Text(
                'Access denied. Only HR can view all employee balances.',
              ),
            ),
          );
        }

        final filteredBalances = _selectedLeaveTypeName == null
            ? data.balances
            : data.balances
                  .where((b) => b.leaveTypeName == _selectedLeaveTypeName)
                  .toList();
        final leaveTypes = _getUniqueLeaveTypes(data.balances);

        return AppScaffold(
          topBar: AppBar(
            title: const Text('Employee Leave Balances'),
            actions: [
              TextButton.icon(
                onPressed: _isInitializing
                    ? null
                    : _initializeBalancesForAllEmployees,
                icon: _isInitializing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check),
                label: const Text('Initialize Balances'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(leaveBalancesProvider(query)),
              ),
            ],
          ),
          body: ResponsiveLayout(
            mobile: _buildContent(
              query: query,
              filteredBalances: filteredBalances,
              leaveTypes: leaveTypes,
              compact: true,
            ),
            tablet: _buildContent(
              query: query,
              filteredBalances: filteredBalances,
              leaveTypes: leaveTypes,
              compact: false,
            ),
            desktop: _buildContent(
              query: query,
              filteredBalances: filteredBalances,
              leaveTypes: leaveTypes,
              compact: false,
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent({
    required LeaveBalancesQuery query,
    required List<LeaveBalance> filteredBalances,
    required List<String> leaveTypes,
    required bool compact,
  }) {
    return Column(
      children: [
        _buildFilters(leaveTypes: leaveTypes, compact: compact),
        _buildSummaryCards(filteredBalances, compact: compact),
        Expanded(
          child: filteredBalances.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(leaveBalancesProvider(query));
                    await ref.read(leaveBalancesProvider(query).future);
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBalances.length,
                    itemBuilder: (context, index) {
                      return _buildBalanceCard(
                        filteredBalances[index],
                        compact: compact,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilters({
    required List<String> leaveTypes,
    required bool compact,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surfaceVariant,
      child: compact
          ? Column(
              children: [
                _buildYearDropdown(),
                const SizedBox(height: 12),
                _buildLeaveTypeDropdown(leaveTypes),
              ],
            )
          : Row(
              children: [
                Expanded(child: _buildYearDropdown()),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildLeaveTypeDropdown(leaveTypes)),
              ],
            ),
    );
  }

  Widget _buildYearDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedYear,
      decoration: const InputDecoration(
        labelText: 'Year',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: List.generate(3, (index) {
        final year = DateTime.now().year - 1 + index;
        return DropdownMenuItem(
          value: year.toString(),
          child: Text(year.toString()),
        );
      }),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedYear = value);
        }
      },
    );
  }

  Widget _buildLeaveTypeDropdown(List<String> leaveTypes) {
    return DropdownButtonFormField<String?>(
      initialValue: _selectedLeaveTypeName,
      decoration: const InputDecoration(
        labelText: 'Leave Type',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All Types')),
        ...leaveTypes.map(
          (type) => DropdownMenuItem<String?>(value: type, child: Text(type)),
        ),
      ],
      onChanged: (value) {
        setState(() => _selectedLeaveTypeName = value);
      },
    );
  }

  Widget _buildSummaryCards(
    List<LeaveBalance> balances, {
    required bool compact,
  }) {
    if (balances.isEmpty) return const SizedBox.shrink();

    final totalEmployees = balances.map((b) => b.employeeId).toSet().length;
    final totalAllocated = balances.fold(0.0, (sum, b) => sum + b.allocated);
    final totalUsed = balances.fold(0.0, (sum, b) => sum + b.used);
    final totalBalance = balances.fold(0.0, (sum, b) => sum + b.balance);

    final cards = [
      _buildSummaryCard(
        'Employees',
        totalEmployees.toString(),
        Icons.people,
        AppColors.primary,
      ),
      _buildSummaryCard(
        'Allocated',
        totalAllocated.toStringAsFixed(0),
        Icons.event_available,
        AppColors.info,
      ),
      _buildSummaryCard(
        'Used',
        totalUsed.toStringAsFixed(0),
        Icons.event_busy,
        AppColors.warning,
      ),
      _buildSummaryCard(
        'Balance',
        totalBalance.toStringAsFixed(0),
        Icons.account_balance_wallet,
        AppColors.success,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: compact
          ? GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: cards,
            )
          : Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(LeaveBalance balance, {required bool compact}) {
    final usagePercentage = balance.usedPercentage;
    final statusColor = usagePercentage < 50
        ? AppColors.success
        : usagePercentage < 80
        ? AppColors.warning
        : AppColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          child: Text(
            balance.employeeName.isNotEmpty
                ? balance.employeeName[0].toUpperCase()
                : '?',
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          balance.employeeName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              balance.leaveTypeName,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBadge(
                  'Allocated',
                  balance.allocated.toString(),
                  AppColors.info,
                ),
                _buildBadge('Used', balance.used.toString(), AppColors.warning),
                _buildBadge('Balance', balance.balance.toString(), statusColor),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usagePercentage / 100,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 6,
              ),
            ),
          ],
        ),
        trailing: compact
            ? null
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${usagePercentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  Text(
                    'used',
                    style: TextStyle(fontSize: 12, color: statusColor),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No leave balances found',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Balances will appear once employees are allocated leave',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _isInitializing
                  ? null
                  : _initializeBalancesForAllEmployees,
              icon: _isInitializing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.playlist_add_check),
              label: const Text('Initialize Balances for All Employees'),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getUniqueLeaveTypes(List<LeaveBalance> balances) {
    final types = balances
        .map((b) => b.leaveTypeName)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    types.sort();
    return types;
  }
}
