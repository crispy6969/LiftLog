import 'package:liftlog/shared/material.dart';
import 'package:sqflite/sqflite.dart';

String friendlyError(Object error) {
  if (error is FormatException) return error.message;
  if (error is DatabaseException && error.isUniqueConstraintError()) {
    return 'That name is already used. Check archived exercises too.';
  }
  if (error is StateError) return error.message.toString();
  return 'Could not complete this action. Your saved data has been kept. Please try again.';
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(friendlyError(error))));
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Delete',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;
