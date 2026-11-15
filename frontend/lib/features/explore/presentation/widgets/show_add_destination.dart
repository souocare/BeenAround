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

/// Result of creating an independent country or city visit.
///
/// The visit is persisted, but no Trip association is implied.
class CreatedVisitResult {
  const CreatedVisitResult({required this.visitId, required this.isCountry});

  final String visitId;
  final bool isCountry;
}

typedef _AddDestinationResult = ({
  bool succeeded,
  CreatedVisitResult? createdVisit,
});

/// Opens the standard Add Destination flow.
///
/// Preserves the existing boolean result and post-registration follow-ups.
Future<bool> showAddDestination(
  BuildContext context, {
  Country? initialCountry,
  AddDestinationType initialDestinationType = AddDestinationType.country,
}) async {
  final result = await _showAddDestinationInternal(
    context,
    initialCountry: initialCountry,
    initialDestinationType: initialDestinationType,
    mode: AddDestinationMode.standard,
  );

  return result.succeeded;
}

/// Creates an independent visit from a Trip visit picker.
///
/// The visit is persisted globally, but Trip association is deferred
/// until the user confirms the picker selection.
Future<CreatedVisitResult?> showAddDestinationWithResult(
  BuildContext context, {
  required AddDestinationType destinationType,
}) async {
  final result = await _showAddDestinationInternal(
    context,
    initialDestinationType: destinationType,
    mode: AddDestinationMode.tripPicker,
  );

  return result.createdVisit;
}

Future<_AddDestinationResult> _showAddDestinationInternal(
  BuildContext context, {
  Country? initialCountry,
  required AddDestinationType initialDestinationType,
  required AddDestinationMode mode,
}) async {
  final isTripPickerMode = mode == AddDestinationMode.tripPicker;

  // Explore owns its existing Cubit in standard mode.
  //
  // When opening this form from a Trip Picker, create a temporary
  // ExploreCubit exclusively for loading the country catalog.
  final temporaryExploreCubit = isTripPickerMode
      ? ExploreCubit(repository: context.read<CountriesRepository>())
      : null;

  final exploreCubit = temporaryExploreCubit ?? context.read<ExploreCubit>();

  // The temporary Cubit must always be closed, including when
  // loading, navigation, or registration throws an exception.
  //
  // Never close the Cubit owned by ExplorePage.
  try {
    if (temporaryExploreCubit != null) {
      // The country picker reads ExploreCubit.state.countries.
      //
      // Load the country catalog before displaying the form so
      // that contextual creation can work independently of ExplorePage.
      await temporaryExploreCubit.load();
    }

    // The caller may have been disposed while countries were loading.
    //
    // In that case, do not attempt to open another route.
    if (!context.mounted) {
      return (succeeded: false, createdVisit: null);
    }

    final repository = exploreCubit.repository;

    final cityVisitsRepository = context.read<CityVisitsRepository>();
    final cityRepository = context.read<CityRepository>();

    final residenceRepository = isTripPickerMode
        ? null
        : context.read<ResidenceRepository>();

    final wishlistRepository = isTripPickerMode
        ? null
        : context.read<WishlistRepository>();

    final tripRepository = isTripPickerMode
        ? null
        : context.read<TripRepository>();

    final tripAssociationRepository = isTripPickerMode
        ? null
        : context.read<TripAssociationRepository>();

    final countriesRepository = repository;

    final width = MediaQuery.sizeOf(context).width;

    // Wishlist follow-ups belong to the standard Explore flow.
    //
    // Contextual Trip Picker creation does not require WishlistCubit.
    final WishlistCubit? wishlistCubit = mode == AddDestinationMode.standard
        ? context.read<WishlistCubit>()
        : null;

    ({
      String countryCode,
      int? cityId,
      String destinationName,
      bool isResidence,
    })?
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
      final suggestionsRepository = tripRepository;
      final suggestionsAssociationRepository = tripAssociationRepository;

      if (visit == null ||
          visit.hasSelectedTrip ||
          suggestionsRepository == null ||
          suggestionsAssociationRepository == null ||
          !context.mounted) {
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

        final trips = await suggestionsRepository.getTrips();

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
          associationRepository: suggestionsAssociationRepository,
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

      if (destination == null ||
          wishlistCubit == null ||
          wishlistCubit.isClosed ||
          !context.mounted) {
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
          if (tripRepository != null)
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
            if (residenceRepository != null)
              BlocProvider<SaveResidenceCubit>(
                create: (_) =>
                    SaveResidenceCubit(repository: residenceRepository),
              ),
            if (wishlistRepository != null)
              BlocProvider<AddWishlistEntryCubit>(
                create: (_) =>
                    AddWishlistEntryCubit(repository: wishlistRepository),
              ),
          ],
          child: AddDestinationSheet(
            initialCountry: initialCountry,
            initialDestinationType: initialDestinationType,
            mode: mode,
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

    Future<_AddDestinationResult> finishRegistration(bool? result) async {
      final succeeded = result ?? false;

      if (!succeeded) {
        return (succeeded: false, createdVisit: null);
      }

      final visit = createdVisit;

      final structuredVisit = visit == null
          ? null
          : CreatedVisitResult(
              visitId: visit.visitId,
              isCountry: visit.isCountry,
            );

      // In Trip Picker mode, only return the persisted visit.
      //
      // No Wishlist follow-up or Trip suggestion is shown here.
      //
      // Trip association remains the picker's responsibility.
      if (mode == AddDestinationMode.tripPicker) {
        return (
          succeeded: structuredVisit != null,
          createdVisit: structuredVisit,
        );
      }

      // Preserve the existing standard behavior when the original
      // BuildContext is no longer mounted.
      if (!context.mounted) {
        return (succeeded: true, createdVisit: structuredVisit);
      }

      final shouldSuggestTrips =
          visit != null &&
          !visit.hasSelectedTrip &&
          !visit.suggestionsWereShown;

      final completed = await runPostRegistrationFollowUps(
        registrationSucceeded: succeeded,
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

      return (succeeded: completed, createdVisit: structuredVisit);
    }

    // ---------------------------------------------------------------------
    // Desktop
    // ---------------------------------------------------------------------

    if (width >= 800) {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
          child: SizedBox(height: 700, child: buildContent(dialogContext)),
        ),
      );

      return await finishRegistration(result);
    }

    // ---------------------------------------------------------------------
    // Mobile
    // ---------------------------------------------------------------------

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

        return SizedBox(height: height, child: buildContent(sheetContext));
      },
    );

    return await finishRegistration(result);
  } finally {
    // The temporary Cubit belongs exclusively to the contextual form.
    //
    // Close it only after the form and its result handling have finished.
    //
    // The standard ExploreCubit must never be closed here.
    if (temporaryExploreCubit != null) {
      await temporaryExploreCubit.close();
    }
  }
}
