import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class GlobalErrorInfo {
  final String code;
  final String message;
  final DateTime occurredAt;

  GlobalErrorInfo({
    required this.code,
    required this.message,
    DateTime? occurredAt,
  }) : occurredAt = occurredAt ?? DateTime.now();
}

class GlobalErrorState extends ChangeNotifier {
  GlobalErrorInfo? _current;

  GlobalErrorInfo? get current => _current;

  void report(Object error, [StackTrace? stackTrace]) {
    final info = _parseError(error);
    if (info == null) return;
    _current = info;
    notifyListeners();
  }

  void clear() {
    _current = null;
    notifyListeners();
  }

  GlobalErrorInfo? _parseError(Object error) {
    if (error is FirebaseException && error.code == 'permission-denied') {
      return GlobalErrorInfo(
        code: error.code,
        message: error.message ?? 'Missing or insufficient permissions.',
      );
    }

    final text = error.toString().toLowerCase();
    if (text.contains('permission-denied') ||
        text.contains('missing or insufficient permissions')) {
      return GlobalErrorInfo(
        code: 'permission-denied',
        message: error.toString(),
      );
    }

    return null;
  }
}

final globalErrorState = GlobalErrorState();
