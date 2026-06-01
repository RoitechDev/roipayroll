import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of leaves available
enum LeaveCategory {
  annual, // Annual/vacation leave
  sick, // Sick leave
  casual, // Casual leave
  maternity, // Maternity leave
  paternity, // Paternity leave
  bereavement, // Bereavement leave
  study, // Study leave
  unpaid, // Unpaid leave
  compensatory, // Compensatory off
}

/// Leave Type Configuration
class LeaveType {
  final String id;
  final String name;
  final LeaveCategory category;
  final String description;
  
  // Allocation
  final double daysPerYear; // Days allocated per year
  final bool carryForward; // Can unused days be carried forward?
  final double maxCarryForward; // Maximum days that can be carried forward
  final double maxAccumulation; // Maximum total days that can accumulate
  
  // Rules
  final bool requiresApproval;
  final bool requiresDocuments; // e.g., medical certificate for sick leave
  final int minNoticeDays; // Minimum notice period required
  final int maxConsecutiveDays; // Maximum consecutive days allowed
  final double minDaysPerRequest; // Minimum days per request
  final double maxDaysPerRequest; // Maximum days per request
  
  // Pay
  final bool isPaid; // Is this leave type paid?
  final double payPercentage; // 100% for full pay, 50% for half pay
  final bool encashable; // Can unused leave be encashed?
  final double encashmentPercentage; // % of unused days that can be encashed
  
  // Applicability
  final bool applicableToAll; // Applicable to all employees?
  final List<String>? applicableGenders; // null = all, ['male'], ['female']
  final int? minServiceMonths; // Minimum service months required
  
