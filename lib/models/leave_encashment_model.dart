import 'package:cloud_firestore/cloud_firestore.dart';

enum EncashmentStatus {
  pending,
  approved,
  rejected,
  processed, // Payment processed
}

/// Leave Encashment Request
class LeaveEncashment {
  final String id;
  final String employeeId;
  final String employeeName;
  final String leaveTypeId;
  final String leaveTypeName;
  final int year;
  
  // Encashment Details
  final double availableDays; // Days available for encashment
  final double daysToEncash; // Days employee wants to encash
  final double dailyRate; // Daily salary rate
  final double encashmentAmount; // Total amount to be paid
  
  // Status
  final EncashmentStatus status;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? processedAt;
  final String? processedBy;
  final String? processedByName;
  final String? remarks;
  
  // Payment
  final String? payrollId; // Link to payroll if included in salary
  final bool includedInPayroll;

  LeaveEncashment({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.year,
    required this.availableDays,
    required this.daysToEncash,
    required this.dailyRate,
    required this.encashmentAmount,
    this.status = EncashmentStatus.pending,
    required this.requestedAt,
    this.approvedAt,
    this.approvedBy,
    this.approvedByName,
    this.processedAt,
    this.processedBy,
    this.processedByName,
    this.remarks,
    this.payrollId,
    this.includedInPayroll = false,
  });

  bool get isPending => status == EncashmentStatus.pending;
  bool get isApproved => status == EncashmentStatus.approved;
  bool get isProcessed => status == EncashmentStatus.processed;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'leaveTypeId': leaveTypeId,
      'leaveTypeName': leaveTypeName,
      'year': year,
      'availableDays': availableDays,
      'daysToEncash': daysToEncash,
      'dailyRate': dailyRate,
      'encashmentAmount': encashmentAmount,
      'status': status.name,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'processedAt': processedAt != null ? Timestamp.fromDate(processedAt!) : null,
      'processedBy': processedBy,
      'processedByName': processedByName,
      'remarks': remarks,
      'payrollId': payrollId,
      'includedInPayroll': includedInPayroll,
    };
  }

  factory LeaveEncashment.fromJson(Map<String, dynamic> json) {
    return LeaveEncashment(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      leaveTypeId: json['leaveTypeId'],
      leaveTypeName: json['leaveTypeName'],
      year: json['year'],
      availableDays: (json['availableDays'] ?? 0).toDouble(),
      daysToEncash: (json['daysToEncash'] ?? 0).toDouble(),
      dailyRate: (json['dailyRate'] ?? 0).toDouble(),
      encashmentAmount: (json['encashmentAmount'] ?? 0).toDouble(),
      status: EncashmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EncashmentStatus.pending,
      ),
      requestedAt: (json['requestedAt'] as Timestamp).toDate(),
      approvedAt: json['approvedAt'] != null
          ? (json['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: json['approvedBy'],
      approvedByName: json['approvedByName'],
      processedAt: json['processedAt'] != null
          ? (json['processedAt'] as Timestamp).toDate()
          : null,
      processedBy: json['processedBy'],
      processedByName: json['processedByName'],
      remarks: json['remarks'],
      payrollId: json['payrollId'],
      includedInPayroll: json['includedInPayroll'] ?? false,
    );
  }

  LeaveEncashment copyWith({
    EncashmentStatus? status,
    DateTime? approvedAt,
    String? approvedBy,
    String? approvedByName,
    DateTime? processedAt,
    String? processedBy,
    String? processedByName,
    String? remarks,
    String? payrollId,
    bool? includedInPayroll,
  }) {
    return LeaveEncashment(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      leaveTypeId: leaveTypeId,
      leaveTypeName: leaveTypeName,
      year: year,
      availableDays: availableDays,
      daysToEncash: daysToEncash,
      dailyRate: dailyRate,
      encashmentAmount: encashmentAmount,
      status: status ?? this.status,
      requestedAt: requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      processedAt: processedAt ?? this.processedAt,
      processedBy: processedBy ?? this.processedBy,
      processedByName: processedByName ?? this.processedByName,
      remarks: remarks ?? this.remarks,
      payrollId: payrollId ?? this.payrollId,
      includedInPayroll: includedInPayroll ?? this.includedInPayroll,
    );
  }
}
