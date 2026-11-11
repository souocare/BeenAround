import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';

import '../../application/trip_visit_suggestions.dart';
import '../../domain/trip_date_compatibility.dart';

import '../../../explore/domain/country_visit.dart';
import '../../../geography/domain/city_visit.dart';

/// Displays existing visits whose dates are compatible with a Trip.
///
/// Selecting a visit only updates the form's local selection.
/// No association is persisted by this widget.
class InlineTripVisitSuggestions extends StatelessWidget {
  const InlineTripVisitSuggestions({
    required this.countrySuggestions,
    required this.citySuggestions,
    required this.countryNamesByCode,
    required this.onCountrySelected,
    required this.onCitySelected,
    this.enabled = true,
    super.key,
  });

  final List<TripVisitSuggestion<CountryVisit>> countrySuggestions;
  final List<TripVisitSuggestion<CityVisit>> citySuggestions;

  final Map<String, String> countryNamesByCode;

  final ValueChanged<CountryVisit> onCountrySelected;
  final ValueChanged<CityVisit> onCitySelected;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (countrySuggestions.isEmpty && citySuggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('inlineTripVisitSuggestions'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
                color: colors.primary,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'SUGGESTED VISITS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          Text(
            'These visits may belong to your Trip. '
            'Select the ones you want to include.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          for (final suggestion in countrySuggestions)
            _SuggestionRow(
              key: Key('suggestedCountryVisit-${suggestion.visit.id}'),
              icon: Icons.public_outlined,
              title:
                  countryNamesByCode[suggestion.visit.countryCode] ??
                  suggestion.visit.countryCode,
              compatibility: suggestion.compatibility,
              enabled: enabled,
              buttonKey: Key('addSuggestedCountryVisit-${suggestion.visit.id}'),
              onAdd: () => onCountrySelected(suggestion.visit),
            ),

          for (final suggestion in citySuggestions)
            _SuggestionRow(
              key: Key('suggestedCityVisit-${suggestion.visit.id}'),
              icon: Icons.location_city_outlined,
              title: suggestion.visit.cityName,
              subtitle: suggestion.visit.countryName,
              compatibility: suggestion.compatibility,
              enabled: enabled,
              buttonKey: Key('addSuggestedCityVisit-${suggestion.visit.id}'),
              onAdd: () => onCitySelected(suggestion.visit),
            ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.icon,
    required this.title,
    required this.compatibility,
    required this.enabled,
    required this.buttonKey,
    required this.onAdd,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final TripDateCompatibility compatibility;
  final bool enabled;
  final Key buttonKey;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final compatibilityText = compatibility == TripDateCompatibility.match
        ? 'Dates overlap'
        : 'Possible date match';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),

          const SizedBox(width: AppSpacing.md),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                const SizedBox(height: 3),

                Text(
                  compatibilityText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.sm),

          TextButton.icon(
            key: buttonKey,
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
