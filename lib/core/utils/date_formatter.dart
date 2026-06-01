import 'package:intl/intl.dart';

/// Date formatting utilities
class DateFormatter {
  // Common date formats
  static final DateFormat _standardFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _longFormat = DateFormat('MMMM dd, yyyy');
  static final DateFormat _shortFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _monthYearFormat = DateFormat('MMMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  
  // Format date as: 13/12/2024
  static String formatStandard(DateTime date) {
    return _standardFormat.format(date);
  }
  
  // Format date as: December 13, 2024
  static String formatLong(DateTime date) {
    return _longFormat.format(date);
  }
  
  // Format date as: 13 Dec 2024
  static String formatShort(DateTime date) {
    return _shortFormat.format(date);
  }
  
  // Format as: December 2024
  static String formatMonthYear(DateTime date) {
    return _monthYearFormat.format(date);
  }
  
  // Format time as: 02:30 PM
  static String formatTime(DateTime date) {
    return _timeFormat.format(date);
  }
  
  // Format date and time as: 13/12/2024 02:30 PM
  static String formatDateTime(DateTime date) {
    return _dateTimeFormat.format(date);
  }
  
  // Get relative time (e.g., "2 days ago", "Just now")
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years ${years == 1 ? 'year' : 'years'} ago';
    }
  }
  
  // Check if date is today
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }
  
  // Check if date is yesterday
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && 
           date.month == yesterday.month && 
           date.day == yesterday.day;
  }
  
  // Format with "Today", "Yesterday", or actual date
  static String formatSmart(DateTime date) {
    if (isToday(date)) {
      return 'Today';
    } else if (isYesterday(date)) {
      return 'Yesterday';
    } else {
      return formatShort(date);
    }
  }
  
  // Get month name
  static String getMonthName(int month) {
    final date = DateTime(2024, month, 1);
    return DateFormat('MMMM').format(date);
  }
  
  // Get short month name (Jan, Feb, etc.)
  static String getShortMonthName(int month) {
    final date = DateTime(2024, month, 1);
    return DateFormat('MMM').format(date);
  }
  
  // Parse string to DateTime
  // Supports: "13/12/2024", "2024-12-13", etc.
  static DateTime? parseDate(String dateString) {
    try {
      // Try standard format first (dd/MM/yyyy)
      return _standardFormat.parse(dateString);
    } catch (e) {
      try {
        // Try ISO format (yyyy-MM-dd)
        return DateTime.parse(dateString);
      } catch (e) {
        return null;
      }
    }
  }
  
  // Get first day of month
  static DateTime getFirstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }
  
  // Get last day of month
  static DateTime getLastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }
  
  // Get number of days in month
  static int getDaysInMonth(DateTime date) {
    return getLastDayOfMonth(date).day;
  }
  
  // Calculate age from date of birth
  static int calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    
    if (now.month < birthDate.month || 
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }
  
  // Calculate work duration (years and months)
  static String calculateWorkDuration(DateTime hireDate) {
    final now = DateTime.now();
    int years = now.year - hireDate.year;
    int months = now.month - hireDate.month;
    
    if (months < 0) {
      years--;
      months += 12;
    }
    
    if (years == 0) {
      return '$months ${months == 1 ? 'month' : 'months'}';
    } else if (months == 0) {
      return '$years ${years == 1 ? 'year' : 'years'}';
    } else {
      return '$years ${years == 1 ? 'year' : 'years'}, $months ${months == 1 ? 'month' : 'months'}';
    }
  }
  
  // Get payroll period label (e.g., "December 2024")
  static String getPayrollPeriod(int month, int year) {
    final date = DateTime(year, month, 1);
    return formatMonthYear(date);
  }
  
  // Check if date is in the past
  static bool isPast(DateTime date) {
    return date.isBefore(DateTime.now());
  }
  
  // Check if date is in the future
  static bool isFuture(DateTime date) {
    return date.isAfter(DateTime.now());
  }
  
  // Get current month and year
  static Map<String, int> getCurrentMonthYear() {
    final now = DateTime.now();
    return {
      'month': now.month,
      'year': now.year,
    };
  }
}
