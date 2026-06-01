import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/public_holiday_model.dart';
import 'package:roipayroll/services/base_service.dart';

class PublicHolidayService extends BaseService {
  final String _collection = 'public_holidays';

  // Create holiday
  Future<void> createHoliday(PublicHoliday holiday) async {
    final holidaysRef = await companyCollection(_collection);
    await holidaysRef.doc(holiday.id).set(holiday.toJson());
  }

  Future<void> addHoliday(PublicHoliday holiday) async {
    await createHoliday(holiday);
  }

  // Get holidays for a year
  Future<List<PublicHoliday>> getHolidaysForYear(int year) async {
    final startDate = DateTime(year, 1, 1);
    final endDate = DateTime(year, 12, 31);

    final holidaysRef = await companyCollection(_collection);
    final snapshot = await holidaysRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date')
        .get();

    return snapshot.docs
        .map((doc) => PublicHoliday.fromJson(docData(doc)))
        .toList();
  }

  Future<List<PublicHoliday>> getHolidaysByYear(int year) async {
    return getHolidaysForYear(year);
  }

  // Get holidays in date range
  Future<List<PublicHoliday>> getHolidaysInRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final holidaysRef = await companyCollection(_collection);
    final snapshot = await holidaysRef
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('date')
        .get();

    return snapshot.docs
        .map((doc) => PublicHoliday.fromJson(docData(doc)))
        .toList();
  }

  // Update holiday
  Future<void> updateHoliday(PublicHoliday holiday) async {
    final holidaysRef = await companyCollection(_collection);
    await holidaysRef.doc(holiday.id).update(holiday.toJson());
  }

  // Delete holiday
  Future<void> deleteHoliday(String id) async {
    final holidaysRef = await companyCollection(_collection);
    await holidaysRef.doc(id).delete();
  }

  // Initialize Nigerian public holidays for 2026
  Future<void> initialize2026Holidays() async {
    final existing = await getHolidaysForYear(2026);
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final holidays = [
      PublicHoliday(
        id: 'new_year_2026',
        name: 'New Year\'s Day',
        date: DateTime(2026, 1, 1),
        type: HolidayType.national,
        description: 'New Year celebration',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'good_friday_2026',
        name: 'Good Friday',
        date: DateTime(2026, 4, 3),
        type: HolidayType.religious,
        description: 'Christian holiday',
        isRecurring: false,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'easter_monday_2026',
        name: 'Easter Monday',
        date: DateTime(2026, 4, 6),
        type: HolidayType.religious,
        description: 'Christian holiday',
        isRecurring: false,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'workers_day_2026',
        name: 'Workers\' Day',
        date: DateTime(2026, 5, 1),
        type: HolidayType.national,
        description: 'International Workers\' Day',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'democracy_day_2026',
        name: 'Democracy Day',
        date: DateTime(2026, 6, 12),
        type: HolidayType.national,
        description: 'Commemoration of democracy',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'eid_al_fitr_2026',
        name: 'Eid-el-Fitr',
        date: DateTime(2026, 4, 20),
        type: HolidayType.religious,
        description: 'End of Ramadan',
        isRecurring: false,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'eid_al_adha_2026',
        name: 'Eid-el-Kabir',
        date: DateTime(2026, 6, 27),
        type: HolidayType.religious,
        description: 'Feast of Sacrifice',
        isRecurring: false,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'independence_day_2026',
        name: 'Independence Day',
        date: DateTime(2026, 10, 1),
        type: HolidayType.national,
        description: 'Nigeria\'s Independence',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'christmas_2026',
        name: 'Christmas Day',
        date: DateTime(2026, 12, 25),
        type: HolidayType.religious,
        description: 'Christian holiday',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'boxing_day_2026',
        name: 'Boxing Day',
        date: DateTime(2026, 12, 26),
        type: HolidayType.national,
        description: 'Day after Christmas',
        isRecurring: true,
        createdAt: now,
      ),
    ];

    for (var holiday in holidays) {
      await createHoliday(holiday);
    }
  }

  Future<void> initializeDefaultHolidays() async {
    await initialize2026Holidays();
  }
}
