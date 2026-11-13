import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/save_flight_cubit.dart';
import '../../domain/flight_repository.dart';
import '../../domain/airport_repository.dart';
import '../../domain/airline_repository.dart';

import 'add_flight_form.dart';
import '../../../explore/data/countries_repository.dart';

/// Opens the personal flight creation flow.
///
/// Returns true only after a flight has been persisted.
///
/// Flight creation does not modify visits, wishlist entries
/// or Trip associations.
Future<bool> showAddFlight(BuildContext context) async {
  // Capture the repositories before opening a Navigator route.
  //
  // Dialogs and bottom sheets may not inherit providers
  // registered below the application's Navigator.
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
        child: const AddFlightForm(),
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

    return result ?? false;
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

  return result ?? false;
}
