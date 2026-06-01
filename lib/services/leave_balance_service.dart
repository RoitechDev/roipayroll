import 'package:roipayroll/models/leave_balance_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/leave_type_service.dart';

class LeaveBalanceService extends BaseService {
  final String _collection = 'leave_balances';
  final _leaveTypeService = LeaveTypeService();

  Future<List<LeaveBalance>> getAllLeaveBalances(int year) async {
    final balancesRef = await companyCollection(_collection);
    final snapshot = await balancesRef.where('year', isEqualTo: year).get();

    return snapshot.docs
        .map((doc) => LeaveBalance.fromJson(docData(doc)))
        .toList();
  }

  Future<List<LeaveBalance>> getEmployeeLeaveBalances(String employeeId) async {
    final currentYear = DateTime.now().year;
    final balancesRef = await companyCollection(_collection);
    final snapshot = await balancesRef
        .where('employeeId', isEqualTo: employeeId)
        .where('year', isEqualTo: currentYear)
        .get();

    return snapshot.docs
        .map((doc) => LeaveBalance.fromJson(docData(doc)))
        .toList();
  }

  Future<LeaveBalance?> getBalance(
    String employeeId,
    String leaveTypeId,
  ) async {
    final currentYear = DateTime.now().year;
    final balancesRef = await companyCollection(_collection);
    final snapshot = await balancesRef
        .where('employeeId', isEqualTo: employeeId)
        .where('leaveTypeId', isEqualTo: leaveTypeId)
        .where('year', isEqualTo: currentYear)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return LeaveBalance.fromJson(docData(snapshot.docs.first));
  }

  // Initialize a single leave-type balance for one employee.
  // Called automatically by submitLeaveRequest() when no balance doc exists,
  // so employees never hit "balance not initialized" errors.
  Future<void> initializeBalanceForLeaveType(
    String employeeId,
    String employeeName,
    String leaveTypeId,
    String leaveTypeName,
  ) async {
    final currentYear = DateTime.now().year;
    final docId = '${employeeId}_${leaveTypeId}_$currentYear';

    // Check it doesn't already exist (race-condition guard)
    final balancesRef = await companyCollection(_collection);
    final existing = await balancesRef.doc(docId).get();
    if (existing.exists) return;

    // Try to get allocation days from the leave type config
    double allocatedDays = 0;
    try {
      final leaveType = await _leaveTypeService.getLeaveTypeById(leaveTypeId);
      allocatedDays = leaveType?.daysPerYear ?? 0;
    } catch (_) {
      allocatedDays = 0;
    }

    final balance = LeaveBalance(
      id: docId,
      employeeId: employeeId,
      employeeName: employeeName,
      leaveTypeId: leaveTypeId,
      leaveTypeName: leaveTypeName,
      year: currentYear,
      allocated: allocatedDays,
      allocatedDays: allocatedDays,
      carriedForward: 0,
      used: 0,
      pending: 0,
      pendingDays: 0,
      encashed: 0,
      lastUpdated: DateTime.now(),
    );

    await balancesRef.doc(balance.id).set(balance.toJson());
  }

  Future<void> initializeEmployeeBalances(
    String employeeId,
    String employeeName,
  ) async {
    final leaveTypes = await _leaveTypeService.getActiveLeaveTypes();
    final currentYear = DateTime.now().year;
    final balancesRef = await companyCollection(_collection);

    for (final leaveType in leaveTypes) {
      final balance = LeaveBalance(
        id: '${employeeId}_${leaveType.id}_$currentYear',
        employeeId: employeeId,
        employeeName: employeeName,
        leaveTypeId: leaveType.id,
        leaveTypeName: leaveType.name,
        year: currentYear,
        allocated: leaveType.daysPerYear,
        allocatedDays: leaveType.daysPerYear,
        carriedForward: 0,
        used: 0,
        pending: 0,
        pendingDays: 0,
        encashed: 0,
        lastUpdated: DateTime.now(),
      );

      await balancesRef.doc(balance.id).set(balance.toJson());
    }
  }

  Future<void> updateBalanceForRequest(
    String employeeId,
    String leaveTypeId,
    double days,
    bool isPending,
  ) async {
    final balance = await getBalance(employeeId, leaveTypeId);
    if (balance == null) return;

    double newPending = balance.pending;
    double newUsed = balance.used;

    if (isPending) {
      newPending += days;
    } else {
      newPending = newPending - days;
      if (newPending < 0) newPending = 0;
      newUsed += days;
    }

    final updated = balance.copyWith(
      pending: newPending,
      used: newUsed,
      lastUpdated: DateTime.now(),
    );

    final balancesRef = await companyCollection(_collection);
    await balancesRef.doc(balance.id).update(updated.toJson());
  }

  Future<void> cancelPendingBalance(
    String employeeId,
    String leaveTypeId,
    double days,
  ) async {
    final balance = await getBalance(employeeId, leaveTypeId);
    if (balance == null) return;

    double newPending = balance.pending - days;
    if (newPending < 0) newPending = 0;

    final updated = balance.copyWith(
      pending: newPending,
      lastUpdated: DateTime.now(),
    );

    final balancesRef = await companyCollection(_collection);
    await balancesRef.doc(balance.id).update(updated.toJson());
  }

  Future<void> updateBalanceForEncashment(
    String employeeId,
    String leaveTypeId,
    double days,
  ) async {
    final balance = await getBalance(employeeId, leaveTypeId);
    if (balance == null) return;

    final updated = balance.copyWith(
      encashed: balance.encashed + days,
      lastUpdated: DateTime.now(),
    );

    final balancesRef = await companyCollection(_collection);
    await balancesRef.doc(balance.id).update(updated.toJson());
  }

  Future<void> carryForwardLeaves(
    String employeeId,
    String employeeName,
  ) async {
    final currentYear = DateTime.now().year;
    final balances = await getEmployeeLeaveBalances(employeeId);

    for (final balance in balances) {
      final leaveType = await _leaveTypeService.getLeaveTypeById(
        balance.leaveTypeId,
      );
      if (leaveType == null || !leaveType.carryForward) continue;

      final availableBalance = balance.balance;
      final carryForward = availableBalance > leaveType.maxCarryForward
          ? leaveType.maxCarryForward
          : availableBalance;

      if (carryForward <= 0) continue;

      final nextYearBalance = LeaveBalance(
        id: '${employeeId}_${leaveType.id}_${currentYear + 1}',
        employeeId: employeeId,
        employeeName: employeeName,
        leaveTypeId: leaveType.id,
        leaveTypeName: leaveType.name,
        year: currentYear + 1,
        allocated: leaveType.daysPerYear,
        allocatedDays: leaveType.daysPerYear,
        carriedForward: carryForward,
        used: 0,
        pending: 0,
        pendingDays: 0,
        encashed: 0,
        lastUpdated: DateTime.now(),
      );

      final balancesRef = await companyCollection(_collection);
      await balancesRef.doc(nextYearBalance.id).set(nextYearBalance.toJson());
    }
  }
}
