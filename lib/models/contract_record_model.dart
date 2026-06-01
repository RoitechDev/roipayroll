import 'package:cloud_firestore/cloud_firestore.dart';

enum ContractType {
  permanent,
  fixedTerm,
  freelance,
  consultant,
  intern,
  partTime,
  contract,
  temporary,
}

enum ContractStatus { active, expired, renewed, terminated, pending }

enum PaymentFrequency { monthly, biWeekly, weekly, daily, perProject }

class ContractRecord {
  final String id;
  final String employeeId;
  final String employeeName;

  // Contract Details
  final ContractType contractType;
  final DateTime startDate;
  final DateTime? endDate; // Null for permanent
  final ContractStatus status;

  // Financial
  final double contractSalary;
  final PaymentFrequency paymentFrequency;
  final String currency;

  // Benefits (for contract workers)
  final bool includesPension;
  final bool includesHealthInsurance;
  final bool includesLeave;
  final bool includesBonus;

  // Renewal
  final bool isRenewable;
  final int? renewalCount;
  final DateTime? lastRenewedAt;
  final String? renewalTerms;

  // Document
  final String? contractDocumentUrl;
  final String? signedDocumentUrl;

  // Termination
  final DateTime? terminationDate;
  final String? terminationReason;
  final String? terminatedBy;

  // Metadata
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ContractRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.contractType,
    required this.startDate,
    this.endDate,
    this.status = ContractStatus.active,
    required this.contractSalary,
    this.paymentFrequency = PaymentFrequency.monthly,
    this.currency = 'NGN',
    this.includesPension = false,
    this.includesHealthInsurance = false,
    this.includesLeave = false,
    this.includesBonus = false,
    this.isRenewable = false,
    this.renewalCount,
    this.lastRenewedAt,
    this.renewalTerms,
    this.contractDocumentUrl,
    this.signedDocumentUrl,
    this.terminationDate,
    this.terminationReason,
    this.terminatedBy,
    required this.createdBy,
    DateTime? createdAt,
    this.updatedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Is permanent contract
  bool get isPermanent => contractType == ContractType.permanent;

  // Days remaining (if fixed-term)
  int? get daysRemaining {
    if (endDate == null) return null;
    final now = DateTime.now();
    return endDate!.difference(now).inDays;
  }

  // Is expiring soon (within 30 days)
  bool get isExpiringSoon {
    if (daysRemaining == null) return false;
    return daysRemaining! <= 30 && daysRemaining! > 0;
  }

  // Is expired
  bool get isExpired {
    if (daysRemaining == null) return false;
    return daysRemaining! < 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'contractType': contractType.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'status': status.name,
      'contractSalary': contractSalary,
      'paymentFrequency': paymentFrequency.name,
      'currency': currency,
      'includesPension': includesPension,
      'includesHealthInsurance': includesHealthInsurance,
      'includesLeave': includesLeave,
      'includesBonus': includesBonus,
      'isRenewable': isRenewable,
      'renewalCount': renewalCount,
      'lastRenewedAt': lastRenewedAt != null
          ? Timestamp.fromDate(lastRenewedAt!)
          : null,
      'renewalTerms': renewalTerms,
      'contractDocumentUrl': contractDocumentUrl,
      'signedDocumentUrl': signedDocumentUrl,
      'terminationDate': terminationDate != null
          ? Timestamp.fromDate(terminationDate!)
          : null,
      'terminationReason': terminationReason,
      'terminatedBy': terminatedBy,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory ContractRecord.fromJson(Map<String, dynamic> json) {
    return ContractRecord(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      contractType: ContractType.values.firstWhere(
        (e) => e.name == json['contractType'],
        orElse: () => ContractType.permanent,
      ),
      startDate: (json['startDate'] as Timestamp).toDate(),
      endDate: json['endDate'] != null
          ? (json['endDate'] as Timestamp).toDate()
          : null,
      status: ContractStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ContractStatus.active,
      ),
      contractSalary: (json['contractSalary'] ?? 0).toDouble(),
      paymentFrequency: PaymentFrequency.values.firstWhere(
        (e) => e.name == json['paymentFrequency'],
        orElse: () => PaymentFrequency.monthly,
      ),
      currency: json['currency'] ?? 'NGN',
      includesPension: json['includesPension'] ?? false,
      includesHealthInsurance: json['includesHealthInsurance'] ?? false,
      includesLeave: json['includesLeave'] ?? false,
      includesBonus: json['includesBonus'] ?? false,
      isRenewable: json['isRenewable'] ?? false,
      renewalCount: json['renewalCount'],
      lastRenewedAt: json['lastRenewedAt'] != null
          ? (json['lastRenewedAt'] as Timestamp).toDate()
          : null,
      renewalTerms: json['renewalTerms'],
      contractDocumentUrl: json['contractDocumentUrl'],
      signedDocumentUrl: json['signedDocumentUrl'],
      terminationDate: json['terminationDate'] != null
          ? (json['terminationDate'] as Timestamp).toDate()
          : null,
      terminationReason: json['terminationReason'],
      terminatedBy: json['terminatedBy'],
      createdBy: json['createdBy'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }
}
