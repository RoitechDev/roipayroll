import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus {
  present,
  absent,
  late,
  halfDay,
  leave,
  weekend,
  holiday,
}

class Attendance {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final DateTime? clockInTime;
  final DateTime? clockOutTime;
  final AttendanceStatus status;
  final String? notes;

  // Location Data
  final String? clockInLocation;
  final double? clockInLatitude;
  final double? clockInLongitude;
  final String? clockOutLocation;
  final double? clockOutLatitude;
  final double? clockOutLongitude;

  // Shift Data
  final String shiftId;
  final DateTime expectedClockIn;
  final DateTime expectedClockOut;

  // Break Data
  final DateTime? lunchBreakStart;
  final DateTime? lunchBreakEnd;
  final Duration? lunchBreakDuration;

  // Work Hours
  final Duration? totalWorkDuration;
  final Duration? regularHours;
  final Duration? overtimeHours;
  final bool isWeekend;

  // Penalties/Bonuses
  final double lateDeduction; // Amount to deduct for being late
  final double overtimePay; // Amount to add for OT
  final int lateMinutes; // Minutes late

  // Regularization
  final bool isRegularized;
  final String? regularizationReason;
  final DateTime? regularizationApprovedAt;
  final String? regularizationApprovedBy;

  Attendance({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.clockInTime,
    this.clockOutTime,
    required this.status,
    this.notes,

    this.clockInLocation,
    this.clockInLatitude,
    this.clockInLongitude,
    this.clockOutLocation,
    this.clockOutLatitude,
    this.clockOutLongitude,

    this.shiftId = 'default',
    required this.expectedClockIn,
    required this.expectedClockOut,

    this.lunchBreakStart,
    this.lunchBreakEnd,
    this.lunchBreakDuration,

    this.totalWorkDuration,
    this.regularHours,
    this.overtimeHours,
    this.isWeekend = false,

    this.lateDeduction = 0.0,
    this.overtimePay = 0.0,
    this.lateMinutes = 0,

    this.isRegularized = false,
    this.regularizationReason,
    this.regularizationApprovedAt,
    this.regularizationApprovedBy,
  });

  // Calculate work duration (excluding lunch break)
  Duration get workDuration {
    if (clockInTime == null || clockOutTime == null) return Duration.zero;

    Duration total = clockOutTime!.difference(clockInTime!);

    // Deduct lunch break if taken
    if (lunchBreakDuration != null) {
      total = total - lunchBreakDuration!;
    }

    return total;
  }

  // Check if clocked out
  bool get isClockedOut => clockOutTime != null;

  // Check if late
  bool get isLate => status == AttendanceStatus.late;

  // Get work hours as decimal (for reporting)
  double get workHoursDecimal => workDuration.inMinutes / 60.0;

  // Alias for new code
  double get actualWorkHours => workHoursDecimal;

  // Get OT hours as decimal - FIXED LINE
  double get overtimeHoursDecimal => (overtimeHours?.inMinutes ?? 0) / 60.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'date': Timestamp.fromDate(date),
      'clockInTime': clockInTime != null
          ? Timestamp.fromDate(clockInTime!)
          : null,
      'clockOutTime': clockOutTime != null
          ? Timestamp.fromDate(clockOutTime!)
          : null,
      'status': status.name,
      'notes': notes,

      'clockInLocation': clockInLocation,
      'clockInLatitude': clockInLatitude,
      'clockInLongitude': clockInLongitude,
      'clockOutLocation': clockOutLocation,
      'clockOutLatitude': clockOutLatitude,
      'clockOutLongitude': clockOutLongitude,

      'shiftId': shiftId,
      'expectedClockIn': Timestamp.fromDate(expectedClockIn),
      'expectedClockOut': Timestamp.fromDate(expectedClockOut),

      'lunchBreakStart': lunchBreakStart != null
          ? Timestamp.fromDate(lunchBreakStart!)
          : null,
      'lunchBreakEnd': lunchBreakEnd != null
          ? Timestamp.fromDate(lunchBreakEnd!)
          : null,
      'lunchBreakDuration': lunchBreakDuration?.inMinutes,

      'totalWorkDuration': totalWorkDuration?.inMinutes,
      'regularHours': regularHours?.inMinutes,
      'overtimeHours': overtimeHours?.inMinutes,
      'isWeekend': isWeekend,

      'lateDeduction': lateDeduction,
      'overtimePay': overtimePay,
      'lateMinutes': lateMinutes,

