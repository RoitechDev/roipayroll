import 'package:cloud_firestore/cloud_firestore.dart';

enum PayrollApprovalStatus {
  draft,
  pendingHRReview,
  pendingAccountantReview,
  pendingAccountantFinalApproval,
  approved,
  rejected,
  processed,
}

enum PayrollType { regular, bonus, commission, thirteenth, adhoc }

PayrollApprovalStatus _parsePayrollApprovalStatus(String? rawValue) {
  switch ((rawValue ?? '').trim()) {
    case 'pendingManagerApproval':
      return PayrollApprovalStatus.pendingAccountantReview;
    case 'pendingFinanceApproval':
      return PayrollApprovalStatus.pendingAccountantFinalApproval;
    default:
      return PayrollApprovalStatus.values.firstWhere(
        (value) => value.name == rawValue,
        orElse: () => PayrollApprovalStatus.draft,
      );
  }
}

class PayrollApproval {
  final String payrollId;
  final PayrollApprovalStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? comments;
  final String? rejectionReason;

  const PayrollApproval({
    required this.payrollId,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    this.comments,
    this.rejectionReason,
  });

  Map<String, dynamic> toJson() {
    return {
      'payrollId': payrollId,
      'status': status.name,
      'reviewedBy': reviewedBy,
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
      'comments': comments,
      'rejectionReason': rejectionReason,
    };
  }

  factory PayrollApproval.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return PayrollApproval(
      payrollId: (json['payrollId'] ?? '').toString(),
      status: _parsePayrollApprovalStatus(json['status']?.toString()),
      reviewedBy: json['reviewedBy']?.toString(),
      reviewedAt: parseDate(json['reviewedAt']),
      comments: json['comments']?.toString(),
      rejectionReason: json['rejectionReason']?.toString(),
    );
  }
}

class Payroll {
  final String id;
  final String employeeId;
  final String employeeName;
  final int month;
  final int year;
  final String currency;
  final String baseCurrency;
  final double exchangeRateToBase;
  final double basicSalary;
  final double allowances;
  final double grossSalary;
  final double paye;
  final double pension;
  final double nhf;
  final double loanDeduction;
  final double otherDeductions;
  final double totalDeductions;
  final double netSalary;
  final double basicSalaryBase;
  final double allowancesBase;
  final double grossSalaryBase;
  final double payeBase;
  final double pensionBase;
  final double nhfBase;
  final double loanDeductionBase;
  final double otherDeductionsBase;
  final double totalDeductionsBase;
  final double netSalaryBase;
  final DateTime processedDate;
  final PayrollType payrollType;
  final double? offCycleAmount;
  final String? offCycleReason;
  final String status; // 'pending', 'approved', 'paid'
  final PayrollApprovalStatus approvalStatus;
  final List<PayrollApproval> approvalHistory;
  final bool isReversal;
  final String? originalPayrollId;
  final String? reversalReason;
  final String? reversedBy;
  final DateTime? reversedAt;
  final bool isReversed;
  final String? reversedPayrollId;
  final String? correctionOfPayrollId;
  final String? correctionReason;
  final String? correctedBy;
  final DateTime? correctedAt;
  final bool isRetroactive;
  final int? retroactiveMonths;
  final double? retroactiveArrears;
  final double? retroactiveArrearsBase;
  final double? retroactiveOldSalary;
  final double? retroactiveNewSalary;
  final double? retroactiveOldSalaryBase;
  final double? retroactiveNewSalaryBase;
  final DateTime? retroactiveEffectiveFrom;
  final DateTime? retroactiveProcessedDate;
  final double? retroactiveTax;
  final double? retroactiveTaxBase;
  final double? varianceGross;
  final double? varianceNet;
  final double? varianceDeductions;
  final double? varianceGrossBase;
  final double? varianceNetBase;
  final double? varianceDeductionsBase;
  final bool isLocked;
  final DateTime? lockedAt;
  final String? lockedBy;
  final int version;

