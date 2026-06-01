import 'package:cloud_firestore/cloud_firestore.dart';

/// Monthly attendance summary for payroll calculation
class AttendanceSummary {
  final String id;
  final String employeeId;
  final String employeeName;
  final int month;
  final int year;

  // Attendance Counts
  final int totalDays; // Working days in month
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int halfDays;
  final int leaveDays;
  final int weekendDays;
  final int holidayDays;

  // Work Hours
  final double totalHoursWorked;
  final double regularHours;
  final double overtimeHours;
  final double expectedHours; // Based on shift

  // Financial Impact
  final double totalLateDeductions;
  final double totalOvertimePay;
  final double totalAbsentDeductions;
  final double totalHalfDayDeductions;
  final double netAttendanceAdjustment; // OT pay - deductions

  // Calculated Fields
  final double attendancePercentage;
  final double punctualityScore; // % of on-time arrivals

  final DateTime generatedAt;

  AttendanceSummary({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.year,
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.lateDays,
    required this.halfDays,
    required this.leaveDays,
    required this.weekendDays,
    required this.holidayDays,
    required this.totalHoursWorked,
    required this.regularHours,
    required this.overtimeHours,
    required this.expectedHours,
    required this.totalLateDeductions,
    required this.totalOvertimePay,
    required this.totalAbsentDeductions,
    required this.totalHalfDayDeductions,
    required this.netAttendanceAdjustment,
    required this.attendancePercentage,
    required this.punctualityScore,
    required this.generatedAt,
  });

  // Calculate attendance grade (A, B, C, D, F)
  String get attendanceGrade {
    if (attendancePercentage >= 95) return 'A';
    if (attendancePercentage >= 85) return 'B';
    if (attendancePercentage >= 75) return 'C';
    if (attendancePercentage >= 60) return 'D';
    return 'F';
  }

  // Check if attendance is acceptable (>= 75%)
  bool get isAttendanceAcceptable => attendancePercentage >= 75;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'month': month,
      'year': year,
      'totalDays': totalDays,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'lateDays': lateDays,
      'halfDays': halfDays,
      'leaveDays': leaveDays,
      'weekendDays': weekendDays,
      'holidayDays': holidayDays,
      'totalHoursWorked': totalHoursWorked,
      'regularHours': regularHours,
      'overtimeHours': overtimeHours,
      'expectedHours': expectedHours,
      'totalLateDeductions': totalLateDeductions,
      'totalOvertimePay': totalOvertimePay,
      'totalAbsentDeductions': totalAbsentDeductions,
      'totalHalfDayDeductions': totalHalfDayDeductions,
      'netAttendanceAdjustment': netAttendanceAdjustment,
      'attendancePercentage': attendancePercentage,
      'punctualityScore': punctualityScore,
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory AttendanceSummary.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return AttendanceSummary(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      month: parseInt(json['month']),
      year: parseInt(json['year']),
      totalDays: parseInt(json['totalDays']),
      presentDays: parseInt(json['presentDays']),
      absentDays: parseInt(json['absentDays']),
      lateDays: parseInt(json['lateDays']),
      halfDays: parseInt(json['halfDays']),
      leaveDays: parseInt(json['leaveDays']),
      weekendDays: parseInt(json['weekendDays']),
      holidayDays: parseInt(json['holidayDays']),
      totalHoursWorked: (json['totalHoursWorked'] ?? 0.0).toDouble(),
      regularHours: (json['regularHours'] ?? 0.0).toDouble(),
      overtimeHours: (json['overtimeHours'] ?? 0.0).toDouble(),
      expectedHours: (json['expectedHours'] ?? 0.0).toDouble(),
      totalLateDeductions: (json['totalLateDeductions'] ?? 0.0).toDouble(),
      totalOvertimePay: (json['totalOvertimePay'] ?? 0.0).toDouble(),
      totalAbsentDeductions: (json['totalAbsentDeductions'] ?? 0.0).toDouble(),
      totalHalfDayDeductions: (json['totalHalfDayDeductions'] ?? 0.0)
          .toDouble(),
      netAttendanceAdjustment: (json['netAttendanceAdjustment'] ?? 0.0)
          .toDouble(),
      attendancePercentage: (json['attendancePercentage'] ?? 0.0).toDouble(),
      punctualityScore: (json['punctualityScore'] ?? 0.0).toDouble(),
      generatedAt: parseDate(json['generatedAt']),
    );
  }
}
