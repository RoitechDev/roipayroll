import 'package:cloud_firestore/cloud_firestore.dart';

enum DeductionCategory {
  statutory,
  loan,
  advance,
  garnishment,
  insurance,
  union,
  other,
}

enum DeductionCalculationMethod { fixedAmount, percentage, formula }

class DeductionType {
  final String id;
  final String name;
  final String? description;
  final DeductionCategory category;
  final DeductionCalculationMethod calculationMethod;
  final double defaultValue;
  final double? percentageRate;
  final String? formula;
  final bool isStatutory;
  final bool isPreTax;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  DeductionType({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.calculationMethod,
    this.defaultValue = 0,
    this.percentageRate,
    this.formula,
    this.isStatutory = false,
    this.isPreTax = false,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DeductionType.fromJson(Map<String, dynamic> json) {
    DateTime readDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      return DateTime.now();
    }

    return DeductionType(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      category: DeductionCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => DeductionCategory.other,
      ),
      calculationMethod: DeductionCalculationMethod.values.firstWhere(
        (e) => e.name == json['calculationMethod'],
        orElse: () => DeductionCalculationMethod.fixedAmount,
      ),
      defaultValue: (json['defaultValue'] ?? 0).toDouble(),
      percentageRate: json['percentageRate'] != null
          ? (json['percentageRate'] as num).toDouble()
          : null,
      formula: json['formula'],
      isStatutory: json['isStatutory'] ?? false,
      isPreTax: json['isPreTax'] ?? false,
      isActive: json['isActive'] ?? true,
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'calculationMethod': calculationMethod.name,
      'defaultValue': defaultValue,
      'percentageRate': percentageRate,
      'formula': formula,
      'isStatutory': isStatutory,
      'isPreTax': isPreTax,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  DeductionType copyWith({
    String? id,
    String? name,
    String? description,
    DeductionCategory? category,
    DeductionCalculationMethod? calculationMethod,
    double? defaultValue,
    double? percentageRate,
    String? formula,
    bool? isStatutory,
    bool? isPreTax,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeductionType(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      defaultValue: defaultValue ?? this.defaultValue,
      percentageRate: percentageRate ?? this.percentageRate,
      formula: formula ?? this.formula,
      isStatutory: isStatutory ?? this.isStatutory,
      isPreTax: isPreTax ?? this.isPreTax,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<DeductionType> nigerianDefaults() {
    final now = DateTime.now();
    return [
      DeductionType(
        id: 'statutory_paye',
        name: 'PAYE',
        description: 'Pay-As-You-Earn tax',
        category: DeductionCategory.statutory,
        calculationMethod: DeductionCalculationMethod.formula,
        formula: 'nigeria_paye',
        isStatutory: true,
        isPreTax: true,
        createdAt: now,
        updatedAt: now,
      ),
      DeductionType(
        id: 'statutory_pension',
        name: 'Pension',
        description: 'Employee pension contribution',
        category: DeductionCategory.statutory,
        calculationMethod: DeductionCalculationMethod.percentage,
        defaultValue: 8.0,
        percentageRate: 8.0,
        isStatutory: true,
        isPreTax: true,
        createdAt: now,
        updatedAt: now,
      ),
      DeductionType(
        id: 'statutory_nhf',
        name: 'NHF',
        description: 'National Housing Fund',
        category: DeductionCategory.statutory,
        calculationMethod: DeductionCalculationMethod.percentage,
        defaultValue: 2.5,
        percentageRate: 2.5,
        isStatutory: true,
        isPreTax: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
