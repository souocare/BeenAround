import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/trips/presentation/widgets/remove_trip_visit_dialog.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_visit_picker_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/visit_date_precision.dart';

import '../../application/trip_associations_cubit.dart';
import '../../application/trip_associations_state.dart';
import '../../../explore/presentation/widgets/add_destination_sheet.dart';
import '../../../explore/presentation/widgets/show_add_destination.dart';
import 'trip_section_empty_state.dart';

/// Read-only presentation of a Trip's associated country and city visits.
///
/// Association actions will be added in M4.5.3B/C.
class TripAssociatedVisitsSection extends StatefulWidget {
  const TripAssociatedVisitsSection({super.key});

  @override
  State<TripAssociatedVisitsSection> createState() =>
      _TripAssociatedVisitsSectionState();
}

class _TripAssociatedVisitsSectionState
    extends State<TripAssociatedVisitsSection> {
  late final Future<Map<String, String>> _countryNamesFuture;

  @override
  void initState() {
    super.initState();

    _countryNamesFuture = _loadCountryNames();
  }

  Future<Map<String, String>> _loadCountryNames() async {
    try {
      final countries = await context
          .read<CountriesRepository>()
          .getCountries();

      return Map.unmodifiable({
        for (final country in countries) country.code: country.name,
      });
    } catch (_) {
      // Country labels are presentational metadata.
      // Association management remains functional if the catalog fails.
      return const {};
    }
  }

  String _countryName(Map<String, String> countryNames, String countryCode) {
    return countryNames[countryCode] ?? countryCode;
  }

  // Todos os métodos existentes ficam aqui.

  String _formatDate(
    BuildContext context,
    DateTime? date,
    VisitDatePrecision? precision,
  ) {
    if (date == null) {
      return 'Unknown';
    }

    final localization = MaterialLocalizations.of(context);

    return switch (precision ?? VisitDatePrecision.day) {
      VisitDatePrecision.day =>
        '${localization.formatMediumDate(date)}, ${date.year}',
      VisitDatePrecision.month => localization.formatMonthYear(date),
      VisitDatePrecision.year => '${date.year}',
    };
  }

  String _formatRange(
    BuildContext context, {
    required DateTime? start,
    required VisitDatePrecision? startPrecision,
    required DateTime? end,
    required VisitDatePrecision? endPrecision,
  }) {
    if (start == null && end == null) {
      return 'Dates unknown';
    }

    if (start != null && end == null) {
      return 'From ${_formatDate(context, start, startPrecision)}';
    }

    if (start == null && end != null) {
      return 'Until ${_formatDate(context, end, endPrecision)}';
    }

    return '${_formatDate(context, start, startPrecision)} – '
        '${_formatDate(context, end, endPrecision)}';
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    VoidCallback? onAdd,
    bool showAddButton = false,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (showAddButton) ...[
          TextButton.icon(
            key: Key('addTrip${title}VisitButton'),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Text(
          '$count',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _addCountryVisit(
    BuildContext context,
    TripAssociationsState state,
  ) async {
    final cubit = context.read<TripAssociationsCubit>();

    final selectedVisitIds = await showTripCountryVisitPicker(
      context: context,
      excludedVisitIds: state.countryVisits.map((visit) => visit.id).toSet(),
      createVisit: () async {
        final result = await showAddDestinationWithResult(
          context,
          destinationType: AddDestinationType.country,
        );

        return result?.visitId;
      },
    );

    if (!context.mounted ||
        selectedVisitIds == null ||
        selectedVisitIds.isEmpty) {
      return;
    }

    await cubit.addCountryVisits(visitIds: selectedVisitIds);
  }

  Future<void> _addCityVisit(
    BuildContext context,
    TripAssociationsState state,
  ) async {
    final cubit = context.read<TripAssociationsCubit>();

    final selectedVisitIds = await showTripCityVisitPicker(
      context: context,
      excludedVisitIds: state.cityVisits.map((visit) => visit.id).toSet(),
      createVisit: () async {
        final result = await showAddDestinationWithResult(
          context,
          destinationType: AddDestinationType.city,
        );

        return result?.visitId;
      },
    );

    if (!context.mounted ||
        selectedVisitIds == null ||
        selectedVisitIds.isEmpty) {
      return;
    }

    await cubit.addCityVisits(visitIds: selectedVisitIds);
  }

  Future<void> _removeCountryVisit(
    BuildContext context, {
    required String visitId,
    required String visitName,
  }) async {
    final cubit = context.read<TripAssociationsCubit>();

    final confirmed = await showRemoveTripVisitDialog(
      context: context,
      visitName: visitName,
    );

    if (!context.mounted || !confirmed) {
      return;
    }

    await cubit.removeCountryVisit(visitId: visitId);
  }

  Future<void> _removeCityVisit(
    BuildContext context, {
    required String visitId,
    required String visitName,
  }) async {
    final cubit = context.read<TripAssociationsCubit>();

    final confirmed = await showRemoveTripVisitDialog(
      context: context,
      visitName: visitName,
    );

    if (!context.mounted || !confirmed) {
      return;
    }

    await cubit.removeCityVisit(visitId: visitId);
  }

  Widget _visitTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String dates,
    required IconData icon,
    required Key key,
    required Key removeButtonKey,
    VoidCallback? onRemove,
    required String removeTooltip,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: key,
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, color: colors.onPrimaryContainer, size: 20),
            ),

            const SizedBox(width: AppSpacing.md),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xs),

                  Text(
                    dates,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.sm),

            IconButton(
              key: removeButtonKey,
              tooltip: removeTooltip,
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
              color: colors.error,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripAssociationsCubit, TripAssociationsState>(
      builder: (context, state) {
        final theme = Theme.of(context);

        if (state.isInitialLoading || !state.hasLoaded) {
          if (state.hasLoadError) {
            return Column(
              key: const Key('tripAssociationsError'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.loadError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  key: const Key('retryTripAssociationsButton'),
                  onPressed: () {
                    context.read<TripAssociationsCubit>().refresh();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry visits'),
                ),
              ],
            );
          }

          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: CircularProgressIndicator(
                key: Key('tripAssociationsLoading'),
              ),
            ),
          );
        }

        return Column(
          key: const Key('tripAssociationsContent'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.isRefreshing)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: LinearProgressIndicator(),
              ),

            if (state.hasLoadError) ...[
              MaterialBanner(
                content: Text(state.loadError!),
                actions: [
                  TextButton(
                    onPressed: () {
                      context.read<TripAssociationsCubit>().refresh();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            if (state.isMutating)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md),
                child: LinearProgressIndicator(),
              ),

            if (state.hasMutationError) ...[
              MaterialBanner(
                key: const Key('tripAssociationMutationError'),
                content: Text(state.mutationError!),
                actions: [
                  TextButton(
                    onPressed: () {
                      context.read<TripAssociationsCubit>().refresh();
                    },
                    child: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            _sectionHeader(
              context,
              title: 'Countries',
              count: state.countryVisits.length,
              icon: Icons.public_outlined,
              showAddButton: state.countryVisits.isNotEmpty,
              onAdd: state.isMutating || state.isLoading
                  ? null
                  : () => _addCountryVisit(context, state),
            ),

            if (state.countryVisits.isEmpty)
              TripSectionEmptyState(
                key: const Key('tripCountriesEmptyState'),
                title: 'No countries added',
                message:
                    'Add country visits to record the destinations '
                    'in this Trip.',
                icon: Icons.public_outlined,
                actionLabel: 'Add countries',
                actionKey: const Key('addTripCountriesVisitButton'),
                onAction: state.isMutating || state.isLoading
                    ? null
                    : () => _addCountryVisit(context, state),
              )
            else
              FutureBuilder<Map<String, String>>(
                future: _countryNamesFuture,
                builder: (context, snapshot) {
                  final countryNames =
                      snapshot.data ?? const <String, String>{};

                  return Column(
                    children: [
                      for (final visit in state.countryVisits)
                        Builder(
                          builder: (context) {
                            final countryName = _countryName(
                              countryNames,
                              visit.countryCode,
                            );

                            final dates = _formatRange(
                              context,
                              start: visit.startedOn,
                              startPrecision: visit.startedOnPrecision,
                              end: visit.endedOn,
                              endPrecision: visit.endedOnPrecision,
                            );

                            return _visitTile(
                              context,
                              key: Key('tripCountryVisit-${visit.id}'),
                              removeButtonKey: Key(
                                'removeTripCountryVisit-${visit.id}',
                              ),
                              title: countryName,
                              icon: Icons.public_outlined,
                              dates: dates,
                              removeTooltip:
                                  'Remove $countryName visit ($dates) from Trip',
                              onRemove: state.isMutating
                                  ? null
                                  : () => _removeCountryVisit(
                                      context,
                                      visitId: visit.id,
                                      visitName: countryName,
                                    ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),

            const SizedBox(height: AppSpacing.xl),

            _sectionHeader(
              context,
              title: 'Cities',
              count: state.cityVisits.length,
              icon: Icons.location_city_outlined,
              showAddButton: state.cityVisits.isNotEmpty,
              onAdd: state.isMutating || state.isLoading
                  ? null
                  : () => _addCityVisit(context, state),
            ),

            if (state.cityVisits.isEmpty)
              TripSectionEmptyState(
                key: const Key('tripCitiesEmptyState'),
                title: 'No cities added',
                message:
                    'Add city visits to record the places '
                    "you've explored during this Trip.",
                icon: Icons.location_city_outlined,
                actionLabel: 'Add cities',
                actionKey: const Key('addTripCitiesVisitButton'),
                onAction: state.isMutating || state.isLoading
                    ? null
                    : () => _addCityVisit(context, state),
              )
            else
              for (final visit in state.cityVisits)
                Builder(
                  builder: (context) {
                    final dates = _formatRange(
                      context,
                      start: visit.startedOn,
                      startPrecision: visit.startedOnPrecision,
                      end: visit.endedOn,
                      endPrecision: visit.endedOnPrecision,
                    );

                    return _visitTile(
                      context,
                      key: Key('tripCityVisit-${visit.id}'),
                      removeButtonKey: Key('removeTripCityVisit-${visit.id}'),
                      title: visit.cityName,
                      subtitle: visit.countryName,
                      icon: Icons.location_city_outlined,
                      dates: dates,
                      removeTooltip:
                          'Remove ${visit.cityName} visit ($dates) from Trip',
                      onRemove: state.isMutating
                          ? null
                          : () => _removeCityVisit(
                              context,
                              visitId: visit.id,
                              visitName: visit.cityName,
                            ),
                    );
                  },
                ),
          ],
        );
      },
    );
  }
}
