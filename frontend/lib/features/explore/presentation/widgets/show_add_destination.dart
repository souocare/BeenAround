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

  final width = MediaQuery.sizeOf(context).width;

  final wishlistCubit = context.read<WishlistCubit>();

  ({String countryCode, int? cityId, String destinationName, bool isResidence})?
  recordedDestination;

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
        ),
      ),
    );
  }

  Future<bool> finishRegistration(bool? result) async {
    final created = result ?? false;

    if (!created || !context.mounted) {
      return created;
    }

    final destination = recordedDestination;

    // A successful Wishlist creation is not a travel registration.
    if (destination == null || wishlistCubit.isClosed) {
      return created;
    }

    // Refresh before checking, so we do not rely on stale Wishlist data.
    await wishlistCubit.refresh();

    if (!context.mounted || wishlistCubit.isClosed) {
      return created;
    }

    final wishlistState = wishlistCubit.state;

    if (wishlistState.phase != WishlistPhase.ready) {
      return created;
    }

    final entry = destination.cityId == null
        ? wishlistState.entryForCountry(destination.countryCode)
        : wishlistState.entryForCity(destination.cityId!);

    // No matching Wishlist entry: nothing else to do.
    if (entry == null) {
      return created;
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

    // The travel record remains saved regardless of the Wishlist decision.
    return created;
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
