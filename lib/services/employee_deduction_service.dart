import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/audit_log_model.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/models/employee_deduction_model.dart';
import 'package:roipayroll/services/audit_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/user_service.dart';

class EmployeeDeductionService extends BaseService {
  // FIX: Changed from 'employee_deductions_v2' to 'employee_deductions'
  final String _collection = 'employee_deductions';
  late final AuditService _auditService;

  EmployeeDeductionService({required UserService userService}) {
    _auditService = AuditService(userService: userService);
  }

  Future<void> assignDeduction(EmployeeDeduction employeeDeduction) async {
    final deductionsRef = await companyCollection(_collection);
    await deductionsRef
        .doc(employeeDeduction.id)
        .set(employeeDeduction.toJson());
    await _auditService.logAction(
      action: AuditAction.deductionAssigned,
      entityType: 'deduction',
      entityId: employeeDeduction.id,
      entityName:
          '${employeeDeduction.employeeName} - ${employeeDeduction.deductionTypeName}',
      after: employeeDeduction.toJson(),
    );
  }

  Future<EmployeeDeduction?> getDeductionById(String id) async {
    final deductionsRef = await companyCollection(_collection);
    final doc = await deductionsRef.doc(id).get();
    if (!doc.exists) return null;
    final data = docDataNullable(doc);
    return data == null ? null : EmployeeDeduction.fromJson(data);
  }

  Future<List<EmployeeDeduction>> getEmployeeDeductions(
    String employeeId, {
    DeductionStatus? status,
  }) async {
    final deductionsRef = await companyCollection(_collection);
    Query<Map<String, dynamic>> query = deductionsRef.where(
      'employeeId',
      isEqualTo: employeeId,
    );

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snapshot = await query.get();
    final deductions = snapshot.docs
        .map((doc) => EmployeeDeduction.fromJson(docData(doc)))
        .toList();
    deductions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deductions;
  }

  Future<List<EmployeeDeduction>> getActiveDeductions(String employeeId) async {
    final now = DateTime.now();
    final all = await getEmployeeDeductions(
      employeeId,
      status: DeductionStatus.active,
    );

    return all.where((d) {
      if (d.nextDeductionDate == null) return true;
      return !d.nextDeductionDate!.isAfter(now);
    }).toList();
  }

  Future<List<EmployeeDeduction>> getAllDeductions({
    DeductionStatus? status,
    DeductionCategory? category,
  }) async {
    final deductionsRef = await companyCollection(_collection);
    final snapshot = await deductionsRef.get();
    var deductions = snapshot.docs
        .map((doc) => EmployeeDeduction.fromJson(docData(doc)))
        .toList();

    if (status != null) {
      deductions = deductions.where((d) => d.status == status).toList();
    }
    if (category != null) {
      deductions = deductions.where((d) => d.category == category).toList();
    }

    deductions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return deductions;
  }

  Future<void> updateDeductionProgress(String id, double amount) async {
    final deduction = await getDeductionById(id);
    if (deduction == null) return;

    final newAmountDeducted = deduction.amountDeducted + amount;
    final newBalance = deduction.totalAmount - newAmountDeducted;
    final newInstallmentsPaid = deduction.installmentsPaid + 1;
    final isComplete = newBalance <= 0.01; // Account for floating point

    final updates = {
      'amountDeducted': newAmountDeducted,
      'balance': newBalance,
      'installmentsPaid': newInstallmentsPaid,
      'updatedAt': Timestamp.now(),
    };

    if (isComplete) {
      updates['status'] = DeductionStatus.completed.name;
      updates['completedAt'] = Timestamp.now();
    }

    final deductionsRef = await companyCollection(_collection);
    await deductionsRef.doc(id).update(updates);
  }

  Future<void> reverseDeductionProgress(String id, double amount) async {
    final deduction = await getDeductionById(id);
    if (deduction == null) return;

    final reversedAmount = amount < 0 ? 0.0 : amount;
    final newTotalDeducted = (deduction.amountDeducted - reversedAmount)
        .clamp(0.0, deduction.totalAmount)
        .toDouble();
    final newInstallmentsPaid = deduction.installmentsPaid > 0
        ? deduction.installmentsPaid - 1
        : 0;

    final deductionsRef = await companyCollection(_collection);
    await deductionsRef.doc(id).update({
      'amountDeducted': newTotalDeducted,
      'totalDeducted': newTotalDeducted,
      'balance': deduction.totalAmount - newTotalDeducted,
      'installmentsPaid': newInstallmentsPaid,
      'status': DeductionStatus.active.name,
      'completedAt': null,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> completeDeduction(String id) async {
    final deductionsRef = await companyCollection(_collection);
    await deductionsRef.doc(id).update({
      'status': DeductionStatus.completed.name,
      'completedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> suspendDeduction(String id) async {
    final deductionsRef = await companyCollection(_collection);
    await deductionsRef.doc(id).update({
      'status': DeductionStatus.suspended.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> resumeDeduction(String id) async {
    final deductionsRef = await companyCollection(_collection);
    await deductionsRef.doc(id).update({
      'status': DeductionStatus.active.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> cancelDeduction(String id) async {
    final deductionsRef = await companyCollection(_collection);
    await deductionsRef.doc(id).update({
      'status': DeductionStatus.cancelled.name,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> approveDeduction(String id, String approverId) async {
    final deductionsRef = await companyCollection(_collection);
    await deductionsRef.doc(id).update({
      'status': DeductionStatus.active.name,
      'approvedBy': approverId,
      'approvedAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> updateNextDeductionDate(String id, DateTime nextDate) async {
    final deductionsRef = await companyCollection(_collection);
    await deductionsRef.doc(id).update({
      'nextDeductionDate': Timestamp.fromDate(nextDate),
      'updatedAt': Timestamp.now(),
    });
  }

  // Get summary for employee
  Future<Map<String, double>> getEmployeeSummary(String employeeId) async {
    final deductions = await getEmployeeDeductions(employeeId);

    double totalActive = 0;
    double totalCompleted = 0;
    double remainingBalance = 0;

    for (final d in deductions) {
      if (d.status == DeductionStatus.active) {
        totalActive += d.amountPerPayroll;
        remainingBalance += d.balance;
      } else if (d.status == DeductionStatus.completed) {
        totalCompleted += d.totalAmount;
      }
    }

    return {
      'totalActive': totalActive,
      'totalCompleted': totalCompleted,
      'remainingBalance': remainingBalance,
    };
  }
}
