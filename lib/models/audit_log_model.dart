import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditAction {
  employeeCreated,
  employeeUpdated,
  employeeDeleted,
  softDelete,
  restore,
  payrollProcessed,
  payrollReversed,
  payrollCorrected,
  payrollRetroactiveProcessed,
  payrollDeleted,
  payrollLocked,
  loanApproved,
  loanRejected,
  userCreated,
  userInvited,
  userUpdated,
  userDeleted,
  userRoleChanged,
  deductionAssigned,
  leaveApproved,
  leaveRejected,
}

class AuditLog {
  final String id;
  final AuditAction action;
  final String userId;
  final String userName;
  final String entityType;
  final String entityId;
  final String? entityName;
  final Map<String, dynamic>? before;
  final Map<String, dynamic>? after;
  final DateTime timestamp;
  final String ipAddress;

  AuditLog({
    required this.id,
    required this.action,
    required this.userId,
    required this.userName,
    required this.entityType,
    required this.entityId,
    this.entityName,
    this.before,
    this.after,
    required this.timestamp,
    required this.ipAddress,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'userId': userId,
      'userName': userName,
      'entityType': entityType,
      'entityId': entityId,
      'entityName': entityName,
      'before': before,
      'after': after,
      'timestamp': Timestamp.fromDate(timestamp),
      'ipAddress': ipAddress,
    };
  }

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    DateTime readTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now();
    }

    Map<String, dynamic>? readMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      return null;
    }

    return AuditLog(
      id: (json['id'] ?? '').toString(),
      action: AuditAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => AuditAction.employeeUpdated,
      ),
      userId: (json['userId'] ?? '').toString(),
      userName: (json['userName'] ?? '').toString(),
      entityType: (json['entityType'] ?? '').toString(),
      entityId: (json['entityId'] ?? '').toString(),
      entityName: json['entityName']?.toString(),
      before: readMap(json['before']),
      after: readMap(json['after']),
      timestamp: readTimestamp(json['timestamp']),
      ipAddress: (json['ipAddress'] ?? 'web').toString(),
    );
  }
}
