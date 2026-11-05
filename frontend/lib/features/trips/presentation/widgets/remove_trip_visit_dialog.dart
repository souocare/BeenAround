import 'package:flutter/material.dart';

/// Confirms removal of a visit association from a Trip.
///
/// This action never deletes the underlying travel record.
Future<bool> showRemoveTripVisitDialog({
  required BuildContext context,
  required String visitName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const Key('removeTripVisitDialog'),
        title: const Text('Remove visit from Trip?'),
        content: Text(
          'Remove $visitName from this Trip?\n\n'
          'The visit will remain in your travel history.',
        ),
        actions: [
          TextButton(
            key: const Key('cancelRemoveTripVisitButton'),
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirmRemoveTripVisitButton'),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Remove'),
          ),
        ],
      );
    },
  );

  return confirmed ?? false;
}
