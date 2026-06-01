import 'package:cloud_firestore/cloud_firestore.dart';

enum ProbationStatus {
  active,
  extended,
  confirmed,
  terminated,
}

class ProbationRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String? employeeEmail;
  
  // Probation Details
  final DateTime startDate;
  final DateTime endDate;
  final int durationMonths;
  final ProbationStatus status;
  
  // Review
  final String? reviewNotes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final double? performanceRating; // 1-5 scale
  
  // Confirmation
  final bool isConfirmed;
  final DateTime? confirmationDate;
  final String? confirmedBy;
  final String? confirmationRemarks;
  
  // Extension
  final bool isExtended;
  final DateTime? extensionEndDate;
  final String? extensionReason;
  
  // Metadata
  final DateTime createdAt;
  final DateTime? updatedAt;

  ProbationRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    this.employeeEmail,
    required this.startDate,
    required this.endDate,
    required this.durationMonths,
    this.status = ProbationStatus.active,
    this.reviewNotes,
    this.reviewedBy,
    this.reviewedAt,
    this.performanceRating,
    this.isConfirmed = false,
    this.confirmationDate,
    this.confirmedBy,
    this.confirmationRemarks,
    this.isExtended = false,
    this.extensionEndDate,
    this.extensionReason,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Days remaining
  int get daysRemaining {
    final now = DateTime.now();
    final targetDate = extensionEndDate ?? endDate;
    return targetDate.difference(now).inDays;
  }

  // Is expiring soon (within 30 days)
  bool get isExpiringSoon => daysRemaining <= 30 && daysRemaining > 0;

  // Is expired
  bool get isExpired => daysRemaining < 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'employeeEmail': employeeEmail,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'durationMonths': durationMonths,
      'status': status.name,
      'reviewNotes': reviewNotes,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'performanceRating': performanceRating,
      'isConfirmed': isConfirmed,
      'confirmationDate': confirmationDate != null ? Timestamp.fromDate(confirmationDate!) : null,
      'confirmedBy': confirmedBy,
      'confirmationRemarks': confirmationRemarks,
      'isExtended': isExtended,
      'extensionEndDate': extensionEndDate != null ? Timestamp.fromDate(extensionEndDate!) : null,
      'extensionReason': extensionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory ProbationRecord.fromJson(Map<String, dynamic> json) {
    return ProbationRecord(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      employeeEmail: json['employeeEmail'],
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: (json['endDate'] as Timestamp).toDate(),
      durationMonths: json['durationMonths'],
      status: ProbationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ProbationStatus.active,
      ),
      reviewNotes: json['reviewNotes'],
      reviewedBy: json['reviewedBy'],
      reviewedAt: json['reviewedAt'] != null ? (json['reviewedAt'] as Timestamp).toDate() : null,
      performanceRating: json['performanceRating']?.toDouble(),
      isConfirmed: json['isConfirmed'] ?? false,
      confirmationDate: json['confirmationDate'] != null ? (json['confirmationDate'] as Timestamp).toDate() : null,
      confirmedBy: json['confirmedBy'],
      confirmationRemarks: json['confirmationRemarks'],
      isExtended: json['isExtended'] ?? false,
      extensionEndDate: json['extensionEndDate'] != null ? (json['extensionEndDate'] as Timestamp).toDate() : null,
      extensionReason: json['extensionReason'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null ? (json['updatedAt'] as Timestamp).toDate() : null,
    );
  }
}
