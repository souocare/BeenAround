import 'package:flutter/material.dart';

import '../../application/trip_suggestions.dart';
import '../../domain/trip_date_compatibility.dart';

/// Displays non-intrusive suggestions during visit registration.
///
/// Selecting a suggestion only updates the form's selected Trip.
/// This widget never persists associations.
class InlineTripSuggestions extends StatelessWidget {
  const InlineTripSuggestions({
    required this.suggestions,
    required this.onTripSelected,
    this.enabled = true,
    super.key,
  });

  final List<TripSuggestion> suggestions;
  final ValueChanged<String> onTripSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('inlineTripSuggestions'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 17,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'SUGGESTED TRIPS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          for (final suggestion in suggestions) ...[
            Row(
              key: Key('inlineSuggestedTrip-${suggestion.trip.id}'),
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        suggestion.trip.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        suggestion.compatibility == TripDateCompatibility.match
                            ? 'Dates overlap with your visit'
                            : 'Possible date match',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  key: Key('selectSuggestedTrip-${suggestion.trip.id}'),
                  onPressed: enabled
                      ? () => onTripSelected(suggestion.trip.id)
                      : null,
                  child: const Text('Select'),
                ),
              ],
            ),
            if (suggestion != suggestions.last) const Divider(height: 20),
          ],
        ],
      ),
    );
  }
}
