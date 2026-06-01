import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/probation_record_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:uuid/uuid.dart';

class ProbationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'probation_records';
  final _notificationService = NotificationService();

  // Create probation record
  Future<ProbationRecord> createProbationRecord({
    required String employeeId,
    required String employeeName,
    required DateTime startDate,
    required int durationMonths, required String employeeEmail,
  }) async {
    final endDate = DateTime(
      startDate.year,
      startDate.month + durationMonths,
      startDate.day,
    );

    final record = ProbationRecord(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      startDate: startDate,
      endDate: endDate,
      durationMonths: durationMonths,
      status: ProbationStatus.active,
    );

    await _firestore
        .collection(_collection)
        .doc(record.id)
        .set(record.toJson());

    // Notify HR
    await _notificationService.sendNotificationToRoles(
      roles: const [UserRole.admin, UserRole.hr],
      title: 'New Probation Started',
      message: '$employeeName started probation ($durationMonths months)',
      type: NotificationType.probation,
      data: {'employeeId': employeeId, 'probationId': record.id},
    );

    return record;
  }

  // Get probation record by employee
  Future<ProbationRecord?> getProbationByEmployee(String employeeId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: ProbationStatus.active.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ProbationRecord.fromJson(snapshot.docs.first.data());
  }

  // Get expiring probations (within days)
  Future<List<ProbationRecord>> getExpiringProbations(int withinDays) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: withinDays));

    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: ProbationStatus.active.name)
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('endDate')
        .get();

    return snapshot.docs
        .map((doc) => ProbationRecord.fromJson(doc.data()))
        .toList();
  }

  // Submit review
  Future<void> submitReview({
    required String probationId,
    required String reviewedBy,
    required String reviewNotes,
    required double performanceRating,
  }) async {
    await _firestore.collection(_collection).doc(probationId).update({
      'reviewNotes': reviewNotes,
      'reviewedBy': reviewedBy,
      'reviewedAt': Timestamp.fromDate(DateTime.now()),
      'performanceRating': performanceRating,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Confirm probation (convert to permanent)
  Future<void> confirmProbation({
    required String probationId,
    required String confirmedBy,
    String? confirmationNotes,
  }) async {
    await _firestore.collection(_collection).doc(probationId).update({
      'status': ProbationStatus.confirmed.name,
      'confirmedBy': confirmedBy,
      'confirmedAt': Timestamp.fromDate(DateTime.now()),
      'confirmationNotes': confirmationNotes,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    final record = await _getProbationById(probationId);
    if (record != null) {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Probation Confirmed',
        message: '${record.employeeName} successfully completed probation',
        type: NotificationType.probation,
        data: {'employeeId': record.employeeId, 'probationId': probationId},
      );
    }
  }

  // Extend probation
  Future<void> extendProbation({
    required String probationId,
    required int additionalMonths,
    required String extendedBy,
    String? extensionReason,
  }) async {
    final record = await _getProbationById(probationId);
    if (record == null) throw 'Probation record not found';

    final newEndDate = DateTime(
      record.endDate.year,
      record.endDate.month + additionalMonths,
      record.endDate.day,
    );

    await _firestore.collection(_collection).doc(probationId).update({
      'status': ProbationStatus.extended.name,
      'endDate': Timestamp.fromDate(newEndDate),
      'durationMonths': record.durationMonths + additionalMonths,
      'extendedBy': extendedBy,
      'extendedAt': Timestamp.fromDate(DateTime.now()),
      'extensionReason': extensionReason,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    await _notificationService.sendNotificationToRoles(
      roles: const [UserRole.admin, UserRole.hr],
      title: 'Probation Extended',
      message:
          '${record.employeeName} probation extended by $additionalMonths months',
      type: NotificationType.probation,
      data: {'employeeId': record.employeeId, 'probationId': probationId},
    );
  }

  // Terminate probation (employee failed)
  Future<void> terminateProbation({
    required String probationId,
    required String terminatedBy,
    required String terminationReason,
  }) async {
    await _firestore.collection(_collection).doc(probationId).update({
      'status': ProbationStatus.terminated.name,
      'terminatedBy': terminatedBy,
      'terminatedAt': Timestamp.fromDate(DateTime.now()),
      'terminationReason': terminationReason,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    final record = await _getProbationById(probationId);
    if (record != null) {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Probation Terminated',
        message: '${record.employeeName} probation terminated',
        type: NotificationType.probation,
        data: {'employeeId': record.employeeId, 'probationId': probationId},
      );
    }
  }

  // Get all probation records
  Future<List<ProbationRecord>> getAllProbationRecords({
    ProbationStatus? status,
  }) async {
    Query query = _firestore.collection(_collection);

    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snapshot = await query.orderBy('endDate', descending: false).get();
    return snapshot.docs
        .map((doc) => ProbationRecord.fromJson(doc.data() as Map<String, dynamic>))
        .toList();
  }

  // Send expiry alerts
  Future<void> sendExpiryAlerts() async {
    final expiring = await getExpiringProbations(30);

    for (var record in expiring) {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Probation Expiring Soon',
        message: '${record.employeeName} probation ends in ${record.daysRemaining} days',
        type: NotificationType.probation,
        data: {'employeeId': record.employeeId, 'probationId': record.id},
      );
    }
  }

  Future<ProbationRecord?> _getProbationById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (!doc.exists) return null;
    return ProbationRecord.fromJson(doc.data()!);
  }

  // ✅ ✅ ✅ THESE ARE THE 3 MISSING METHODS YOUR PROVIDER NEEDS ✅ ✅ ✅

  /// Get employees due for probation completion (within specified days)
  Future<List<Employee>> getEmployeesDueProbation({int withinDays = 30}) async {
    final expiring = await getExpiringProbations(withinDays);
    
    final List<Employee> employees = [];
    for (var probation in expiring) {
      try {
        final employeeDoc = await _firestore
            .collection('employees')
            .doc(probation.employeeId)
            .get();
        
        if (employeeDoc.exists) {
          employees.add(Employee.fromJson(employeeDoc.data()!));
        }
      } catch (e) {
        print('Error fetching employee ${probation.employeeId}: $e');
      }
    }
    
    return employees;
  }

  /// Get employees with expiring contracts (within specified days)
  Future<List<Employee>> getEmployeesWithExpiringContracts({int withinDays = 30}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: withinDays));

    final contractsSnapshot = await _firestore
        .collection('contract_records')
        .where('status', isEqualTo: 'active')
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    final List<Employee> employees = [];
    for (var contractDoc in contractsSnapshot.docs) {
      try {
        final contractData = contractDoc.data();
        final employeeId = contractData['employeeId'] as String;
        
        final employeeDoc = await _firestore
            .collection('employees')
            .doc(employeeId)
            .get();
        
        if (employeeDoc.exists) {
          employees.add(Employee.fromJson(employeeDoc.data()!));
        }
      } catch (e) {
        print('Error fetching employee: $e');
      }
    }
    
    return employees;
  }

  /// Send lifecycle reminders for probations and contracts
  Future<Map<String, int>> sendLifecycleReminders({int withinDays = 30}) async {
    int probationReminders = 0;
    int contractReminders = 0;

    // Send probation expiry alerts
    final expiringProbations = await getExpiringProbations(withinDays);
    for (var record in expiringProbations) {
      try {
        await _notificationService.sendNotificationToRoles(
          roles: const [UserRole.admin, UserRole.hr],
          title: 'Probation Expiring Soon',
          message: '${record.employeeName} probation ends in ${record.daysRemaining} days',
          type: NotificationType.probation,
          data: {'employeeId': record.employeeId, 'probationId': record.id},
        );
        probationReminders++;
      } catch (e) {
        print('Error sending probation reminder: $e');
      }
    }

    // Send contract expiry alerts
    final now = DateTime.now();
    final endDate = now.add(Duration(days: withinDays));
    
    final contractsSnapshot = await _firestore
        .collection('contract_records')
        .where('status', isEqualTo: 'active')
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    for (var contractDoc in contractsSnapshot.docs) {
      try {
        final contractData = contractDoc.data();
        final employeeName = contractData['employeeName'] as String;
        final employeeId = contractData['employeeId'] as String;
        final contractId = contractDoc.id;
        
        await _notificationService.sendNotificationToRoles(
          roles: const [UserRole.admin, UserRole.hr],
          title: 'Contract Expiring Soon',
          message: '$employeeName contract ending soon',
          type: NotificationType.contract,
          data: {'employeeId': employeeId, 'contractId': contractId},
        );
        contractReminders++;
      } catch (e) {
        print('Error sending contract reminder: $e');
      }
    }

    return {
      'probationReminders': probationReminders,
      'contractReminders': contractReminders,
      'total': probationReminders + contractReminders,
      'probationDue': probationReminders,
      'contractDue': contractReminders,
    };
  }
}