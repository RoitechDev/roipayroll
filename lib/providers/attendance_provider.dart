import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/attendance_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/services/attendance_service.dart';

class AttendanceFilterQuery {
  final String filter;
  final bool isAdmin;
  final String? employeeId;

  const AttendanceFilterQuery({
    required this.filter,
    required this.isAdmin,
    this.employeeId,
  });

  @override
  bool operator ==(Object other) {
    return other is AttendanceFilterQuery &&
        other.filter == filter &&
        other.isAdmin == isAdmin &&
        other.employeeId == employeeId;
  }

  @override
  int get hashCode => Object.hash(filter, isAdmin, employeeId);
}

final filteredAttendanceProvider =
    FutureProvider.family<List<Attendance>, AttendanceFilterQuery>((
      ref,
      query,
    ) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);
      final attendanceService = AttendanceService();
      final now = DateTime.now();

      if (!query.isAdmin) {
        final employeeId = query.employeeId;
        if (employeeId == null || employeeId.isEmpty) return [];

        switch (query.filter) {
          case 'Today':
            final today = await attendanceService.getTodayAttendance(
              employeeId,
            );
            return today != null ? [today] : [];
          case 'This Week':
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            return attendanceService.getEmployeeAttendance(
              employeeId,
              startDate: DateTime(
                startOfWeek.year,
                startOfWeek.month,
                startOfWeek.day,
              ),
              endDate: now,
            );
          case 'This Month':
            return attendanceService.getEmployeeAttendance(
              employeeId,
              startDate: DateTime(now.year, now.month, 1),
              endDate: now,
            );
          case 'All':
            return attendanceService.getEmployeeAttendance(employeeId);
          default:
            final today = await attendanceService.getTodayAttendance(
              employeeId,
            );
            return today != null ? [today] : [];
        }
      }

      switch (query.filter) {
        case 'Today':
          return attendanceService.getTodayAllAttendance();
        case 'This Week':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          return attendanceService.getAttendanceByDateRange(
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
            now,
          );
        case 'This Month':
          return attendanceService.getAttendanceByDateRange(
            DateTime(now.year, now.month, 1),
            now,
          );
        case 'All':
          return attendanceService.getAllAttendance(limit: 100);
        default:
          return attendanceService.getTodayAllAttendance();
      }
    });

final todayAttendanceProvider = FutureProvider.family<Attendance?, String>((
  ref,
  employeeId,
) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);
  final normalizedEmployeeId = employeeId.trim();
  if (normalizedEmployeeId.isEmpty) {
    return null;
  }

  return AttendanceService().getTodayAttendance(normalizedEmployeeId);
});