  Payroll({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.month,
    required this.year,
    this.currency = 'NGN',
    this.baseCurrency = 'NGN',
    this.exchangeRateToBase = 1.0,
    required this.basicSalary,
    this.allowances = 0,
    required this.grossSalary,
    required this.paye,
    required this.pension,
    required this.nhf,
    this.loanDeduction = 0,
    this.otherDeductions = 0,
    required this.totalDeductions,
    required this.netSalary,
    required this.basicSalaryBase,
    required this.allowancesBase,
    required this.grossSalaryBase,
    required this.payeBase,
    required this.pensionBase,
    required this.nhfBase,
    required this.loanDeductionBase,
    required this.otherDeductionsBase,
    required this.totalDeductionsBase,
    required this.netSalaryBase,
    required this.processedDate,
    this.payrollType = PayrollType.regular,
    this.offCycleAmount,
    this.offCycleReason,
    this.status = 'pending',
    this.approvalStatus = PayrollApprovalStatus.draft,
    this.approvalHistory = const <PayrollApproval>[],
    this.isReversal = false,
    this.originalPayrollId,
    this.reversalReason,
    this.reversedBy,
    this.reversedAt,
    this.isReversed = false,
    this.reversedPayrollId,
    this.correctionOfPayrollId,
    this.correctionReason,
    this.correctedBy,
    this.correctedAt,
    this.isRetroactive = false,
    this.retroactiveMonths,
    this.retroactiveArrears,
    this.retroactiveArrearsBase,
    this.retroactiveOldSalary,
    this.retroactiveNewSalary,
    this.retroactiveOldSalaryBase,
    this.retroactiveNewSalaryBase,
    this.retroactiveEffectiveFrom,
    this.retroactiveProcessedDate,
    this.retroactiveTax,
    this.retroactiveTaxBase,
    this.varianceGross,
    this.varianceNet,
    this.varianceDeductions,
    this.varianceGrossBase,
    this.varianceNetBase,
    this.varianceDeductionsBase,
    this.isLocked = false,
    this.lockedAt,
    this.lockedBy,
    this.version = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'month': month,
      'year': year,
      'currency': currency,
      'baseCurrency': baseCurrency,
      'exchangeRateToBase': exchangeRateToBase,
      'basicSalary': basicSalary,
      'allowances': allowances,
      'grossSalary': grossSalary,
      'paye': paye,
      'pension': pension,
      'nhf': nhf,
      'loanDeduction': loanDeduction,
      'otherDeductions': otherDeductions,
      'totalDeductions': totalDeductions,
      'netSalary': netSalary,
      'basicSalaryBase': basicSalaryBase,
      'allowancesBase': allowancesBase,
      'grossSalaryBase': grossSalaryBase,
      'payeBase': payeBase,
      'pensionBase': pensionBase,
      'nhfBase': nhfBase,
      'loanDeductionBase': loanDeductionBase,
      'otherDeductionsBase': otherDeductionsBase,
      'totalDeductionsBase': totalDeductionsBase,
      'netSalaryBase': netSalaryBase,
      'processedDate': Timestamp.fromDate(processedDate),
      'payrollType': payrollType.name,
      'offCycleAmount': offCycleAmount,
      'offCycleReason': offCycleReason,
      'status': status,
      'approvalStatus': approvalStatus.name,
      'approvalHistory': approvalHistory
          .map((approvalEntry) => approvalEntry.toJson())
          .toList(),
      'isReversal': isReversal,
      'originalPayrollId': originalPayrollId,
      'reversalReason': reversalReason,
      'reversedBy': reversedBy,
      'reversedAt': reversedAt == null ? null : Timestamp.fromDate(reversedAt!),
      'isReversed': isReversed,
      'reversedPayrollId': reversedPayrollId,
      'correctionOfPayrollId': correctionOfPayrollId,
      'correctionReason': correctionReason,
      'correctedBy': correctedBy,
      'correctedAt': correctedAt == null
          ? null
          : Timestamp.fromDate(correctedAt!),
      'isRetroactive': isRetroactive,
      'retroactiveMonths': retroactiveMonths,
      'retroactiveArrears': retroactiveArrears,
      'retroactiveArrearsBase': retroactiveArrearsBase,
      'retroactiveOldSalary': retroactiveOldSalary,
      'retroactiveNewSalary': retroactiveNewSalary,
      'retroactiveOldSalaryBase': retroactiveOldSalaryBase,
      'retroactiveNewSalaryBase': retroactiveNewSalaryBase,
      'retroactiveEffectiveFrom': retroactiveEffectiveFrom == null
          ? null
          : Timestamp.fromDate(retroactiveEffectiveFrom!),
      'retroactiveProcessedDate': retroactiveProcessedDate == null
          ? null
          : Timestamp.fromDate(retroactiveProcessedDate!),
      'retroactiveTax': retroactiveTax,
      'retroactiveTaxBase': retroactiveTaxBase,
      'varianceGross': varianceGross,
      'varianceNet': varianceNet,
      'varianceDeductions': varianceDeductions,
      'varianceGrossBase': varianceGrossBase,
      'varianceNetBase': varianceNetBase,
      'varianceDeductionsBase': varianceDeductionsBase,
      'isLocked': isLocked,
      'lockedAt': lockedAt != null ? Timestamp.fromDate(lockedAt!) : null,
      'lockedBy': lockedBy,
      'version': version,
    };
  }

