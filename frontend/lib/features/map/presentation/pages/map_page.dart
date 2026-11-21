import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../explore/data/countries_repository.dart';
import '../../../explore/presentation/navigation/open_country_details.dart';
import '../../../flights/application/flight_catalog_resolver.dart';
import '../../../flights/domain/airline_repository.dart';
import '../../../flights/domain/airport_repository.dart';
import '../../../flights/domain/flight_repository.dart';
import '../../../geography/domain/city_repository.dart';
import '../../../geography/domain/city_visits_repository.dart';
import '../../../residences/domain/residence_repository.dart';
import '../../../trips/domain/trip_repository.dart';
import '../../../wishlist/domain/wishlist_repository.dart';

import '../../application/map_city_projection.dart';
import '../../application/map_context_panel_selection.dart';
import '../../application/map_country_projection.dart';
import '../../application/map_country_related_cubit.dart';
import '../../application/map_country_related_state.dart';
import '../../application/map_cubit.dart';
import '../../application/map_search_cubit.dart';
import '../../application/map_search_service.dart';
import '../../application/map_search_state.dart';
import '../../application/map_state.dart';

import '../../domain/map_search_destination.dart';

import '../map_overlay_layout.dart';
import '../widgets/map_airport_panel.dart';
import '../widgets/map_city_panel.dart';
import '../widgets/map_context_panel_shell.dart';
import '../widgets/map_country_panel.dart';
import '../widgets/map_search_results_panel.dart';
import '../widgets/map_toolbar.dart';
import '../widgets/travel_map.dart';
import '../widgets/map_flight_route_panel.dart';

// -----------------------------------------------------------------------------
// Map page
// -----------------------------------------------------------------------------

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // -------------------------------------------------------------------
        // Geographic visualization
        // -------------------------------------------------------------------
        BlocProvider<MapCubit>(
          create: (context) {
            final cityRepository = context.read<CityRepository>();

            final flightCatalogResolver = FlightCatalogResolver(
              airportRepository: context.read<AirportRepository>(),
              airlineRepository: context.read<AirlineRepository>(),
            );

            return MapCubit(
                countriesRepository: context.read<CountriesRepository>(),
                cityVisitsRepository: context.read<CityVisitsRepository>(),
                residenceRepository: context.read<ResidenceRepository>(),
                wishlistRepository: context.read<WishlistRepository>(),
                countryProjection: MapCountryProjection(
                  cityRepository: cityRepository,
                ),
                cityProjection: MapCityProjection(
                  cityRepository: cityRepository,
                ),
                flightRepository: context.read<FlightRepository>(),
                flightCatalogResolver: flightCatalogResolver,
              )
              ..load()
              ..loadAirports();
          },
        ),

        // -------------------------------------------------------------------
        // Related country information
        // -------------------------------------------------------------------
        BlocProvider<MapCountryRelatedCubit>(
          create: (context) => MapCountryRelatedCubit(
            cityVisitsRepository: context.read<CityVisitsRepository>(),
            tripRepository: context.read<TripRepository>(),
          ),
        ),

        // -------------------------------------------------------------------
        // Unified geographic search
        // -------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Map view
// -----------------------------------------------------------------------------

class _MapView extends StatefulWidget {
  const _MapView();

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  // ---------------------------------------------------------------------------
  // Search presentation state
  // ---------------------------------------------------------------------------

  bool _isSearchOpen = false;

  MapSearchDestination? _searchFocusDestination;
  int _searchFocusRequestId = 0;

  // ---------------------------------------------------------------------------
  // Contextual panel compaction
  // ---------------------------------------------------------------------------

  /// Incremented when the active geographic panel should compact.
  int _panelCompactRequestId = 0;

  /// Prevents repeated compaction during the same search session.
  bool _compactedForCurrentSearch = false;

  // ---------------------------------------------------------------------------
  // Open search
  // ---------------------------------------------------------------------------

  void _openSearch() {
    if (_isSearchOpen) {
      return;
    }

    setState(() {
      _isSearchOpen = true;
      _compactedForCurrentSearch = false;
    });
  }

