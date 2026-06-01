import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roipayroll/services/user_service.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});
