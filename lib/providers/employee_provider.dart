import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/employee_service.dart';

final employeeListProvider =
    FutureProvider.autoDispose<List<Employee>>((ref) async {
      ref.watch(appRefreshProvider);
      ref.watch(appAutoRefreshProvider);
      final companyId = ref.watch(companyIdProvider);
      if (companyId == null || companyId.isEmpty) return [];
      return EmployeeService().getAllEmployees();
    });

final employeeProvider = FutureProvider.family<Employee?, String>(
  (ref, employeeId) async {
    ref.watch(appRefreshProvider);
    ref.watch(appAutoRefreshProvider);
    return EmployeeService().getEmployeeById(employeeId);
  },
);

final employeeSearchProvider = Provider.family<List<Employee>, String>((
  ref,
  query,
) {
  final employees = ref.watch(employeeListProvider).value ?? <Employee>[];
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return employees;

  return employees.where((employee) {
    return employee.fullName.toLowerCase().contains(normalized) ||
        employee.id.toLowerCase().contains(normalized) ||
        employee.email.toLowerCase().contains(normalized) ||
        employee.department.toLowerCase().contains(normalized);
  }).toList();
});
