import 'package:cloud_firestore/cloud_firestore.dart';

enum ClearanceDepartment {
  it,
  finance,
  hr,
  admin,
}

enum ClearanceStatus {
  pending,
  cleared,
  notApplicable,
}

class ClearanceItem {
  final String id;
  final String exitRequestId;
  final ClearanceDepartment department;
  final String description;
  final ClearanceStatus status;
  final String? clearedBy;
  final DateTime? clearedAt;
  final String? remarks;

  const ClearanceItem({
    required this.id,
    required this.exitRequestId,
    required this.department,
    required this.description,
    this.status = ClearanceStatus.pending,
    this.clearedBy,
    this.clearedAt,
    this.remarks,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exitRequestId': exitRequestId,
      'department': department.name,
      'description': description,
      'status': status.name,
      'clearedBy': clearedBy,
      'clearedAt': clearedAt != null ? Timestamp.fromDate(clearedAt!) : null,
      'remarks': remarks,
    };
  }

  factory ClearanceItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ClearanceItem(
      id: (json['id'] ?? '').toString(),
      exitRequestId: (json['exitRequestId'] ?? '').toString(),
      department: ClearanceDepartment.values.firstWhere(
        (value) => value.name == json['department'],
        orElse: () => ClearanceDepartment.hr,
      ),
      description: (json['description'] ?? '').toString(),
      status: ClearanceStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => ClearanceStatus.pending,
      ),
      clearedBy: json['clearedBy']?.toString(),
      clearedAt: parseNullableDate(json['clearedAt']),
      remarks: json['remarks']?.toString(),
    );
  }
}
