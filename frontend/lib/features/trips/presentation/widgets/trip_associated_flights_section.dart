import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';

import '../../../explore/data/countries_repository.dart';

import '../../../flights/application/delete_flight_cubit.dart';
import '../../../flights/application/flight_catalog_resolver.dart';
import '../../../flights/application/flight_details_cubit.dart';

import '../../../flights/domain/airline_repository.dart';
import '../../../flights/domain/airport_repository.dart';
import '../../../flights/domain/flight.dart';
import '../../../flights/domain/flight_repository.dart';

import '../../../flights/presentation/pages/flight_details_page.dart';

import '../../application/trip_associations_cubit.dart';
import '../../application/trip_associations_state.dart';
import 'trip_flight_picker_dialog.dart';
import '../../../flights/presentation/navigation/open_flight_details.dart';

/// Displays independent flights explicitly associated with a Trip.
///
/// Removing an association never deletes the original Flight.
class TripAssociatedFlightsSection extends StatefulWidget {
  const TripAssociatedFlightsSection({super.key});

  @override
  State<TripAssociatedFlightsSection> createState() =>
      _TripAssociatedFlightsSectionState();
}

class _TripAssociatedFlightsSectionState
    extends State<TripAssociatedFlightsSection> {
  late final FlightCatalogResolver _catalogResolver;
  Future<ResolvedFlightCatalog>? _catalogFuture;
  String? _catalogSignature;

  @override
  void initState() {
    super.initState();

    _catalogResolver = FlightCatalogResolver(
      airportRepository: context.read<AirportRepository>(),
      airlineRepository: context.read<AirlineRepository>(),
    );
  }

  String _formatDate(BuildContext context, Flight flight) {
    final date = DateTime.tryParse(flight.departureOn);

    if (date == null) {
      return flight.departureOn;
    }

    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  Future<ResolvedFlightCatalog> _resolveCatalog(List<Flight> flights) {
    final airportIds = <int>{};
    final airlineIds = <int>{};

    for (final flight in flights) {
      airportIds.add(flight.departureAirportId);
      airportIds.add(flight.arrivalAirportId);

      if (flight.airlineId != null) {
        airlineIds.add(flight.airlineId!);
      }
    }

    final sortedAirports = airportIds.toList()..sort();
    final sortedAirlines = airlineIds.toList()..sort();

    final signature =
        'airports:${sortedAirports.join(",")};'
        'airlines:${sortedAirlines.join(",")}';

    if (_catalogSignature != signature || _catalogFuture == null) {
      _catalogSignature = signature;
      _catalogFuture = _catalogResolver.resolve(flights);
    }

    return _catalogFuture!;
  }

  Future<void> _addFlights(
    BuildContext context,
    TripAssociationsState state,
  ) async {
    final cubit = context.read<TripAssociationsCubit>();

    final selectedIds = await showTripFlightPicker(
      context: context,
      excludedFlightIds: state.flights.map((flight) => flight.id).toSet(),
    );

    if (!context.mounted ||
        cubit.isClosed ||
        selectedIds == null ||
        selectedIds.isEmpty) {
      return;
    }

    await cubit.addFlights(flightIds: selectedIds);
  }

  String _airportLabel(ResolvedFlightCatalog catalog, int airportId) {
    final airport = catalog.airportFor(airportId);

    return airport?.displayCode ?? 'Airport $airportId';
  }

  Future<void> _removeFlight(BuildContext context, Flight flight) async {
    final cubit = context.read<TripAssociationsCubit>();

    final confirmed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove flight from Trip?'),
          content: const Text(
            'This will only remove the association with this Trip. '
            'The flight will remain available in Explore.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || confirmed != true || cubit.isClosed) {
      return;
    }

    await cubit.removeFlight(flightId: flight.id);
  }

  Future<void> _openFlightDetails(BuildContext context, Flight flight) async {
    final associationsCubit = context.read<TripAssociationsCubit>();

    final result = await openFlightDetails(context, flightId: flight.id);

    if (!context.mounted || associationsCubit.isClosed) {
      return;
    }

    if (result != FlightDetailsNavigationResult.viewed) {
      await associationsCubit.refresh();
    }
  }

  Widget _flightCard(
    BuildContext context, {
    required Flight flight,
    required ResolvedFlightCatalog catalog,
    required bool isMutating,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final departure = _airportLabel(catalog, flight.departureAirportId);

    final arrival = _airportLabel(catalog, flight.arrivalAirportId);

    return Card(
      key: Key('tripFlight-${flight.id}'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flight_takeoff_outlined, color: colors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    '$departure → $arrival',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            Text(
              _formatDate(context, flight),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            if (flight.flightNumber != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(flight.flightNumber!, style: theme.textTheme.bodySmall),
            ],

            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Text(
                  flight.isFlown ? 'Flown' : 'Planned',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colors.primary,
                  ),
                ),

                const Spacer(),

                TextButton(
                  key: Key('viewTripFlight-${flight.id}'),
                  onPressed: () => _openFlightDetails(context, flight),
                  child: const Text('View'),
                ),

                IconButton(
                  key: Key('removeTripFlight-${flight.id}'),
                  tooltip: 'Remove from Trip',
                  onPressed: isMutating
                      ? null
                      : () => _removeFlight(context, flight),
                  icon: Icon(Icons.remove_circle_outline, color: colors.error),
                ),
              ],
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
        final colors = theme.colorScheme;

        // Initial loading and errors are already displayed by
        // TripAssociatedVisitsSection, which shares the same Cubit.
        if (!state.hasLoaded) {
          return const SizedBox.shrink();
        }

        return Column(
          key: const Key('tripAssociatedFlightsSection'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flight_outlined, color: colors.primary),

                const SizedBox(width: AppSpacing.sm),

                Expanded(
                  child: Text(
                    'Flights',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('addTripFlightsButton'),
                  onPressed: state.isMutating || state.isLoading
                      ? null
                      : () => _addFlights(context, state),
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),

                const SizedBox(width: AppSpacing.sm),

                Text(
                  '${state.flights.length}',
                  key: const Key('tripFlightsCount'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),

            if (state.flights.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  'No flights associated with this Trip yet.',
                  key: const Key('tripFlightsEmptyState'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              )
            else
              FutureBuilder<ResolvedFlightCatalog>(
                future: _resolveCatalog(state.flights),
                builder: (context, snapshot) {
                  final resolvedCatalog =
                      snapshot.data ??
                      ResolvedFlightCatalog(
                        airports: const {},
                        airlines: const {},
                      );

                  return Column(
                    children: [
                      for (final flight in state.flights)
                        _flightCard(
                          context,
                          flight: flight,
                          catalog: resolvedCatalog,
                          isMutating: state.isMutating,
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
