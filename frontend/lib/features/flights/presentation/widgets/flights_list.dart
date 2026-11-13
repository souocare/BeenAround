import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/app_empty_state.dart';
import '../../../../app/widgets/app_error_state.dart';
import '../../../../app/widgets/app_loading_state.dart';

import '../../application/flights_cubit.dart';
import '../../application/flights_state.dart';

import 'flight_card.dart';
import '../../application/flight_catalog_resolver.dart';
import '../../application/flight_details_cubit.dart';

import '../../domain/flight_repository.dart';
import '../../domain/airport_repository.dart';
import '../../domain/airline_repository.dart';

import '../pages/flight_details_page.dart';

class FlightsList extends StatelessWidget {
  const FlightsList({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FlightsListContent();
  }
}

class _FlightsListContent extends StatelessWidget {
  const _FlightsListContent();

  Future<void> _openFlightDetails(BuildContext context, String flightId) async {
    // Capture dependencies before pushing a new route.
    //
    // The new route may not inherit repository providers
    // registered below the application's Navigator.
    final flightRepository = context.read<FlightRepository>();
    final airportRepository = context.read<AirportRepository>();
    final airlineRepository = context.read<AirlineRepository>();

    final resolver = FlightCatalogResolver(
      airportRepository: airportRepository,
      airlineRepository: airlineRepository,
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return BlocProvider<FlightDetailsCubit>(
            create: (_) => FlightDetailsCubit(
              repository: flightRepository,
              catalogResolver: resolver,
            )..load(flightId),
            child: FlightDetailsPage(flightId: flightId),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlightsCubit, FlightsState>(
      builder: (context, state) {
        if (state.phase == FlightsPhase.initial ||
            (state.phase == FlightsPhase.loading && state.flights.isEmpty)) {
          return const AppLoadingState(message: 'Loading your flights...');
        }

        if (state.phase == FlightsPhase.failure && state.flights.isEmpty) {
          return AppErrorState(
            title: 'Unable to load flights',
            message:
                state.errorMessage ??
                'Something went wrong while loading your flight history.',
            onRetry: context.read<FlightsCubit>().load,
          );
        }

        if (state.isEmpty) {
          return const AppEmptyState(
            title: 'No flights recorded',
            message:
                'Your flights will appear here once you start '
                'recording your aviation history.',
            icon: Icons.flight_outlined,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final flight in state.flights)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: ValueKey('open-flight-${flight.id}'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openFlightDetails(context, flight.id),
                    child: FlightCard(
                      flight: flight,

                      departureAirport: state.airportFor(
                        flight.departureAirportId,
                      ),

                      arrivalAirport: state.airportFor(flight.arrivalAirportId),

                      airline: flight.airlineId == null
                          ? null
                          : state.airlineFor(flight.airlineId!),

                      airlineName: state.airlineNameFor(flight),
                    ),
                  ),
                ),
              ),

            if (state.loadMoreError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  state.loadMoreError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),

            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: state.isLoadingMore
                      ? null
                      : context.read<FlightsCubit>().loadMore,
                  child: state.isLoadingMore
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load More Flights'),
                ),
              ),
          ],
        );
      },
    );
  }
}
