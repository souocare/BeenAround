import 'package:flutter/material.dart';

import '../../application/explore_city_aggregation.dart';

/// Displays a city and its aggregated Been, Lived and Wish statuses.
///
/// This widget does not own travel records or navigation logic.
class ExploreCityCard extends StatelessWidget {
  const ExploreCityCard({required this.entry, required this.onTap, super.key});

  final ExploreCityEntry entry;
  final VoidCallback onTap;

  String get _subtitle {
    final city = entry.city;
    final summary = entry.summary;

    final statuses = <String>[];

    if (summary.hasBeen) {
      final count = summary.visitCount;
      statuses.add('$count ${count == 1 ? 'visit' : 'visits'}');
    }

    if (summary.hasLived) {
      statuses.add('Lived');
    }

    if (summary.isWishlisted) {
      statuses.add('Wishlist');
    }

    if (statuses.isEmpty) {
      return city.countryName;
    }

    return '${city.countryName} · ${statuses.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final city = entry.city;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          key: Key('visitedCityCard-${city.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_city_outlined,
                color: colors.primary,
                size: 28,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right_rounded,
                color: colors.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
