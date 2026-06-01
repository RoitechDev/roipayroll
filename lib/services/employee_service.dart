import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/import_result_model.dart';
import 'package:roipayroll/models/audit_log_model.dart';
import 'package:roipayroll/services/audit_service.dart';
import 'package:roipayroll/services/contract_service.dart';
import 'package:roipayroll/services/encryption_service.dart';
import 'package:roipayroll/services/probation_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:roipayroll/models/contract_record_model.dart';
import 'package:uuid/uuid.dart';

class EmployeeService extends BaseService {
  final String _collection = 'employees';
  final AuditService _auditService = AuditService(userService: UserService());
  final ProbationService _probationService = ProbationService();
  final ContractService _contractService = ContractService();

  Future<Employee> createEmployee(Employee employee) async {
    final created = employee.id.trim().isEmpty
        ? employee.copyWith(id: const Uuid().v4())
        : employee;

    await addEmployee(created);

    if (created.employmentType == EmploymentType.probation) {
      final durationMonths = _resolveDurationMonths(
        created.hireDate,
        created.probationEndDate,
        fallbackMonths: 3,
      );
      await _probationService.createProbationRecord(
        employeeId: created.id,
        employeeName: created.fullName,
        employeeEmail: created.email,
        startDate: created.hireDate,
        durationMonths: durationMonths,
      );
    }

    if (created.employmentType == EmploymentType.contract) {
      await _contractService.createContract(
        employeeId: created.id,
        employeeName: created.fullName,
        contractType: ContractType.fixedTerm,
        startDate: created.hireDate,
        endDate: created.contractEndDate,
        contractSalary: created.basicSalary,
        createdBy: 'system',
      );
    }

    return created;
  }

  Future<List<Employee>> getEmployeesByType(EmploymentType type) async {
    final allEmployees = await getAllEmployees();
    return allEmployees
        .where((employee) => employee.employmentType == type)
        .toList();
  }

  Future<Employee?> findByEmail(String email) async {
    final normalized = email.trim().toLowerCase();
    final allEmployees = await getAllEmployees();
    for (final employee in allEmployees) {
      if (employee.email.trim().toLowerCase() == normalized) {
        return employee;
      }
    }
    return null;
  }

  Future<void> addEmployee(
    Employee employee, {
    String? companyIdOverride,
  }) async {
    try {
      final companyId = companyIdOverride ?? await getCompanyId();
      final employees = companyCollectionRef(companyId, _collection);
      final created = employee.copyWith(companyId: companyId);
      final encryptedEmployee = await created.toJsonEncrypted();
      await employees.doc(employee.id).set(encryptedEmployee);
      await _auditService.logAction(
        action: AuditAction.employeeCreated,
        entityType: 'employee',
        entityId: created.id,
        entityName: created.fullName,
        after: await created.toAuditJson(),
      );
    } catch (e) {
      debugPrint('Error adding employee: $e');
      rethrow;
    }
  }

  Future<List<Employee>> getAllEmployees() async {
    try {
      final employees = await companyCollection(_collection);
      final snapshot = await employees.get();
      final parsedEmployees = await Future.wait(
        snapshot.docs.map((doc) => Employee.fromJsonEncrypted(docData(doc))),
      );
      return parsedEmployees.where((employee) => !employee.isDeleted).toList();
    } catch (e) {
      debugPrint('Error getting employees: $e');
      return [];
    }
  }

