import 'package:flutter/foundation.dart';
import 'package:roipayroll/models/notification_model.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/base_service.dart';
import 'package:uuid/uuid.dart';

class NotificationService extends BaseService {
  final String _collection = 'notifications';

  // Send notification to a specific user
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notification = AppNotification(
        id: const Uuid().v4(),
        userId: userId,
        title: title,
        message: message,
        type: type,
        createdAt: DateTime.now(),
        data: data,
      );

      final notificationsRef = await companyCollection(_collection);
      await notificationsRef.doc(notification.id).set(notification.toJson());

      print('✅ Notification sent to user: $userId');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  // Send notification to multiple users
  Future<void> sendNotificationToMultiple({
    required List<String> userIds,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notificationsRef = await companyCollection(_collection);
      final batch = firestore.batch();

      for (final userId in userIds) {
        final notification = AppNotification(
          id: const Uuid().v4(),
          userId: userId,
          title: title,
          message: message,
          type: type,
          createdAt: DateTime.now(),
          data: data,
        );

        batch.set(notificationsRef.doc(notification.id), notification.toJson());
      }

      await batch.commit();
      print('✅ Notifications sent to ${userIds.length} users');
    } catch (e) {
      print('❌ Error sending batch notifications: $e');
    }
  }

  // Send to all users with specific roles
  Future<void> sendNotificationToRoles({
    required List<UserRole> roles,
    required String title,
    required String message,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get all users with specified roles
      final companyId = await getCompanyId();
      final usersSnapshot = await companyCollectionRef(
        companyId,
        'users',
      ).get();

      final targetUsers = usersSnapshot.docs
          .where((doc) {
            final role = docData(doc)['role'] as String?;
            final normalizedRole = role?.toLowerCase();
            return roles.any((r) => r.name == normalizedRole);
          })
          .map((doc) => doc.id)
          .toList();

      if (targetUsers.isEmpty) {
        print(
          '⚠️ No users found with roles: ${roles.map((r) => r.name).join(', ')}',
        );
        return;
      }

      await sendNotificationToMultiple(
        userIds: targetUsers,
        title: title,
        message: message,
        type: type,
        data: data,
      );
    } catch (e) {
      print('❌ Error sending notifications to roles: $e');
    }
  }

  // Get user notifications stream
  Stream<List<AppNotification>> getUserNotificationsStream(
    String userId,
  ) async* {
    final notificationsRef = await companyCollection(_collection);
    final query = notificationsRef
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true);

    if (kIsWeb) {
      yield* webPollingStream(() async {
        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => AppNotification.fromJson(docData(doc)))
            .toList();
      });
      return;
    }

    yield* query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => AppNotification.fromJson(docData(doc)))
          .toList(),
    );
  }

  // Get unread count
  Stream<int> getUnreadCountStream(String userId) async* {
    final notificationsRef = await companyCollection(_collection);
    final query = notificationsRef
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false);

    if (kIsWeb) {
      yield* webPollingStream(() async {
        final snapshot = await query.get();
        return snapshot.docs.length;
      });
      return;
    }

    yield* query.snapshots().map((snapshot) => snapshot.docs.length);
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final notificationsRef = await companyCollection(_collection);
      await notificationsRef.doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all as read for a user
  Future<void> markAllAsRead(String userId) async {
    try {
      final notificationsRef = await companyCollection(_collection);
      final unreadNotifications = await notificationsRef
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = firestore.batch();
      for (final doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('❌ Error marking all as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final notificationsRef = await companyCollection(_collection);
      await notificationsRef.doc(notificationId).delete();
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  // Delete all notifications for a user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final notificationsRef = await companyCollection(_collection);
      final notifications = await notificationsRef
          .where('userId', isEqualTo: userId)
          .get();

      final batch = firestore.batch();
      for (final doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
    }
  }
}