  // ---------------------------------------------------------------------------
  // Search query changes
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String value) {
    context.read<MapSearchCubit>().queryChanged(value);

    // Opening search alone must not compact the contextual panel.
    //
    // Compaction starts when the user enters a non-empty query,
    // which is when the search results become visible.
    if (!_isSearchOpen || value.trim().isEmpty || _compactedForCurrentSearch) {
      return;
    }

    // Compact the currently selected geographic panel.
    //
    // Search compaction must not change the selection,
    // map status, geographic records or camera position.
    final mapState = context.read<MapCubit>().state;

    final selection = resolveMapContextPanelSelection(mapState);

    if (selection == null) {
      return;
    }

    setState(() {
      _compactedForCurrentSearch = true;
      _panelCompactRequestId++;
    });
  }

  // ---------------------------------------------------------------------------
  // Close search
  // ---------------------------------------------------------------------------

  void _closeSearch() {
    if (!_isSearchOpen) {
      return;
    }

    context.read<MapSearchCubit>().clear();

    setState(() {
      _isSearchOpen = false;
      _compactedForCurrentSearch = false;
    });

    // Deliberately preserve the contextual panel extent.
    //
    // Closing search must not resize the panel.
  }

  // ---------------------------------------------------------------------------
  // Search destination selection
  // ---------------------------------------------------------------------------

  void _onSearchDestinationSelected(MapSearchDestination destination) {
    // Cities and airports require valid coordinates.
    // Country navigation uses geographic geometry.
    if (destination.type != MapSearchDestinationType.country &&
        !destination.hasCoordinates) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location unavailable for ${destination.title}.'),
          duration: const Duration(seconds: 2),
        ),
      );

      return;
    }

    // Update the geographic selection without creating
    // or modifying personal travel records.
    context.read<MapCubit>().selectSearchDestination(destination);

    // Close search without modifying the selected destination
    // or contextual panel extent.
    _closeSearch();

    // Request camera navigation independently from selection state.
    //
    // This allows the same destination to be focused repeatedly.
    setState(() {
      _searchFocusDestination = destination;
      _searchFocusRequestId++;
    });
  }

  // ---------------------------------------------------------------------------
  // Country details navigation
  // ---------------------------------------------------------------------------

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

    if (!opened || !context.mounted) {
      return;
    }

    // Refresh map projections after edits made in CountryDetailsPage.
    if (!mapCubit.isClosed) {
      await mapCubit.refresh();
    }

    if (!context.mounted || relatedCubit.isClosed) {
      return;
    }

    // The selected country may have changed while navigating.
    final selectedCode = mapCubit.state.selectedCountryCode;

    relatedCubit.clear();

    if (selectedCode != null) {
      await relatedCubit.load(selectedCode);
    }
  }

  // ---------------------------------------------------------------------------
  // Contextual geographic panel content
  // ---------------------------------------------------------------------------

  Widget _buildContextPanel(
    BuildContext context,
    MapState state,
    MapContextPanelSelection selection, {
    required ScrollController scrollController,
    required bool showDragHandle,
  }) {
    switch (selection) {
      // -----------------------------------------------------------------------
      // Country
      // -----------------------------------------------------------------------

      case MapCountryPanelSelection(:final countryCode):
        final preview = state.countryPreviews[countryCode];

        if (preview == null) {
          return const SizedBox.shrink();
        }

        return BlocBuilder<MapCountryRelatedCubit, MapCountryRelatedState>(
          key: ValueKey(selection.key),
          builder: (context, relatedState) {
            final matchingState = relatedState.countryCode == countryCode;

            return MapCountryPanel(
              preview: preview,
              relatedState: matchingState
                  ? relatedState
                  : MapCountryRelatedState(
                      phase: MapCountryRelatedPhase.loading,
                      countryCode: countryCode,
                    ),
              onClose: context.read<MapCubit>().clearSelection,
              onViewDetails: () =>
                  _openSelectedCountryDetails(context, countryCode),
              panelScrollController: scrollController,
              showDragHandle: showDragHandle,
            );
          },
        );

      // -----------------------------------------------------------------------
      // City
      // -----------------------------------------------------------------------

      case MapCityPanelSelection(:final data):
        return MapCityPanel(
          key: ValueKey(selection.key),
          data: data,
          onClose: context.read<MapCubit>().clearSelection,
          panelScrollController: scrollController,
          showDragHandle: showDragHandle,
        );

      // -----------------------------------------------------------------------
      // Airport
      // -----------------------------------------------------------------------

      case MapAirportPanelSelection(
        :final destination,
        :final airport,
        :final airportPhase,
      ):
        return MapAirportPanel(
          key: ValueKey(selection.key),
          destination: destination,
          airport: airport,
          airportPhase: airportPhase,
          airportErrorMessage: state.airportErrorMessage,
          onClose: context.read<MapCubit>().clearSelection,
          panelScrollController: scrollController,
          showDragHandle: showDragHandle,
        );

      // -----------------------------------------------------------------------
      // Completed-flight route
      // -----------------------------------------------------------------------

      case MapFlightRoutePanelSelection(
        :final route,
        :final firstAirport,
        :final secondAirport,
      ):
        return MapFlightRoutePanel(
          key: ValueKey(selection.key),
          route: route,
          firstAirport: firstAirport,
          secondAirport: secondAirport,
          onClose: context.read<MapCubit>().clearSelection,
          panelScrollController: scrollController,
          showDragHandle: showDragHandle,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------------------------

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
            final panelSelection = resolveMapContextPanelSelection(state);

            final mediaQuery = MediaQuery.of(context);

            // ---------------------------------------------------------------
            // Shared responsive overlay layout
            //
            // When a contextual side panel is visible, the toolbar and
            // geographic search results occupy the remaining map area.
            //
            // In portrait, the existing full-width layout is preserved.
            // ---------------------------------------------------------------

            final overlayLayout = calculateMapOverlayLayout(
              viewportSize: mediaQuery.size,
              safePadding: mediaQuery.padding,
              hasSelection: panelSelection != null,
              keyboardInset: mediaQuery.viewInsets.bottom,
            );

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
                    selectedSearchDestination: state.selectedSearchDestination,
                    searchFocusDestination: _searchFocusDestination,
                    searchFocusRequestId: _searchFocusRequestId,
                    airports: state.airports.values.toList(growable: false),
                    flightRoutesGeoJson: state.flightRoutesGeoJson,

                    // -----------------------------------------------------
                    // City selection
                    // -----------------------------------------------------
                    onCitySelected: (cityId) {
                      _closeSearch();

                      context.read<MapCubit>().selectCity(cityId);
                    },

                    // -----------------------------------------------------
                    // Airport selection
                    // -----------------------------------------------------
                    onAirportSelected: (airportId) {
                      _closeSearch();

                      final cubit = context.read<MapCubit>();

                      final airport = cubit.state.airports[airportId];

                      if (airport == null) {
                        return;
                      }

                      final destination = MapSearchDestination(
                        type: MapSearchDestinationType.airport,
                        id: 'airport:${airport.airportId}',
                        title: airport.name,
                        subtitle: airport.code,
                        countryCode: airport.countryCode,
                        latitude: airport.latitude,
                        longitude: airport.longitude,
                        airportCode: airport.code,
                      );

                      cubit.selectSearchDestination(destination);
                    },

                    // -----------------------------------------------------
                    // Country selection
                    // -----------------------------------------------------
                    onCountrySelected: (countryCode) {
                      _closeSearch();

                      final cubit = context.read<MapCubit>();

                      if (countryCode == null) {
                        cubit.clearSelection();
                      } else {
                        cubit.selectCountry(countryCode);
                      }
                    },

                    onFlightRouteSelected: (routeId) {
                      _closeSearch();

                      context.read<MapCubit>().selectFlightRoute(routeId);
                    },

                    // -----------------------------------------------------
                    // Existing temporary catalog markers
                    // -----------------------------------------------------
                    onSearchDestinationSelected: (destination) {
                      _closeSearch();

                      context.read<MapCubit>().selectSearchDestination(
                        destination,
                      );
                    },
                  ),
                ),

                // ---------------------------------------------------------
                // Persistent contextual geographic panel
                //
                // Rendered below the toolbar and search results.
                //
                // The shared shell remains mounted when selection
                // changes between countries, cities and airports.
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
                    child: panelSelection == null
                        ? const SizedBox.shrink(
                            key: ValueKey('mapContextPanelClosed'),
                          )
                        : MapContextPanelShell(
                            key: const ValueKey('mapContextPanelOpen'),
                            selectionKey: panelSelection.key,
                            compactRequestId: _panelCompactRequestId,
                            onClose: context.read<MapCubit>().clearSelection,
                            contentBuilder:
                                (context, scrollController, showDragHandle) {
                                  return _buildContextPanel(
                                    context,
                                    state,
                                    panelSelection,
                                    scrollController: scrollController,
                                    showDragHandle: showDragHandle,
                                  );
                                },
                          ),
                  ),
                ),

                // ---------------------------------------------------------
                // Map toolbar
                //
                // Rendered above the contextual panel.
                //
                // In landscape, its horizontal area excludes the
                // contextual side panel.
                // ---------------------------------------------------------
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOutCubic,
                  top: overlayLayout.toolbarTop,
                  left: overlayLayout.left,
                  right: overlayLayout.right,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: MapToolbar(
                      selectedStatus: state.activeStatus,
                      isSearchOpen: _isSearchOpen,
                      onSearchOpen: _openSearch,
                      onSearchClose: _closeSearch,
                      onSearchChanged: _onSearchChanged,
                      allowCompactFilter: overlayLayout.hasSidePanel,
                      onStatusSelected: (status) {
                        _closeSearch();

                        context.read<MapCubit>().selectStatus(status);
                      },
                    ),
                  ),
                ),

                // ---------------------------------------------------------
                // Geographic search results
                //
                // Share the same horizontal area as the toolbar.
                //
                // The maximum height accounts for:
                // - Actual viewport dimensions.
                // - Safe areas.
                // - Keyboard.
                // - Bottom margin.
                //
                // The search list remains independently scrollable.
                // ---------------------------------------------------------
                if (_isSearchOpen && overlayLayout.resultsMaxHeight > 0)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 380),
                    curve: Curves.easeInOutCubic,
                    top: overlayLayout.resultsTop,
                    left: overlayLayout.left,
                    right: overlayLayout.right,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: BlocBuilder<MapSearchCubit, MapSearchState>(
                          builder: (context, searchState) {
                            final query = searchState.query.trim();

                            if (query.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            // Height is calculated by the shared
                            // responsive overlay layout.
                            //
                            // Do not recompute viewport and keyboard
                            // constraints inside the search panel.
                            final panelHeight = overlayLayout.resultsMaxHeight;

                            return SizedBox(
                              width: double.infinity,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: MapSearchResultsPanel(
                                    key: const ValueKey(
                                      'mapSearchResultsVisible',
                                    ),
                                    state: searchState,
                                    maxHeight: panelHeight,
                                    onDestinationSelected:
                                        _onSearchDestinationSelected,
                                    onRetry: context
                                        .read<MapSearchCubit>()
                                        .retry,
                                  ),
                                ),
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
