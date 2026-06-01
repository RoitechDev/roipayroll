import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/employee_document_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/providers/app_refresh_provider.dart';
import 'package:roipayroll/providers/auth_provider.dart';
import 'package:roipayroll/services/employee_document_service.dart';
import 'package:roipayroll/services/employee_service.dart';
import 'package:roipayroll/services/permission_service.dart';

enum DocumentRoleScope { employee, accountant, hr, admin }

class DocumentData {
  final AppUser? user;
  final DocumentRoleScope scope;
  final bool canUpload;
  final bool canManage;
  final bool canSendReminders;
  final bool canViewOrganization;
  final List<EmployeeDocument> myDocuments;
  final List<EmployeeDocument> organizationDocuments;
  final List<EmployeeDocument> expiringDocuments;
  final List<Employee> uploadTargets;

  const DocumentData({
    required this.user,
    required this.scope,
    required this.canUpload,
    required this.canManage,
    required this.canSendReminders,
    required this.canViewOrganization,
    required this.myDocuments,
    required this.organizationDocuments,
    required this.expiringDocuments,
    required this.uploadTargets,
  });
}

final documentDataProvider = FutureProvider<DocumentData>((ref) async {
  ref.watch(appRefreshProvider);
  ref.watch(appAutoRefreshProvider);

  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    return const DocumentData(
      user: null,
      scope: DocumentRoleScope.employee,
      canUpload: false,
      canManage: false,
      canSendReminders: false,
      canViewOrganization: false,
      myDocuments: <EmployeeDocument>[],
      organizationDocuments: <EmployeeDocument>[],
      expiringDocuments: <EmployeeDocument>[],
      uploadTargets: <Employee>[],
    );
  }

  final documentService = EmployeeDocumentService();
  final employeeService = EmployeeService();
  final canUpload = PermissionService.hasPermission(
    user,
    Permission.uploadDocuments,
  );
  final canManage = PermissionService.hasPermission(
    user,
    Permission.manageDocuments,
  );
  final canSendReminders =
      user.role == UserRole.admin || user.role == UserRole.hr;
  final canViewOrganization =
      user.role != UserRole.employee &&
      PermissionService.hasPermission(user, Permission.viewDocuments);

  final employeeId = user.employeeId?.trim() ?? '';
  final myDocuments = employeeId.isEmpty
      ? <EmployeeDocument>[]
      : (await documentService.getEmployeeDocuments(
          employeeId,
        )).where((doc) => documentService.canViewDocument(doc, user)).toList();

  final organizationDocuments = canViewOrganization
      ? (await documentService.getAllDocuments())
            .where((doc) => documentService.canViewDocument(doc, user))
            .toList()
      : <EmployeeDocument>[];

  final expiringDocuments = canViewOrganization
      ? (await documentService.getExpiringDocuments(
          withinDays: 30,
        )).where((doc) => documentService.canViewDocument(doc, user)).toList()
      : myDocuments.where((doc) {
          if (doc.expiryDate == null) return false;
          final cutoff = DateTime.now().add(const Duration(days: 30));
          return !doc.expiryDate!.isAfter(cutoff);
        }).toList();

  final uploadTargets = canUpload
      ? await employeeService.getAllEmployees()
      : <Employee>[];

  return DocumentData(
    user: user,
    scope: switch (user.role) {
      UserRole.admin => DocumentRoleScope.admin,
      UserRole.hr => DocumentRoleScope.hr,
      UserRole.accountant => DocumentRoleScope.accountant,
      UserRole.employee => DocumentRoleScope.employee,
    },
    canUpload: canUpload,
    canManage: canManage,
    canSendReminders: canSendReminders,
    canViewOrganization: canViewOrganization,
    myDocuments: myDocuments,
    organizationDocuments: organizationDocuments,
    expiringDocuments: expiringDocuments,
    uploadTargets: uploadTargets,
  );
});

final documentActionsProvider = Provider<DocumentActions>((ref) {
  return DocumentActions(ref);
});

class DocumentActions {
  final Ref _ref;
  final _service = EmployeeDocumentService();

  DocumentActions(this._ref);

  Future<void> upload({
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
  }) async {
    await _service.uploadDocument(
      employeeId: employeeId,
      employeeName: employeeName,
      title: title,
      type: type,
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      fileUrl: fileUrl,
      fileName: fileName,
      issuedDate: issuedDate,
      expiryDate: expiryDate,
      visibility: visibility,
    );
    _ref.invalidate(documentDataProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }

  Future<int> sendReminders({int withinDays = 30}) async {
    final count = await _service.sendExpiryReminders(withinDays: withinDays);
    _ref.invalidate(documentDataProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
    return count;
  }

  Future<void> deleteDocument(String id) async {
    await _service.deleteDocument(id);
    _ref.invalidate(documentDataProvider);
    _ref
        .read(appManualRefreshControllerProvider)
        .add(DateTime.now().millisecondsSinceEpoch);
  }
}
