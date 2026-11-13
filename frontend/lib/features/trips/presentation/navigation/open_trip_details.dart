import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../explore/data/countries_repository.dart';
import '../../../geography/domain/city_visits_repository.dart';

import '../../../flights/domain/airline_repository.dart';
import '../../../flights/domain/airport_repository.dart';
import '../../../flights/domain/flight_repository.dart';

import '../../domain/trip_repository.dart';
import '../../domain/trip_association_repository.dart';

import '../pages/trip_details_page.dart';

/// Opens Trip Details with all dependencies required by its features.
///
/// Repositories are captured from the source route and explicitly
/// forwarded to the destination route.
///
/// The caller remains responsible for refreshing its own data
/// after returning.
Future<void> openTripDetails(
  BuildContext context, {
  required String tripId,
}) async {
  // Capture dependencies before pushing the destination route.
  //
  // Providers below a Navigator are not automatically available
  // to routes pushed by that Navigator.
  final tripRepository = context.read<TripRepository>();
  final tripAssociationRepository = context.read<TripAssociationRepository>();

  final countriesRepository = context.read<CountriesRepository>();
  final cityVisitsRepository = context.read<CityVisitsRepository>();

  final flightRepository = context.read<FlightRepository>();
  final airportRepository = context.read<AirportRepository>();
  final airlineRepository = context.read<AirlineRepository>();

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TripRepository>.value(value: tripRepository),
          RepositoryProvider<TripAssociationRepository>.value(
            value: tripAssociationRepository,
          ),
          RepositoryProvider<CountriesRepository>.value(
            value: countriesRepository,
          ),
          RepositoryProvider<CityVisitsRepository>.value(
            value: cityVisitsRepository,
          ),
          RepositoryProvider<FlightRepository>.value(value: flightRepository),
          RepositoryProvider<AirportRepository>.value(value: airportRepository),
          RepositoryProvider<AirlineRepository>.value(value: airlineRepository),
        ],
        child: TripDetailsPage(tripId: tripId),
      ),
    ),
  );
}
