import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final appManualRefreshControllerProvider = Provider<StreamController<int>>((
  ref,
) {
  final controller = StreamController<int>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

final appRefreshProvider = StreamProvider<int>((ref) {
  final controller = ref.watch(appManualRefreshControllerProvider);
  return controller.stream;
});

final appAutoRefreshEnabledProvider = Provider<bool>((ref) => false);

final appAutoRefreshProvider = StreamProvider.autoDispose<DateTime>((ref) {
  if (!ref.watch(appAutoRefreshEnabledProvider)) {
    return const Stream<DateTime>.empty();
  }

  return Stream.periodic(const Duration(seconds: 60), (_) => DateTime.now());
});