  // Status
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LeaveType({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.daysPerYear,
    this.carryForward = false,
    this.maxCarryForward = 0,
    this.maxAccumulation = 0,
    this.requiresApproval = true,
    this.requiresDocuments = false,
    this.minNoticeDays = 1,
    this.maxConsecutiveDays = 30,
    this.minDaysPerRequest = 0.5,
    this.maxDaysPerRequest = 365,
    this.isPaid = true,
    this.payPercentage = 100.0,
    this.encashable = false,
    this.encashmentPercentage = 0.0,
    this.applicableToAll = true,
    this.applicableGenders,
    this.minServiceMonths,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'description': description,
      'daysPerYear': daysPerYear,
      'carryForward': carryForward,
      'maxCarryForward': maxCarryForward,
      'maxAccumulation': maxAccumulation,
      'requiresApproval': requiresApproval,
      'requiresDocuments': requiresDocuments,
      'minNoticeDays': minNoticeDays,
      'maxConsecutiveDays': maxConsecutiveDays,
      'minDaysPerRequest': minDaysPerRequest,
      'maxDaysPerRequest': maxDaysPerRequest,
      'isPaid': isPaid,
      'payPercentage': payPercentage,
      'encashable': encashable,
      'encashmentPercentage': encashmentPercentage,
      'applicableToAll': applicableToAll,
      'applicableGenders': applicableGenders,
      'minServiceMonths': minServiceMonths,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory LeaveType.fromJson(Map<String, dynamic> json) {
    return LeaveType(
      id: json['id'],
      name: json['name'],
      category: LeaveCategory.values.firstWhere((e) => e.name == json['category']),
      description: json['description'],
      daysPerYear: (json['daysPerYear'] ?? 0).toDouble(),
      carryForward: json['carryForward'] ?? false,
      maxCarryForward: (json['maxCarryForward'] ?? 0).toDouble(),
      maxAccumulation: (json['maxAccumulation'] ?? 0).toDouble(),
      requiresApproval: json['requiresApproval'] ?? true,
      requiresDocuments: json['requiresDocuments'] ?? false,
      minNoticeDays: json['minNoticeDays'] ?? 1,
      maxConsecutiveDays: json['maxConsecutiveDays'] ?? 30,
      minDaysPerRequest: (json['minDaysPerRequest'] ?? 0.5).toDouble(),
      maxDaysPerRequest: (json['maxDaysPerRequest'] ?? 365).toDouble(),
      isPaid: json['isPaid'] ?? true,
      payPercentage: (json['payPercentage'] ?? 100.0).toDouble(),
      encashable: json['encashable'] ?? false,
      encashmentPercentage: (json['encashmentPercentage'] ?? 0.0).toDouble(),
      applicableToAll: json['applicableToAll'] ?? true,
      applicableGenders: json['applicableGenders'] != null
          ? List<String>.from(json['applicableGenders'])
          : null,
      minServiceMonths: json['minServiceMonths'],
      isActive: json['isActive'] ?? true,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Default Nigerian leave types
  static List<LeaveType> get defaultLeaveTypes {
    final now = DateTime.now();
    
    return [
      // Annual Leave (21 days as per Nigerian Labor Act)
      LeaveType(
        id: 'annual',
        name: 'Annual Leave',
        category: LeaveCategory.annual,
        description: 'Annual vacation leave (21 days per year)',
        daysPerYear: 21,
        carryForward: true,
        maxCarryForward: 5,
        maxAccumulation: 26,
        requiresApproval: true,
        minNoticeDays: 14,
        maxConsecutiveDays: 21,
        isPaid: true,
        encashable: true,
        encashmentPercentage: 50,
        createdAt: now,
      ),
      
      // Sick Leave
      LeaveType(
        id: 'sick',
        name: 'Sick Leave',
        category: LeaveCategory.sick,
        description: 'Medical leave with certificate',
        daysPerYear: 12,
        requiresApproval: true,
        requiresDocuments: true,
        minNoticeDays: 0,
        maxConsecutiveDays: 90,
        isPaid: true,
        payPercentage: 100,
        createdAt: now,
      ),
      
      // Casual Leave
      LeaveType(
        id: 'casual',
        name: 'Casual Leave',
        category: LeaveCategory.casual,
        description: 'Short-term personal leave',
        daysPerYear: 7,
        requiresApproval: true,
        minNoticeDays: 1,
        maxConsecutiveDays: 3,
        maxDaysPerRequest: 3,
        isPaid: true,
        createdAt: now,
      ),
      
      // Maternity Leave (12 weeks)
      LeaveType(
        id: 'maternity',
        name: 'Maternity Leave',
        category: LeaveCategory.maternity,
        description: '12 weeks maternity leave',
        daysPerYear: 84,
        requiresApproval: true,
        requiresDocuments: true,
        minNoticeDays: 30,
        maxConsecutiveDays: 84,
        isPaid: true,
        applicableToAll: false,
        applicableGenders: ['female'],
        createdAt: now,
      ),
      
      // Paternity Leave
      LeaveType(
        id: 'paternity',
        name: 'Paternity Leave',
        category: LeaveCategory.paternity,
        description: '5 days paternity leave',
        daysPerYear: 5,
        requiresApproval: true,
        requiresDocuments: true,
        minNoticeDays: 7,
        maxConsecutiveDays: 5,
        isPaid: true,
        applicableToAll: false,
        applicableGenders: ['male'],
        createdAt: now,
      ),

      // Bereavement / Compassionate Leave
      LeaveType(
        id: 'bereavement',
        name: 'Bereavement Leave',
        category: LeaveCategory.bereavement,
        description: 'Compassionate leave for loss of a close family member',
        daysPerYear: 5,
        requiresApproval: true,
        requiresDocuments: false,
        minNoticeDays: 0,
        maxConsecutiveDays: 5,
        isPaid: true,
        createdAt: now,
      ),

      // Study Leave
      LeaveType(
        id: 'study',
        name: 'Study Leave',
        category: LeaveCategory.study,
        description: 'Study or examination leave',
        daysPerYear: 10,
        requiresApproval: true,
        requiresDocuments: true,
        minNoticeDays: 7,
        maxConsecutiveDays: 10,
        isPaid: true,
        createdAt: now,
      ),

      // Unpaid Leave
      LeaveType(
        id: 'unpaid',
        name: 'Unpaid Leave',
        category: LeaveCategory.unpaid,
        description: 'Unpaid leave granted at employer discretion',
        daysPerYear: 30,
        requiresApproval: true,
        requiresDocuments: false,
        minNoticeDays: 7,
        maxConsecutiveDays: 30,
        isPaid: false,
        payPercentage: 0,
        createdAt: now,
      ),

      // Compensatory Leave
      LeaveType(
        id: 'compensatory',
        name: 'Compensatory Leave',
        category: LeaveCategory.compensatory,
        description: 'Time off in lieu of overtime/extra duty',
        daysPerYear: 10,
        requiresApproval: true,
        requiresDocuments: false,
        minNoticeDays: 1,
        maxConsecutiveDays: 5,
        isPaid: true,
        createdAt: now,
      ),
    ];
  }
}
