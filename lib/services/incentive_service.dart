import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/core/utils/currency_formatter.dart';
import 'package:roipayroll/models/commission_rule_model.dart';
import 'package:roipayroll/models/incentive_entry_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:uuid/uuid.dart';

class IncentiveService extends BaseService {
  final String _collection = 'incentives';
  final NotificationService _notificationService = NotificationService();

  Future<IncentiveEntry> submitIncentive({
    required String employeeId,
    required String employeeName,
    required IncentiveType type,
    required double amount,
    required String description,
    required DateTime incentiveDate,
    double? salesAmount,
    double? commissionRatePercent,
    String? tierName,
    String? performancePeriod,
    BonusCategory? bonusCategory,
    String? bonusTemplateId,
    bool isTaxable = true,
  }) async {
    final entry = IncentiveEntry(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      type: type,
      amount: amount,
      description: description,
      incentiveDate: DateTime(
        incentiveDate.year,
        incentiveDate.month,
        incentiveDate.day,
      ),
      submittedAt: DateTime.now(),
      salesAmount: salesAmount,
      commissionRatePercent: commissionRatePercent,
      tierName: tierName?.trim().isEmpty == true ? null : tierName?.trim(),
      performancePeriod: performancePeriod?.trim().isEmpty == true
          ? null
          : performancePeriod?.trim(),
      bonusCategory: bonusCategory,
      bonusTemplateId: bonusTemplateId?.trim().isEmpty == true
          ? null
          : bonusTemplateId?.trim(),
      isTaxable: isTaxable,
    );

    final ref = await companyCollection(_collection);
    await ref.doc(entry.id).set(entry.toJson());
    await _notifyApproversOfNewEntry(entry);
    return entry;
  }

