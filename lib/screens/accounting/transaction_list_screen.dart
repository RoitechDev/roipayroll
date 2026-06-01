import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roipayroll/models/payroll_transaction_model.dart';
import 'package:roipayroll/services/payroll_transaction_service.dart';

class TransactionListScreen extends StatefulWidget {
  final String? payrollRunId;
  final int? month;
  final int? year;

  const TransactionListScreen({
    super.key,
    this.payrollRunId,
    this.month,
    this.year,
  });

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _service = PayrollTransactionService();
  List<PayrollTransaction> _transactions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      List<PayrollTransaction> transactions;
      if (widget.payrollRunId != null) {
        transactions = await _service.getTransactionsByPayrollRun(
          widget.payrollRunId!,
        );
      } else if (widget.month != null && widget.year != null) {
        transactions = await _service.getTransactionsForPeriod(
          month: widget.month!,
          year: widget.year!,
        );
      } else {
        transactions = [];
      }

      setState(() {
        _transactions = transactions;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _transactions.isNotEmpty ? _exportTransactions : null,
            tooltip: 'Export to CSV',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $_error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadTransactions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _transactions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No transactions found'),
                ],
              ),
            )
          : Column(
              children: [
                _buildSummaryCard(),
                Expanded(
                  child: ListView.builder(
                    itemCount: _transactions.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final tx = _transactions[index];
                      return _buildTransactionCard(tx);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    final totalDebits = _transactions.fold<double>(
      0.0,
      (runningTotal, tx) => runningTotal + tx.amountBase,
    );
    final totalCredits = _transactions.fold<double>(
      0.0,
      (runningTotal, tx) => runningTotal + tx.amountBase,
    );
    final isBalanced = (totalDebits - totalCredits).abs() < 0.01;

    return Card(
      margin: const EdgeInsets.all(16),
      color: isBalanced ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Transactions',
                  _transactions.length.toString(),
                  Icons.receipt,
                ),
                _buildSummaryItem(
                  'Total Debits',
                  'NGN ${_formatAmount(totalDebits)}',
                  Icons.arrow_upward,
                ),
                _buildSummaryItem(
                  'Total Credits',
                  'NGN ${_formatAmount(totalCredits)}',
                  Icons.arrow_downward,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBalanced ? Icons.check_circle : Icons.warning,
                  color: isBalanced ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isBalanced ? 'Balanced OK' : 'Not Balanced!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isBalanced ? Colors.green[700] : Colors.red[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue[700]),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTransactionCard(PayrollTransaction tx) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getTypeColor(tx.type),
          child: Icon(_getTypeIcon(tx.type), color: Colors.white, size: 20),
        ),
        title: Text(
          tx.description,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${tx.employeeName} - ${dateFormat.format(tx.transactionDate)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'NGN ${tx.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (tx.currency != 'NGN')
              Text(
                tx.currency,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
          ],
        ),
        children: [
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Debit Account', tx.debitAccountName),
                _buildDetailRow('Credit Account', tx.creditAccountName),
                _buildDetailRow(
                  'Amount (Base)',
                  'NGN ${tx.amountBase.toStringAsFixed(2)}',
                ),
                if (tx.exchangeRate != 1.0)
                  _buildDetailRow(
                    'Exchange Rate',
                    tx.exchangeRate.toStringAsFixed(4),
                  ),
                _buildDetailRow('Transaction ID', tx.id),
                _buildDetailRow('Payroll Run ID', tx.payrollRunId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(TransactionType type) {
    switch (type) {
      case TransactionType.salary:
        return Colors.blue;
      case TransactionType.salaryPayment:
        return Colors.teal;
      case TransactionType.deductionPayment:
        return Colors.deepOrange;
      case TransactionType.paye:
        return Colors.red;
      case TransactionType.pension:
        return Colors.green;
      case TransactionType.nhf:
        return Colors.orange;
      case TransactionType.loan:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.salary:
        return Icons.attach_money;
      case TransactionType.salaryPayment:
        return Icons.account_balance_wallet;
      case TransactionType.deductionPayment:
        return Icons.outbox;
      case TransactionType.paye:
        return Icons.account_balance;
      case TransactionType.pension:
        return Icons.savings;
      case TransactionType.nhf:
        return Icons.home;
      case TransactionType.loan:
        return Icons.money_off;
      default:
        return Icons.receipt;
    }
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    } else if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(2)}K';
    } else {
      return amount.toStringAsFixed(2);
    }
  }

  void _exportTransactions() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Export feature coming soon')));
  }
}
