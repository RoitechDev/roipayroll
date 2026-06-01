import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_transaction_model.dart';
import 'package:roipayroll/services/base_service.dart';

class DeductionTransactionService extends BaseService {
  final String _collection = 'deduction_transactions';

  Future<void> recordTransaction(DeductionTransaction transaction) async {
    final transactionsRef = await companyCollection(_collection);
    await transactionsRef.doc(transaction.id).set(transaction.toJson());
  }

  Future<List<DeductionTransaction>> getAllTransactions({
    DateTime? from,
    DateTime? to,
  }) async {
    final transactionsRef = await companyCollection(_collection);
    final snapshot = await transactionsRef.get();
    return _filterAndSortByDate(snapshot.docs, from: from, to: to);
  }

  Future<List<DeductionTransaction>> getEmployeeTransactions(
    String employeeId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final transactionsRef = await companyCollection(_collection);
    final snapshot = await transactionsRef
        .where('employeeId', isEqualTo: employeeId)
        .get();

    return _filterAndSortByDate(snapshot.docs, from: from, to: to);
  }

  Future<List<DeductionTransaction>> getPayrollTransactions(
    String payrollId,
  ) async {
    final transactionsRef = await companyCollection(_collection);
    final snapshot = await transactionsRef
        .where('payrollId', isEqualTo: payrollId)
        .get();

    final transactions = snapshot.docs
        .map((doc) => DeductionTransaction.fromJson(docData(doc)))
        .toList();
    transactions.sort((a, b) => b.processedAt.compareTo(a.processedAt));
    return transactions;
  }

  Future<void> deleteTransactionsForPayroll(String payrollId) async {
    final transactions = await getPayrollTransactions(payrollId);
    if (transactions.isEmpty) return;

    final transactionsRef = await companyCollection(_collection);
    final batch = firestore.batch();
    for (final transaction in transactions) {
      batch.delete(transactionsRef.doc(transaction.id));
    }
    await batch.commit();
  }

  Future<List<DeductionTransaction>> getTransactionsByType(
    String typeId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final transactionsRef = await companyCollection(_collection);
    final snapshot = await transactionsRef
        .where('deductionTypeId', isEqualTo: typeId)
        .get();

    return _filterAndSortByDate(snapshot.docs, from: from, to: to);
  }

  Future<double> getTotalDeductions(
    String employeeId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final transactions = await getEmployeeTransactions(
      employeeId,
      from: from,
      to: to,
    );
    double runningTotal = 0;
    for (final txn in transactions) {
      runningTotal += txn.amount;
    }
    return runningTotal;
  }

  Future<Map<String, dynamic>> getDeductionSummary(DateTime period) async {
    final month = period.month;
    final year = period.year;
    final transactionsRef = await companyCollection(_collection);
    final snapshot = await transactionsRef.get();

    final monthly = snapshot.docs
        .map((doc) => DeductionTransaction.fromJson(docData(doc)))
        .where((t) => t.payrollMonth == month && t.payrollYear == year)
        .toList();

    double totalAmount = 0;
    final byType = <String, double>{};
    final byEmployee = <String, double>{};

    for (final txn in monthly) {
      totalAmount += txn.amount;
      byType[txn.deductionTypeName] =
          (byType[txn.deductionTypeName] ?? 0) + txn.amount;
      byEmployee[txn.employeeId] =
          (byEmployee[txn.employeeId] ?? 0) + txn.amount;
    }

    return {
      'month': month,
      'year': year,
      'totalAmount': totalAmount,
      'transactionCount': monthly.length,
      'byType': byType,
      'byEmployee': byEmployee,
    };
  }

  List<DeductionTransaction> _filterAndSortByDate(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    DateTime? from,
    DateTime? to,
  }) {
    final items = docs
        .map((doc) => DeductionTransaction.fromJson(docData(doc)))
        .where((t) {
          if (from != null && t.processedAt.isBefore(from)) return false;
          if (to != null && t.processedAt.isAfter(to)) return false;
          return true;
        })
        .toList();

    items.sort((a, b) => b.processedAt.compareTo(a.processedAt));
    return items;
  }
}
