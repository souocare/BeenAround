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
import '../../../flights/domain/airport_repository.dart';

import '../../application/map_search_service.dart';
import '../../application/map_search_cubit.dart';

import '../../application/map_search_state.dart';
import '../../domain/map_search_destination.dart';
import '../widgets/map_search_results_panel.dart';

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
        BlocProvider<MapSearchCubit>(
          create: (context) {
            final service = MapSearchService(
              countriesRepository: context.read<CountriesRepository>(),
              cityRepository: context.read<CityRepository>(),
              airportRepository: context.read<AirportRepository>(),
            );

            return MapSearchCubit(search: service.search);
          },
        ),
      ],
      child: const _MapView(),
    );
  }
}

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  bool _isSearchOpen = false;

  void _openSearch() {
    if (_isSearchOpen) return;

    setState(() {
      _isSearchOpen = true;
    });
  }

  void _onSearchDestinationSelected(MapSearchDestination destination) {
    _closeSearch();

    // Geographic navigation will be implemented in M7.3F.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Map navigation to ${destination.title} is coming next.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _closeSearch() {
    if (!_isSearchOpen) return;

    context.read<MapSearchCubit>().clear();

    setState(() {
      _isSearchOpen = false;
    });
  }

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
        resizeToAvoidBottomInset: false,
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
                    selectedCity: state.selectedCity,
                    onCitySelected: (cityId) {
                      _closeSearch();
                      context.read<MapCubit>().selectCity(cityId);
                    },
                    onCountrySelected: (countryCode) {
                      _closeSearch();
                      final cubit = context.read<MapCubit>();
                      if (countryCode == null) {
                        cubit.clearSelection();
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
                  left: MediaQuery.paddingOf(context).left + 16,
                  right: MediaQuery.paddingOf(context).right + 16,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: MapToolbar(
                      selectedStatus: state.activeStatus,
                      isSearchOpen: _isSearchOpen,
                      onSearchOpen: _openSearch,
                      onSearchClose: _closeSearch,
                      onSearchChanged: context
                          .read<MapSearchCubit>()
                          .queryChanged,
                      onStatusSelected: (status) {
                        _closeSearch();
                        context.read<MapCubit>().selectStatus(status);
                      },
                    ),
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

                // ---------------------------------------------------------
                // Geographic search results
                // ---------------------------------------------------------
                if (_isSearchOpen)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 66,
                    left: MediaQuery.paddingOf(context).left + 16,
                    right: MediaQuery.paddingOf(context).right + 16,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: BlocBuilder<MapSearchCubit, MapSearchState>(
                          builder: (context, searchState) {
                            final query = searchState.query.trim();

                            if (query.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            final mediaQuery = MediaQuery.of(context);

                            final availableHeight =
                                mediaQuery.size.height -
                                mediaQuery.viewInsets.bottom -
                                mediaQuery.padding.top -
                                90;

                            final panelHeight = availableHeight.clamp(
                              0.0,
                              420.0,
                            );

                            if (panelHeight <= 0) {
                              return const SizedBox.shrink();
                            }

                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: MapSearchResultsPanel(
                                key: const ValueKey('mapSearchResultsVisible'),
                                state: searchState,
                                maxHeight: panelHeight,
                                onDestinationSelected:
                                    _onSearchDestinationSelected,
                                onRetry: context.read<MapSearchCubit>().retry,
                              ),
                            );
                          },
                        ),
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
