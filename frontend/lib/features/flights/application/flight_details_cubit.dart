import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';

import '../domain/flight.dart';
import '../domain/flight_repository.dart';

import 'flight_catalog_resolver.dart';
import 'flight_details_state.dart';

/// Loads and presents one user-owned flight.
///
/// The backend remains responsible for ownership checks.
///
/// Catalog resolution is best-effort: a missing airport or
/// airline must not make the flight inaccessible.
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
      final flight = await _repository.getFlight(flightId: flightId);

      if (!_isCurrent(generation)) return;

      // A flight record can be shown before its catalog
      // metadata is available.
      emit(FlightDetailsState(phase: FlightDetailsPhase.ready, flight: flight));

      await _resolveCatalog(flight, generation);
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

  Future<void> _resolveCatalog(Flight flight, int generation) async {
    try {
      final catalog = await _catalogResolver.resolve([flight]);

      if (!_isCurrent(generation)) return;

      emit(
        FlightDetailsState(
          phase: FlightDetailsPhase.ready,
          flight: flight,
          departureAirport: catalog.airportFor(flight.departureAirportId),
          arrivalAirport: catalog.airportFor(flight.arrivalAirportId),
          airline: flight.airlineId == null
              ? null
              : catalog.airlineFor(flight.airlineId!),
        ),
      );
    } catch (_) {
      // Flight details must remain usable when catalog
      // resolution fails.
      //
      // The resolver does not cache failed requests,
      // allowing another load to retry later.
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
