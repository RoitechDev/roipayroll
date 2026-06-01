import 'package:roipayroll/models/leave_type_model.dart';
import 'package:roipayroll/services/base_service.dart';

class LeaveTypeService extends BaseService {
  final String _collection = 'leave_types';

  Future<void> createLeaveType(LeaveType leaveType) async {
    final leaveTypesRef = await companyCollection(_collection);
    await leaveTypesRef.doc(leaveType.id).set(leaveType.toJson());
  }

  Future<List<LeaveType>> getActiveLeaveTypes() async {
    final leaveTypesRef = await companyCollection(_collection);
    final snapshot = await leaveTypesRef
        .where('isActive', isEqualTo: true)
        .get();

    final leaveTypes = snapshot.docs
        .map((doc) => LeaveType.fromJson(docData(doc)))
        .toList();
    leaveTypes.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return leaveTypes;
  }

  Future<List<LeaveType>> getAllLeaveTypes() async {
    final leaveTypesRef = await companyCollection(_collection);
    final snapshot = await leaveTypesRef.orderBy('name').get();

    return snapshot.docs
        .map((doc) => LeaveType.fromJson(docData(doc)))
        .toList();
  }

  Future<LeaveType?> getLeaveTypeById(String id) async {
    final leaveTypesRef = await companyCollection(_collection);
    final doc = await leaveTypesRef.doc(id).get();
    if (!doc.exists) return null;
    final data = docDataNullable(doc);
    return data == null ? null : LeaveType.fromJson(data);
  }

  Future<void> updateLeaveType(LeaveType leaveType) async {
    final leaveTypesRef = await companyCollection(_collection);
    await leaveTypesRef.doc(leaveType.id).update(leaveType.toJson());
  }

  Future<void> updateLeaveTypeFields(
    String leaveTypeId,
    Map<String, dynamic> fields,
  ) async {
    final leaveTypesRef = await companyCollection(_collection);
    await leaveTypesRef.doc(leaveTypeId).update(fields);
  }

  Future<void> seedDefaultLeaveTypesIfEmpty() async {
    final leaveTypesRef = await companyCollection(_collection);
    final existing = await leaveTypesRef.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final batch = firestore.batch();
    for (final type in LeaveType.defaultLeaveTypes) {
      final ref = leaveTypesRef.doc(type.id);
      batch.set(ref, type.toJson());
    }
    await batch.commit();
  }

  Future<void> initializeDefaultLeaveTypes() async {
    await seedDefaultLeaveTypesIfEmpty();
  }
}
