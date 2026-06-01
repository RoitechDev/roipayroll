import 'package:flutter/material.dart';

enum ShiftType {
  regular, // 9 AM - 5 PM
  morning, // 6 AM - 2 PM
  evening, // 2 PM - 10 PM
  night, // 10 PM - 6 AM
  flexible, // No fixed hours
}

class Shift {
  final String id;
  final String name;
  final ShiftType type;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Duration workDuration; // Expected work hours (8 hours)
  final TimeOfDay? lunchBreakStart;
  final TimeOfDay? lunchBreakEnd;
  final Duration? lunchBreakDuration;
  final Duration
  gracePeriod; // Late if clock-in after startTime + gracePeriod (15 min)
  final double overtimeMultiplier; // 1.5x on weekdays
  final double weekendMultiplier; // 2x on weekends
  final bool isActive;

  Shift({
    required this.id,
    required this.name,
    required this.type,
    required this.startTime,
    required this.endTime,
    required this.workDuration,
    this.lunchBreakStart,
    this.lunchBreakEnd,
    this.lunchBreakDuration,
    this.gracePeriod = const Duration(minutes: 15),
    this.overtimeMultiplier = 1.5,
    this.weekendMultiplier = 2.0,
    this.isActive = true,
  });

  // Calculate if clock-in time is late
  bool isLate(DateTime clockInTime) {
    final shiftStart = DateTime(
      clockInTime.year,
      clockInTime.month,
      clockInTime.day,
      startTime.hour,
      startTime.minute,
    );
    final lateThreshold = shiftStart.add(gracePeriod);
    return clockInTime.isAfter(lateThreshold);
  }

  // Calculate overtime hours
  double calculateOvertimeHours(Duration actualWorkDuration, bool isWeekend) {
    final overtimeHours = actualWorkDuration.inMinutes - workDuration.inMinutes;
    if (overtimeHours <= 0) return 0.0;

    final hours = overtimeHours / 60.0;
    return isWeekend ? hours * weekendMultiplier : hours * overtimeMultiplier;
  }

  // Get expected clock-in time for a date
  DateTime getExpectedClockIn(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
  }

  // Get expected clock-out time for a date
  DateTime getExpectedClockOut(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'startTime':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'endTime':
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'workDuration': workDuration.inMinutes,
      'lunchBreakStart': lunchBreakStart != null
          ? '${lunchBreakStart!.hour.toString().padLeft(2, '0')}:${lunchBreakStart!.minute.toString().padLeft(2, '0')}'
          : null,
      'lunchBreakEnd': lunchBreakEnd != null
          ? '${lunchBreakEnd!.hour.toString().padLeft(2, '0')}:${lunchBreakEnd!.minute.toString().padLeft(2, '0')}'
          : null,
      'lunchBreakDuration': lunchBreakDuration?.inMinutes,
      'gracePeriod': gracePeriod.inMinutes,
      'overtimeMultiplier': overtimeMultiplier,
      'weekendMultiplier': weekendMultiplier,
      'isActive': isActive,
    };
  }

  factory Shift.fromJson(Map<String, dynamic> json) {
    return Shift(
      id: json['id'],
      name: json['name'],
      type: ShiftType.values.firstWhere((e) => e.name == json['type']),
      startTime: _parseTimeOfDay(json['startTime']),
      endTime: _parseTimeOfDay(json['endTime']),
      workDuration: Duration(minutes: json['workDuration']),
      lunchBreakStart: json['lunchBreakStart'] != null
          ? _parseTimeOfDay(json['lunchBreakStart'])
          : null,
      lunchBreakEnd: json['lunchBreakEnd'] != null
          ? _parseTimeOfDay(json['lunchBreakEnd'])
          : null,
      lunchBreakDuration: json['lunchBreakDuration'] != null
          ? Duration(minutes: json['lunchBreakDuration'])
          : null,
      gracePeriod: Duration(minutes: json['gracePeriod'] ?? 15),
      overtimeMultiplier: (json['overtimeMultiplier'] ?? 1.5).toDouble(),
      weekendMultiplier: (json['weekendMultiplier'] ?? 2.0).toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  static TimeOfDay _parseTimeOfDay(String time) {
    final parts = time.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // Default Nigerian office shift (9 AM - 5 PM)
  static Shift get defaultShift {
    return Shift(
      id: 'default',
      name: 'Regular Office Hours',
      type: ShiftType.regular,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 17, minute: 0),
      workDuration: const Duration(hours: 8),
      lunchBreakStart: const TimeOfDay(hour: 12, minute: 0),
      lunchBreakEnd: const TimeOfDay(hour: 13, minute: 0),
      lunchBreakDuration: const Duration(hours: 1),
      gracePeriod: const Duration(minutes: 15),
    );
  }
}
