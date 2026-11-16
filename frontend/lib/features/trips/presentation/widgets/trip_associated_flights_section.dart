import 'package:beenaround/app/theme/app_action_icons.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_association_slidable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';

import '../../../flights/application/flight_catalog_resolver.dart';
import '../../../flights/domain/airline_repository.dart';
import '../../../flights/domain/airport_repository.dart';
import '../../../flights/domain/flight.dart';

import '../../../flights/presentation/navigation/open_flight_details.dart';
import '../../../flights/presentation/widgets/flight_card.dart';
import '../../../flights/presentation/widgets/show_add_flight.dart';

import '../../application/trip_associations_cubit.dart';
import '../../application/trip_associations_state.dart';

import 'trip_flight_picker_dialog.dart';
import 'trip_section_empty_state.dart';
import '../../../../app/widgets/adaptive_confirmation_dialog.dart';

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

  String _flightAccessibilityLabel(
    Flight flight,
    ResolvedFlightCatalog catalog,
  ) {
    final departure =
        catalog.airportFor(flight.departureAirportId)?.displayCode ??
        '${flight.departureAirportId}';

    final arrival =
        catalog.airportFor(flight.arrivalAirportId)?.displayCode ??
        '${flight.arrivalAirportId}';

    final flightNumber = flight.flightNumber?.trim();

    final prefix = flightNumber != null && flightNumber.isNotEmpty
        ? 'Flight $flightNumber'
        : 'Flight';

    return '$prefix, $departure to $arrival';
  }

  Future<void> _addFlights(
    BuildContext context,
    TripAssociationsState state,
  ) async {
    final cubit = context.read<TripAssociationsCubit>();

    final selectedIds = await showTripFlightPicker(
      context: context,
      excludedFlightIds: state.flights.map((flight) => flight.id).toSet(),
      createFlight: () => showAddFlightWithResult(context),
    );

    if (!context.mounted ||
        cubit.isClosed ||
        selectedIds == null ||
        selectedIds.isEmpty) {
      return;
    }

    await cubit.addFlights(flightIds: selectedIds);
  }

  Future<void> _removeFlight(BuildContext context, Flight flight) async {
    final cubit = context.read<TripAssociationsCubit>();

    final confirmed = await showAdaptiveConfirmationDialog(
      context,
      title: 'Remove flight from Trip?',
      message:
          'This will only remove the association with this Trip. '
          'The flight will remain available in Explore.',
      confirmLabel: 'Remove',
      cancelLabel: 'Cancel',
      isDestructive: true,
      dialogKey: const Key('removeTripFlightDialog'),
      cancelButtonKey: const Key('cancelRemoveTripFlightButton'),
      confirmButtonKey: const Key('confirmRemoveTripFlightButton'),
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
    final flightLabel = _flightAccessibilityLabel(flight, catalog);

    return Padding(
      key: Key('tripFlight-${flight.id}'),
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: TripAssociationSlidable(
        associationId: 'flight-${flight.id}',
        removeLabel: 'Delete',
        enabled: !isMutating,
        onRemoveRequested: () => _removeFlight(context, flight),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Semantics(
            label: 'View $flightLabel',
            explicitChildNodes: true,
            child: InkWell(
              key: Key('openTripFlight-${flight.id}'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openFlightDetails(context, flight),
              child: FlightCard(
                flight: flight,
                departureAirport: catalog.airportFor(flight.departureAirportId),
                arrivalAirport: catalog.airportFor(flight.arrivalAirportId),
                airline: flight.airlineId == null
                    ? null
                    : catalog.airlineFor(flight.airlineId!),
                airlineName: catalog.airlineNameFor(flight),
              ),
            ),
          ),
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
                if (state.flights.isNotEmpty)
                  TextButton.icon(
                    key: const Key('addTripFlightsButton'),
                    onPressed: state.isMutating || state.isLoading
                        ? null
                        : () => _addFlights(context, state),
                    icon: Icon(AppActionIcons.add(context)),
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
              TripSectionEmptyState(
                key: const Key('tripFlightsEmptyState'),
                title: 'No flights added',
                message:
                    'Add flights to connect the destinations '
                    'you visited during this Trip.',
                icon: Icons.flight_outlined,
                actionLabel: 'Add flights',
                actionKey: const Key('addTripFlightsButton'),
                onAction: state.isMutating || state.isLoading
                    ? null
                    : () => _addFlights(context, state),
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
