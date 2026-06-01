import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/core/utils/overtime_policy_helper.dart';
import 'package:roipayroll/models/attendance_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/public_holiday_service.dart';
import 'package:roipayroll/services/shift_service.dart';
import 'package:uuid/uuid.dart';

class AttendanceService extends BaseService {
  final String _collection = 'attendance';
  final _shiftService = ShiftService();
  final _employeeService = EmployeeService();
  final _publicHolidayService = PublicHolidayService();

  // Constants
  static const double LATE_DEDUCTION_AMOUNT = 500.0; // ₦500 per late arrival

  /// Clock in for the day
  Future<Attendance> clockIn({
    required String employeeId,
    required String employeeName,
    String? notes,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if already clocked in today
    final existing = await getTodayAttendance(employeeId);
    if (existing != null) {
      throw Exception(
        'Already clocked in today at ${_formatTime(existing.clockInTime!)}',
      );
    }

    // Get employee's shift (default 9-5)
    final shift = await _shiftService.getEmployeeShift(employeeId);

    // Calculate expected clock in/out times
    final expectedClockIn = shift.getExpectedClockIn(today);
    final expectedClockOut = shift.getExpectedClockOut(today);

    // Check if weekend / holiday before late penalties
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final isHoliday = await _isHoliday(today);

    // Determine if late (not applicable for weekend/holiday)
    final isLate = !isWeekend && !isHoliday && shift.isLate(now);
    final lateMinutes = isLate ? now.difference(expectedClockIn).inMinutes : 0;

    // Calculate late deduction (only if more than grace period)
    final lateDeduction = isLate ? LATE_DEDUCTION_AMOUNT : 0.0;

    // Determine status
    final status = isHoliday
        ? AttendanceStatus.holiday
        : isWeekend
        ? AttendanceStatus.weekend
        : isLate
        ? AttendanceStatus.late
        : AttendanceStatus.present;

    // Create attendance record
    final attendance = Attendance(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      date: today,
      clockInTime: now,
      shiftId: shift.id,
      expectedClockIn: expectedClockIn,
      expectedClockOut: expectedClockOut,
      status: status,
      notes: notes,
      lateDeduction: lateDeduction,
      isWeekend: isWeekend,
    );

    // Save to Firestore
    final attendanceRef = await companyCollection(_collection);
    await attendanceRef.doc(attendance.id).set(attendance.toJson());

    print('✅ Clock in successful for $employeeName at ${_formatTime(now)}');
    if (isLate) {
      print(
        '⚠️  Late by $lateMinutes minutes - Deduction: ₦${lateDeduction.toStringAsFixed(2)}',
      );
    }

    return attendance;
  }

  /// Clock out for the day
  Future<Attendance> clockOut({
    required String attendanceId,
    String? notes,
  }) async {
    final attendanceRef = await companyCollection(_collection);
    final doc = await attendanceRef.doc(attendanceId).get();

    if (!doc.exists) {
      throw Exception('Attendance record not found');
    }

    final data = docDataNullable(doc);
    if (data == null) {
      throw Exception('Attendance record not found');
    }
    final attendance = Attendance.fromJson(data);

    if (attendance.clockOutTime != null) {
      throw Exception(
        'Already clocked out at ${_formatTime(attendance.clockOutTime!)}',
      );
    }

    final now = DateTime.now();
    final shift = await _shiftService.getShiftById(attendance.shiftId);
    final overtimePolicy = await _loadOvertimePolicy();
    final employee = await _employeeService.getEmployeeById(
      attendance.employeeId,
    );
    final isHoliday = await _isHoliday(attendance.date);
    final isWeekend =
        attendance.date.weekday == DateTime.saturday ||
        attendance.date.weekday == DateTime.sunday;

    // Calculate work duration (excluding lunch break)
    final totalDuration = now.difference(attendance.clockInTime!);
    final lunchBreakDuration =
        shift?.lunchBreakDuration ?? const Duration(hours: 1);
    final workDuration = totalDuration - lunchBreakDuration;

    // Calculate regular and overtime hours
    final expectedWorkHours = shift?.workDuration ?? const Duration(hours: 8);
    final regularHours = workDuration > expectedWorkHours
        ? expectedWorkHours
        : workDuration;
    final overtimeHours = workDuration > expectedWorkHours
        ? workDuration - expectedWorkHours
        : Duration.zero;

    // Calculate overtime pay
    final overtimeHoursDecimal = overtimeHours.inMinutes / 60.0;
    final overtimeMultiplier = isHoliday
        ? overtimePolicy.holidayMultiplier
        : isWeekend
        ? overtimePolicy.weekendMultiplier
        : overtimePolicy.weekdayMultiplier;
    final baseHourlyRate = OvertimePolicyHelper.resolveBaseHourlyRate(
      employee?.basicSalary ?? 0.0,
    );
    final overtimePay = overtimePolicy.enabled
        ? overtimeHoursDecimal * baseHourlyRate * overtimeMultiplier
        : 0.0;

    // Update attendance record
    final updatedAttendance = attendance.copyWith(
      clockOutTime: now,
      status: isHoliday
          ? AttendanceStatus.holiday
          : isWeekend
          ? AttendanceStatus.weekend
          : attendance.status,
      totalWorkDuration: workDuration,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      overtimePay: overtimePay,
      isWeekend: isWeekend,
      lunchBreakDuration: lunchBreakDuration,
      notes: notes ?? attendance.notes,
    );

    await attendanceRef.doc(attendanceId).update(updatedAttendance.toJson());

    print(
      '✅ Clock out successful for ${attendance.employeeName} at ${_formatTime(now)}',
    );
    print(
      '   Work Duration: ${(workDuration.inMinutes / 60.0).toStringAsFixed(2)} hours',
    );
    if (overtimeHours.inMinutes > 0) {
      print(
        '   Overtime: ${overtimeHoursDecimal.toStringAsFixed(2)} hours - Pay: ₦${overtimePay.toStringAsFixed(2)}',
      );
    }

    return updatedAttendance;
  }

  /// Get today's attendance for an employee
  Future<Attendance?> getTodayAttendance(String employeeId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final attendanceRef = await companyCollection(_collection);
    final snapshot = await attendanceRef
        .where('employeeId', isEqualTo: employeeId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Attendance.fromJson(docData(snapshot.docs.first));
  }

  /// Get all attendance for today (admin/HR)
  Future<List<Attendance>> getTodayAllAttendance() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final attendanceRef = await companyCollection(_collection);
    final snapshot = await attendanceRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Attendance.fromJson(docData(doc)))
        .toList();
  }

