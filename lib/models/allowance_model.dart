import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeAllowances {
  final String employeeId;
  final double housingAllowance;
  final double transportAllowance;
  final double medicalAllowance;
  final double mealAllowance;
  final Map<String, double> customAllowances;

  EmployeeAllowances({
    required this.employeeId,
    this.housingAllowance = 0,
    this.transportAllowance = 0,
    this.medicalAllowance = 0,
    this.mealAllowance = 0,
    this.customAllowances = const {},
  });

  double get totalAllowances {
    double total = housingAllowance + transportAllowance + medicalAllowance + mealAllowance;
    customAllowances.forEach((key, value) {
      total += value;
    });
    return total;
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'housingAllowance': housingAllowance,
      'transportAllowance': transportAllowance,
      'medicalAllowance': medicalAllowance,
      'mealAllowance': mealAllowance,
      'customAllowances': customAllowances,
    };
  }

  factory EmployeeAllowances.fromJson(Map<String, dynamic> json) {
    return EmployeeAllowances(
      employeeId: json['employeeId'] ?? '',
      housingAllowance: (json['housingAllowance'] ?? 0).toDouble(),
      transportAllowance: (json['transportAllowance'] ?? 0).toDouble(),
      medicalAllowance: (json['medicalAllowance'] ?? 0).toDouble(),
      mealAllowance: (json['mealAllowance'] ?? 0).toDouble(),
      customAllowances: Map<String, double>.from(json['customAllowances'] ?? {}),
    );
  }
}

class EmployeeDeductions {
  final String employeeId;
  final double loanDeduction;
  final double advanceDeduction;
  final double unionDues;
  final double cooperativeContribution;
  final Map<String, double> customDeductions;

  EmployeeDeductions({
    required this.employeeId,
    this.loanDeduction = 0,
    this.advanceDeduction = 0,
    this.unionDues = 0,
    this.cooperativeContribution = 0,
    this.customDeductions = const {},
  });

  double get totalDeductions {
    double total = loanDeduction + advanceDeduction + unionDues + cooperativeContribution;
    customDeductions.forEach((key, value) {
      total += value;
    });
    return total;
  }

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'loanDeduction': loanDeduction,
      'advanceDeduction': advanceDeduction,
      'unionDues': unionDues,
      'cooperativeContribution': cooperativeContribution,
      'customDeductions': customDeductions,
    };
  }

  factory EmployeeDeductions.fromJson(Map<String, dynamic> json) {
    return EmployeeDeductions(
      employeeId: json['employeeId'] ?? '',
      loanDeduction: (json['loanDeduction'] ?? 0).toDouble(),
      advanceDeduction: (json['advanceDeduction'] ?? 0).toDouble(),
      unionDues: (json['unionDues'] ?? 0).toDouble(),
      cooperativeContribution: (json['cooperativeContribution'] ?? 0).toDouble(),
      customDeductions: Map<String, double>.from(json['customDeductions'] ?? {}),
    );
  }
}

enum AllowanceValueType { fixed, percentage }

enum AllowanceFrequency { recurring, oneTime }

enum AllowancePercentageBase { basicSalary, grossSalary }

class AllowanceDefinition {
  final String id;
  final String name;
  final AllowanceValueType valueType;
  final double amount;
  final bool taxable;
  final AllowanceFrequency frequency;
  final AllowancePercentageBase percentageBase;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  AllowanceDefinition({
    required this.id,
    required this.name,
    required this.valueType,
    required this.amount,
    required this.taxable,
    required this.frequency,
    this.percentageBase = AllowancePercentageBase.basicSalary,
    this.isActive = true,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'valueType': valueType.name,
      'amount': amount,
      'taxable': taxable,
      'frequency': frequency.name,
      'percentageBase': percentageBase.name,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory AllowanceDefinition.fromJson(Map<String, dynamic> json) {
    AllowanceValueType parseValueType(String? raw) {
      return AllowanceValueType.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => AllowanceValueType.fixed,
      );
    }

    AllowanceFrequency parseFrequency(String? raw) {
      return AllowanceFrequency.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => AllowanceFrequency.recurring,
      );
    }

    AllowancePercentageBase parseBase(String? raw) {
      return AllowancePercentageBase.values.firstWhere(
        (value) => value.name == raw,
        orElse: () => AllowancePercentageBase.basicSalary,
      );
    }

    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return AllowanceDefinition(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      valueType: parseValueType(json['valueType']),
      amount: (json['amount'] ?? 0).toDouble(),
      taxable: json['taxable'] ?? true,
      frequency: parseFrequency(json['frequency']),
      percentageBase: parseBase(json['percentageBase']),
      isActive: json['isActive'] ?? true,
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }
}

class EmployeeAllowanceAssignment {
  final String id;
  final String employeeId;
  final String allowanceId;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? lastPaidPeriod;
  final DateTime createdAt;
  final DateTime? updatedAt;

  EmployeeAllowanceAssignment({
    required this.id,
    required this.employeeId,
    required this.allowanceId,
    this.isActive = true,
    this.startDate,
    this.endDate,
    this.lastPaidPeriod,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool isActiveFor(DateTime periodStart, DateTime periodEnd) {
    if (!isActive) return false;
    if (startDate != null && startDate!.isAfter(periodEnd)) return false;
    if (endDate != null && endDate!.isBefore(periodStart)) return false;
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'allowanceId': allowanceId,
      'isActive': isActive,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'lastPaidPeriod': lastPaidPeriod,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory EmployeeAllowanceAssignment.fromJson(Map<String, dynamic> json) {
    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return EmployeeAllowanceAssignment(
      id: json['id'] ?? '',
      employeeId: json['employeeId'] ?? '',
      allowanceId: json['allowanceId'] ?? '',
      isActive: json['isActive'] ?? true,
      startDate: readDate(json['startDate']),
      endDate: readDate(json['endDate']),
      lastPaidPeriod: json['lastPaidPeriod'],
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }
}

class AllowanceLineItem {
  final String allowanceId;
  final String name;
  final double amount;
  final bool taxable;
  final AllowanceFrequency frequency;

  AllowanceLineItem({
    required this.allowanceId,
    required this.name,
    required this.amount,
    required this.taxable,
    required this.frequency,
  });
}

class AllowanceCalculation {
  final double total;
  final double taxableTotal;
  final double nonTaxableTotal;
  final List<AllowanceLineItem> items;
  final List<String> appliedOneTimeAssignmentIds;
  final bool usedNewModel;

  const AllowanceCalculation({
    required this.total,
    required this.taxableTotal,
    required this.nonTaxableTotal,
    required this.items,
    required this.appliedOneTimeAssignmentIds,
    required this.usedNewModel,
  });
}
