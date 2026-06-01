import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/models/user_model.dart';
import 'package:roipayroll/services/user_service.dart';

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges().map((user) {
    UserService.clearCurrentUserCache();
    return user;
  });
});

final currentUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) return null;
  return UserService().getCurrentUserProfile();
});

final companyIdProvider = Provider<String?>((ref) {
  return ref.watch(currentUserProvider).value?.companyId;
});

final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).value?.role == UserRole.admin;
});

final isHRProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).value?.role == UserRole.hr;
});

final isAccountantProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider).value?.role == UserRole.accountant;
});
