import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddDestinationWishForm extends StatelessWidget {
  const AddDestinationWishForm({
    required this.note,
    required this.onNoteChanged,
    required this.includeCountry,
    required this.onIncludeCountryChanged,
    required this.enabled,
    this.cityCountryName,
    super.key,
  });

  final String note;
  final ValueChanged<String> onNoteChanged;

  final bool includeCountry;
  final ValueChanged<bool> onIncludeCountryChanged;

  final bool enabled;

  /// Only supplied when the selected destination is a city.
  final String? cityCountryName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'YOUR WISHLIST',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          "A place you'd love to explore.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'NOTE (OPTIONAL)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 10),

        TextFormField(
          key: const Key('wishlistNoteField'),
          initialValue: note,
          enabled: enabled,
          maxLines: 4,
          minLines: 3,
          maxLength: 1000,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            hintText: 'Why would you like to visit this place?',
            hintMaxLines: 2,
            filled: true,
            fillColor: colors.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.all(16),
          ),
          onChanged: onNoteChanged,
        ),

        if (cityCountryName != null) ...[
          const SizedBox(height: 12),

          Material(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            child: CheckboxListTile(
              key: const Key('wishlistIncludeCountry'),
              value: includeCountry,
              onChanged: enabled
                  ? (value) => onIncludeCountryChanged(value ?? false)
                  : null,
              title: Text(
                'Also add $cityCountryName to my wishlist',
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                'The country will be added separately, without the city note.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
