import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../explore/data/countries_repository.dart';

import '../../application/save_flight_cubit.dart';

import '../../domain/airline.dart';
import '../../domain/airline_repository.dart';
import '../../domain/airport.dart';
import '../../domain/airport_repository.dart';
import '../../domain/flight.dart';
import '../../domain/flight_repository.dart';

import 'add_flight_form.dart';

/// Opens the edit flow for an existing personal flight.
///
/// Returns true only when changes were successfully persisted.
///
/// The caller must provide the resolved airport metadata and,
/// when the flight references a catalog airline, that airline.
///
/// Editing never creates visits or Trip associations.
Future<bool> showEditFlight(
  BuildContext context, {
  required Flight flight,
  required Airport departureAirport,
  required Airport arrivalAirport,
  required Airline? airline,
}) async {
  // ---------------------------------------------------------
  // Validate initial catalog metadata.
  //
  // A partially resolved flight must never be used to
  // initialize an editable form.
  // ---------------------------------------------------------

  if (departureAirport.id != flight.departureAirportId) {
    throw ArgumentError('Departure airport does not match the flight.');
  }

  if (arrivalAirport.id != flight.arrivalAirportId) {
    throw ArgumentError('Arrival airport does not match the flight.');
  }

  if (flight.airlineId != null && airline?.id != flight.airlineId) {
    throw ArgumentError('Catalog airline is not resolved for this flight.');
  }

  // ---------------------------------------------------------
  // Capture dependencies before opening a Navigator route.
  //
  // Dialogs and modal sheets may not inherit providers
  // registered below the application's Navigator.
  // ---------------------------------------------------------

  final flightRepository = context.read<FlightRepository>();
  final airportRepository = context.read<AirportRepository>();
  final airlineRepository = context.read<AirlineRepository>();
  final countriesRepository = context.read<CountriesRepository>();

  final width = MediaQuery.sizeOf(context).width;

  Widget buildContent() {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AirportRepository>.value(value: airportRepository),
        RepositoryProvider<AirlineRepository>.value(value: airlineRepository),
        RepositoryProvider<CountriesRepository>.value(
          value: countriesRepository,
        ),
      ],
      child: BlocProvider<SaveFlightCubit>(
        create: (_) => SaveFlightCubit(repository: flightRepository),
        child: AddFlightForm(
          initialFlight: flight,
          initialDepartureAirport: departureAirport,
          initialArrivalAirport: arrivalAirport,
          initialAirline: airline,
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Desktop / wide layouts
  // ---------------------------------------------------------

  if (width >= 800) {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 820),
        child: SizedBox(height: 760, child: buildContent()),
      ),
    );

    return result ?? false;
  }

  // ---------------------------------------------------------
  // Mobile / narrow layouts
  // ---------------------------------------------------------

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height * 0.94;

      return SizedBox(height: height, child: buildContent());
    },
  );

  return result ?? false;
}