      'isRegularized': isRegularized,
      'regularizationReason': regularizationReason,
      'regularizationApprovedAt': regularizationApprovedAt != null
          ? Timestamp.fromDate(regularizationApprovedAt!)
          : null,
      'regularizationApprovedBy': regularizationApprovedBy,
    };
  }

  factory Attendance.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    int? parseMinutes(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value);
      return null;
    }

    final date = parseDate(json['date']) ?? DateTime.now();
    final expectedClockIn =
        parseDate(json['expectedClockIn']) ?? DateTime(date.year, date.month, date.day, 9);
    final expectedClockOut =
        parseDate(json['expectedClockOut']) ?? DateTime(date.year, date.month, date.day, 17);

    return Attendance(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      date: date,
      clockInTime: parseDate(json['clockInTime']),
      clockOutTime: parseDate(json['clockOutTime']),
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AttendanceStatus.present,
      ),
      notes: json['notes'],

      clockInLocation: json['clockInLocation'],
      clockInLatitude: json['clockInLatitude'],
      clockInLongitude: json['clockInLongitude'],
      clockOutLocation: json['clockOutLocation'],
      clockOutLatitude: json['clockOutLatitude'],
      clockOutLongitude: json['clockOutLongitude'],

      shiftId: json['shiftId'] ?? 'default',
      expectedClockIn: expectedClockIn,
      expectedClockOut: expectedClockOut,

      lunchBreakStart: parseDate(json['lunchBreakStart']),
      lunchBreakEnd: parseDate(json['lunchBreakEnd']),
      lunchBreakDuration: parseMinutes(json['lunchBreakDuration']) != null
          ? Duration(minutes: parseMinutes(json['lunchBreakDuration'])!)
          : null,

      totalWorkDuration: parseMinutes(json['totalWorkDuration']) != null
          ? Duration(minutes: parseMinutes(json['totalWorkDuration'])!)
          : null,
      regularHours: parseMinutes(json['regularHours']) != null
          ? Duration(minutes: parseMinutes(json['regularHours'])!)
          : null,
      overtimeHours: parseMinutes(json['overtimeHours']) != null
          ? Duration(minutes: parseMinutes(json['overtimeHours'])!)
          : null,
      isWeekend: json['isWeekend'] ?? false,

      lateDeduction: (json['lateDeduction'] ?? 0.0).toDouble(),
      overtimePay: (json['overtimePay'] ?? 0.0).toDouble(),
      lateMinutes: json['lateMinutes'] ?? 0,

      isRegularized: json['isRegularized'] ?? false,
      regularizationReason: json['regularizationReason'],
      regularizationApprovedAt: parseDate(json['regularizationApprovedAt']),
      regularizationApprovedBy: json['regularizationApprovedBy'],
    );
  }

  Attendance copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    DateTime? date,
    DateTime? clockInTime,
    DateTime? clockOutTime,
    AttendanceStatus? status,
    String? notes,
    String? clockInLocation,
    double? clockInLatitude,
    double? clockInLongitude,
    String? clockOutLocation,
    double? clockOutLatitude,
    double? clockOutLongitude,
    String? shiftId,
    DateTime? expectedClockIn,
    DateTime? expectedClockOut,
    DateTime? lunchBreakStart,
    DateTime? lunchBreakEnd,
    Duration? lunchBreakDuration,
    Duration? totalWorkDuration,
    Duration? regularHours,
    Duration? overtimeHours,
    bool? isWeekend,
    double? lateDeduction,
    double? overtimePay,
    int? lateMinutes,
    bool? isRegularized,
    String? regularizationReason,
    DateTime? regularizationApprovedAt,
    String? regularizationApprovedBy,
  }) {
    return Attendance(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      date: date ?? this.date,
      clockInTime: clockInTime ?? this.clockInTime,
      clockOutTime: clockOutTime ?? this.clockOutTime,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      clockInLocation: clockInLocation ?? this.clockInLocation,
      clockInLatitude: clockInLatitude ?? this.clockInLatitude,
      clockInLongitude: clockInLongitude ?? this.clockInLongitude,
      clockOutLocation: clockOutLocation ?? this.clockOutLocation,
      clockOutLatitude: clockOutLatitude ?? this.clockOutLatitude,
      clockOutLongitude: clockOutLongitude ?? this.clockOutLongitude,
      shiftId: shiftId ?? this.shiftId,
      expectedClockIn: expectedClockIn ?? this.expectedClockIn,
      expectedClockOut: expectedClockOut ?? this.expectedClockOut,
      lunchBreakStart: lunchBreakStart ?? this.lunchBreakStart,
      lunchBreakEnd: lunchBreakEnd ?? this.lunchBreakEnd,
      lunchBreakDuration: lunchBreakDuration ?? this.lunchBreakDuration,
      totalWorkDuration: totalWorkDuration ?? this.totalWorkDuration,
      regularHours: regularHours ?? this.regularHours,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      isWeekend: isWeekend ?? this.isWeekend,
      lateDeduction: lateDeduction ?? this.lateDeduction,
      overtimePay: overtimePay ?? this.overtimePay,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      isRegularized: isRegularized ?? this.isRegularized,
      regularizationReason: regularizationReason ?? this.regularizationReason,
      regularizationApprovedAt:
          regularizationApprovedAt ?? this.regularizationApprovedAt,
      regularizationApprovedBy:
          regularizationApprovedBy ?? this.regularizationApprovedBy,
    );
  }
}
