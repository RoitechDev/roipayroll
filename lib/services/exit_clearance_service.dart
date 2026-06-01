import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/exit_clearance_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:uuid/uuid.dart';

class ExitClearanceService extends BaseService {
  final String _collection = 'exit_clearance_items';

  Future<List<ClearanceItem>> getClearanceItems(String exitRequestId) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref
        .where('exitRequestId', isEqualTo: exitRequestId)
        .get();
    return snapshot.docs
        .map((doc) => ClearanceItem.fromJson(docData(doc)))
        .toList();
  }

  Future<List<ClearanceItem>> ensureClearanceChecklist(
    String exitRequestId,
  ) async {
    final existing = await getClearanceItems(exitRequestId);
    if (existing.isNotEmpty) return existing;

    final defaults = <ClearanceItem>[
      ClearanceItem(
        id: const Uuid().v4(),
        exitRequestId: exitRequestId,
        department: ClearanceDepartment.it,
        description: 'Return laptop, phone, access cards',
      ),
      ClearanceItem(
        id: const Uuid().v4(),
        exitRequestId: exitRequestId,
        department: ClearanceDepartment.finance,
        description: 'Clear outstanding payments and liabilities',
      ),
      ClearanceItem(
        id: const Uuid().v4(),
        exitRequestId: exitRequestId,
        department: ClearanceDepartment.hr,
        description: 'Complete exit interview and documentation',
      ),
      ClearanceItem(
        id: const Uuid().v4(),
        exitRequestId: exitRequestId,
        department: ClearanceDepartment.admin,
        description: 'Return ID card, keys, parking pass',
      ),
    ];

    final ref = await companyCollection(_collection);
    final batch = firestore.batch();
    for (final item in defaults) {
      batch.set(ref.doc(item.id), item.toJson());
    }
    await batch.commit();
    return defaults;
  }

  Future<void> updateClearanceItemStatus({
    required String itemId,
    required ClearanceStatus status,
    String? clearedBy,
    String? remarks,
  }) async {
    final ref = await companyCollection(_collection);
    await ref.doc(itemId).update({
      'status': status.name,
      'clearedBy': clearedBy,
      'clearedAt': status == ClearanceStatus.cleared
          ? Timestamp.fromDate(DateTime.now())
          : null,
      'remarks': remarks,
    });
  }

  Future<bool> isExitFullyCleared(String exitRequestId) async {
    final items = await getClearanceItems(exitRequestId);
    if (items.isEmpty) return false;
    return items.every(
      (item) =>
          item.status == ClearanceStatus.cleared ||
          item.status == ClearanceStatus.notApplicable,
    );
  }
}
