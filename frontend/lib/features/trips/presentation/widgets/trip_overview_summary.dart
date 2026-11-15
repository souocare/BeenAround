import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';

import '../../application/trip_associations_cubit.dart';
import '../../application/trip_associations_state.dart';

/// Compact summary of the travel records associated with a Trip.
///
/// Countries and cities represent unique destinations.
/// Flights represent associated flight records.
///
/// This widget is read-only and does not manage associations.
class TripOverviewSummary extends StatelessWidget {
  const TripOverviewSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripAssociationsCubit, TripAssociationsState>(
      builder: (context, state) {
        if (!state.hasLoaded) {
          return const SizedBox.shrink();
        }

        final countryCount = state.countryVisits
            .map((visit) => visit.countryCode)
            .toSet()
            .length;

        final cityCount = state.cityVisits
            .map((visit) => visit.cityId)
            .toSet()
            .length;

        final flightCount = state.flights.length;

        final theme = Theme.of(context);
        final colors = theme.colorScheme;

        return Container(
          key: const Key('tripOverviewSummary'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.public_outlined,
                  value: countryCount,
                  label: 'Countries',
                  key: const Key('tripOverviewCountries'),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.location_city_outlined,
                  value: cityCount,
                  label: 'Cities',
                  key: const Key('tripOverviewCities'),
                ),
              ),
              Expanded(
                child: _SummaryMetric(
                  icon: Icons.flight_outlined,
                  value: flightCount,
                  label: 'Flights',
                  key: const Key('tripOverviewFlights'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.value,
    required this.label,
    super.key,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: colors.primary, size: 22),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
