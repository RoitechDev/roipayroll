import 'package:roipayroll/models/attendance_model.dart';
import 'package:roipayroll/models/attendance_summary_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/core/utils/overtime_policy_helper.dart';
import 'package:roipayroll/services/attendance_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/public_holiday_service.dart';
import 'package:uuid/uuid.dart';

class AttendanceSummaryService extends BaseService {
  final String _collection = 'attendance_summaries';
  final _attendanceService = AttendanceService();
  final _publicHolidayService = PublicHolidayService();

  // Constants
  static const double LATE_DEDUCTION_AMOUNT = 500.0; // ₦500 per late
  static const double HALF_DAY_RATE = 0.5; // 50% deduction

  // Generate monthly summary for an employee
  Future<AttendanceSummary> generateMonthlySummary(
    Employee employee,
    int month,
    int year,
  ) async {
    final overtimePolicy = await _loadOvertimePolicy();

    // Get all attendance records for the month
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0);
    final holidays = await _publicHolidayService.getHolidaysInRange(
      startDate,
      DateTime(year, month + 1, 0, 23, 59, 59, 999),
    );
    final holidayDateKeys = holidays
        .map((h) => OvertimePolicyHelper.dateKey(h.date))
        .toSet();
    final holidayDays = holidayDateKeys.length;

    final attendances = await _attendanceService.getEmployeeAttendance(
      employee.id,
      startDate: startDate,
      endDate: endDate,
    );

    // Calculate working days (Mon-Fri)
    int workingDays = 0;
    int weekendDays = 0;
    for (int day = 1; day <= endDate.day; day++) {
      final date = DateTime(year, month, day);
      if (_isWeekend(date)) {
        weekendDays++;
      } else if (!holidayDateKeys.contains(
        OvertimePolicyHelper.dateKey(date),
      )) {
        workingDays++;
      } else {
        // Weekday holiday: excluded from working day denominator.
      }
    }

    // Count attendance statuses
    int presentDays = 0;
    int absentDays = 0;
    int lateDays = 0;
    int halfDays = 0;
    int leaveDays = 0;

    double totalHoursWorked = 0;
    double regularHours = 0;
    double overtimeHours = 0;
    double totalLateDeductions = 0;
    double totalOvertimePay = 0;
    double weekdayOvertimeHours = 0;
    double weekendOvertimeHours = 0;
    double holidayOvertimeHours = 0;
    double weekdayOvertimePay = 0;
    double weekendOvertimePay = 0;
    double holidayOvertimePay = 0;
    final baseHourlyRate = OvertimePolicyHelper.resolveBaseHourlyRate(
      employee.basicSalary,
    );

    // Process each attendance record
    for (var attendance in attendances) {
      switch (attendance.status) {
        case AttendanceStatus.present:
          presentDays++;
          break;
        case AttendanceStatus.late:
          lateDays++;
          presentDays++; // Late still counts as present
          totalLateDeductions += attendance.lateDeduction;
          break;
        case AttendanceStatus.absent:
          absentDays++;
          break;
        case AttendanceStatus.halfDay:
          halfDays++;
          break;
        case AttendanceStatus.leave:
          leaveDays++;
          break;
        case AttendanceStatus.weekend:
          // Weekends are not counted in working days
          break;
        case AttendanceStatus.holiday:
          // Holidays are tracked separately
          break;
      }

      // Add work hours
      totalHoursWorked += attendance.workHoursDecimal;
      regularHours += (attendance.regularHours?.inMinutes ?? 0) / 60.0;
      final otHours = (attendance.overtimeHours?.inMinutes ?? 0) / 60.0;
      overtimeHours += otHours;
      if (overtimePolicy.enabled && otHours > 0) {
        final dayKey = OvertimePolicyHelper.dateKey(attendance.date);
        final isHoliday = holidayDateKeys.contains(dayKey);
        final isWeekend =
            _isWeekend(attendance.date) ||
            attendance.isWeekend ||
            attendance.status == AttendanceStatus.weekend;

        if (isHoliday) {
          holidayOvertimeHours += otHours;
          holidayOvertimePay +=
              otHours * baseHourlyRate * overtimePolicy.holidayMultiplier;
        } else if (isWeekend) {
          weekendOvertimeHours += otHours;
          weekendOvertimePay +=
              otHours * baseHourlyRate * overtimePolicy.weekendMultiplier;
        } else {
          weekdayOvertimeHours += otHours;
          weekdayOvertimePay +=
              otHours * baseHourlyRate * overtimePolicy.weekdayMultiplier;
        }
      }
    }
    totalOvertimePay =
        weekdayOvertimePay + weekendOvertimePay + holidayOvertimePay;

    // Calculate deductions
    final dailyRate = employee.basicSalary / 30;
    final totalAbsentDeductions = absentDays * dailyRate;
    final totalHalfDayDeductions = halfDays * (dailyRate * HALF_DAY_RATE);

    // Calculate net adjustment (OT pay - deductions)
    final netAttendanceAdjustment =
        totalOvertimePay -
        totalLateDeductions -
        totalAbsentDeductions -
        totalHalfDayDeductions;

    // Calculate percentages
    final expectedDays = workingDays - leaveDays;
    final attendancePercentage = expectedDays > 0
        ? (presentDays / expectedDays) * 100
        : 0.0;

    final punctualityScore = presentDays > 0
        ? ((presentDays - lateDays) / presentDays) * 100
        : 0.0;

    final expectedHours = workingDays * 8.0; // 8 hours per day

