import 'package:cloud_firestore/cloud_firestore.dart';

/// Employee Leave Balance for a specific leave type
class LeaveBalance {
  final String id;
  final String employeeId;
  final String employeeName;
  final String leaveTypeId;
  final String leaveTypeName;
  final int year;

  // Balance
  final double allocated; // Days allocated for the year
  final double carriedForward; // Days carried from previous year
  final double used; // Days already used
  final double pending; // Days in pending requests
  final double encashed; // Days encashed

  // Calculated
  double get totalAvailable => allocated + carriedForward;
  double get balance => totalAvailable - used - pending - encashed;
  double get usedPercentage =>
      totalAvailable > 0 ? (used / totalAvailable) * 100 : 0;

  final DateTime lastUpdated;

  LeaveBalance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.year,
    double? allocated,
    double? allocatedDays,
    double? carriedForward,
    double? carriedForwardDays,
    double? used,
    double? usedDays,
    double? pending,
    double? pendingDays,
    double? encashed,
    double? encashedDays,
    required this.lastUpdated,
  })  : allocated = allocated ?? allocatedDays ?? 0,
        carriedForward = carriedForward ?? carriedForwardDays ?? 0,
        used = used ?? usedDays ?? 0,
        pending = pending ?? pendingDays ?? 0,
        encashed = encashed ?? encashedDays ?? 0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'leaveTypeId': leaveTypeId,
      'leaveTypeName': leaveTypeName,
      'year': year,
      'allocated': allocated,
      'carriedForward': carriedForward,
      'used': used,
      'pending': pending,
      'encashed': encashed,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      leaveTypeId: json['leaveTypeId'],
      leaveTypeName: json['leaveTypeName'],
      year: json['year'],
      allocated: (json['allocated'] ?? 0).toDouble(),
      carriedForward: (json['carriedForward'] ?? 0).toDouble(),
      used: (json['used'] ?? 0).toDouble(),
      pending: (json['pending'] ?? 0).toDouble(),
      encashed: (json['encashed'] ?? 0).toDouble(),
      lastUpdated: (json['lastUpdated'] as Timestamp).toDate(),
    );
  }

  double get allocatedDays => allocated;
  double get usedDays => used;
  double get pendingDays => pending;
  double get availableBalance => balance;
  double get encashedDays => encashed;

  LeaveBalance copyWith({
    double? allocated,
    double? allocatedDays,
    double? carriedForward,
    double? carriedForwardDays,
    double? used,
    double? usedDays,
    double? pending,
    double? pendingDays,
    double? encashed,
    double? encashedDays,
    DateTime? lastUpdated,
  }) {
    return LeaveBalance(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName,
      leaveTypeId: leaveTypeId,
      leaveTypeName: leaveTypeName,
      year: year,
      allocated: allocated ?? allocatedDays ?? this.allocated,
      carriedForward: carriedForward ?? carriedForwardDays ?? this.carriedForward,
      used: used ?? usedDays ?? this.used,
      pending: pending ?? pendingDays ?? this.pending,
      encashed: encashed ?? encashedDays ?? this.encashed,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
