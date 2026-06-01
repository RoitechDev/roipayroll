import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/firebase_options.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _internalRegistrationAppName =
      'RoiPayrollInternalRegistration';

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      return result;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'No user found with this email';
        case 'wrong-password':
          throw 'Wrong password';
        case 'invalid-email':
          throw 'Invalid email address';
        case 'user-disabled':
          throw 'This account has been disabled';
        case 'invalid-credential':
          throw 'Invalid email or password';
        default:
          throw 'Login failed: ${e.message}';
      }
    } catch (_) {
      throw 'An error occurred. Please try again';
    }
  }

  // Used by internal admin account creation flows.
  Future<UserCredential?> register(String email, String password) async {
    FirebaseAuth? internalAuth;
    try {
      internalAuth = await _internalRegistrationAuth();
      final result = await internalAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return result;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw 'This email is already registered';
        case 'weak-password':
          throw 'Password is too weak';
        case 'invalid-email':
          throw 'Invalid email address';
        default:
          throw 'Registration failed: ${e.message}';
      }
    } catch (_) {
      throw 'An error occurred. Please try again';
    } finally {
      try {
        await internalAuth?.signOut();
      } catch (e) {
        debugPrint('Internal registration sign-out failed (non-fatal): $e');
      }
    }
  }

  Future<FirebaseAuth> _internalRegistrationAuth() async {
    try {
      final app = Firebase.app(_internalRegistrationAppName);
      return FirebaseAuth.instanceFor(app: app);
    } catch (_) {
      final app = await Firebase.initializeApp(
        name: _internalRegistrationAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return FirebaseAuth.instanceFor(app: app);
    }
  }

  // Public registration: creates company + first admin user profile.
  Future<UserCredential?> registerCompanyAdmin({
    required String email,
    required String password,
    required String companyName,
    String? adminName,
  }) async {
    UserCredential? credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final authUser = credential.user;
      if (authUser == null) throw 'Registration failed';

      final companyRef = _firestore.collection('companies').doc();
      final companyId = companyRef.id;
      final now = Timestamp.now();

      await _firestore.collection('companies').doc(companyId).set({
        'id': companyId,
        'name': companyName.trim(),
        'email': email.trim(),
        'phone': '',
        'address': '',
        'registrationNumber': '',
        'createdAt': now,
        'isActive': true,
      });

      await _firestore
          .collection('companies')
          .doc(companyId)
          .collection('users')
          .doc(authUser.uid)
          .set({
            'id': authUser.uid,
            'email': email.trim(),
            'name': (adminName == null || adminName.trim().isEmpty)
                ? companyName.trim()
                : adminName.trim(),
            'role': 'admin',
            'companyId': companyId,
            'employeeId': null,
            'createdAt': now,
            'isActive': true,
          });

      // SECURITY FIX: Removed duplicate root user creation
      // User document should ONLY exist at companies/{companyId}/users/{uid}
      // Root-level users/ collection creates security vulnerability

      // Send Firebase built-in verification email (free, no backend needed)
      try {
        await credential.user!.sendEmailVerification();
      } catch (e) {
        debugPrint('Verification email failed (non-fatal): $e');
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw 'This email is already registered';
        case 'weak-password':
          throw 'Password is too weak';
        case 'invalid-email':
          throw 'Invalid email address';
        default:
          throw 'Registration failed: ${e.message}';
      }
    } catch (e) {
      // Best-effort rollback of auth account if profile creation fails.
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (_) {}
      }
      throw 'Company registration failed: $e';
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  bool isLoggedIn() {
    return _auth.currentUser != null;
  }
}
