import 'package:cloud_firestore/cloud_firestore.dart';

enum ExitStatus {
  pending,
  underReview,
  approved,
  rejected,
  completed,
  cancelled,
}

enum ExitType {
  resignation,
  termination,
  contractExpiry,
  retirement,
  endOfInternship,
  mutualAgreement,
  absconding,
}

class FinalSettlement {
  final double proratedSalary;
  final double unusedLeaveValue;
  final double gratuity;
  final double pendingReimbursements;
  final double outstandingLoans;
  final double netSettlement;

  const FinalSettlement({
    required this.proratedSalary,
    required this.unusedLeaveValue,
    required this.gratuity,
    required this.pendingReimbursements,
    required this.outstandingLoans,
    required this.netSettlement,
  });

  Map<String, dynamic> toJson() {
    return {
      'proratedSalary': proratedSalary,
      'unusedLeaveValue': unusedLeaveValue,
      'gratuity': gratuity,
      'pendingReimbursements': pendingReimbursements,
      'outstandingLoans': outstandingLoans,
      'netSettlement': netSettlement,
    };
  }

  factory FinalSettlement.fromJson(Map<String, dynamic> json) {
    return FinalSettlement(
      proratedSalary: (json['proratedSalary'] ?? 0).toDouble(),
      unusedLeaveValue: (json['unusedLeaveValue'] ?? 0).toDouble(),
      gratuity: (json['gratuity'] ?? 0).toDouble(),
      pendingReimbursements: (json['pendingReimbursements'] ?? 0).toDouble(),
      outstandingLoans: (json['outstandingLoans'] ?? 0).toDouble(),
      netSettlement: (json['netSettlement'] ?? 0).toDouble(),
    );
  }
}

class ExitRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime resignationDate;
  final DateTime lastWorkingDate;
  final String reason;
  final ExitType exitType;
  final String? initiatedBy;
  final int noticePeriodDays;
  final DateTime noticeStartDate;
  final bool isShortNotice;
  final int shortNoticeDays;
  final bool eligibleForRehire;
  final String? rehireRemarks;
  final String? performanceRating;
  final ExitStatus status;
  final FinalSettlement? finalSettlement;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExitRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.resignationDate,
    required this.lastWorkingDate,
    required this.reason,
    this.exitType = ExitType.resignation,
    this.initiatedBy,
    this.noticePeriodDays = 0,
    DateTime? noticeStartDate,
    this.isShortNotice = false,
    this.shortNoticeDays = 0,
    this.eligibleForRehire = true,
    this.rehireRemarks,
    this.performanceRating,
    this.status = ExitStatus.pending,
    this.finalSettlement,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  }) : noticeStartDate = noticeStartDate ?? resignationDate;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'resignationDate': Timestamp.fromDate(resignationDate),
      'lastWorkingDate': Timestamp.fromDate(lastWorkingDate),
      'reason': reason,
      'exitType': exitType.name,
      'initiatedBy': initiatedBy,
      'noticePeriodDays': noticePeriodDays,
      'noticeStartDate': Timestamp.fromDate(noticeStartDate),
      'isShortNotice': isShortNotice,
      'shortNoticeDays': shortNoticeDays,
      'eligibleForRehire': eligibleForRehire,
      'rehireRemarks': rehireRemarks,
      'performanceRating': performanceRating,
      'status': status.name,
      'finalSettlement': finalSettlement?.toJson(),
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ExitRequest.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ExitRequest(
      id: (json['id'] ?? '').toString(),
      employeeId: (json['employeeId'] ?? '').toString(),
      employeeName: (json['employeeName'] ?? '').toString(),
      resignationDate: parseDate(json['resignationDate']),
      lastWorkingDate: parseDate(json['lastWorkingDate']),
      reason: (json['reason'] ?? '').toString(),
      exitType: ExitType.values.firstWhere(
        (value) => value.name == json['exitType'],
        orElse: () => ExitType.resignation,
      ),
      initiatedBy: json['initiatedBy']?.toString(),
      noticePeriodDays: (json['noticePeriodDays'] ?? 0).toInt(),
      noticeStartDate: parseDate(
        json['noticeStartDate'] ?? json['resignationDate'],
      ),
      isShortNotice: json['isShortNotice'] == true,
      shortNoticeDays: (json['shortNoticeDays'] ?? 0).toInt(),
      eligibleForRehire: json['eligibleForRehire'] ?? true,
      rehireRemarks: json['rehireRemarks']?.toString(),
      performanceRating: json['performanceRating']?.toString(),
      status: ExitStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => ExitStatus.pending,
      ),
      finalSettlement: json['finalSettlement'] is Map
          ? FinalSettlement.fromJson(
              (json['finalSettlement'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
      reviewedBy: json['reviewedBy']?.toString(),
      reviewedAt: parseNullableDate(json['reviewedAt']),
      rejectionReason: json['rejectionReason']?.toString(),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  ExitRequest copyWith({
    ExitType? exitType,
    String? initiatedBy,
    int? noticePeriodDays,
    DateTime? noticeStartDate,
    bool? isShortNotice,
    int? shortNoticeDays,
    bool? eligibleForRehire,
    String? rehireRemarks,
    String? performanceRating,
    ExitStatus? status,
    FinalSettlement? finalSettlement,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
    DateTime? updatedAt,
  }) {
    return ExitRequest(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      resignationDate: resignationDate,
      lastWorkingDate: lastWorkingDate,
      reason: reason,
      exitType: exitType ?? this.exitType,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      noticePeriodDays: noticePeriodDays ?? this.noticePeriodDays,
      noticeStartDate: noticeStartDate ?? this.noticeStartDate,
      isShortNotice: isShortNotice ?? this.isShortNotice,
      shortNoticeDays: shortNoticeDays ?? this.shortNoticeDays,
      eligibleForRehire: eligibleForRehire ?? this.eligibleForRehire,
      rehireRemarks: rehireRemarks ?? this.rehireRemarks,
      performanceRating: performanceRating ?? this.performanceRating,
      status: status ?? this.status,
      finalSettlement: finalSettlement ?? this.finalSettlement,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
