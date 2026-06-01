import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:roipayroll/models/employee_document_model.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/notification_service.dart';
import 'package:roipayroll/services/permission_service.dart';
import 'package:roipayroll/services/user_service.dart';
import 'package:uuid/uuid.dart';

class EmployeeDocumentService extends BaseService {
  final String _collection = 'employee_documents';
  final _notificationService = NotificationService();
  final _userService = UserService();

  Future<EmployeeDocument> uploadDocument({
    required String employeeId,
    required String employeeName,
    required String title,
    required EmployeeDocumentType type,
    required String uploadedBy,
    required String uploadedByName,
    String? fileUrl,
    String? fileName,
    DateTime? issuedDate,
    DateTime? expiryDate,
    DocumentVisibility visibility = DocumentVisibility.public,
    bool isSystemGenerated = false,
    String? relatedRecordId,
    String? relatedRecordType,
  }) async {
    final user = await _userService.getCurrentUserProfile();
    if (user == null) {
      throw Exception('User profile not found.');
    }
    PermissionService.requirePermission(user, Permission.uploadDocuments);

    final doc = EmployeeDocument(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      title: title.trim(),
      type: type,
      fileUrl: fileUrl?.trim().isEmpty == true ? null : fileUrl?.trim(),
      fileName: fileName?.trim().isEmpty == true ? null : fileName?.trim(),
      issuedDate: issuedDate == null
          ? null
          : DateTime(issuedDate.year, issuedDate.month, issuedDate.day),
      expiryDate: expiryDate == null
          ? null
          : DateTime(expiryDate.year, expiryDate.month, expiryDate.day),
      uploadedAt: DateTime.now(),
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      visibility: visibility,
      isSystemGenerated: isSystemGenerated,
      relatedRecordId: relatedRecordId,
      relatedRecordType: relatedRecordType,
    );

    final ref = await companyCollection(_collection);
    await ref.doc(doc.id).set(doc.toJson());
    return doc;
  }

