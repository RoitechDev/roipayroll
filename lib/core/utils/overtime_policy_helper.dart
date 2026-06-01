class OvertimePolicy {
  final bool enabled;
  final double weekdayMultiplier;
  final double weekendMultiplier;
  final double holidayMultiplier;

  const OvertimePolicy({
    required this.enabled,
    required this.weekdayMultiplier,
    required this.weekendMultiplier,
    required this.holidayMultiplier,
  });
}

class OvertimePolicyHelper {
  static const double fallbackHourlyRate = 1000.0;
  static const OvertimePolicy defaultPolicy = OvertimePolicy(
    enabled: true,
    weekdayMultiplier: 1.5,
    weekendMultiplier: 2.0,
    holidayMultiplier: 2.0,
  );

  static OvertimePolicy fromSettings(Map<String, dynamic> settings) {
    return OvertimePolicy(
      enabled: _asBool(settings['overtimeEnabled'], fallback: true),
      weekdayMultiplier: _asDouble(
        settings['overtimeWeekdayMultiplier'],
        fallback: 1.5,
      ),
      weekendMultiplier: _asDouble(
        settings['overtimeWeekendMultiplier'],
        fallback: 2.0,
      ),
      holidayMultiplier: _asDouble(
        settings['overtimeHolidayMultiplier'],
        fallback: 2.0,
      ),
    );
  }

  static double resolveBaseHourlyRate(double basicSalary) {
    if (basicSalary <= 0) return fallbackHourlyRate;
    // 173.33 ~= (40 hours/week * 52 weeks) / 12 months
    return basicSalary / 173.33;
  }

  static String dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static bool _asBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true') return true;
      if (v == 'false') return false;
    }
    return fallback;
  }

  static double _asDouble(dynamic value, {required double fallback}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
