import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveRequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

enum LeaveDurationType {
  fullDay,
  halfDay,
  multipleDays,
}

/// Leave Request/Application
class LeaveRequest {
  final String id;
  final String employeeId;
  final String employeeName;
  final String leaveTypeId;
  final String leaveTypeName;
  
  // Request Details
  final DateTime startDate;
  final DateTime endDate;
  final double numberOfDays;
  final LeaveDurationType durationType;
  final String reason;
  final List<String>? attachmentUrls; // Medical certificates, etc.
  
  // Status
  final LeaveRequestStatus status;
  final DateTime requestedAt;
  final DateTime? processedAt;
  final String? processedBy;
  final String? processedByName;
  final String? remarks; // Approval/rejection remarks
  
  // Contact
  final String? contactPhone;
  final String? contactAddress;
  
  // Handover
  final String? handoverTo; // Employee ID
  final String? handoverToName;
  final String? handoverNotes;

  LeaveRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.startDate,
    required this.endDate,
    required this.numberOfDays,
    required this.durationType,
    required this.reason,
    this.attachmentUrls,
    this.status = LeaveRequestStatus.pending,
    required this.requestedAt,
    this.processedAt,
    this.processedBy,
    this.processedByName,
    this.remarks,
    this.contactPhone,
    this.contactAddress,
    this.handoverTo,
    this.handoverToName,
    this.handoverNotes,
  });

  // Check if request is still pending
  bool get isPending => status == LeaveRequestStatus.pending;
  bool get isApproved => status == LeaveRequestStatus.approved;
  bool get isRejected => status == LeaveRequestStatus.rejected;
  bool get isCancelled => status == LeaveRequestStatus.cancelled;
  
  // Check if leave is in the future
  bool get isFuture => startDate.isAfter(DateTime.now());
  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }
  bool get isPast => endDate.isBefore(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'leaveTypeId': leaveTypeId,
      'leaveTypeName': leaveTypeName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'numberOfDays': numberOfDays,
      'durationType': durationType.name,
      'reason': reason,
      'attachmentUrls': attachmentUrls,
      'status': status.name,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
      'processedByName': processedByName,
      'remarks': remarks,
      'contactPhone': contactPhone,
      'contactAddress': contactAddress,
      'handoverTo': handoverTo,
      'handoverToName': handoverToName,
      'handoverNotes': handoverNotes,
    };
  }

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      leaveTypeId: json['leaveTypeId'],
      leaveTypeName: json['leaveTypeName'],
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: (json['endDate'] as Timestamp).toDate(),
      numberOfDays: (json['numberOfDays'] ?? 0).toDouble(),
      durationType: LeaveDurationType.values.firstWhere(
        (e) => e.name == json['durationType'],
        orElse: () => LeaveDurationType.fullDay,
      ),
      reason: json['reason'],
      attachmentUrls: json['attachmentUrls'] != null
          ? List<String>.from(json['attachmentUrls'])
          : null,
      status: LeaveRequestStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => LeaveRequestStatus.pending,
      ),
      requestedAt: (json['requestedAt'] as Timestamp).toDate(),
      processedAt: json['processedAt'] != null
          ? (json['processedAt'] as Timestamp).toDate()
          : null,
      processedBy: json['processedBy'],
      processedByName: json['processedByName'],
      remarks: json['remarks'],
      contactPhone: json['contactPhone'],
      contactAddress: json['contactAddress'],
      handoverTo: json['handoverTo'],
      handoverToName: json['handoverToName'],
      handoverNotes: json['handoverNotes'],
    );
  }

  LeaveRequest copyWith({
    LeaveRequestStatus? status,
    DateTime? processedAt,
    String? processedBy,
    String? processedByName,
    String? remarks,
  }) {
    return LeaveRequest(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      leaveTypeId: leaveTypeId,
      leaveTypeName: leaveTypeName,
      startDate: startDate,
      endDate: endDate,
      numberOfDays: numberOfDays,
      durationType: durationType,
      reason: reason,
      attachmentUrls: attachmentUrls,
      status: status ?? this.status,
      requestedAt: requestedAt,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      processedByName: processedByName ?? this.processedByName,
      remarks: remarks ?? this.remarks,
      contactPhone: contactPhone,
      contactAddress: contactAddress,
      handoverTo: handoverTo,
      handoverToName: handoverToName,
      handoverNotes: handoverNotes,
    );
  }
}
