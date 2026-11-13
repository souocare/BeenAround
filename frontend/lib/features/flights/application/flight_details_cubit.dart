import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/flight.dart';
import '../domain/flight_repository.dart';
import '../domain/flight_timing.dart';

import 'flight_catalog_resolver.dart';
import 'flight_details_state.dart';

/// Loads and presents one user-owned flight.
///
/// The backend remains responsible for ownership checks
/// and timezone-aware timing calculations.
///
/// Catalog resolution is best-effort: missing airports
/// or airlines must not make the flight inaccessible.
class FlightDetailsCubit extends Cubit<FlightDetailsState> {
  FlightDetailsCubit({
    required FlightRepository repository,
    required FlightCatalogResolver catalogResolver,
  }) : _repository = repository,
       _catalogResolver = catalogResolver,
       super(const FlightDetailsState());

  final FlightRepository _repository;
  final FlightCatalogResolver _catalogResolver;

  int _requestGeneration = 0;

  Future<void> load(String flightId) async {
    if (isClosed) return;

    final generation = ++_requestGeneration;

    emit(const FlightDetailsState(phase: FlightDetailsPhase.loading));

    try {
      final detail = await _repository.getFlightDetail(flightId: flightId);

      if (!_isCurrent(generation)) return;

      final flight = detail.flight;
      final timing = detail.timing;

      // Show the flight and its calculated timing immediately.
      //
      // The UI must not wait for airport or airline
      // catalog requests to finish.
      emit(
        FlightDetailsState(
          phase: FlightDetailsPhase.ready,
          flight: flight,
          timing: timing,
        ),
      );

      await _resolveCatalog(
        flight: flight,
        timing: timing,
        generation: generation,
      );
    } on ApiException catch (error) {
      if (!_isCurrent(generation)) return;

      emit(
        FlightDetailsState(
          phase: FlightDetailsPhase.failure,
          errorMessage: error.message,
        ),
      );
    } catch (_) {
      if (!_isCurrent(generation)) return;

      emit(
        const FlightDetailsState(
          phase: FlightDetailsPhase.failure,
          errorMessage: 'Unable to load this flight.',
        ),
      );
    }
  }

  Future<void> _resolveCatalog({
    required Flight flight,
    required FlightTiming timing,
    required int generation,
  }) async {
    try {
      final catalog = await _catalogResolver.resolve([flight]);

      if (!_isCurrent(generation)) return;

      emit(
        FlightDetailsState(
          phase: FlightDetailsPhase.ready,
          flight: flight,

          // Preserve timing when catalog metadata arrives.
          timing: timing,

          departureAirport: catalog.airportFor(flight.departureAirportId),

          arrivalAirport: catalog.airportFor(flight.arrivalAirportId),

          airline: flight.airlineId == null
              ? null
              : catalog.airlineFor(flight.airlineId!),
        ),
      );
    } catch (_) {
      // Flight details and timing remain visible.
      //
      // Failed catalog requests are not cached, so another
      // load can retry them.
    }
  }

  bool _isCurrent(int generation) {
    return !isClosed && generation == _requestGeneration;
  }

  @override
  Future<void> close() {
    ++_requestGeneration;

    return super.close();
  }
}
