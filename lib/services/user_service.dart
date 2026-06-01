import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/encryption_service.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static AppUser? _cachedCurrentUser;
  static String? _cachedCurrentUserUid;
  static String? _cachedCurrentCompanyId;

  CollectionReference<Map<String, dynamic>> _companyUsers(String companyId) {
    return _firestore
        .collection('companies')
        .doc(companyId)
        .collection('users');
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findUserDocByUid(
    String uid,
    String? email,
  ) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) return null;

    try {
      final byStoredId = await _firestore
          .collectionGroup('users')
          .where('id', isEqualTo: normalizedUid)
          .limit(1)
          .get();
      if (byStoredId.docs.isNotEmpty) {
        return byStoredId.docs.first;
      }
    } catch (e) {
      debugPrint('User lookup by stored id failed: $e');
    }

    try {
      final byDocumentId = await _firestore
          .collectionGroup('users')
          .where(FieldPath.documentId, isEqualTo: normalizedUid)
          .limit(1)
          .get();
      if (byDocumentId.docs.isNotEmpty) {
        return byDocumentId.docs.first;
      }
    } catch (e) {
      debugPrint('User lookup by document id failed: $e');
    }

    final normalizedEmail = email?.trim();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      try {
        final byEmail = await _firestore
            .collectionGroup('users')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          return byEmail.docs.first;
        }
      } catch (e) {
        debugPrint('User lookup by email failed: $e');
      }
    }

    final byCompanyScan = await _findUserDocByDirectCompanyScan(
      normalizedUid,
      normalizedEmail,
    );
    if (byCompanyScan != null) {
      return byCompanyScan;
    }

    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?>
  _findUserDocByDirectCompanyScan(String uid, String? email) async {
    try {
      final companies = await _firestore.collection('companies').get();

      for (final company in companies.docs) {
        try {
          final directUserDoc = await company.reference
              .collection('users')
              .doc(uid)
              .get();
          if (directUserDoc.exists) {
            return directUserDoc;
          }
        } catch (e) {
          debugPrint('Direct user lookup failed for company ${company.id}: $e');
        }
      }

      if (email == null || email.isEmpty) {
        return null;
      }

      for (final company in companies.docs) {
        try {
          final byEmail = await company.reference
              .collection('users')
              .where('email', isEqualTo: email)
              .limit(1)
              .get();
          if (byEmail.docs.isNotEmpty) {
            return byEmail.docs.first;
          }
        } catch (e) {
          debugPrint(
            'Direct email lookup failed for company ${company.id}: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('Direct company scan for user failed: $e');
    }

    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findEmployeeDocForUser(
    String uid,
    String? email,
  ) async {
    final normalizedUid = uid.trim();
    final normalizedEmail = email?.trim();

    if (normalizedUid.isNotEmpty) {
      try {
        final byUserId = await _firestore
            .collectionGroup('employees')
            .where('userId', isEqualTo: normalizedUid)
            .limit(1)
            .get();
        if (byUserId.docs.isNotEmpty) {
          return byUserId.docs.first;
        }
      } catch (e) {
        debugPrint('Employee lookup by userId failed: $e');
      }
    }

    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      try {
        final byEmail = await _firestore
            .collectionGroup('employees')
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          return byEmail.docs.first;
        }
      } catch (e) {
        debugPrint('Employee lookup by email failed: $e');
      }
    }

    return null;
  }

  String? _companyIdFromDocPath(DocumentSnapshot<Map<String, dynamic>> doc) {
    final companyDoc = doc.reference.parent.parent;
    final companyId = companyDoc?.id.trim();
    if (companyId == null || companyId.isEmpty) {
      return null;
    }
    return companyId;
  }

  Future<AppUser?> _decodeUserDoc(
    DocumentSnapshot<Map<String, dynamic>> userDoc, {
    required String uid,
    required String? email,
  }) async {
    final rawData = userDoc.data();
    if (rawData == null) {
      return null;
    }
    final raw = Map<String, dynamic>.from(rawData);
    final companyId = (raw['companyId'] as String?)?.trim().isNotEmpty == true
        ? (raw['companyId'] as String).trim()
        : _companyIdFromDocPath(userDoc);

    if (companyId != null && companyId.isNotEmpty) {
      raw['companyId'] = companyId;
    }

    raw['id'] = (raw['id'] as String?)?.trim().isNotEmpty == true
        ? raw['id']
        : uid;
    raw['email'] = (raw['email'] as String?)?.trim().isNotEmpty == true
        ? raw['email']
        : (email ?? '');

    try {
      return await AppUser.fromJsonEncrypted(raw);
    } catch (e) {
      debugPrint('Encrypted user profile decode failed, falling back: $e');
      try {
        return AppUser.fromJson(raw);
      } catch (inner) {
        debugPrint('Plain user profile decode failed: $inner');
        return null;
      }
    }
  }

  Future<AppUser?> _buildFallbackEmployeeProfile({
    required String uid,
    required String? email,
  }) async {
    final employeeDoc = await _findEmployeeDocForUser(uid, email);
    final employeeData = employeeDoc?.data();
    if (employeeDoc == null || employeeData == null) {
      return null;
    }

    final companyId =
        (employeeData['companyId'] as String?)?.trim().isNotEmpty == true
        ? (employeeData['companyId'] as String).trim()
        : _companyIdFromDocPath(employeeDoc);
    if (companyId == null || companyId.isEmpty) {
      return null;
    }

    final firstName = (employeeData['firstName'] as String?)?.trim() ?? '';
    final lastName = (employeeData['lastName'] as String?)?.trim() ?? '';
    final fullName = '$firstName $lastName'.trim();
    final employeeEmail =
        (employeeData['email'] as String?)?.trim().isNotEmpty == true
        ? (employeeData['email'] as String).trim()
        : (email ?? '');
    final createdAt = employeeData['createdAt'];
    final hireDate = employeeData['hireDate'];

    DateTime resolvedCreatedAt() {
      if (createdAt is Timestamp) return createdAt.toDate();
      if (createdAt is DateTime) return createdAt;
      if (hireDate is Timestamp) return hireDate.toDate();
      if (hireDate is DateTime) return hireDate;
      return DateTime.now();
    }

    return AppUser(
      id: uid,
      email: employeeEmail,
      name: fullName.isEmpty
          ? (employeeEmail.isEmpty ? 'Employee' : employeeEmail)
          : fullName,
      role: UserRole.employee,
      companyId: companyId,
      employeeId: (employeeData['id'] as String?)?.trim(),
      createdAt: resolvedCreatedAt(),
      isActive:
          (employeeData['status'] as String?)?.toLowerCase() != 'inactive',
    );
  }

  /// Get current user profile from nested company users.
  Future<AppUser?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    if (_cachedCurrentUserUid == user.uid && _cachedCurrentUser != null) {
      return _cachedCurrentUser;
    }

    try {
      final userDoc = await _findUserDocByUid(user.uid, user.email);
      if (userDoc != null) {
        final profile = await _decodeUserDoc(
          userDoc,
          uid: user.uid,
          email: user.email,
        );
        if (profile != null) {
          _cachedCurrentUserUid = user.uid;
          _cachedCurrentUser = profile;
          _cachedCurrentCompanyId = profile.companyId.trim().isEmpty
              ? null
              : profile.companyId.trim();
        }
        return profile;
      }

      final fallbackProfile = await _buildFallbackEmployeeProfile(
        uid: user.uid,
        email: user.email,
      );
      if (fallbackProfile != null) {
        _cachedCurrentUserUid = user.uid;
        _cachedCurrentUser = fallbackProfile;
        _cachedCurrentCompanyId = fallbackProfile.companyId.trim();
        return fallbackProfile;
      }
    } catch (e) {
      debugPrint('Error in getCurrentUserProfile: $e');
    }

    return null;
  }

  /// Get current company ID
  Future<String?> getCurrentCompanyId() async {
    final user = await getCurrentUserProfile();
    if (user != null && user.companyId.trim().isNotEmpty) {
      return user.companyId.trim();
    }
    final authUser = _auth.currentUser;
    if (_cachedCurrentUserUid == authUser?.uid &&
        _cachedCurrentCompanyId != null &&
        _cachedCurrentCompanyId!.trim().isNotEmpty) {
      return _cachedCurrentCompanyId!.trim();
    }
    if (authUser == null) return null;
    final companyId = await findCompanyIdForUser(
      authUser.uid,
      email: authUser.email,
    );
    if (companyId != null && companyId.trim().isNotEmpty) {
      _cachedCurrentUserUid = authUser.uid;
      _cachedCurrentCompanyId = companyId.trim();
    }
    return companyId;
  }

  /// Get all users in the current company
  Future<List<AppUser>> getAllUsers() async {
    final currentUser = await getCurrentUserProfile();
    if (currentUser == null || currentUser.companyId.isEmpty) {
      return [];
    }

    final snapshot = await _companyUsers(currentUser.companyId).get();
    return Future.wait(
      snapshot.docs.map((doc) => AppUser.fromJsonEncrypted(doc.data())),
    );
  }

  /// Create a new user profile
  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String name,
    required UserRole role,
    required String companyId,
    String? employeeId,
    String? phoneNumber,
  }) async {
    final user = AppUser(
      id: uid,
      email: email,
      name: name,
      role: role,
      companyId: companyId,
      employeeId: employeeId,
      phoneNumber: phoneNumber,
      createdAt: DateTime.now(),
      isActive: true,
    );

    await upsertUserProfileData(
      uid: uid,
      companyId: companyId,
      data: await user.toJsonEncrypted(),
    );
  }

  /// Create or update the company-scoped user document.
  Future<void> upsertUserProfileData({
    required String uid,
    required String companyId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    final companyUserRef = _companyUsers(companyId).doc(uid);
    final encryptedData = await EncryptionService.encryptFields(
      data,
      AppUser.sensitiveFields,
    );
    await companyUserRef.set(encryptedData, SetOptions(merge: merge));
  }

  /// Find company ID for a user
  Future<String?> findCompanyIdForUser(String userId, {String? email}) async {
    try {
      final userDoc = await _findUserDocByUid(userId, email);
      if (userDoc != null) {
        final data = userDoc.data();
        final storedCompanyId = (data?['companyId'] as String?)?.trim();
        if (storedCompanyId != null && storedCompanyId.isNotEmpty) {
          return storedCompanyId;
        }
        return _companyIdFromDocPath(userDoc);
      }

      final employeeDoc = await _findEmployeeDocForUser(userId, email);
      if (employeeDoc != null) {
        final employeeData = employeeDoc.data();
        final storedCompanyId = (employeeData?['companyId'] as String?)?.trim();
        if (storedCompanyId != null && storedCompanyId.isNotEmpty) {
          return storedCompanyId;
        }
        return _companyIdFromDocPath(employeeDoc);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Update user profile
  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final companyId = await findCompanyIdForUser(userId);
    if (companyId == null || companyId.isEmpty) {
      throw Exception('User company context not found');
    }
    final encryptedUpdates = await EncryptionService.encryptFields(
      updates,
      AppUser.sensitiveFields,
    );
    await _companyUsers(companyId).doc(userId).update(encryptedUpdates);
  }

  /// Get user by ID
  Future<AppUser?> getUserById(String userId) async {
    final userDoc = await _findUserDocByUid(userId, null);
    if (userDoc == null) return null;

    return _decodeUserDoc(userDoc, uid: userId, email: null);
  }

  /// Get user by employee ID
  Future<AppUser?> getUserByEmployeeId(
    String employeeId,
    String companyId,
  ) async {
    final snapshot = await _companyUsers(
      companyId,
    ).where('employeeId', isEqualTo: employeeId).limit(1).get();

    if (snapshot.docs.isEmpty) return null;
    return AppUser.fromJsonEncrypted(snapshot.docs.first.data());
  }

  /// Check if user exists
  Future<bool> userExists(String userId) async {
    final user = await getUserById(userId);
    return user != null;
  }

  /// Deactivate user
  Future<void> deactivateUser(String userId) async {
    final companyId = await findCompanyIdForUser(userId);
    if (companyId == null || companyId.isEmpty) {
      throw Exception('User company context not found');
    }

    await _companyUsers(companyId).doc(userId).update({
      'isActive': false,
      'deactivatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Activate user
  Future<void> activateUser(String userId) async {
    final companyId = await findCompanyIdForUser(userId);
    if (companyId == null || companyId.isEmpty) {
      throw Exception('User company context not found');
    }

    await _companyUsers(companyId).doc(userId).update({
      'isActive': true,
      'deactivatedAt': FieldValue.delete(),
    });
  }

  static void clearCurrentUserCache() {
    _cachedCurrentUser = null;
    _cachedCurrentUserUid = null;
    _cachedCurrentCompanyId = null;
  }
}
