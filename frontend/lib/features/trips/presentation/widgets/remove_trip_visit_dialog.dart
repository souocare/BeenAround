import 'package:flutter/material.dart';

import '../../../../app/widgets/adaptive_confirmation_dialog.dart';

/// Confirms removal of a visit association from a Trip.
///
/// This action never deletes the underlying travel record.
Future<bool> showRemoveTripVisitDialog({
  required BuildContext context,
  required String visitName,
}) {
  return showAdaptiveConfirmationDialog(
    context,
    title: 'Remove visit from Trip?',
    message:
        'Remove $visitName from this Trip?\n\n'
        'The visit will remain in your travel history.',
    confirmLabel: 'Remove',
    cancelLabel: 'Cancel',
    isDestructive: true,
    dialogKey: const Key('removeTripVisitDialog'),
    cancelButtonKey: const Key('cancelRemoveTripVisitButton'),
    confirmButtonKey: const Key('confirmRemoveTripVisitButton'),
  );
}
