import 'package:flutter/material.dart';
import 'package:roipayroll/services/payroll_transaction_service.dart';

class LiabilityBalancesDashboard extends StatefulWidget {
  const LiabilityBalancesDashboard({super.key});

  @override
  State<LiabilityBalancesDashboard> createState() =>
      _LiabilityBalancesDashboardState();
}

class _LiabilityBalancesDashboardState
    extends State<LiabilityBalancesDashboard> {
  final _service = PayrollTransactionService();
  Map<String, double> _liabilities = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLiabilities();
  }

  Future<void> _loadLiabilities() async {
    setState(() => _loading = true);

    try {
      final employeePayableBalance = await _service.getAccountBalance('2100');
      final payeBalance = await _service.getAccountBalance('2110');
      final pensionBalance = await _service.getAccountBalance('2120');
      final nhfBalance = await _service.getAccountBalance('2130');
      final otherDeductionsBalance = await _service.getAccountBalance('2150');

      setState(() {
        _liabilities = {
          'Employee Net Payable': employeePayableBalance,
          'PAYE Tax Payable': payeBalance,
          'Pension Fund Payable': pensionBalance,
          'NHF Payable': nhfBalance,
          'Other Deductions Payable': otherDeductionsBalance,
        };
        _loading = false;
      });
    } catch (error) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final totalOwed = _liabilities.values.fold(0.0, (a, b) => a + b);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 32,
                  color: Colors.red[700],
                ),
                const SizedBox(width: 12),
                Text(
                  'Outstanding Liabilities',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadLiabilities,
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 24),
            ..._liabilities.entries.map((entry) {
              final progress = entry.value / (totalOwed > 0 ? totalOwed : 1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.red[300]!,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Text(
                      'NGN ${_formatAmount(entry.value)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL OWED',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'NGN ${_formatAmount(totalOwed)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.red[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.payment),
                label: const Text('Schedule Payments'),
                onPressed: totalOwed > 0
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment scheduling coming soon'),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(2);
    }
  }
}
