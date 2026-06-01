import 'package:cloud_firestore/cloud_firestore.dart';

enum HolidayType {
  national, // National public holiday
  religious, // Religious holiday
  regional, // State/regional holiday
  company, // Company-specific holiday
}

/// Public Holiday Configuration
class PublicHoliday {
  final String id;
  final String name;
  final DateTime date;
  final HolidayType type;
  final String? description;
  final bool isRecurring; // Does it repeat yearly?
  final bool isOptional; // Optional holiday?
  final List<String>? applicableStates; // null = all states
  final bool isActive;
  final DateTime createdAt;

  PublicHoliday({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    this.description,
    this.isRecurring = true,
    this.isOptional = false,
    this.applicableStates,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': Timestamp.fromDate(date),
      'type': type.name,
      'description': description,
      'isRecurring': isRecurring,
      'isOptional': isOptional,
      'applicableStates': applicableStates,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PublicHoliday.fromJson(Map<String, dynamic> json) {
    return PublicHoliday(
      id: json['id'],
      name: json['name'],
      date: (json['date'] as Timestamp).toDate(),
      type: HolidayType.values.firstWhere((e) => e.name == json['type']),
      description: json['description'],
      isRecurring: json['isRecurring'] ?? true,
      isOptional: json['isOptional'] ?? false,
      applicableStates: json['applicableStates'] != null
          ? List<String>.from(json['applicableStates'])
          : null,
      isActive: json['isActive'] ?? true,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  // Default Nigerian public holidays for 2026
  static List<PublicHoliday> get defaultHolidays2026 {
    final now = DateTime.now();
    
    return [
      PublicHoliday(
        id: 'new-year-2026',
        name: 'New Year\'s Day',
        date: DateTime(2026, 1, 1),
        type: HolidayType.national,
        description: 'First day of the year',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'good-friday-2026',
        name: 'Good Friday',
        date: DateTime(2026, 4, 3),
        type: HolidayType.religious,
        description: 'Christian holiday',
        isRecurring: false,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'easter-monday-2026',
        name: 'Easter Monday',
        date: DateTime(2026, 4, 6),
        type: HolidayType.religious,
        description: 'Christian holiday',
        isRecurring: false,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'workers-day-2026',
        name: 'Workers\' Day',
        date: DateTime(2026, 5, 1),
        type: HolidayType.national,
        description: 'International Workers\' Day',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'democracy-day-2026',
        name: 'Democracy Day',
        date: DateTime(2026, 6, 12),
        type: HolidayType.national,
        description: 'Celebration of democracy',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'eid-al-adha-2026',
        name: 'Eid-al-Adha',
        date: DateTime(2026, 6, 16),
        type: HolidayType.religious,
        description: 'Islamic festival of sacrifice',
        isRecurring: false,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'independence-day-2026',
        name: 'Independence Day',
        date: DateTime(2026, 10, 1),
        type: HolidayType.national,
        description: 'Nigeria\'s Independence Day',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'christmas-2026',
        name: 'Christmas Day',
        date: DateTime(2026, 12, 25),
        type: HolidayType.religious,
        description: 'Christian holiday',
        isRecurring: true,
        createdAt: now,
      ),
      PublicHoliday(
        id: 'boxing-day-2026',
        name: 'Boxing Day',
        date: DateTime(2026, 12, 26),
        type: HolidayType.national,
        description: 'Day after Christmas',
        isRecurring: true,
        createdAt: now,
      ),
    ];
  }
}
