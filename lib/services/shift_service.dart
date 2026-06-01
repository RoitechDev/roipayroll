import 'package:roipayroll/models/shift_model.dart';
import 'package:roipayroll/services/base_service.dart';

class ShiftService extends BaseService {
  final String _collection = 'shifts';

  // Create shift
  Future<void> createShift(Shift shift) async {
    final shiftsRef = await companyCollection(_collection);
    await shiftsRef.doc(shift.id).set(shift.toJson());
  }

  // Get shift by ID
  Future<Shift?> getShiftById(String shiftId) async {
    try {
      final shiftsRef = await companyCollection(_collection);
      final doc = await shiftsRef.doc(shiftId).get();
      if (doc.exists) {
        final data = docDataNullable(doc);
        if (data != null) {
          return Shift.fromJson(data);
        }
      }

      // Return default shift if not found
      return Shift.defaultShift;
    } catch (e) {
      print('Error getting shift: $e');
      return Shift.defaultShift;
    }
  }

  // Get all active shifts
  Future<List<Shift>> getAllShifts() async {
    try {
      final shiftsRef = await companyCollection(_collection);
      final snapshot = await shiftsRef.where('isActive', isEqualTo: true).get();

      return snapshot.docs.map((doc) => Shift.fromJson(docData(doc))).toList();
    } catch (e) {
      print('Error getting shifts: $e');
      return [];
    }
  }

  // Update shift
  Future<void> updateShift(Shift shift) async {
    final shiftsRef = await companyCollection(_collection);
    await shiftsRef.doc(shift.id).update(shift.toJson());
  }

  // Delete shift
  Future<void> deleteShift(String shiftId) async {
    final shiftsRef = await companyCollection(_collection);
    await shiftsRef.doc(shiftId).delete();
  }

  // Initialize default shift if none exists
  Future<void> initializeDefaultShift() async {
    try {
      final shiftsRef = await companyCollection(_collection);
      final doc = await shiftsRef.doc('default').get();

      if (!doc.exists) {
        print('Creating default shift...');
        await createShift(Shift.defaultShift);
        print('✅ Default shift created');
      }
    } catch (e) {
      print('Error initializing default shift: $e');
    }
  }

  // Get employee's assigned shift (for now, everyone uses default)
  Future<Shift> getEmployeeShift(String employeeId) async {
    // TODO: In future, fetch from employee's assigned shift
    // For now, return default shift
    return await getShiftById('default') ?? Shift.defaultShift;
  }

  // Assign shift to employee
  Future<void> assignShiftToEmployee(String employeeId, String shiftId) async {
    final employeesRef = await companyCollection('employees');
    await employeesRef.doc(employeeId).update({'shiftId': shiftId});
  }
}
