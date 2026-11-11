import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/add_country_visit_cubit.dart';
import '../../application/explore_cubit.dart';
import 'add_destination_sheet.dart';
import '../../domain/country.dart';
import '../../application/add_city_visit_cubit.dart';
import '../../../geography/domain/city_visits_repository.dart';
import '../../../geography/domain/city_repository.dart';
import '../../data/countries_repository.dart';
import '../../../residences/domain/residence_repository.dart';
import '../../../residences/application/save_residence_cubit.dart';

import '../../../wishlist/domain/wishlist_repository.dart';
import '../../../wishlist/application/add_wishlist_entry_cubit.dart';
import '../../../trips/domain/trip_association_repository.dart';
import '../../../trips/domain/trip_repository.dart';
import '../../../wishlist/application/wishlist_cubit.dart';
import '../../../wishlist/application/wishlist_state.dart';
import '../../../wishlist/presentation/widgets/show_remove_wishlist_entry.dart';
import '../../../../core/models/partial_visit_date.dart';

import '../../../trips/application/trip_suggestions.dart';
import '../../../trips/presentation/widgets/suggested_trips_dialog.dart';
import '../../application/post_registration_follow_ups.dart';

Future<bool> showAddDestination(
  BuildContext context, {
  Country? initialCountry,
}) async {
  final exploreCubit = context.read<ExploreCubit>();
  final repository = exploreCubit.repository;
  final cityVisitsRepository = context.read<CityVisitsRepository>();
  final cityRepository = context.read<CityRepository>();
  final residenceRepository = context.read<ResidenceRepository>();
  final wishlistRepository = context.read<WishlistRepository>();
  final tripRepository = context.read<TripRepository>();

  final tripAssociationRepository = context.read<TripAssociationRepository>();
  final countriesRepository = repository;

  final width = MediaQuery.sizeOf(context).width;

  final wishlistCubit = context.read<WishlistCubit>();

  ({String countryCode, int? cityId, String destinationName, bool isResidence})?
  recordedDestination;
  ({
    String visitId,
    bool isCountry,
    bool hasSelectedTrip,
    bool suggestionsWereShown,
  })?
  createdVisit;

  Future<void> handleTripSuggestions() async {
    final visit = createdVisit;

    if (visit == null || visit.hasSelectedTrip || !context.mounted) {
      return;
    }

    try {
      // Load the persisted visit, not the original form values.
      PartialVisitDate? visitStart;
      PartialVisitDate? visitEnd;

      if (visit.isCountry) {
        final visits = await countriesRepository.getCountryVisits();

        final matches = visits.where((item) => item.id == visit.visitId);

        if (matches.isEmpty) return;

        final persisted = matches.first;

        if (persisted.startedOn != null &&
            persisted.startedOnPrecision != null) {
          visitStart = PartialVisitDate(
            date: persisted.startedOn!,
            precision: persisted.startedOnPrecision!,
          );
        }

        if (persisted.endedOn != null && persisted.endedOnPrecision != null) {
          visitEnd = PartialVisitDate(
            date: persisted.endedOn!,
            precision: persisted.endedOnPrecision!,
          );
        }
      } else {
        final visits = await cityVisitsRepository.getCityVisits();

        final matches = visits.where((item) => item.id == visit.visitId);

        if (matches.isEmpty) return;

        final persisted = matches.first;

        if (persisted.startedOn != null &&
            persisted.startedOnPrecision != null) {
          visitStart = PartialVisitDate(
            date: persisted.startedOn!,
            precision: persisted.startedOnPrecision!,
          );
        }

        if (persisted.endedOn != null && persisted.endedOnPrecision != null) {
          visitEnd = PartialVisitDate(
            date: persisted.endedOn!,
            precision: persisted.endedOnPrecision!,
          );
        }
      }

      // The MVP suggestion policy requires both date boundaries.
      if (visitStart == null || visitEnd == null) {
        return;
      }

      final trips = await tripRepository.getTrips();

      if (!context.mounted) return;

      final suggestions = findCompatibleTrips(
        trips: trips,
        visitStart: visitStart,
        visitEnd: visitEnd,
      );

      if (suggestions.isEmpty) return;

      final destinationName =
          recordedDestination?.destinationName ?? 'Your visit';

      await showSuggestedTripsDialog(
        context: context,
        visitId: visit.visitId,
        isCountry: visit.isCountry,
        destinationName: destinationName,
        suggestions: suggestions,
        associationRepository: tripAssociationRepository,
      );
    } catch (_) {
      // Trip suggestions are optional.
      //
      // A failure here must never be reported as a failure to
      // create the visit, which has already been persisted.
    }
  }

  Future<void> handleWishlistFollowUp() async {
    final destination = recordedDestination;

    if (destination == null || wishlistCubit.isClosed || !context.mounted) {
      return;
    }

    // Refresh before checking to avoid stale Wishlist data.
    await wishlistCubit.refresh();

    if (!context.mounted || wishlistCubit.isClosed) {
      return;
    }

    final wishlistState = wishlistCubit.state;

    if (wishlistState.phase != WishlistPhase.ready) {
      return;
    }

    final entry = destination.cityId == null
        ? wishlistState.entryForCountry(destination.countryCode)
        : wishlistState.entryForCity(destination.cityId!);

    if (entry == null) {
      return;
    }

    final removed = await showRemoveWishlistEntry(
      context: context,
      entry: entry,
      destinationName: destination.destinationName,
      cancelLabel: 'Keep in Wishlist',
      confirmationMessage: destination.isResidence
          ? 'You have recorded living in ${destination.destinationName}. '
                'Would you like to remove it from your Wishlist?'
          : 'You have recorded a visit to ${destination.destinationName}. '
                'Would you like to remove it from your Wishlist?',
    );

    if (removed && !wishlistCubit.isClosed) {
      await wishlistCubit.refresh();
    }
  }

  Widget buildContent(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<CityRepository>.value(value: cityRepository),
        RepositoryProvider<CountriesRepository>.value(value: repository),
        RepositoryProvider<TripRepository>.value(value: tripRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ExploreCubit>.value(value: exploreCubit),
          BlocProvider<AddCountryVisitCubit>(
            create: (_) => AddCountryVisitCubit(
              repository: repository,
              tripAssociationRepository: tripAssociationRepository,
            ),
          ),
          BlocProvider<AddCityVisitCubit>(
            create: (_) => AddCityVisitCubit(
              repository: cityVisitsRepository,
              tripAssociationRepository: tripAssociationRepository,
            ),
          ),
          BlocProvider<SaveResidenceCubit>(
            create: (_) => SaveResidenceCubit(repository: residenceRepository),
          ),
          BlocProvider<AddWishlistEntryCubit>(
            create: (_) =>
                AddWishlistEntryCubit(repository: wishlistRepository),
          ),
        ],
        child: AddDestinationSheet(
          initialCountry: initialCountry,
          onTravelRecorded:
              ({
                required countryCode,
                required cityId,
                required destinationName,
                required isResidence,
              }) {
                recordedDestination = (
                  countryCode: countryCode,
                  cityId: cityId,
                  destinationName: destinationName,
                  isResidence: isResidence,
                );
              },
          onVisitCreated:
              ({
                required visitId,
                required isCountry,
                required hasSelectedTrip,
                required suggestionsWereShown,
              }) {
                createdVisit = (
                  visitId: visitId,
                  isCountry: isCountry,
                  hasSelectedTrip: hasSelectedTrip,
                  suggestionsWereShown: suggestionsWereShown,
                );
              },
        ),
      ),
    );
  }

  Future<bool> finishRegistration(bool? result) async {
    final created = result ?? false;

    if (!created || !context.mounted) {
      return created;
    }

    final visit = createdVisit;

    final shouldSuggestTrips =
        visit != null && !visit.hasSelectedTrip && !visit.suggestionsWereShown;

    return runPostRegistrationFollowUps(
      registrationSucceeded: created,
      shouldSuggestTrips: shouldSuggestTrips,
      handleWishlist: () async {
        if (!context.mounted) return;

        await handleWishlistFollowUp();
      },
      handleTripSuggestions: () async {
        if (!context.mounted) return;

        await handleTripSuggestions();
      },
    );
  }

  if (width >= 800) {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
        child: SizedBox(height: 700, child: buildContent(context)),
      ),
    );

    return finishRegistration(result);
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
    builder: (context) {
      final height = MediaQuery.sizeOf(context).height * 0.94;

      return SizedBox(height: height, child: buildContent(context));
    },
  );

  return finishRegistration(result);
}