  Future<List<EmployeeDocument>> getEmployeeDocuments(String employeeId) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.where('employeeId', isEqualTo: employeeId).get();
    final docs = snapshot.docs
        .map((doc) => EmployeeDocument.fromJson(docData(doc)))
        .toList();
    docs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return docs;
  }

  Future<EmployeeDocument?> getDocumentById(String id) async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.doc(id).get();
    final data = docDataNullable(snapshot);
    if (data == null) return null;
    return EmployeeDocument.fromJson(data);
  }

  Future<void> downloadDocument(String documentId) async {
    final doc = await getDocumentById(documentId);
    if (doc == null) throw 'Document not found';
    if (doc.fileUrl == null || doc.fileUrl!.isEmpty) {
      throw 'No file URL';
    }
  }

  Future<EmployeeDocument> storePayslip({
    required String employeeId,
    required String employeeName,
    required String payrollId,
    required int month,
    required int year,
    required String pdfUrl,
    required String uploadedBy,
    required String uploadedByName,
  }) async {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final safeMonth = month.clamp(1, 12);
    final doc = EmployeeDocument(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      title: 'Payslip - ${monthNames[safeMonth - 1]} $year',
      type: EmployeeDocumentType.payslip,
      fileUrl: pdfUrl,
      fileName: 'payslip_${safeMonth}_$year.pdf',
      uploadedAt: DateTime.now(),
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      visibility: DocumentVisibility.employeeOnly,
      isSystemGenerated: true,
      relatedRecordId: payrollId,
      relatedRecordType: 'payroll',
    );

    final ref = await companyCollection(_collection);
    await ref.doc(doc.id).set(doc.toJson());
    return doc;
  }

  Future<EmployeeDocument> storeContract({
    required String employeeId,
    required String employeeName,
    required String contractId,
    required String documentUrl,
    required DateTime startDate,
    required String uploadedBy,
    required String uploadedByName,
    DateTime? expiryDate,
  }) async {
    final doc = EmployeeDocument(
      id: const Uuid().v4(),
      employeeId: employeeId,
      employeeName: employeeName,
      title: 'Employment Contract - ${startDate.year}',
      type: EmployeeDocumentType.contract,
      fileUrl: documentUrl,
      fileName: 'contract_${startDate.year}.pdf',
      issuedDate: startDate,
      expiryDate: expiryDate,
      uploadedAt: DateTime.now(),
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      visibility: DocumentVisibility.hrOnly,
      isSystemGenerated: false,
      relatedRecordId: contractId,
      relatedRecordType: 'contract',
    );

    final ref = await companyCollection(_collection);
    await ref.doc(doc.id).set(doc.toJson());
    return doc;
  }

  bool canViewDocument(EmployeeDocument document, AppUser currentUser) {
    if (currentUser.role == UserRole.admin) return true;

    if (currentUser.employeeId == document.employeeId) {
      return document.visibility == DocumentVisibility.public ||
          document.visibility == DocumentVisibility.employeeOnly;
    }

    if (currentUser.role == UserRole.hr) {
      return document.visibility == DocumentVisibility.public ||
          document.visibility == DocumentVisibility.employeeOnly ||
          document.visibility == DocumentVisibility.hrOnly;
    }

    if (currentUser.role == UserRole.accountant) {
      return document.visibility == DocumentVisibility.public ||
          document.visibility == DocumentVisibility.employeeOnly ||
          document.visibility == DocumentVisibility.accountantOnly;
    }

    return false;
  }

  static const List<EmployeeDocumentType> requiredDocuments = [
    EmployeeDocumentType.contract,
    EmployeeDocumentType.idCard,
    EmployeeDocumentType.bankDetails,
  ];

  Future<List<EmployeeDocumentType>> getMissingDocuments(
    String employeeId,
  ) async {
    final existing = await getEmployeeDocuments(employeeId);
    final existingTypes = existing.map((d) => d.type).toSet();
    return requiredDocuments
        .where((type) => !existingTypes.contains(type))
        .toList();
  }

  Future<List<EmployeeDocument>> getAllDocuments() async {
    final ref = await companyCollection(_collection);
    final snapshot = await ref.get();
    final docs = snapshot.docs
        .map((doc) => EmployeeDocument.fromJson(docData(doc)))
        .toList();
    docs.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    return docs;
  }

  Future<List<EmployeeDocument>> getExpiringDocuments({
    int withinDays = 30,
  }) async {
    final all = await getAllDocuments();
    final now = DateTime.now();
    final cutoff = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: withinDays));
    return all.where((doc) {
      if (doc.expiryDate == null) return false;
      return !doc.expiryDate!.isAfter(cutoff);
    }).toList();
  }

  Future<int> sendExpiryReminders({int withinDays = 30}) async {
    final user = await _userService.getCurrentUserProfile();
    if (user == null) {
      throw Exception('User profile not found.');
    }
    if (user.role != UserRole.admin && user.role != UserRole.hr) {
      throw Exception('You do not have permission to send expiry reminders.');
    }

    final expiring = await getExpiringDocuments(withinDays: withinDays);
    if (expiring.isEmpty) return 0;

    var reminderCount = 0;
    final companyId = await getCompanyId();

    for (final doc in expiring) {
      final alreadyRecentlySent =
          doc.lastReminderSentAt != null &&
          DateTime.now().difference(doc.lastReminderSentAt!).inDays < 7;
      if (alreadyRecentlySent) {
        continue;
      }

      final expiryText = doc.expiryDate == null
          ? 'N/A'
          : '${doc.expiryDate!.day}/${doc.expiryDate!.month}/${doc.expiryDate!.year}';

      await _notificationService.sendNotificationToRoles(
        roles: const [UserRole.admin, UserRole.hr],
        title: 'Document Expiry Alert',
        message: '${doc.employeeName}: "${doc.title}" expires on $expiryText.',
        type: NotificationType.general,
        data: {
          'documentId': doc.id,
          'employeeId': doc.employeeId,
          'expiryDate': doc.expiryDate?.toIso8601String(),
        },
      );

      final userDoc = await firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .where('employeeId', isEqualTo: doc.employeeId)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        await _notificationService.sendNotification(
          userId: userDoc.docs.first.id,
          title: 'Your Document Is Nearing Expiry',
          message: '"${doc.title}" expires on $expiryText. Please renew it.',
          type: NotificationType.general,
          data: {
            'documentId': doc.id,
            'employeeId': doc.employeeId,
            'expiryDate': doc.expiryDate?.toIso8601String(),
          },
        );
      }

      final ref = await companyCollection(_collection);
      await ref.doc(doc.id).update({'lastReminderSentAt': Timestamp.now()});
      reminderCount++;
    }

    return reminderCount;
  }

  Future<void> deleteDocument(String id) async {
    final user = await _userService.getCurrentUserProfile();
    if (user == null) {
      throw Exception('User profile not found.');
    }
    PermissionService.requirePermission(user, Permission.manageDocuments);

    final ref = await companyCollection(_collection);
    await ref.doc(id).delete();
  }
}
