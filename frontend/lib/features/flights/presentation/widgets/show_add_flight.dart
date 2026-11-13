import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/save_flight_cubit.dart';
import '../../application/save_flight_state.dart';

import '../../domain/flight.dart';
import '../../domain/flight_repository.dart';
import '../../domain/airport_repository.dart';
import '../../domain/airline_repository.dart';

import 'add_flight_form.dart';
import '../../../explore/data/countries_repository.dart';

/// Opens the personal flight creation flow.
///
/// Returns true only after a flight has been persisted.
///
/// Preserved for callers that only need to know whether
/// a flight was created.
Future<bool> showAddFlight(BuildContext context) async {
  final flight = await showAddFlightWithResult(context);

  return flight != null;
}

/// Opens the personal flight creation flow and returns
/// the newly persisted Flight.
///
/// Returns null when the user cancels the form.
///
/// Flight creation remains independent of Trips, visits,
/// and wishlist entries.
///
/// The caller decides whether to offer an explicit
/// Trip association after creation.
Future<Flight?> showAddFlightWithResult(BuildContext context) async {
  // Capture repositories before opening a Navigator route.
  //
  // Dialogs and bottom sheets may not inherit providers
  // registered below the application's Navigator.
  final flightRepository = context.read<FlightRepository>();
  final airportRepository = context.read<AirportRepository>();
  final airlineRepository = context.read<AirlineRepository>();
  final countriesRepository = context.read<CountriesRepository>();

  final width = MediaQuery.sizeOf(context).width;

  Flight? createdFlight;

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
        child: BlocListener<SaveFlightCubit, SaveFlightState>(
          listenWhen: (previous, current) =>
              !previous.isSuccess && current.isSuccess,

          listener: (context, state) {
            // Capture the persisted Flight before the
            // form closes its modal route.
            createdFlight = state.flight;
          },

          child: const AddFlightForm(),
        ),
      ),
    );
  }

  if (width >= 800) {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 820),
        child: SizedBox(height: 760, child: buildContent()),
      ),
    );

    return result == true ? createdFlight : null;
  }

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

  return result == true ? createdFlight : null;
}
