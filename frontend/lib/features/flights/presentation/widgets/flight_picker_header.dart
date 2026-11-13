import 'package:flutter/material.dart';

/// Shared navigation header for aviation pickers.
class FlightPickerHeader extends StatelessWidget {
  const FlightPickerHeader({required this.title, this.onBack, super.key});

  final String title;

  /// Defaults to dismissing the current picker.
  ///
  /// Pickers with internal navigation can override this
  /// to return to their previous browsing level.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton(
          key: const Key('flightPickerBackButton'),
          tooltip: 'Back',
          onPressed: onBack ?? () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