  Future<List<IncentiveEntry>> getEmployeeIncentives(String employeeId) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.where('employeeId', isEqualTo: employeeId).get();
    final entries = snapshot.docs
        .map((doc) => IncentiveEntry.fromJson(docData(doc)))
        .toList();
    entries.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return entries;
  }

  Future<List<IncentiveEntry>> getPendingIncentives() async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('status', isEqualTo: IncentiveStatus.pending.name)
        .get();
    final entries = snapshot.docs
        .map((doc) => IncentiveEntry.fromJson(docData(doc)))
        .toList();
    entries.sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    return entries;
  }

  Future<void> approveIncentive(
    String id,
    String approverId,
    String approverName,
  ) async {
    final ref = await companyCollection(_collection);
    final doc = await ref.doc(id).get();
    final data = docDataNullable(doc);
    if (data == null) {
      throw Exception('Incentive entry not found.');
    }
    final entry = IncentiveEntry.fromJson(data);

    await ref.doc(id).update({
      'status': IncentiveStatus.approved.name,
      'approvedBy': approverId,
      'approvedByName': approverName,
      'approvedAt': Timestamp.now(),
      'rejectionReason': null,
    });

    await _notifyEmployeeDecision(
      entry,
      approved: true,
      approverName: approverName,
    );
  }

  Future<void> rejectIncentive(
    String id,
    String approverId,
    String approverName,
    String reason,
  ) async {
    final ref = await companyCollection(_collection);
    final doc = await ref.doc(id).get();
    final data = docDataNullable(doc);
    if (data == null) {
      throw Exception('Incentive entry not found.');
    }
    final entry = IncentiveEntry.fromJson(data);

    await ref.doc(id).update({
      'status': IncentiveStatus.rejected.name,
      'approvedBy': approverId,
      'approvedByName': approverName,
      'approvedAt': Timestamp.now(),
      'rejectionReason': reason,
    });

    await _notifyEmployeeDecision(
      entry,
      approved: false,
      approverName: approverName,
      rejectionReason: reason,
    );
  }

  Future<List<IncentiveEntry>> getApprovedIncentivesForPayroll(
    String employeeId,
    int month,
    int year,
  ) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: IncentiveStatus.approved.name)
        .get();

    final periodEnd = DateTime(year, month + 1, 0, 23, 59, 59, 999);
    return snapshot.docs
        .map((doc) => IncentiveEntry.fromJson(docData(doc)))
        .where((entry) {
          if (entry.payrollId != null && entry.payrollId!.trim().isNotEmpty) {
            return false;
          }
          if (entry.approvedAt == null) return false;
          return !entry.approvedAt!.isAfter(periodEnd);
        })
        .toList();
  }

  Future<void> markIncentivesPaid(
    List<String> incentiveIds, {
    required String payrollId,
    required int payrollMonth,
    required int payrollYear,
  }) async {
    if (incentiveIds.isEmpty) return;
    final ref = await companyCollection(_collection);
    final batch = firestore.batch();
    for (final id in incentiveIds) {
      batch.update(ref.doc(id), {
        'status': IncentiveStatus.paid.name,
        'payrollId': payrollId,
        'payrollMonth': payrollMonth,
        'payrollYear': payrollYear,
        'paidAt': Timestamp.now(),
      });
    }
    await batch.commit();
  }

  Future<void> unmarkIncentivesPaidForPayroll(String payrollId) async {
    final normalizedPayrollId = payrollId.trim();
    if (normalizedPayrollId.isEmpty) return;

    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('payrollId', isEqualTo: normalizedPayrollId)
        .get();
    if (snapshot.docs.isEmpty) return;

    final batch = firestore.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': IncentiveStatus.approved.name,
        'payrollId': null,
        'payrollMonth': null,
        'payrollYear': null,
        'paidAt': null,
      });
    }
    await batch.commit();
  }

  TieredCommissionResult calculateTieredCommission(
    double salesAmount,
    List<CommissionTier> tiers,
  ) {
    double totalCommission = 0;
    double remainingSales = salesAmount;
    String tierName = '';

    final sortedTiers = List<CommissionTier>.from(tiers)
      ..sort((a, b) => a.minSales.compareTo(b.minSales));

    for (final tier in sortedTiers) {
      if (remainingSales <= 0) break;

      final tierRange = tier.maxSales - tier.minSales;
      final salesInTier = remainingSales > tierRange
          ? tierRange
          : remainingSales;

      totalCommission += salesInTier * (tier.ratePercent / 100);
      remainingSales -= salesInTier;

      tierName = '${tier.ratePercent}%';
    }

    return TieredCommissionResult(
      totalCommission: totalCommission,
      tierName: tierName,
      averageRate: salesAmount > 0 ? (totalCommission / salesAmount) * 100 : 0,
    );
  }

  Future<List<IncentiveEntry>> createBulkBonus({
    required List<Map<String, String>> employees,
    required double amount,
    required String description,
    BonusCategory? category,
    String? bonusTemplateId,
    bool isTaxable = true,
  }) async {
    final entries = <IncentiveEntry>[];

    for (final emp in employees) {
      final entry = await submitIncentive(
        employeeId: emp['id']!,
        employeeName: emp['name']!,
        type: IncentiveType.bonus,
        amount: amount,
        description: description,
        incentiveDate: DateTime.now(),
        bonusCategory: category,
        bonusTemplateId: bonusTemplateId,
        isTaxable: isTaxable,
      );

      entries.add(entry);
    }

    return entries;
  }

  Future<void> _notifyApproversOfNewEntry(IncentiveEntry entry) async {
    try {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr, UserRole.accountant],
        title: 'New Incentive Entry',
        message:
            '${entry.employeeName} submitted ${CurrencyFormatter.formatNaira(entry.amount)} for ${entry.type.name}.',
        type: NotificationType.general,
        data: {
          'type': 'incentive_request',
          'incentiveId': entry.id,
          'employeeId': entry.employeeId,
          'employeeName': entry.employeeName,
          'incentiveType': entry.type.name,
          'amount': entry.amount,
          'submittedAt': entry.submittedAt.toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error sending incentive request notification: $e');
    }
  }

  Future<void> _notifyEmployeeDecision(
    IncentiveEntry entry, {
    required bool approved,
    required String approverName,
    String? rejectionReason,
  }) async {
    try {
      final employeesRef = await companyCollection('employees');
      final employeeDoc = await employeesRef.doc(entry.employeeId).get();
      final employeeData = docDataNullable(employeeDoc);
      final userId = employeeData?['userId'];
      if (userId == null || userId.toString().trim().isEmpty) return;

      await _notificationService.sendNotification(
        userId: userId.toString(),
        title: approved ? 'Incentive Approved' : 'Incentive Rejected',
        message: approved
            ? 'Your incentive entry for ${CurrencyFormatter.formatNaira(entry.amount)} was approved by $approverName.'
            : 'Your incentive entry for ${CurrencyFormatter.formatNaira(entry.amount)} was rejected by $approverName. Reason: ${rejectionReason ?? 'No reason provided'}.',
        type: NotificationType.general,
        data: {
          'type': approved ? 'incentive_approved' : 'incentive_rejected',
          'incentiveId': entry.id,
          'employeeId': entry.employeeId,
          'employeeName': entry.employeeName,
          'incentiveType': entry.type.name,
          'amount': entry.amount,
          'approvedBy': approverName,
          if (!approved) 'rejectionReason': rejectionReason,
        },
      );
    } catch (e) {
      debugPrint('Error sending incentive decision notification: $e');
    }
  }
}

class TieredCommissionResult {
  final double totalCommission;
  final String tierName;
  final double averageRate;

  TieredCommissionResult({
    required this.totalCommission,
    required this.tierName,
    required this.averageRate,
  });
}
