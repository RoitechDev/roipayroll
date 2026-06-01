import 'package:cloud_firestore/cloud_firestore.dart';

enum BonusCategory {
  performance,
  project,
  referral,
  retention,
  annual,
  holiday,
  spot,
  signing,
  other,
}

class BonusTemplate {
  final String id;
  final String name;
  final BonusCategory category;
  final String description;
  final bool isTaxable;
  final bool isRecurring;
  final String? recurrenceRule;
  final double? defaultAmount;
  final String? eligibilityRules;
  final bool requiresApproval;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  const BonusTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    this.isTaxable = true,
    this.isRecurring = false,
    this.recurrenceRule,
    this.defaultAmount,
    this.eligibilityRules,
    this.requiresApproval = true,
    this.isActive = true,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'description': description,
      'isTaxable': isTaxable,
      'isRecurring': isRecurring,
      'recurrenceRule': recurrenceRule,
      'defaultAmount': defaultAmount,
      'eligibilityRules': eligibilityRules,
      'requiresApproval': requiresApproval,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory BonusTemplate.fromJson(Map<String, dynamic> json) {
    return BonusTemplate(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: BonusCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => BonusCategory.other,
      ),
      description: json['description'] ?? '',
      isTaxable: json['isTaxable'] ?? true,
      isRecurring: json['isRecurring'] ?? false,
      recurrenceRule: json['recurrenceRule'],
      defaultAmount: json['defaultAmount']?.toDouble(),
      eligibilityRules: json['eligibilityRules'],
      requiresApproval: json['requiresApproval'] ?? true,
      isActive: json['isActive'] ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] ?? '',
    );
  }
}
