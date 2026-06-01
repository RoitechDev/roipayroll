import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/deduction_type_model.dart';
import 'package:roipayroll/services/base_service.dart';

class DeductionTypeService extends BaseService {
  final String _collection = 'deduction_types';

  Future<void> initializeDefaultTypes() async {
    final typesRef = await companyCollection(_collection);
    final existing = await typesRef.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final defaults = DeductionType.nigerianDefaults();
    final batch = firestore.batch();
    for (final type in defaults) {
      final ref = typesRef.doc(type.id);
      batch.set(ref, type.toJson());
    }
    await batch.commit();
  }

  Future<List<DeductionType>> getAllDeductionTypes() async {
    final typesRef = await companyCollection(_collection);
    final snapshot = await typesRef.get();
    final types = snapshot.docs
        .map((doc) => DeductionType.fromJson(docData(doc)))
        .toList();
    types.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return types;
  }

  Future<List<DeductionType>> getActiveDeductionTypes() async {
    final typesRef = await companyCollection(_collection);
    final snapshot = await typesRef.where('isActive', isEqualTo: true).get();
    final types = snapshot.docs
        .map((doc) => DeductionType.fromJson(docData(doc)))
        .toList();
    types.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return types;
  }

  Future<DeductionType?> getDeductionTypeById(String id) async {
    final typesRef = await companyCollection(_collection);
    final doc = await typesRef.doc(id).get();
    if (!doc.exists) return null;
    final data = docDataNullable(doc);
    return data == null ? null : DeductionType.fromJson(data);
  }

  Future<List<DeductionType>> getTypesByCategory(
    DeductionCategory category,
  ) async {
    final typesRef = await companyCollection(_collection);
    final snapshot = await typesRef
        .where('category', isEqualTo: category.name)
        .get();
    final types = snapshot.docs
        .map((doc) => DeductionType.fromJson(docData(doc)))
        .toList();
    types.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return types;
  }

  Future<void> createDeductionType(DeductionType type) async {
    final typesRef = await companyCollection(_collection);
    await typesRef.doc(type.id).set(type.toJson());
  }

  Future<void> updateDeductionType(String id, Map<String, dynamic> data) async {
    final typesRef = await companyCollection(_collection);
    await typesRef.doc(id).update({
      ...data,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> toggleActive(String id) async {
    final typesRef = await companyCollection(_collection);
    final doc = await typesRef.doc(id).get();
    if (!doc.exists) return;

    final data = docDataNullable(doc);
    if (data == null) return;
    final current = DeductionType.fromJson(data);
    await typesRef.doc(id).update({
      'isActive': !current.isActive,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
