import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:roipayroll/services/user_service.dart';

/// Base service class that provides common functionality for all services
/// All service classes should extend this base class
abstract class BaseService {
  static const Duration webPollInterval = Duration(seconds: 20);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  Stream<T> webPollingStream<T>(
    Future<T> Function() loader, {
    Duration interval = webPollInterval,
  }) async* {
    yield await loader();

    if (!kIsWeb) {
      return;
    }

    yield* Stream.periodic(interval).asyncMap((_) => loader());
  }

  /// Get the current company ID from the logged-in user
  Future<String> getCompanyId() async {
    final user = await _userService.getCurrentUserProfile();
    final fromProfile = user?.companyId.trim();
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return fromProfile;
    }

    final fallbackCompanyId = await _userService.getCurrentCompanyId();
    if (fallbackCompanyId == null || fallbackCompanyId.trim().isEmpty) {
      throw Exception('User not found or company ID not set');
    }
    return fallbackCompanyId.trim();
  }

  /// Get a reference to a collection scoped to the current company
  /// Returns: `companies/{companyId}/collections/{collectionName}`
  Future<CollectionReference<Map<String, dynamic>>> companyCollection(
    String collectionName,
  ) async {
    final companyId = await getCompanyId();
    return firestore
        .collection('companies')
        .doc(companyId)
        .collection(collectionName)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );
  }

  /// Get a reference to a collection scoped to a specific company
  /// Returns: `companies/{companyId}/collections/{collectionName}`
  CollectionReference<Map<String, dynamic>> companyCollectionRef(
    String companyId,
    String collectionName,
  ) {
    return firestore
        .collection('companies')
        .doc(companyId)
        .collection(collectionName)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data() ?? {},
          toFirestore: (data, _) => data,
        );
  }

  /// Soft delete a document by setting isDeleted flag
  Future<void> softDelete(
    String collectionName,
    String documentId, {
    String? reason,
  }) async {
    final ref = await companyCollection(collectionName);
    await ref.doc(documentId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
      'deletionReason': reason,
    });
  }

  /// Restore a soft-deleted document
  Future<void> restoreSoftDeleted(
    String collectionName,
    String documentId,
  ) async {
    final ref = await companyCollection(collectionName);
    await ref.doc(documentId).update({
      'isDeleted': false,
      'deletedAt': FieldValue.delete(),
      'deletionReason': FieldValue.delete(),
      'restoredAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get the current user's ID
  String? getCurrentUserId() {
    return auth.currentUser?.uid;
  }

  /// Get the current user's email
  String? getCurrentUserEmail() {
    return auth.currentUser?.email;
  }

  /// Check if user is authenticated
  bool isAuthenticated() {
    return auth.currentUser != null;
  }

  /// Cast Firestore document data to `Map<String, dynamic>`.
  /// Handles the `Object?` to `Map<String, dynamic>` conversion.
  Map<String, dynamic> docData(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) return {};
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(data as Map);
  }

  /// Cast Firestore document data to `Map<String, dynamic>` (nullable).
  /// Returns null if document doesn't exist.
  Map<String, dynamic>? docDataNullable(DocumentSnapshot doc) {
    if (!doc.exists) return null;
    final data = doc.data();
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    return Map<String, dynamic>.from(data as Map);
  }
}
