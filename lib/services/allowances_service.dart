import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/allowance_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:uuid/uuid.dart';

/// Service for managing employee allowances and deductions
class AllowancesService extends BaseService {
  final String _allowancesCollection = 'employee_allowances';
  final String _deductionsCollection = 'employee_deductions';
  final String _allowanceTypesCollection = 'allowance_types';
  final String _allowanceAssignmentsCollection =
      'employee_allowance_assignments';

  // Save or update employee allowances
  Future<void> saveAllowances(EmployeeAllowances allowances) async {
    final allowancesRef = await companyCollection(_allowancesCollection);
    await allowancesRef.doc(allowances.employeeId).set(allowances.toJson());
  }

  // Get employee allowances
  Future<EmployeeAllowances> getAllowances(String employeeId) async {
    try {
      final allowancesRef = await companyCollection(_allowancesCollection);
      final doc = await allowancesRef.doc(employeeId).get();

      if (doc.exists) {
        final data = docDataNullable(doc);
        if (data != null) {
          return EmployeeAllowances.fromJson(data);
        }
      }

      // Return empty allowances if none exist
      return EmployeeAllowances(employeeId: employeeId);
    } catch (e) {
      return EmployeeAllowances(employeeId: employeeId);
    }
  }

  // Save or update employee deductions
  Future<void> saveDeductions(EmployeeDeductions deductions) async {
    final deductionsRef = await companyCollection(_deductionsCollection);
    await deductionsRef.doc(deductions.employeeId).set(deductions.toJson());
  }

  // Get employee deductions
  Future<EmployeeDeductions> getDeductions(String employeeId) async {
    try {
      final deductionsRef = await companyCollection(_deductionsCollection);
      final doc = await deductionsRef.doc(employeeId).get();

      if (doc.exists) {
        final data = docDataNullable(doc);
        if (data != null) {
          return EmployeeDeductions.fromJson(data);
        }
      }

      // Return empty deductions if none exist
      return EmployeeDeductions(employeeId: employeeId);
    } catch (e) {
      return EmployeeDeductions(employeeId: employeeId);
    }
  }

  // Delete employee allowances
  Future<void> deleteAllowances(String employeeId) async {
    final allowancesRef = await companyCollection(_allowancesCollection);
    await allowancesRef.doc(employeeId).delete();
  }

  // Delete employee deductions
  Future<void> deleteDeductions(String employeeId) async {
    final deductionsRef = await companyCollection(_deductionsCollection);
    await deductionsRef.doc(employeeId).delete();
  }

  // Get total allowances for an employee
  Future<double> getTotalAllowances(String employeeId) async {
    final allowances = await getAllowances(employeeId);
    return allowances.totalAllowances;
  }

  // Get total deductions for an employee
  Future<double> getTotalDeductions(String employeeId) async {
    final deductions = await getDeductions(employeeId);
    return deductions.totalDeductions;
  }

  // ===== Allowance Types (new model) =====
  Future<void> saveAllowanceType(AllowanceDefinition allowance) async {
    final ref = await companyCollection(_allowanceTypesCollection);
    await ref.doc(allowance.id).set(allowance.toJson());
  }

