import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../explore/data/countries_repository.dart';

import '../../application/delete_flight_cubit.dart';
import '../../application/flight_catalog_resolver.dart';
import '../../application/flight_details_cubit.dart';

import '../../domain/airline_repository.dart';
import '../../domain/airport_repository.dart';
import '../../domain/flight_repository.dart';

import '../pages/flight_details_page.dart';

enum FlightDetailsNavigationResult { viewed, updated, deleted }

/// Opens the existing Flight Details flow.
///
/// The caller owns any list or association refresh.
/// This function does not modify Trips or visits.
Future<FlightDetailsNavigationResult> openFlightDetails(
  BuildContext context, {
  required String flightId,
}) async {
  // Capture dependencies before pushing a route.
  final flightRepository = context.read<FlightRepository>();
  final airportRepository = context.read<AirportRepository>();
  final airlineRepository = context.read<AirlineRepository>();
  final countriesRepository = context.read<CountriesRepository>();

  final resolver = FlightCatalogResolver(
    airportRepository: airportRepository,
    airlineRepository: airlineRepository,
  );

  var wasUpdated = false;

  final deleted = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) {
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider<FlightRepository>.value(value: flightRepository),
            RepositoryProvider<AirportRepository>.value(
              value: airportRepository,
            ),
            RepositoryProvider<AirlineRepository>.value(
              value: airlineRepository,
            ),
            RepositoryProvider<CountriesRepository>.value(
              value: countriesRepository,
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<FlightDetailsCubit>(
                create: (_) => FlightDetailsCubit(
                  repository: flightRepository,
                  catalogResolver: resolver,
                )..load(flightId),
              ),
              BlocProvider<DeleteFlightCubit>(
                create: (_) => DeleteFlightCubit(repository: flightRepository),
              ),
            ],
            child: FlightDetailsPage(
              flightId: flightId,
              onFlightUpdated: () {
                wasUpdated = true;
              },
            ),
          ),
        );
      },
    ),
  );

  if (deleted == true) {
    return FlightDetailsNavigationResult.deleted;
  }

  if (wasUpdated) {
    return FlightDetailsNavigationResult.updated;
  }

  return FlightDetailsNavigationResult.viewed;
}
