import 'package:roipayroll/models/audit_log_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:uuid/uuid.dart';

class AuditService extends BaseService {
  final String _collection = 'audit_logs';
  final UserService userService;

  AuditService({required this.userService});

  Future<void> logAction({
    required AuditAction action,
    required String entityType,
    required String entityId,
    String? entityName,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    String? userId,
    String? userName,
  }) async {
    try {
      final actor = await userService.getCurrentUserProfile();
      final log = AuditLog(
        id: const Uuid().v4(),
        action: action,
        userId: userId ?? actor?.id ?? 'system',
        userName: userName ?? actor?.name ?? 'System',
        entityType: entityType,
        entityId: entityId,
        entityName: entityName,
        before: before,
        after: after,
        timestamp: DateTime.now(),
        ipAddress: 'web',
      );

      final logsRef = await companyCollection(_collection);
      await logsRef.doc(log.id).set(log.toJson());
    } catch (_) {
      // Audit logging should not block business operations.
    }
  }

  Future<List<AuditLog>> getRecentLogs({int limit = 50}) async {
    final logsRef = await companyCollection(_collection);
    final snapshot = await logsRef
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => AuditLog.fromJson(docData(doc))).toList();
  }
}