  Future<List<AllowanceDefinition>> getAllowanceTypes({
    bool activeOnly = true,
  }) async {
    final ref = await companyCollection(_allowanceTypesCollection);
    Query<Map<String, dynamic>> query = ref;
    if (activeOnly) {
      query = query.where('isActive', isEqualTo: true);
    }
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => AllowanceDefinition.fromJson(docData(doc)))
        .toList();
  }

  Future<void> ensureDefaultAllowanceTypes() async {
    final ref = await companyCollection(_allowanceTypesCollection);
    final snapshot = await ref.get();
    final existingNames = snapshot.docs
        .map((doc) => docData(doc)['name'])
        .whereType<String>()
        .map((name) => name.trim().toLowerCase())
        .toSet();
    final existingIds = snapshot.docs.map((doc) => doc.id).toSet();

    final defaults = <AllowanceDefinition>[
      AllowanceDefinition(
        id: 'housing_allowance',
        name: 'Housing Allowance',
        valueType: AllowanceValueType.fixed,
        amount: 10000,
        taxable: true,
        frequency: AllowanceFrequency.recurring,
        percentageBase: AllowancePercentageBase.basicSalary,
        isActive: true,
      ),
      AllowanceDefinition(
        id: 'transport_allowance',
        name: 'Transport Allowance',
        valueType: AllowanceValueType.fixed,
        amount: 10000,
        taxable: true,
        frequency: AllowanceFrequency.recurring,
        percentageBase: AllowancePercentageBase.basicSalary,
        isActive: true,
      ),
      AllowanceDefinition(
        id: 'medical_allowance',
        name: 'Medical Allowance',
        valueType: AllowanceValueType.fixed,
        amount: 10000,
        taxable: true,
        frequency: AllowanceFrequency.recurring,
        percentageBase: AllowancePercentageBase.basicSalary,
        isActive: true,
      ),
      AllowanceDefinition(
        id: 'meal_allowance',
        name: 'Meal Allowance',
        valueType: AllowanceValueType.fixed,
        amount: 10000,
        taxable: true,
        frequency: AllowanceFrequency.recurring,
        percentageBase: AllowancePercentageBase.basicSalary,
        isActive: true,
      ),
    ];

    for (final allowance in defaults) {
      final nameKey = allowance.name.trim().toLowerCase();
      if (existingNames.contains(nameKey) ||
          existingIds.contains(allowance.id)) {
        continue;
      }
      await ref.doc(allowance.id).set(allowance.toJson());
    }
  }

  Future<void> ensureDefaultAssignmentsForEmployees(
    List<String> employeeIds,
  ) async {
    if (employeeIds.isEmpty) return;
    final allowanceTypes = await getAllowanceTypes(activeOnly: true);
    if (allowanceTypes.isEmpty) return;

    final ref = await companyCollection(_allowanceAssignmentsCollection);
    var batch = ref.firestore.batch();
    var writes = 0;

    Future<void> flushBatch() async {
      if (writes == 0) return;
      await batch.commit();
      batch = ref.firestore.batch();
      writes = 0;
    }

    for (final employeeId in employeeIds) {
      final snapshot = await ref
          .where('employeeId', isEqualTo: employeeId)
          .get();
      final assignedIds = snapshot.docs
          .map((doc) => docData(doc)['allowanceId'])
          .whereType<String>()
          .toSet();

      for (final type in allowanceTypes) {
        if (assignedIds.contains(type.id)) continue;
        final assignment = EmployeeAllowanceAssignment(
          id: const Uuid().v4(),
          employeeId: employeeId,
          allowanceId: type.id,
          isActive: true,
        );
        batch.set(ref.doc(assignment.id), assignment.toJson());
        writes += 1;
        if (writes >= 450) {
          await flushBatch();
        }
      }
    }

    await flushBatch();
  }

  Future<void> assignAllowanceToEmployee({
    required String employeeId,
    required String allowanceId,
    DateTime? startDate,
    DateTime? endDate,
    bool isActive = true,
  }) async {
    final assignment = EmployeeAllowanceAssignment(
      id: const Uuid().v4(),
      employeeId: employeeId,
      allowanceId: allowanceId,
      startDate: startDate,
      endDate: endDate,
      isActive: isActive,
    );
    final ref = await companyCollection(_allowanceAssignmentsCollection);
    await ref.doc(assignment.id).set(assignment.toJson());
  }

  Future<List<EmployeeAllowanceAssignment>> getEmployeeAllowanceAssignments(
    String employeeId,
  ) async {
    final ref = await companyCollection(_allowanceAssignmentsCollection);
    final snapshot = await ref.where('employeeId', isEqualTo: employeeId).get();
    return snapshot.docs
        .map((doc) => EmployeeAllowanceAssignment.fromJson(docData(doc)))
        .toList();
  }

  Future<AllowanceCalculation> calculateEmployeeAllowances({
    required String employeeId,
    required double basicSalary,
    required int month,
    required int year,
    bool includeLegacyFallback = true,
    bool markOneTimePaid = false,
  }) async {
    final periodStart = DateTime(year, month, 1);
    final periodEnd = DateTime(year, month + 1, 0);
    final periodKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

    final assignments = await getEmployeeAllowanceAssignments(employeeId);
    if (assignments.isEmpty && includeLegacyFallback) {
      final legacy = await getAllowances(employeeId);
      if (legacy.totalAllowances <= 0) {
        return const AllowanceCalculation(
          total: 0,
          taxableTotal: 0,
          nonTaxableTotal: 0,
          items: [],
          appliedOneTimeAssignmentIds: [],
          usedNewModel: false,
        );
      }
      return AllowanceCalculation(
        total: legacy.totalAllowances,
        taxableTotal: legacy.totalAllowances,
        nonTaxableTotal: 0,
        items: [
          AllowanceLineItem(
            allowanceId: 'legacy_allowances',
            name: 'Legacy Allowances',
            amount: legacy.totalAllowances,
            taxable: true,
            frequency: AllowanceFrequency.recurring,
          ),
        ],
        appliedOneTimeAssignmentIds: const [],
        usedNewModel: false,
      );
    }

    final allowanceTypes = await getAllowanceTypes(activeOnly: false);
    final typeMap = {for (final type in allowanceTypes) type.id: type};

    double total = 0;
    double taxableTotal = 0;
    double nonTaxableTotal = 0;
    final items = <AllowanceLineItem>[];
    final appliedOneTimeAssignments = <String>[];

    for (final assignment in assignments) {
      if (!assignment.isActiveFor(periodStart, periodEnd)) continue;
      final definition = typeMap[assignment.allowanceId];
      if (definition == null || !definition.isActive) continue;

      if (definition.frequency == AllowanceFrequency.oneTime &&
          assignment.lastPaidPeriod == periodKey) {
        continue;
      }

      double amount;
      switch (definition.valueType) {
        case AllowanceValueType.fixed:
          amount = definition.amount;
          break;
        case AllowanceValueType.percentage:
          final base =
              definition.percentageBase == AllowancePercentageBase.basicSalary
              ? basicSalary
              : basicSalary;
          amount = base * (definition.amount / 100);
          break;
      }

      if (amount <= 0) continue;

      total += amount;
      if (definition.taxable) {
        taxableTotal += amount;
      } else {
        nonTaxableTotal += amount;
      }

      items.add(
        AllowanceLineItem(
          allowanceId: definition.id,
          name: definition.name,
          amount: amount,
          taxable: definition.taxable,
          frequency: definition.frequency,
        ),
      );

      if (definition.frequency == AllowanceFrequency.oneTime) {
        appliedOneTimeAssignments.add(assignment.id);
      }
    }

    if (markOneTimePaid && appliedOneTimeAssignments.isNotEmpty) {
      await markOneTimeAssignmentsPaid(
        appliedOneTimeAssignments,
        month: month,
        year: year,
      );
    }

    return AllowanceCalculation(
      total: total,
      taxableTotal: taxableTotal,
      nonTaxableTotal: nonTaxableTotal,
      items: items,
      appliedOneTimeAssignmentIds: appliedOneTimeAssignments,
      usedNewModel: true,
    );
  }

  Future<void> markOneTimeAssignmentsPaid(
    List<String> assignmentIds, {
    required int month,
    required int year,
  }) async {
    if (assignmentIds.isEmpty) return;
    final periodKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final ref = await companyCollection(_allowanceAssignmentsCollection);
    for (final assignmentId in assignmentIds) {
      await ref.doc(assignmentId).update({
        'lastPaidPeriod': periodKey,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  Future<void> clearOneTimeAssignmentsPaidForPeriod(
    String employeeId, {
    required int month,
    required int year,
  }) async {
    final normalizedEmployeeId = employeeId.trim();
    if (normalizedEmployeeId.isEmpty) return;

    final periodKey =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final ref = await companyCollection(_allowanceAssignmentsCollection);
    final snapshot = await ref
        .where('employeeId', isEqualTo: normalizedEmployeeId)
        .where('lastPaidPeriod', isEqualTo: periodKey)
        .get();
    if (snapshot.docs.isEmpty) return;

    for (final doc in snapshot.docs) {
      await doc.reference.update({
        'lastPaidPeriod': null,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// Migrates all legacy allowance data to the new assignment system
  Future<Map<String, dynamic>> migrateAllLegacyAllowances() async {
    int employeesProcessed = 0;
    int employeesMigrated = 0;
    int allowancesCreated = 0;
    final errors = <String>[];

    try {
      // Get all legacy allowances
      final allowancesRef = await companyCollection(_allowancesCollection);
      final allowancesSnapshot = await allowancesRef.get();

      // Create a map: employeeId -> allowance type -> amount
      final legacyData = <String, Map<String, double>>{};

      for (final doc in allowancesSnapshot.docs) {
        final data = docData(doc);
        final employeeId = data['employeeId'] as String?;
        if (employeeId == null) continue;

        final amounts = <String, double>{};
        if ((data['housingAllowance'] ?? 0) > 0) {
          amounts['housing_allowance'] = (data['housingAllowance'] as num)
              .toDouble();
        }
        if ((data['transportAllowance'] ?? 0) > 0) {
          amounts['transport_allowance'] = (data['transportAllowance'] as num)
              .toDouble();
        }
        if ((data['medicalAllowance'] ?? 0) > 0) {
          amounts['medical_allowance'] = (data['medicalAllowance'] as num)
              .toDouble();
        }
        if ((data['mealAllowance'] ?? 0) > 0) {
          amounts['meal_allowance'] = (data['mealAllowance'] as num).toDouble();
        }

        if (amounts.isNotEmpty) {
          legacyData[employeeId] = amounts;
        }
      }

      employeesProcessed = legacyData.length;

      // For each employee with legacy data
      for (final entry in legacyData.entries) {
        final employeeId = entry.key;
        final amounts = entry.value;

        try {
          // Check if employee already has assignments
          final existingAssignments = await getEmployeeAllowanceAssignments(
            employeeId,
          );
          final existingAllowanceIds = existingAssignments
              .map((a) => a.allowanceId)
              .toSet();

          // Get allowance types
          final allowanceTypes = await getAllowanceTypes(activeOnly: false);
          final typeMap = {for (final type in allowanceTypes) type.id: type};

          // Create assignments for each legacy allowance
          for (final allowanceEntry in amounts.entries) {
            final allowanceId = allowanceEntry.key;
            final amount = allowanceEntry.value;

            // Skip if already assigned
            if (existingAllowanceIds.contains(allowanceId)) continue;

            // Get or create allowance type
            AllowanceDefinition? type = typeMap[allowanceId];

            if (type == null) {
              // Create custom type with the legacy amount
              type = AllowanceDefinition(
                id: allowanceId,
                name: allowanceId
                    .replaceAll('_', ' ')
                    .split(' ')
                    .map((word) => word[0].toUpperCase() + word.substring(1))
                    .join(' '),
                valueType: AllowanceValueType.fixed,
                amount: amount,
                taxable: true,
                frequency: AllowanceFrequency.recurring,
                isActive: true,
              );
              await saveAllowanceType(type);
            }

            // Create assignment
            await assignAllowanceToEmployee(
              employeeId: employeeId,
              allowanceId: allowanceId,
              isActive: true,
            );

            allowancesCreated++;
          }

          employeesMigrated++;
        } catch (e) {
          errors.add('Employee $employeeId: $e');
        }
      }

      // Disable legacy fallback after successful migration
      if (employeesMigrated > 0) {
        await disableLegacyFallback();
      }

      return {
        'success': true,
        'employeesProcessed': employeesProcessed,
        'employeesMigrated': employeesMigrated,
        'allowancesCreated': allowancesCreated,
        'errors': errors,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'employeesProcessed': employeesProcessed,
        'employeesMigrated': employeesMigrated,
        'allowancesCreated': allowancesCreated,
        'errors': errors,
      };
    }
  }

  Future<void> disableLegacyFallback() async {
    final settingsRef = await companyCollection('settings');
    await settingsRef.doc('allowances').set({
      'legacyFallbackEnabled': false,
      'migratedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<bool> isLegacyFallbackEnabled() async {
    try {
      final settingsRef = await companyCollection('settings');
      final doc = await settingsRef.doc('allowances').get();
      if (!doc.exists) return true; // Default to enabled
      final data = docDataNullable(doc);
      return data?['legacyFallbackEnabled'] ?? true;
    } catch (e) {
      return true;
    }
  }
}
