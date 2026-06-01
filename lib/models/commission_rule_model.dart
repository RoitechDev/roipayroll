import 'package:cloud_firestore/cloud_firestore.dart';

enum CommissionCalculationType {
  flatRate,
  tiered,
  fixedAmount,
}

class CommissionRule {
  final String id;
  final String name;
  final String description;
  final CommissionCalculationType calculationType;
  final double? flatRatePercent;
  final List<CommissionTier> tiers;
  final double? fixedAmount;
  final String? applicableTo;
  final bool isActive;
  final DateTime createdAt;
  final String createdBy;

  const CommissionRule({
    required this.id,
    required this.name,
    required this.description,
    required this.calculationType,
    this.flatRatePercent,
    this.tiers = const [],
    this.fixedAmount,
    this.applicableTo,
    this.isActive = true,
    required this.createdAt,
    required this.createdBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'calculationType': calculationType.name,
      'flatRatePercent': flatRatePercent,
      'tiers': tiers.map((t) => t.toJson()).toList(),
      'fixedAmount': fixedAmount,
      'applicableTo': applicableTo,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'createdBy': createdBy,
    };
  }

  factory CommissionRule.fromJson(Map<String, dynamic> json) {
    return CommissionRule(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      calculationType: CommissionCalculationType.values.firstWhere(
        (e) => e.name == json['calculationType'],
        orElse: () => CommissionCalculationType.flatRate,
      ),
      flatRatePercent: json['flatRatePercent']?.toDouble(),
      tiers:
          (json['tiers'] as List<dynamic>?)
              ?.map((t) => CommissionTier.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      fixedAmount: json['fixedAmount']?.toDouble(),
      applicableTo: json['applicableTo'],
      isActive: json['isActive'] ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdBy: json['createdBy'] ?? '',
    );
  }
}

class CommissionTier {
  final double minSales;
  final double maxSales;
  final double ratePercent;

  const CommissionTier({
    required this.minSales,
    required this.maxSales,
    required this.ratePercent,
  });

  Map<String, dynamic> toJson() {
    return {
      'minSales': minSales,
      'maxSales': maxSales,
      'ratePercent': ratePercent,
    };
  }

  factory CommissionTier.fromJson(Map<String, dynamic> json) {
    return CommissionTier(
      minSales: (json['minSales'] ?? 0).toDouble(),
      maxSales: (json['maxSales'] ?? double.infinity).toDouble(),
      ratePercent: (json['ratePercent'] ?? 0).toDouble(),
    );
  }
}
