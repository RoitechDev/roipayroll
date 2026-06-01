import 'package:flutter/material.dart';

class ModernDialogs {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String cancelText = 'Cancel',
    String confirmText = 'Confirm',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
