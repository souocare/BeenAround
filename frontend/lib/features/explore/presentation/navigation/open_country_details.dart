import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/country_trips_cubit.dart';
import '../../application/explore_cubit.dart';
import '../../application/visited_cities_cubit.dart';
import '../../data/countries_repository.dart';

import '../../../geography/domain/city_visits_repository.dart';
import '../../../residences/application/residences_cubit.dart';
import '../../../residences/domain/residence_repository.dart';
import '../../../trips/domain/trip_association_repository.dart';
import '../../../trips/domain/trip_repository.dart';
import '../../../wishlist/application/wishlist_cubit.dart';
import '../../../wishlist/domain/wishlist_repository.dart';

import '../pages/country_details_page.dart';

/// Opens the existing country details page using independent route-owned
/// Cubits.
///
/// Returns true if the page was opened and subsequently dismissed.
///
/// The caller may refresh its own data after navigation.
Future<bool> openCountryDetails({
  required BuildContext context,
  required String countryCode,
}) async {
  final normalizedCode = countryCode.trim().toUpperCase();

  if (normalizedCode.isEmpty) return false;

  // Resolve dependencies before any asynchronous operation.
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final countriesRepository = context.read<CountriesRepository>();
  final cityVisitsRepository = context.read<CityVisitsRepository>();
  final residenceRepository = context.read<ResidenceRepository>();
  final wishlistRepository = context.read<WishlistRepository>();
  final tripRepository = context.read<TripRepository>();
  final tripAssociationRepository = context.read<TripAssociationRepository>();

  try {
    // Use the real country catalogue instead of reconstructing
    // an incomplete Country from the map preview.
    final countries = await countriesRepository.getCountries();

    if (!context.mounted) return false;

    final matchingCountries = countries.where(
      (country) => country.code == normalizedCode,
    );

    if (matchingCountries.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Country details are unavailable.')),
      );

      return false;
    }

    final country = matchingCountries.first;

    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MultiRepositoryProvider(
          providers: [
            RepositoryProvider<CountriesRepository>.value(
              value: countriesRepository,
            ),
            RepositoryProvider<CityVisitsRepository>.value(
              value: cityVisitsRepository,
            ),
            RepositoryProvider<ResidenceRepository>.value(
              value: residenceRepository,
            ),
            RepositoryProvider<WishlistRepository>.value(
              value: wishlistRepository,
            ),
            RepositoryProvider<TripRepository>.value(value: tripRepository),
            RepositoryProvider<TripAssociationRepository>.value(
              value: tripAssociationRepository,
            ),
          ],
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ExploreCubit>(
                create: (_) =>
                    ExploreCubit(repository: countriesRepository)..load(),
              ),
              BlocProvider<VisitedCitiesCubit>(
                create: (_) =>
                    VisitedCitiesCubit(repository: cityVisitsRepository)
                      ..load(),
              ),
              BlocProvider<ResidencesCubit>(
                create: (_) =>
                    ResidencesCubit(repository: residenceRepository)..load(),
              ),
              BlocProvider<WishlistCubit>(
                create: (_) =>
                    WishlistCubit(repository: wishlistRepository)..load(),
              ),
              BlocProvider<CountryTripsCubit>(
                create: (_) => CountryTripsCubit(
                  repository: tripRepository,
                  countryCode: country.code,
                )..load(),
              ),
            ],
            child: CountryDetailsPage(country: country),
          ),
        ),
      ),
    );

    return true;
  } catch (error, stackTrace) {
    debugPrint('Unable to open country details: $error');
    debugPrintStack(stackTrace: stackTrace);

    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to open country details.')),
      );
    }

    return false;
  }
}
