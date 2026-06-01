import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/leave_encashment_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/leave_balance_service.dart';

class LeaveEncashmentService extends BaseService {
  final String _collection = 'leave_encashments';
  final _leaveBalanceService = LeaveBalanceService();

  // Submit encashment request
  Future<LeaveEncashment> submitEncashmentRequest(
    LeaveEncashment request,
  ) async {
    // Validate available balance before encashment
    final balance = await _leaveBalanceService.getBalance(
      request.employeeId,
      request.leaveTypeId,
    );
    if (balance == null) {
      throw Exception('Leave balance not initialized for this leave type.');
    }
    if (request.daysToEncash > balance.availableBalance) {
      throw Exception(
        'Insufficient leave balance. Available: ${balance.availableBalance.toStringAsFixed(1)} days.',
      );
    }

    final encashmentsRef = await companyCollection(_collection);
    await encashmentsRef.doc(request.id).set(request.toJson());

    return request;
  }

  // Approve encashment
  Future<void> approveEncashment(
    String encashmentId,
    String approverId,
    String approverName, {
    String? remarks,
  }) async {
    final encashment = await getEncashmentById(encashmentId);
    if (encashment == null) throw Exception('Encashment not found');

    final encashmentsRef = await companyCollection(_collection);
    await encashmentsRef.doc(encashmentId).update({
      'status': EncashmentStatus.approved.name,
      'processedAt': Timestamp.fromDate(DateTime.now()),
      'processedBy': approverId,
      'processedByName': approverName,
      'remarks': remarks,
    });

    // Update balance
    await _leaveBalanceService.updateBalanceForEncashment(
      encashment.employeeId,
      encashment.leaveTypeId,
      encashment.daysToEncash,
    );
  }

  // Reject encashment
  Future<void> rejectEncashment(
    String encashmentId,
    String approverId,
    String approverName,
    String remarks,
  ) async {
    final encashmentsRef = await companyCollection(_collection);
    await encashmentsRef.doc(encashmentId).update({
      'status': EncashmentStatus.rejected.name,
      'processedAt': Timestamp.fromDate(DateTime.now()),
      'processedBy': approverId,
      'processedByName': approverName,
      'remarks': remarks,
    });
  }

  // Get encashment by ID
  Future<LeaveEncashment?> getEncashmentById(String id) async {
    final encashmentsRef = await companyCollection(_collection);
    final doc = await encashmentsRef.doc(id).get();
    if (!doc.exists) return null;
    final data = docDataNullable(doc);
    return data == null ? null : LeaveEncashment.fromJson(data);
  }

  // Get employee encashments
  Future<List<LeaveEncashment>> getEmployeeEncashments(
    String employeeId,
  ) async {
    final encashmentsRef = await companyCollection(_collection);
    final snapshot = await encashmentsRef
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('requestedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => LeaveEncashment.fromJson(docData(doc)))
        .toList();
  }

  // Get pending encashments
  Future<List<LeaveEncashment>> getPendingEncashments() async {
    final encashmentsRef = await companyCollection(_collection);
    final snapshot = await encashmentsRef
        .where('status', isEqualTo: EncashmentStatus.pending.name)
        .orderBy('requestedAt', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => LeaveEncashment.fromJson(docData(doc)))
        .toList();
  }

  Future<List<LeaveEncashment>> getProcessedEncashments() async {
    final encashmentsRef = await companyCollection(_collection);
    final snapshot = await encashmentsRef.get();

    final processed = snapshot.docs
        .map((doc) => LeaveEncashment.fromJson(docData(doc)))
        .where((encashment) => encashment.status != EncashmentStatus.pending)
        .toList();
    processed.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return processed;
  }
}
