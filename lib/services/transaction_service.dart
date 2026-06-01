import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/services/base_service.dart';

/// Shared helper for transactional financial operations.
class TransactionService extends BaseService {
  static const String _lockCollection = 'idempotency_locks';

  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) operation, {
    int maxRetries = 5,
  }) async {
    var attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await firestore.runTransaction<T>(operation);
      } on FirebaseException catch (error) {
        attempts++;
        if (error.code == 'aborted' && attempts < maxRetries) {
          debugPrint(
            'Transaction conflict, retrying... (attempt $attempts/$maxRetries)',
          );
          await Future.delayed(Duration(milliseconds: 100 * attempts));
          continue;
        }
        rethrow;
      }
    }

    throw Exception('Transaction failed after $maxRetries attempts.');
  }

  DocumentReference<Map<String, dynamic>> idempotencyLockRef(
    String companyId,
    String lockKey,
  ) {
    return companyCollectionRef(companyId, _lockCollection).doc(lockKey);
  }

  Future<bool> checkAndSetIdempotencyLock(
    Transaction transaction, {
    required String companyId,
    required String lockKey,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) async {
    final lockRef = idempotencyLockRef(companyId, lockKey);
    final lockDoc = await transaction.get(lockRef);

    if (lockDoc.exists) {
      debugPrint('Idempotency lock exists for: $lockKey');
      return false;
    }

    transaction.set(lockRef, {
      'lockKey': lockKey,
      'companyId': companyId,
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': metadata,
    });
    return true;
  }

  Future<void> removeIdempotencyLock(String companyId, String lockKey) async {
    await idempotencyLockRef(companyId, lockKey).delete();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    return transaction.get(ref);
  }

  void updateWithVersion(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> updates,
  ) {
    transaction.update(ref, {
      ...updates,
      'version': FieldValue.increment(1),
      'lastModified': FieldValue.serverTimestamp(),
    });
  }

  void setDoc(
    Transaction transaction,
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> data, {
    bool merge = false,
  }) {
    transaction.set(ref, {
      ...data,
      'version': data['version'] ?? 1,
      'createdAt': data.containsKey('createdAt')
          ? data['createdAt']
          : FieldValue.serverTimestamp(),
    }, SetOptions(merge: merge));
  }
}