  /// Get employee attendance records
  Future<List<Attendance>> getEmployeeAttendance(
    String employeeId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final attendanceRef = await companyCollection(_collection);
    final snapshot = await attendanceRef
        .where('employeeId', isEqualTo: employeeId)
        .get();

    final attendances = snapshot.docs
        .map((doc) => Attendance.fromJson(docData(doc)))
        .where((attendance) {
          if (startDate != null && attendance.date.isBefore(startDate)) {
            return false;
          }
          if (endDate != null && attendance.date.isAfter(endDate)) {
            return false;
          }
          return true;
        })
        .toList();
    attendances.sort((a, b) => b.date.compareTo(a.date));
    return attendances;
  }

  /// Get attendance by date range (admin/HR)
  Future<List<Attendance>> getAttendanceByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final attendanceRef = await companyCollection(_collection);
    final snapshot = await attendanceRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => Attendance.fromJson(docData(doc)))
        .toList();
  }

  /// Get all attendance (with limit)
  Future<List<Attendance>> getAllAttendance({int limit = 100}) async {
    final attendanceRef = await companyCollection(_collection);
    final snapshot = await attendanceRef
        .orderBy('date', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => Attendance.fromJson(docData(doc)))
        .toList();
  }

  /// Mark employee as absent (manual entry by admin)
  Future<void> markAbsent({
    required String employeeId,
    required String employeeName,
    required DateTime date,
    String? reason,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final shift = await _shiftService.getEmployeeShift(employeeId);

    final attendance = Attendance(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      date: dateOnly,
      status: AttendanceStatus.absent,
      shiftId: shift.id,
      expectedClockIn: shift.getExpectedClockIn(dateOnly),
      expectedClockOut: shift.getExpectedClockOut(dateOnly),
      notes: reason,
    );

    final attendanceRef = await companyCollection(_collection);
    await attendanceRef.doc(attendance.id).set(attendance.toJson());
  }

  /// Mark employee as on leave
  Future<void> markLeave({
    required String employeeId,
    required String employeeName,
    required DateTime date,
    String? leaveType,
  }) async {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final shift = await _shiftService.getEmployeeShift(employeeId);

    final attendance = Attendance(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      date: dateOnly,
      status: AttendanceStatus.leave,
      shiftId: shift.id,
      expectedClockIn: shift.getExpectedClockIn(dateOnly),
      expectedClockOut: shift.getExpectedClockOut(dateOnly),
      notes: leaveType,
    );

    final attendanceRef = await companyCollection(_collection);
    await attendanceRef.doc(attendance.id).set(attendance.toJson());
  }

  /// Update attendance status
  Future<void> updateAttendanceStatus(
    String attendanceId,
    AttendanceStatus status, {
    String? notes,
  }) async {
    final updates = <String, dynamic>{'status': status.name};

    if (notes != null) {
      updates['notes'] = notes;
    }

    final attendanceRef = await companyCollection(_collection);
    await attendanceRef.doc(attendanceId).update(updates);
  }

  /// Delete attendance record
  Future<void> deleteAttendance(String attendanceId) async {
    final attendanceRef = await companyCollection(_collection);
    await attendanceRef.doc(attendanceId).delete();
  }

  /// Helper: Format time as "9:30 AM"
  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<bool> _isHoliday(DateTime date) async {
    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
      final holidays = await _publicHolidayService.getHolidaysInRange(
        dayStart,
        dayEnd,
      );
      return holidays.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<OvertimePolicy> _loadOvertimePolicy() async {
    try {
      final companyId = await getCompanyId();
      final settingsDoc = await firestore
          .collection('companies')
          .doc(companyId)
          .collection('settings')
          .doc('general')
          .get();
      return OvertimePolicyHelper.fromSettings(
        settingsDoc.data() ?? const <String, dynamic>{},
      );
    } catch (_) {
      return OvertimePolicyHelper.defaultPolicy;
    }
  }

  Future<dynamic> getCurrentLocation() async {}
}