  factory Payroll.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return Payroll(
      id: json['id'],
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      month: json['month'],
      year: json['year'],
      currency: (json['currency'] ?? 'NGN').toString(),
      baseCurrency: (json['baseCurrency'] ?? 'NGN').toString(),
      exchangeRateToBase: (json['exchangeRateToBase'] ?? 1).toDouble(),
      basicSalary: (json['basicSalary'] ?? 0).toDouble(),
      allowances: (json['allowances'] ?? 0).toDouble(),
      grossSalary: (json['grossSalary'] ?? 0).toDouble(),
      paye: (json['paye'] ?? 0).toDouble(),
      pension: (json['pension'] ?? 0).toDouble(),
      nhf: (json['nhf'] ?? 0).toDouble(),
      loanDeduction: (json['loanDeduction'] ?? 0).toDouble(),
      otherDeductions: (json['otherDeductions'] ?? 0).toDouble(),
      totalDeductions: (json['totalDeductions'] ?? 0).toDouble(),
      netSalary: (json['netSalary'] ?? 0).toDouble(),
      basicSalaryBase: (json['basicSalaryBase'] ?? json['basicSalary'] ?? 0)
          .toDouble(),
      allowancesBase: (json['allowancesBase'] ?? json['allowances'] ?? 0)
          .toDouble(),
      grossSalaryBase: (json['grossSalaryBase'] ?? json['grossSalary'] ?? 0)
          .toDouble(),
      payeBase: (json['payeBase'] ?? json['paye'] ?? 0).toDouble(),
      pensionBase: (json['pensionBase'] ?? json['pension'] ?? 0).toDouble(),
      nhfBase: (json['nhfBase'] ?? json['nhf'] ?? 0).toDouble(),
      loanDeductionBase:
          (json['loanDeductionBase'] ?? json['loanDeduction'] ?? 0).toDouble(),
      otherDeductionsBase:
          (json['otherDeductionsBase'] ?? json['otherDeductions'] ?? 0)
              .toDouble(),
      totalDeductionsBase:
          (json['totalDeductionsBase'] ?? json['totalDeductions'] ?? 0)
              .toDouble(),
      netSalaryBase: (json['netSalaryBase'] ?? json['netSalary'] ?? 0)
          .toDouble(),
      processedDate: parseDate(json['processedDate']),
      payrollType: PayrollType.values.firstWhere(
        (value) => value.name == json['payrollType'],
        orElse: () => PayrollType.regular,
      ),
      offCycleAmount: (json['offCycleAmount'] as num?)?.toDouble(),
      offCycleReason: json['offCycleReason']?.toString(),
      status: json['status'] ?? 'pending',
      approvalStatus: _parsePayrollApprovalStatus(
        json['approvalStatus']?.toString(),
      ),
      approvalHistory: (json['approvalHistory'] as List<dynamic>? ?? [])
          .map(
            (entry) => PayrollApproval.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
      isReversal: json['isReversal'] == true,
      originalPayrollId: json['originalPayrollId']?.toString(),
      reversalReason: json['reversalReason']?.toString(),
      reversedBy: json['reversedBy']?.toString(),
      reversedAt: json['reversedAt'] == null
          ? null
          : parseDate(json['reversedAt']),
      isReversed: json['isReversed'] == true,
      reversedPayrollId: json['reversedPayrollId']?.toString(),
      correctionOfPayrollId: json['correctionOfPayrollId']?.toString(),
      correctionReason: json['correctionReason']?.toString(),
      correctedBy: json['correctedBy']?.toString(),
      correctedAt: json['correctedAt'] == null
          ? null
          : parseDate(json['correctedAt']),
      isRetroactive: json['isRetroactive'] == true,
      retroactiveMonths: (json['retroactiveMonths'] as num?)?.toInt(),
      retroactiveArrears: (json['retroactiveArrears'] as num?)?.toDouble(),
      retroactiveArrearsBase: (json['retroactiveArrearsBase'] as num?)
          ?.toDouble(),
      retroactiveOldSalary: (json['retroactiveOldSalary'] as num?)?.toDouble(),
      retroactiveNewSalary: (json['retroactiveNewSalary'] as num?)?.toDouble(),
      retroactiveOldSalaryBase: (json['retroactiveOldSalaryBase'] as num?)
          ?.toDouble(),
      retroactiveNewSalaryBase: (json['retroactiveNewSalaryBase'] as num?)
          ?.toDouble(),
      retroactiveEffectiveFrom: json['retroactiveEffectiveFrom'] == null
          ? null
          : parseDate(json['retroactiveEffectiveFrom']),
      retroactiveProcessedDate: json['retroactiveProcessedDate'] == null
          ? null
          : parseDate(json['retroactiveProcessedDate']),
      retroactiveTax: (json['retroactiveTax'] as num?)?.toDouble(),
      retroactiveTaxBase: (json['retroactiveTaxBase'] as num?)?.toDouble(),
      varianceGross: (json['varianceGross'] as num?)?.toDouble(),
      varianceNet: (json['varianceNet'] as num?)?.toDouble(),
      varianceDeductions: (json['varianceDeductions'] as num?)?.toDouble(),
      varianceGrossBase: (json['varianceGrossBase'] as num?)?.toDouble(),
      varianceNetBase: (json['varianceNetBase'] as num?)?.toDouble(),
      varianceDeductionsBase: (json['varianceDeductionsBase'] as num?)
          ?.toDouble(),
      isLocked: json['isLocked'] == true,
      lockedAt: json['lockedAt'] == null ? null : parseDate(json['lockedAt']),
      lockedBy: json['lockedBy']?.toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}

class PayrollPreview {
  final int month;
  final int year;
  final String currency;
  final int totalEmployees;
  final double totalGross;
  final double totalNet;
  final double totalDeductions;
  final List<PayrollPreviewItem> items;
  final DateTime generatedAt;

  PayrollPreview({
    required this.month,
    required this.year,
    this.currency = 'NGN',
    required this.totalEmployees,
    required this.totalGross,
    required this.totalNet,
    required this.totalDeductions,
    required this.items,
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'year': year,
      'currency': currency,
      'totalEmployees': totalEmployees,
      'totalGross': totalGross,
      'totalNet': totalNet,
      'totalDeductions': totalDeductions,
      'items': items.map((item) => item.toJson()).toList(),
      'generatedAt': Timestamp.fromDate(generatedAt),
    };
  }

  factory PayrollPreview.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return PayrollPreview(
      month: json['month'],
      year: json['year'],
      currency: (json['currency'] ?? 'NGN').toString(),
      totalEmployees: json['totalEmployees'],
      totalGross: (json['totalGross'] ?? 0).toDouble(),
      totalNet: (json['totalNet'] ?? 0).toDouble(),
      totalDeductions: (json['totalDeductions'] ?? 0).toDouble(),
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (item) => PayrollPreviewItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      generatedAt: parseDate(json['generatedAt']),
    );
  }
}

class PayrollPreviewItem {
  final String employeeId;
  final String employeeName;
  final double grossSalary;
  final double netSalary;
  final double totalDeductions;
  final Payroll breakdown;

  PayrollPreviewItem({
    required this.employeeId,
    required this.employeeName,
    required this.grossSalary,
    required this.netSalary,
    required this.totalDeductions,
    required this.breakdown,
  });

  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'grossSalary': grossSalary,
      'netSalary': netSalary,
      'totalDeductions': totalDeductions,
      'breakdown': breakdown.toJson(),
    };
  }

  factory PayrollPreviewItem.fromJson(Map<String, dynamic> json) {
    return PayrollPreviewItem(
      employeeId: json['employeeId'],
      employeeName: json['employeeName'],
      grossSalary: (json['grossSalary'] ?? 0).toDouble(),
      netSalary: (json['netSalary'] ?? 0).toDouble(),
      totalDeductions: (json['totalDeductions'] ?? 0).toDouble(),
      breakdown: Payroll.fromJson(json['breakdown'] as Map<String, dynamic>),
    );
  }
}
