import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Shows a platform-adaptive confirmation dialog.
///
/// Returns true when the user confirms the action.
/// Returns false when the user cancels or dismisses the dialog.
///
/// This is a presentation component and contains no
/// feature-specific business rules.
Future<bool> showAdaptiveConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool isDestructive = false,
}) async {
  final platform = Theme.of(context).platform;

  final useCupertino =
      platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      if (useCupertino) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(cancelLabel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: isDestructive,
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(confirmLabel),
            ),
          ],
        );
      }

      final colors = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        icon: isDestructive
            ? Icon(Icons.warning_amber_rounded, color: colors.error)
            : null,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: colors.error,
                    foregroundColor: colors.onError,
                  )
                : null,
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
