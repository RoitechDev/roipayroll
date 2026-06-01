import 'package:uuid/uuid.dart';

enum AlertSeverity { critical, warning, info }

enum AlertType {
  missingSalary,
  duplicateEmail,
  payrollProcessed,
  userWithoutRole,
  highLoanRatio,
  noAttendance,
  missingLeaveBalance,
  excessiveDeductions,
}

class SystemAlert {
  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final String? employeeId;
  final String? employeeName;
  final Map<String, dynamic>? metadata;

  SystemAlert({
    String? id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    this.employeeId,
    this.employeeName,
    this.metadata,
  }) : id = id ?? const Uuid().v4();

  bool get isBlocking => severity == AlertSeverity.critical;
}