  Future<Employee?> getEmployeeById(String id) async {
    try {
      final employees = await companyCollection(_collection);
      final doc = await employees.doc(id).get();
      if (doc.exists) {
        final data = docDataNullable(doc);
        if (data == null) return null;
        final employee = await Employee.fromJsonEncrypted(data);
        await _repairEmployeeSensitiveFields(doc.reference, data);
        if (employee.isDeleted) return null;
        return employee;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting employee by ID: $e');
      return null;
    }
  }

  Future<Employee?> getEmployeeByUserId(String userId) async {
    try {
      final employees = await companyCollection(_collection);
      final snapshot = await employees
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final data = docData(doc);
        final employee = await Employee.fromJsonEncrypted(data);
        await _repairEmployeeSensitiveFields(doc.reference, data);
        return employee;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting employee by userId: $e');
      return null;
    }
  }

  Future<void> updateEmployee(Employee employee) async {
    try {
      final companyId = (employee.companyId ?? '').trim().isNotEmpty
          ? employee.companyId!.trim()
          : await getCompanyId();
      final before = await getEmployeeById(employee.id);
      final employees = companyCollectionRef(companyId, _collection);
      final updated = employee.copyWith(companyId: companyId);
      final encryptedEmployee = await updated.toJsonEncrypted();
      await employees.doc(employee.id).update(encryptedEmployee);
      await _auditService.logAction(
        action: AuditAction.employeeUpdated,
        entityType: 'employee',
        entityId: updated.id,
        entityName: updated.fullName,
        before: before == null ? null : await before.toAuditJson(),
        after: await updated.toAuditJson(),
      );
    } catch (e) {
      debugPrint('Error updating employee: $e');
      rethrow;
    }
  }

  Future<void> deleteEmployee(
    String id, {
    String reason = 'User deleted record',
  }) async {
    try {
      final existing = await getEmployeeById(id);
      if (existing == null) return;
      await softDelete(_collection, id, reason: reason);
      await _auditService.logAction(
        action: AuditAction.employeeDeleted,
        entityType: 'employee',
        entityId: id,
        entityName: existing.fullName,
        before: await existing.toAuditJson(),
      );
    } catch (e) {
      debugPrint('Error deleting employee: $e');
      rethrow;
    }
  }

  Stream<List<Employee>> getEmployeesStream() async* {
    try {
      final employees = await companyCollection(_collection);
      Future<List<Employee>> parseEmployees(
        QuerySnapshot<Map<String, dynamic>> snapshot,
      ) async {
        final parsedEmployees = <Employee>[];
        for (final doc in snapshot.docs) {
          try {
            parsedEmployees.add(await Employee.fromJsonEncrypted(docData(doc)));
          } catch (e) {
            debugPrint('Error parsing employee ${doc.id}: $e');
            rethrow;
          }
        }
        return parsedEmployees
            .where((employee) => !employee.isDeleted)
            .toList();
      }

      if (kIsWeb) {
        yield* webPollingStream(
          () async => parseEmployees(await employees.get()),
        );
        return;
      }

      yield* employees.snapshots().asyncMap(parseEmployees);
    } catch (_) {}
  }

  Future<List<Employee>> searchEmployees(String query) async {
    try {
      final allEmployees = await getAllEmployees();
      return allEmployees.where((employee) {
        final fullName = '${employee.firstName} ${employee.lastName}'
            .toLowerCase();
        return fullName.contains(query.toLowerCase());
      }).toList();
    } catch (e) {
      debugPrint('Error searching employees: $e');
      return [];
    }
  }

  Future<List<Employee>> getEmployeesByDepartment(String department) async {
    try {
      final allEmployees = await getAllEmployees();
      return allEmployees
          .where((employee) => employee.department == department)
          .toList();
    } catch (e) {
      debugPrint('Error getting employees by department: $e');
      return [];
    }
  }

  Future<List<Employee>> getDeletedEmployees() async {
    try {
      final employees = await companyCollection(_collection);
      final snapshot = await employees.get();
      final parsedEmployees = await Future.wait(
        snapshot.docs.map((doc) => Employee.fromJsonEncrypted(docData(doc))),
      );
      return parsedEmployees.where((employee) => employee.isDeleted).toList();
    } catch (e) {
      debugPrint('Error getting deleted employees: $e');
      return [];
    }
  }

  Future<void> restoreEmployee(String employeeId) async {
    try {
      await restoreSoftDeleted(_collection, employeeId);
      final employees = await companyCollection(_collection);
      final doc = await employees.doc(employeeId).get();
      if (!doc.exists) return;
      final data = docDataNullable(doc);
      if (data == null) return;
      final restored = await Employee.fromJsonEncrypted(data);
      await _auditService.logAction(
        action: AuditAction.restore,
        entityType: 'employee',
        entityId: employeeId,
        entityName: restored.fullName,
        after: await restored.toAuditJson(),
      );
    } catch (e) {
      debugPrint('Error restoring employee: $e');
      rethrow;
    }
  }

  Future<bool> migrateEmployeeSensitiveFields(String employeeId) async {
    final employees = await companyCollection(_collection);
    final doc = await employees.doc(employeeId).get();
    if (!doc.exists) return false;
    final data = docDataNullable(doc);
    if (data == null) return false;
    return _repairEmployeeSensitiveFields(doc.reference, data);
  }

  Future<int> migrateAllEmployeeSensitiveFields() async {
    final employees = await companyCollection(_collection);
    final snapshot = await employees.get();
    var migrated = 0;

    for (final doc in snapshot.docs) {
      try {
        final updated = await _repairEmployeeSensitiveFields(
          doc.reference,
          docData(doc),
        );
        if (updated) {
          migrated++;
        }
      } catch (e) {
        debugPrint('Error migrating employee ${doc.id}: $e');
      }
    }

    return migrated;
  }

  Future<ImportResult> importEmployeesFromCsv(
    String csvData, {
    bool hasHeader = true,
  }) async {
    final rows = _parseCsv(csvData);
    if (rows.isEmpty) {
      return ImportResult(total: 0, failed: 1, errors: ['CSV is empty.']);
    }

    final header = hasHeader ? rows.first : const <String>[];
    final dataRows = hasHeader ? rows.skip(1).toList() : rows;
    final result = ImportResult(total: dataRows.length);
    final headerMap = <String, int>{};
    for (int i = 0; i < header.length; i++) {
      headerMap[header[i].trim().toLowerCase()] = i;
    }

    for (int i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      final csvRowNumber = i + (hasHeader ? 2 : 1);
      try {
        final fullNameSource = _readValue(row, headerMap, [
          'full_name',
          'fullname',
          'full name',
        ]);
        final fallbackFullName = fullNameSource.isNotEmpty
            ? fullNameSource
            : _readIndex(row, 0);
        final splitNames = _splitFullName(fallbackFullName);

        final firstName = _readValue(row, headerMap, [
          'first_name',
          'firstname',
          'first name',
        ]);
        final lastName = _readValue(row, headerMap, [
          'last_name',
          'lastname',
          'last name',
        ]);
        final email = _readValue(row, headerMap, ['email']).isNotEmpty
            ? _readValue(row, headerMap, ['email']).trim()
            : _readIndex(row, 2).trim();
        final phone =
            _readValue(row, headerMap, [
              'phone',
              'phone_number',
              'phone number',
            ]).isNotEmpty
            ? _readValue(row, headerMap, [
                'phone',
                'phone_number',
                'phone number',
              ]).trim()
            : _readIndex(row, 3).trim();
        final department = _readValue(row, headerMap, ['department']).isNotEmpty
            ? _readValue(row, headerMap, ['department']).trim()
            : _readIndex(row, 4).trim();
        final position =
            _readValue(row, headerMap, [
              'position',
              'job_title',
              'job title',
            ]).isNotEmpty
            ? _readValue(row, headerMap, [
                'position',
                'job_title',
                'job title',
              ]).trim()
            : _readIndex(row, 5).trim();
        final salaryRaw =
            _readValue(row, headerMap, [
              'basic_salary',
              'basicsalary',
              'salary',
              'basic salary',
            ]).isNotEmpty
            ? _readValue(row, headerMap, [
                'basic_salary',
                'basicsalary',
                'salary',
                'basic salary',
              ])
            : _readIndex(row, 6);
        final hireDateRaw =
            _readValue(row, headerMap, [
              'hire_date',
              'hiredate',
              'date_hired',
              'date hired',
            ]).isNotEmpty
            ? _readValue(row, headerMap, [
                'hire_date',
                'hiredate',
                'date_hired',
                'date hired',
              ])
            : _readIndex(row, 7);

        final basicSalary = double.tryParse(
          salaryRaw.replaceAll(',', '').trim(),
        );
        final hireDate = DateTime.tryParse(hireDateRaw.trim());

        final resolvedFirstName = firstName.trim().isNotEmpty
            ? firstName.trim()
            : splitNames.$1.trim();
        final resolvedLastName = lastName.trim().isNotEmpty
            ? lastName.trim()
            : splitNames.$2.trim();

        if (resolvedFirstName.isEmpty) {
          throw Exception('First name is required');
        }
        if (email.isEmpty) {
          throw Exception('Email is required');
        }
        if (basicSalary == null) {
          throw Exception('Invalid basic salary: "$salaryRaw"');
        }
        if (hireDate == null) {
          throw Exception(
            'Invalid hire date: "$hireDateRaw" (expected YYYY-MM-DD)',
          );
        }

        final employee = Employee(
          id: const Uuid().v4(),
          firstName: resolvedFirstName,
          lastName: resolvedLastName,
          email: email,
          phone: phone,
          department: department.isEmpty ? 'Not Assigned' : department,
          position: position.isEmpty ? 'Not Assigned' : position,
          basicSalary: basicSalary,
          hireDate: hireDate,
          status: 'active',
        );

        await addEmployee(employee);
        result.successful++;
      } catch (e) {
        result.failed++;
        result.errors.add('Row $csvRowNumber: $e');
      }
    }

    return result;
  }

  int _resolveDurationMonths(
    DateTime startDate,
    DateTime? endDate, {
    required int fallbackMonths,
  }) {
    if (endDate == null) return fallbackMonths;
    var months =
        (endDate.year - startDate.year) * 12 +
        (endDate.month - startDate.month);
    if (endDate.day < startDate.day) {
      months -= 1;
    }
    return months <= 0 ? fallbackMonths : months;
  }

  List<List<String>> _parseCsv(String data) {
    final rows = <List<String>>[];
    final currentRow = <String>[];
    final field = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < data.length; i++) {
      final char = data[i];
      final next = i + 1 < data.length ? data[i + 1] : '';

      if (char == '"') {
        if (inQuotes && next == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        currentRow.add(field.toString());
        field.clear();
      } else if ((char == '\n' || char == '\r') && !inQuotes) {
        if (char == '\r' && next == '\n') i++;
        currentRow.add(field.toString());
        field.clear();
        if (currentRow.any((value) => value.trim().isNotEmpty)) {
          rows.add(List<String>.from(currentRow));
        }
        currentRow.clear();
      } else {
        field.write(char);
      }
    }

    if (field.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(field.toString());
      if (currentRow.any((value) => value.trim().isNotEmpty)) {
        rows.add(List<String>.from(currentRow));
      }
    }

    return rows;
  }

  String _readValue(
    List<String> row,
    Map<String, int> headerMap,
    List<String> keys,
  ) {
    for (final key in keys) {
      final idx = headerMap[key];
      if (idx != null && idx < row.length) {
        return row[idx];
      }
    }
    return '';
  }

  String _readIndex(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index];
  }

  (String, String) _splitFullName(String fullName) {
    final normalized = fullName.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return ('', '');
    final parts = normalized.split(' ');
    if (parts.length == 1) return (parts.first, '');
    final firstName = parts.first;
    final lastName = parts.sublist(1).join(' ');
    return (firstName, lastName);
  }

  Future<bool> _repairEmployeeSensitiveFields(
    DocumentReference<Map<String, dynamic>> ref,
    Map<String, dynamic> currentData,
  ) async {
    final normalized = await EncryptionService.normalizeFieldsForStorage(
      currentData,
      Employee.sensitiveFields,
    );

    final updates = <String, dynamic>{};
    for (final field in Employee.sensitiveFields) {
      if (!normalized.containsKey(field)) continue;
      final normalizedValue = normalized[field];
      final currentValue = currentData[field];
      if (normalizedValue != null && normalizedValue != currentValue) {
        updates[field] = normalizedValue;
      }
    }

    if (updates.isEmpty) {
      return false;
    }

    await ref.set(updates, SetOptions(merge: true));
    return true;
  }
}
