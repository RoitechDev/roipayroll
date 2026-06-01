import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:roipayroll/firebase_options.dart';
import 'package:roipayroll/models/audit_log_model.dart';
import 'package:roipayroll/models/employee_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/audit_service.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:roipayroll/services/user_service.dart';

class EmployeeInvitationService extends BaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final AuditService _auditService;
  late final UserService _userService;

  EmployeeInvitationService() {
    _userService = UserService();
    _auditService = AuditService(userService: _userService);
  }

  Future<String> inviteEmployee(Employee employee) async {
    final companyId = await getCompanyId();
    final email = employee.email.trim();
    if (email.isEmpty) {
      throw 'Employee email is required';
    }

    final tempPassword = _generatePassword();
    final now = DateTime.now();
    String userId = employee.userId ?? '';
    FirebaseApp? inviteApp;

    try {
      if (!employee.hasLogin || userId.isEmpty) {
        inviteApp = await _ensureInviteApp();
        final inviteAuth = FirebaseAuth.instanceFor(app: inviteApp);

        final credential = await inviteAuth.createUserWithEmailAndPassword(
          email: email,
          password: tempPassword,
        );
        final createdUser = credential.user;
        if (createdUser == null) {
          throw 'Failed to create login account';
        }

        userId = createdUser.uid;

        await _userService.upsertUserProfileData(
          uid: userId,
          companyId: companyId,
          data: {
            'id': userId,
            'email': email,
            'name': employee.fullName,
            'role': UserRole.employee.name,
            'companyId': companyId,
            'employeeId': employee.id,
            'createdAt': Timestamp.now(),
            'isActive': true,
            'requirePasswordChange': true,
            'passwordChangedAt': null,
            'lastLoginAt': null,
            'invitationSentAt': Timestamp.now(),
            'mustChangePassword': true,
          },
        );

        await inviteAuth.signOut();
      } else {
        await _userService.upsertUserProfileData(
          uid: userId,
          companyId: companyId,
          data: {'requirePasswordChange': true, 'mustChangePassword': true},
        );
      }

      await _auth.sendPasswordResetEmail(email: email);

      await firestore
          .collection('companies')
          .doc(companyId)
          .collection('employees')
          .doc(employee.id)
          .set({
            'hasLogin': true,
            'userId': userId,
            'invitationStatus': InvitationStatus.inviteSent.name,
            'invitedAt': employee.invitedAt == null
                ? Timestamp.fromDate(now)
                : Timestamp.fromDate(employee.invitedAt!),
            'lastInviteSentAt': Timestamp.fromDate(now),
            'inviteAttempts': employee.inviteAttempts + 1,
            'inviteError': null,
          }, SetOptions(merge: true));

      await _auditService.logAction(
        action: AuditAction.userInvited,
        entityType: 'employee',
        entityId: employee.id,
        entityName: employee.fullName,
        after: {
          'email': email,
          'userId': userId,
          'invitationStatus': InvitationStatus.inviteSent.name,
          'inviteAttempts': employee.inviteAttempts + 1,
        },
      );

      return tempPassword;
    } on FirebaseAuthException catch (e) {
      final message = _mapAuthError(e, email);
      await _markInviteFailed(
        companyId: companyId,
        employeeId: employee.id,
        error: message,
      );
      throw message;
    } catch (e) {
      await _markInviteFailed(
        companyId: companyId,
        employeeId: employee.id,
        error: e.toString(),
      );
      rethrow;
    } finally {
      if (inviteApp != null) {
        try {
          await inviteApp.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> resetInvitation(Employee employee) async {
    final companyId = await getCompanyId();

    await firestore
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employee.id)
        .set({
          'hasLogin': false,
          'userId': null,
          'invitationStatus': InvitationStatus.notInvited.name,
          'inviteError': null,
          'lastInviteSentAt': Timestamp.now(),
        }, SetOptions(merge: true));
  }

  Future<void> updateEmailAndReset(String employeeId, String newEmail) async {
    final companyId = await getCompanyId();
    final employeeRef = firestore
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId);

    final snapshot = await employeeRef.get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw 'Employee record not found';
    }

    final employee = await Employee.fromJsonEncrypted(data);
    await resetInvitation(employee);

    await employeeRef.set({'email': newEmail.trim()}, SetOptions(merge: true));
  }

  Future<void> markPasswordChanged({
    required String companyId,
    required String employeeId,
  }) async {
    final now = Timestamp.now();
    await firestore
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .set({
          'invitationStatus': InvitationStatus.passwordChanged.name,
          'passwordChangedAt': now,
        }, SetOptions(merge: true));
  }

  Future<void> markEmployeeActiveOnLogin({
    required String companyId,
    required String employeeId,
    required InvitationStatus currentStatus,
  }) async {
    final update = <String, dynamic>{'lastLoginAt': Timestamp.now()};

    if (currentStatus == InvitationStatus.passwordChanged) {
      update['invitationStatus'] = InvitationStatus.active.name;
    }

    await firestore
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .set(update, SetOptions(merge: true));
  }

  Future<void> _markInviteFailed({
    required String companyId,
    required String employeeId,
    required String error,
  }) async {
    await firestore
        .collection('companies')
        .doc(companyId)
        .collection('employees')
        .doc(employeeId)
        .set({
          'invitationStatus': InvitationStatus.inviteFailed.name,
          'inviteError': error,
          'lastInviteSentAt': Timestamp.now(),
        }, SetOptions(merge: true));
  }

  String _mapAuthError(FirebaseAuthException e, String email) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Email $email is already registered';
      case 'invalid-email':
        return 'Invalid email format: $email';
      case 'weak-password':
        return 'Generated temporary password is too weak';
      default:
        return e.message ?? e.code;
    }
  }

  String _generatePassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#';
    final random = Random.secure();
    return List.generate(
      12,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  Future<FirebaseApp> _ensureInviteApp() async {
    const appName = 'roipayroll-invite-app';
    try {
      return Firebase.app(appName);
    } catch (_) {
      return Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }
}
