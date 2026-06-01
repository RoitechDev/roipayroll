// TODO Implement this library.
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSummary {
  final String id;
  final String employeeId;
  final String employeeName;
  final int month;
  final int year;

  // Day counts
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int lateDays;
  final int halfDays;
  final int leaveDays;
  final int weekendDays;
  final int holidayDays;

  // Work hours
  final double totalHoursWorked;
  final double regularHours;
  final double overtimeHours;
  final double expectedHours;

  // Financial
  final double totalLateDeductions;
  final double totalOvertimePay;
  final double weekdayOvertimeHours;
  final double weekendOvertimeHours;
  final double holidayOvertimeHours;
  final double weekdayOvertimePay;
  final double weekendOvertimePay;
  final double holidayOvertimePay;
  final double overtimeWeekdayMultiplier;
  final double overtimeWeekendMultiplier;
  final double overtimeHolidayMultiplier;
  final double totalAbsentDeductions;
  final double totalHalfDayDeductions;
  final double netAttendanceAdjustment;

  // Metrics
  final double attendancePercentage;
  final double punctualityScore;

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
    this.weekdayOvertimeHours = 0.0,
    this.weekendOvertimeHours = 0.0,
    this.holidayOvertimeHours = 0.0,
    this.weekdayOvertimePay = 0.0,
    this.weekendOvertimePay = 0.0,
    this.holidayOvertimePay = 0.0,
    this.overtimeWeekdayMultiplier = 1.5,
    this.overtimeWeekendMultiplier = 2.0,
    this.overtimeHolidayMultiplier = 2.0,
    required this.totalAbsentDeductions,
    required this.totalHalfDayDeductions,
    required this.netAttendanceAdjustment,
    required this.attendancePercentage,
    required this.punctualityScore,
    required this.generatedAt,
  });

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
      'weekdayOvertimeHours': weekdayOvertimeHours,
      'weekendOvertimeHours': weekendOvertimeHours,
      'holidayOvertimeHours': holidayOvertimeHours,
      'weekdayOvertimePay': weekdayOvertimePay,
      'weekendOvertimePay': weekendOvertimePay,
      'holidayOvertimePay': holidayOvertimePay,
      'overtimeWeekdayMultiplier': overtimeWeekdayMultiplier,
      'overtimeWeekendMultiplier': overtimeWeekendMultiplier,
      'overtimeHolidayMultiplier': overtimeHolidayMultiplier,
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
      totalHoursWorked: (json['totalHoursWorked'] ?? 0).toDouble(),
      regularHours: (json['regularHours'] ?? 0).toDouble(),
      overtimeHours: (json['overtimeHours'] ?? 0).toDouble(),
      expectedHours: (json['expectedHours'] ?? 0).toDouble(),
      totalLateDeductions: (json['totalLateDeductions'] ?? 0).toDouble(),
      totalOvertimePay: (json['totalOvertimePay'] ?? 0).toDouble(),
      weekdayOvertimeHours: (json['weekdayOvertimeHours'] ?? 0).toDouble(),
      weekendOvertimeHours: (json['weekendOvertimeHours'] ?? 0).toDouble(),
      holidayOvertimeHours: (json['holidayOvertimeHours'] ?? 0).toDouble(),
      weekdayOvertimePay: (json['weekdayOvertimePay'] ?? 0).toDouble(),
      weekendOvertimePay: (json['weekendOvertimePay'] ?? 0).toDouble(),
      holidayOvertimePay: (json['holidayOvertimePay'] ?? 0).toDouble(),
      overtimeWeekdayMultiplier: (json['overtimeWeekdayMultiplier'] ?? 1.5)
          .toDouble(),
      overtimeWeekendMultiplier: (json['overtimeWeekendMultiplier'] ?? 2.0)
          .toDouble(),
      overtimeHolidayMultiplier: (json['overtimeHolidayMultiplier'] ?? 2.0)
          .toDouble(),
      totalAbsentDeductions: (json['totalAbsentDeductions'] ?? 0).toDouble(),
      totalHalfDayDeductions: (json['totalHalfDayDeductions'] ?? 0).toDouble(),
      netAttendanceAdjustment: (json['netAttendanceAdjustment'] ?? 0)
          .toDouble(),
      attendancePercentage: (json['attendancePercentage'] ?? 0).toDouble(),
      punctualityScore: (json['punctualityScore'] ?? 0).toDouble(),
      generatedAt: parseDate(json['generatedAt']),
    );
  }

  AttendanceSummary copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    int? month,
    int? year,
    int? totalDays,
    int? presentDays,
    int? absentDays,
    int? lateDays,
    int? halfDays,
    int? leaveDays,
    int? weekendDays,
    int? holidayDays,
    double? totalHoursWorked,
    double? regularHours,
    double? overtimeHours,
    double? expectedHours,
    double? totalLateDeductions,
    double? totalOvertimePay,
    double? weekdayOvertimeHours,
    double? weekendOvertimeHours,
    double? holidayOvertimeHours,
    double? weekdayOvertimePay,
    double? weekendOvertimePay,
    double? holidayOvertimePay,
    double? overtimeWeekdayMultiplier,
    double? overtimeWeekendMultiplier,
    double? overtimeHolidayMultiplier,
    double? totalAbsentDeductions,
    double? totalHalfDayDeductions,
    double? netAttendanceAdjustment,
    double? attendancePercentage,
    double? punctualityScore,
    DateTime? generatedAt,
  }) {
    return AttendanceSummary(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      month: month ?? this.month,
      year: year ?? this.year,
      totalDays: totalDays ?? this.totalDays,
      presentDays: presentDays ?? this.presentDays,
      absentDays: absentDays ?? this.absentDays,
      lateDays: lateDays ?? this.lateDays,
      halfDays: halfDays ?? this.halfDays,
      leaveDays: leaveDays ?? this.leaveDays,
      weekendDays: weekendDays ?? this.weekendDays,
      holidayDays: holidayDays ?? this.holidayDays,
      totalHoursWorked: totalHoursWorked ?? this.totalHoursWorked,
      regularHours: regularHours ?? this.regularHours,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      expectedHours: expectedHours ?? this.expectedHours,
      totalLateDeductions: totalLateDeductions ?? this.totalLateDeductions,
      totalOvertimePay: totalOvertimePay ?? this.totalOvertimePay,
      weekdayOvertimeHours: weekdayOvertimeHours ?? this.weekdayOvertimeHours,
      weekendOvertimeHours: weekendOvertimeHours ?? this.weekendOvertimeHours,
      holidayOvertimeHours: holidayOvertimeHours ?? this.holidayOvertimeHours,
      weekdayOvertimePay: weekdayOvertimePay ?? this.weekdayOvertimePay,
      weekendOvertimePay: weekendOvertimePay ?? this.weekendOvertimePay,
      holidayOvertimePay: holidayOvertimePay ?? this.holidayOvertimePay,
      overtimeWeekdayMultiplier:
          overtimeWeekdayMultiplier ?? this.overtimeWeekdayMultiplier,
      overtimeWeekendMultiplier:
          overtimeWeekendMultiplier ?? this.overtimeWeekendMultiplier,
      overtimeHolidayMultiplier:
          overtimeHolidayMultiplier ?? this.overtimeHolidayMultiplier,
      totalAbsentDeductions:
          totalAbsentDeductions ?? this.totalAbsentDeductions,
      totalHalfDayDeductions:
          totalHalfDayDeductions ?? this.totalHalfDayDeductions,
      netAttendanceAdjustment:
          netAttendanceAdjustment ?? this.netAttendanceAdjustment,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      punctualityScore: punctualityScore ?? this.punctualityScore,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }
}
