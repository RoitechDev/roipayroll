import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/contract_record_model.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/employee_document_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:uuid/uuid.dart';

class ContractService extends BaseService {
  final String _collection = 'contract_records';
  final _notificationService = NotificationService();
  final _documentService = EmployeeDocumentService();
  final _userService = UserService();

  // Create contract
  Future<ContractRecord> createContract({
    required String employeeId,
    required String employeeName,
    required ContractType contractType,
    required DateTime startDate,
    DateTime? endDate,
    required double contractSalary,
    required String createdBy,
    PaymentFrequency paymentFrequency = PaymentFrequency.monthly,
    bool includesPension = false,
    bool includesHealthInsurance = false,
    bool includesLeave = false,
    bool includesBonus = false,
    bool isRenewable = false,
    String? renewalTerms,
  }) async {
    final contract = ContractRecord(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      contractType: contractType,
      startDate: startDate,
      endDate: endDate,
      status: ContractStatus.active,
      contractSalary: contractSalary,
      paymentFrequency: paymentFrequency,
      includesPension: includesPension,
      includesHealthInsurance: includesHealthInsurance,
      includesLeave: includesLeave,
      includesBonus: includesBonus,
      isRenewable: isRenewable,
      renewalTerms: renewalTerms,
      createdBy: createdBy,
    );

    final collectionRef = await companyCollection(_collection);
    await collectionRef.doc(contract.id).set(contract.toJson());

    // Notify HR
    await _notificationService.sendNotificationToRoles(
      roles: const [UserRole.admin, UserRole.hr],
      title: 'New Contract Created',
      message: '$employeeName - ${contractType.name} contract created',
      type: NotificationType.contract,
      data: {'employeeId': employeeId, 'contractId': contract.id},
    );

    return contract;
  }

  // Get contract by ID
  Future<ContractRecord?> getContractById(String id) async {
    final collectionRef = await companyCollection(_collection);
    final doc = await collectionRef.doc(id).get();
    if (!doc.exists) return null;
    final data = docDataNullable(doc);
    return data == null ? null : ContractRecord.fromJson(data);
  }