    // Create summary
    final summary = AttendanceSummary(
      id: const Uuid().v4(),
      employeeId: employee.id,
      employeeName: employee.fullName,
      month: month,
      year: year,
      totalDays: workingDays,
      presentDays: presentDays,
      absentDays: absentDays,
      lateDays: lateDays,
      halfDays: halfDays,
      leaveDays: leaveDays,
      weekendDays: weekendDays,
      holidayDays: holidayDays,
      totalHoursWorked: totalHoursWorked,
      regularHours: regularHours,
      overtimeHours: overtimeHours,
      expectedHours: expectedHours,
      totalLateDeductions: totalLateDeductions,
      totalOvertimePay: totalOvertimePay,
      weekdayOvertimeHours: weekdayOvertimeHours,
      weekendOvertimeHours: weekendOvertimeHours,
      holidayOvertimeHours: holidayOvertimeHours,
      weekdayOvertimePay: weekdayOvertimePay,
      weekendOvertimePay: weekendOvertimePay,
      holidayOvertimePay: holidayOvertimePay,
      overtimeWeekdayMultiplier: overtimePolicy.weekdayMultiplier,
      overtimeWeekendMultiplier: overtimePolicy.weekendMultiplier,
      overtimeHolidayMultiplier: overtimePolicy.holidayMultiplier,
      totalAbsentDeductions: totalAbsentDeductions,
      totalHalfDayDeductions: totalHalfDayDeductions,
      netAttendanceAdjustment: netAttendanceAdjustment,
      attendancePercentage: attendancePercentage,
      punctualityScore: punctualityScore,
      generatedAt: DateTime.now(),
    );

    // Save to Firestore (best effort; rules may block this for some roles)
    try {
      await saveSummary(summary);
    } catch (e) {
      print('Error saving summary: $e');
    }

    return summary;
  }

  // Save summary to Firestore
  Future<void> saveSummary(AttendanceSummary summary) async {
    final summariesRef = await companyCollection(_collection);
    await summariesRef.doc(summary.id).set(summary.toJson());
  }

  // Get summary for employee and month
  Future<AttendanceSummary?> getSummary(
    String employeeId,
    int month,
    int year,
  ) async {
    try {
      final summariesRef = await companyCollection(_collection);
      final snapshot = await summariesRef
          .where('employeeId', isEqualTo: employeeId)
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return AttendanceSummary.fromJson(docData(snapshot.docs.first));
      }
      return null;
    } catch (e) {
      print('Error getting summary: $e');
      return null;
    }
  }

  // Get or generate summary (checks if exists, generates if not)
  Future<AttendanceSummary> getOrGenerateSummary(
    Employee employee,
    int month,
    int year,
  ) async {
    // Check if summary already exists
    final existing = await getSummary(employee.id, month, year);
    if (existing != null) {
      return existing;
    }

    // Generate new summary
    try {
      return await generateMonthlySummary(employee, month, year);
    } catch (e) {
      // Do not block payroll if attendance read/index/rules fail.
      print('Error generating summary, using zero-adjustment fallback: $e');
      final endDate = DateTime(year, month + 1, 0);
      int workingDays = 0;
      int weekendDays = 0;
      for (int day = 1; day <= endDate.day; day++) {
        final date = DateTime(year, month, day);
        if (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          weekendDays++;
        } else {
          workingDays++;
        }
      }

      return AttendanceSummary(
        id: const Uuid().v4(),
        employeeId: employee.id,
        employeeName: employee.fullName,
        month: month,
        year: year,
        totalDays: workingDays,
        presentDays: 0,
        absentDays: 0,
        lateDays: 0,
        halfDays: 0,
        leaveDays: 0,
        weekendDays: weekendDays,
        holidayDays: 0,
        totalHoursWorked: 0,
        regularHours: 0,
        overtimeHours: 0,
        expectedHours: workingDays * 8.0,
        totalLateDeductions: 0,
        totalOvertimePay: 0,
        weekdayOvertimeHours: 0,
        weekendOvertimeHours: 0,
        holidayOvertimeHours: 0,
        weekdayOvertimePay: 0,
        weekendOvertimePay: 0,
        holidayOvertimePay: 0,
        overtimeWeekdayMultiplier:
            OvertimePolicyHelper.defaultPolicy.weekdayMultiplier,
        overtimeWeekendMultiplier:
            OvertimePolicyHelper.defaultPolicy.weekendMultiplier,
        overtimeHolidayMultiplier:
            OvertimePolicyHelper.defaultPolicy.holidayMultiplier,
        totalAbsentDeductions: 0,
        totalHalfDayDeductions: 0,
        netAttendanceAdjustment: 0,
        attendancePercentage: 0,
        punctualityScore: 0,
        generatedAt: DateTime.now(),
      );
    }
  }

  // Get all summaries for a month (for admin)
  Future<List<AttendanceSummary>> getAllSummariesForMonth(
    int month,
    int year,
  ) async {
    try {
      final summariesRef = await companyCollection(_collection);
      final snapshot = await summariesRef
          .where('month', isEqualTo: month)
          .where('year', isEqualTo: year)
          .get();

      return snapshot.docs
          .map((doc) => AttendanceSummary.fromJson(docData(doc)))
          .toList();
    } catch (e) {
      print('Error getting summaries: $e');
      return [];
    }
  }

  // Delete summary
  Future<void> deleteSummary(String summaryId) async {
    final summariesRef = await companyCollection(_collection);
    await summariesRef.doc(summaryId).delete();
  }

  // Regenerate summary (delete old and create new)
  Future<AttendanceSummary> regenerateSummary(
    Employee employee,
    int month,
    int year,
  ) async {
    // Delete existing summary
    final existing = await getSummary(employee.id, month, year);
    if (existing != null) {
      await deleteSummary(existing.id);
    }

    // Generate new summary
    return await generateMonthlySummary(employee, month, year);
  }

  bool _isWeekend(DateTime date) {
    return date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
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
}
