import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../explore/data/countries_repository.dart';
import '../../../geography/domain/city_repository.dart';
import '../../../geography/domain/city_visits_repository.dart';
import '../../../residences/domain/residence_repository.dart';
import '../../../trips/domain/trip_repository.dart';
import '../../../wishlist/domain/wishlist_repository.dart';

import '../../application/map_country_projection.dart';
import '../../application/map_country_related_cubit.dart';
import '../../application/map_country_related_state.dart';
import '../../application/map_cubit.dart';
import '../../application/map_state.dart';

import '../widgets/map_country_panel.dart';
import '../widgets/map_toolbar.dart';
import '../widgets/travel_map.dart';
import '../../application/map_city_projection.dart';
import '../../../explore/presentation/navigation/open_country_details.dart';

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<MapCubit>(
          create: (context) {
            final cityRepository = context.read<CityRepository>();

            return MapCubit(
              countriesRepository: context.read<CountriesRepository>(),

              cityVisitsRepository: context.read<CityVisitsRepository>(),

              residenceRepository: context.read<ResidenceRepository>(),

              wishlistRepository: context.read<WishlistRepository>(),

              countryProjection: MapCountryProjection(
                cityRepository: cityRepository,
              ),

              cityProjection: MapCityProjection(cityRepository: cityRepository),
            )..load();
          },
        ),
        BlocProvider<MapCountryRelatedCubit>(
          create: (context) => MapCountryRelatedCubit(
            cityVisitsRepository: context.read<CityVisitsRepository>(),
            tripRepository: context.read<TripRepository>(),
          ),
        ),
      ],
      child: const _MapView(),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView();

  Future<void> _openSelectedCountryDetails(
    BuildContext context,
    String countryCode,
  ) async {
    final mapCubit = context.read<MapCubit>();
    final relatedCubit = context.read<MapCountryRelatedCubit>();

    final opened = await openCountryDetails(
      context: context,
      countryCode: countryCode,
    );

    if (!opened || !context.mounted) return;

    // Refresh map projections after edits made in CountryDetailsPage.
    if (!mapCubit.isClosed) {
      await mapCubit.refresh();
    }

    if (!context.mounted || relatedCubit.isClosed) return;

    // The selected country may have changed while navigating.
    final selectedCode = mapCubit.state.selectedCountryCode;

    relatedCubit.clear();

    if (selectedCode != null) {
      await relatedCubit.load(selectedCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MapCubit, MapState>(
      listenWhen: (previous, current) =>
          previous.selectedCountryCode != current.selectedCountryCode,
      listener: (context, state) {
        final relatedCubit = context.read<MapCountryRelatedCubit>();
        final countryCode = state.selectedCountryCode;

        if (countryCode == null) {
          relatedCubit.clear();
        } else {
          relatedCubit.load(countryCode);
        }
      },
      child: Scaffold(
        body: BlocBuilder<MapCubit, MapState>(
          builder: (context, state) {
            return Stack(
              children: [
                // ---------------------------------------------------------
                // Interactive map
                // ---------------------------------------------------------
                Positioned.fill(
                  child: TravelMap(
                    highlightedCountryCodes: state.highlightedCountryCodes,
                    selectedCountryCode: state.selectedCountryCode,
                    cities: state.visibleCities,
                    onCountrySelected: (countryCode) {
                      final cubit = context.read<MapCubit>();

                      if (countryCode == null) {
                        cubit.clearCountrySelection();
                      } else {
                        cubit.selectCountry(countryCode);
                      }
                    },
                  ),
                ),

                // ---------------------------------------------------------
                // Map toolbar
                // ---------------------------------------------------------
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 12,
                  right: MediaQuery.paddingOf(context).right + 16,
                  child: MapToolbar(
                    selectedStatus: state.activeStatus,
                    onStatusSelected: context.read<MapCubit>().selectStatus,
                  ),
                ),

                // ---------------------------------------------------------
                // Selected country panel
                // ---------------------------------------------------------
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 550),
                    reverseDuration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      final slideAnimation = Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(animation);

                      return SlideTransition(
                        position: slideAnimation,
                        child: child,
                      );
                    },
                    child: state.selectedCountryPreview == null
                        ? const SizedBox.shrink(
                            key: ValueKey('mapCountryPanelClosed'),
                          )
                        : BlocBuilder<
                            MapCountryRelatedCubit,
                            MapCountryRelatedState
                          >(
                            key: ValueKey(
                              state.selectedCountryPreview!.countryCode,
                            ),
                            builder: (context, relatedState) {
                              final preview = state.selectedCountryPreview!;

                              final matchingState =
                                  relatedState.countryCode ==
                                  preview.countryCode;

                              return MapCountryPanel(
                                preview: preview,
                                relatedState: matchingState
                                    ? relatedState
                                    : MapCountryRelatedState(
                                        phase: MapCountryRelatedPhase.loading,
                                        countryCode: preview.countryCode,
                                      ),
                                onClose: context
                                    .read<MapCubit>()
                                    .clearCountrySelection,
                                onViewDetails: () =>
                                    _openSelectedCountryDetails(
                                      context,
                                      preview.countryCode,
                                    ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