  // Get active contract by employee
  Future<ContractRecord?> getActiveContract(String employeeId) async {
    final collectionRef = await companyCollection(_collection);
    final snapshot = await collectionRef
        .where('employeeId', isEqualTo: employeeId)
        .where('status', isEqualTo: ContractStatus.active.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return ContractRecord.fromJson(docData(snapshot.docs.first));
  }

  // Get expiring contracts (within days)
  Future<List<ContractRecord>> getExpiringContracts(int withinDays) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: withinDays));

    final collectionRef = await companyCollection(_collection);
    final snapshot = await collectionRef
        .where('status', isEqualTo: ContractStatus.active.name)
        .where('endDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .where('endDate', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .orderBy('endDate')
        .get();

    return snapshot.docs
        .map((doc) => ContractRecord.fromJson(docData(doc)))
        .toList();
  }

  // Renew contract
  Future<ContractRecord> renewContract({
    required String contractId,
    required DateTime newEndDate,
    double? newSalary,
    String? renewalTerms,
  }) async {
    final oldContract = await getContractById(contractId);
    if (oldContract == null) throw 'Contract not found';

    // Mark old contract as renewed
    final collectionRef = await companyCollection(_collection);
    await collectionRef.doc(contractId).update({
      'status': ContractStatus.renewed.name,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Create new contract
    final renewalCount = (oldContract.renewalCount ?? 0) + 1;

    final newContract = ContractRecord(
      id: const Uuid().v4(),
      employeeId: oldContract.employeeId,
      employeeName: oldContract.employeeName,
      contractType: oldContract.contractType,
      startDate: DateTime.now(),
      endDate: newEndDate,
      status: ContractStatus.active,
      contractSalary: newSalary ?? oldContract.contractSalary,
      paymentFrequency: oldContract.paymentFrequency,
      includesPension: oldContract.includesPension,
      includesHealthInsurance: oldContract.includesHealthInsurance,
      includesLeave: oldContract.includesLeave,
      includesBonus: oldContract.includesBonus,
      isRenewable: oldContract.isRenewable,
      renewalCount: renewalCount,
      lastRenewedAt: DateTime.now(),
      renewalTerms: renewalTerms ?? oldContract.renewalTerms,
      createdBy: oldContract.createdBy,
    );

    await collectionRef.doc(newContract.id).set(newContract.toJson());

    // Notify HR
    await _notificationService.sendNotificationToRoles(
      roles: const [UserRole.admin, UserRole.hr],
      title: 'Contract Renewed',
      message:
          '${newContract.employeeName} contract renewed (Renewal #$renewalCount)',
      type: NotificationType.contract,
      data: {
        'employeeId': newContract.employeeId,
        'contractId': newContract.id,
      },
    );

    return newContract;
  }

  // Convert to permanent
  Future<ContractRecord> convertToPermanent({
    required String contractId,
    required double permanentSalary,
  }) async {
    final oldContract = await getContractById(contractId);
    if (oldContract == null) throw 'Contract not found';

    // Mark old contract as terminated
    final collectionRef = await companyCollection(_collection);
    await collectionRef.doc(contractId).update({
      'status': ContractStatus.terminated.name,
      'terminationDate': Timestamp.fromDate(DateTime.now()),
      'terminationReason': 'Converted to permanent',
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Create permanent contract
    final permanentContract = ContractRecord(
      id: const Uuid().v4(),
      employeeId: oldContract.employeeId,
      employeeName: oldContract.employeeName,
      contractType: ContractType.permanent,
      startDate: DateTime.now(),
      endDate: null, // Permanent has no end date
      status: ContractStatus.active,
      contractSalary: permanentSalary,
      paymentFrequency: PaymentFrequency.monthly,
      includesPension: true,
      includesHealthInsurance: true,
      includesLeave: true,
      includesBonus: true,
      isRenewable: false,
      createdBy: oldContract.createdBy,
    );

    await collectionRef
        .doc(permanentContract.id)
        .set(permanentContract.toJson());

    // Notify HR
    await _notificationService.sendNotificationToRoles(
      roles: const [UserRole.admin, UserRole.hr],
      title: 'Converted to Permanent',
      message:
          '${permanentContract.employeeName} converted to permanent employee',
      type: NotificationType.contract,
      data: {
        'employeeId': permanentContract.employeeId,
        'contractId': permanentContract.id,
      },
    );

    return permanentContract;
  }

  // Terminate contract
  Future<void> terminateContract({
    required String contractId,
    required String reason,
    required String terminatedBy,
  }) async {
    final collectionRef = await companyCollection(_collection);
    await collectionRef.doc(contractId).update({
      'status': ContractStatus.terminated.name,
      'terminationDate': Timestamp.fromDate(DateTime.now()),
      'terminationReason': reason,
      'terminatedBy': terminatedBy,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    final contract = await getContractById(contractId);
    if (contract != null) {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Contract Terminated',
        message: '${contract.employeeName} contract terminated',
        type: NotificationType.contract,
        data: {'employeeId': contract.employeeId, 'contractId': contractId},
      );
    }
  }

  // Upload contract document
  Future<void> uploadContractDocument({
    required String contractId,
    required String documentUrl,
    bool isSigned = false,
    String? uploadedBy,
    String? uploadedByName,
  }) async {
    final field = isSigned ? 'signedDocumentUrl' : 'contractDocumentUrl';
    final collectionRef = await companyCollection(_collection);
    await collectionRef.doc(contractId).update({
      field: documentUrl,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });

    if (documentUrl.trim().isEmpty) return;
    final contract = await getContractById(contractId);
    if (contract == null) return;

    final actor = await _userService.getCurrentUserProfile();
    final resolvedUploadedBy = (uploadedBy ?? '').trim().isNotEmpty
        ? uploadedBy!.trim()
        : (actor?.id ?? contract.createdBy);
    final resolvedUploadedByName = (uploadedByName ?? '').trim().isNotEmpty
        ? uploadedByName!.trim()
        : (actor?.name ?? 'System');

    await _documentService.storeContract(
      employeeId: contract.employeeId,
      employeeName: contract.employeeName,
      contractId: contract.id,
      documentUrl: documentUrl,
      startDate: contract.startDate,
      expiryDate: contract.endDate,
      uploadedBy: resolvedUploadedBy,
      uploadedByName: resolvedUploadedByName,
    );
  }

  // Get employment history
  Future<List<ContractRecord>> getEmploymentHistory(String employeeId) async {
    final collectionRef = await companyCollection(_collection);
    final snapshot = await collectionRef
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('startDate', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => ContractRecord.fromJson(docData(doc)))
        .toList();
  }

  // Get all contracts
  Future<List<ContractRecord>> getAllContracts({
    ContractType? type,
    ContractStatus? status,
  }) async {
    final collectionRef = await companyCollection(_collection);
    Query query = collectionRef;

    if (type != null) {
      query = query.where('contractType', isEqualTo: type.name);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }

    final snapshot = await query.orderBy('startDate', descending: true).get();
    return snapshot.docs
        .map((doc) => ContractRecord.fromJson(docData(doc)))
        .toList();
  }

  // Send expiry alerts
  Future<void> sendExpiryAlerts() async {
    final expiring = await getExpiringContracts(30);

    for (var contract in expiring) {
      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Contract Expiring Soon',
        message:
            '${contract.employeeName} contract ends in ${contract.daysRemaining} days',
        type: NotificationType.contract,
        data: {'employeeId': contract.employeeId, 'contractId': contract.id},
      );
    }
  }
}
