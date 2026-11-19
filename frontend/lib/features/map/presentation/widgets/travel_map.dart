import 'dart:async';

import 'package:beenaround/features/map/application/map_country_camera_bounds.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../data/world_geojson_repository.dart';
import '../../domain/world_map_viewport.dart';
import 'country_map_style.dart';
import '../../application/map_country_highlight_geojson.dart';
import '../../application/map_camera_target.dart';
import '../../application/map_country_focus_padding.dart';
import '../../application/map_city_geojson_projection.dart';
import '../../domain/map_city_data.dart';

class TravelMap extends StatefulWidget {
  const TravelMap({
    this.worldRepository,
    this.highlightedCountryCodes = const <String>{},
    this.cities = const <MapCityData>[],
    this.onCountrySelected,
    this.selectedCountryCode,
    this.onCitySelected,
    this.selectedCity,
    super.key,
  });

  final WorldGeoJsonRepository? worldRepository;

  final Set<String> highlightedCountryCodes;

  /// Cities currently visible according to the map application state.
  final List<MapCityData> cities;

  /// Reports the tapped country code, or null when tapping outside a country.
  final ValueChanged<String?>? onCountrySelected;

  final String? selectedCountryCode;

  /// Reports the catalog ID of the tapped city marker.
  final ValueChanged<int>? onCitySelected;

  /// Currently selected city, independently of the active map filter.
  final MapCityData? selectedCity;

  @override
  State<TravelMap> createState() => _TravelMapState();
}

class _TravelMapState extends State<TravelMap> {
  // ---------------------------------------------------------------------------
  // Source IDs
  // ---------------------------------------------------------------------------

  static const _worldSourceId = 'travel-map-world-source';
  static const _highlightSourceId = 'travel-map-highlight-source';
  static const _selectionSourceId = 'travel-map-selection-source';
  static const _citySourceId = 'travel-map-city-source';
  static const _selectedCitySourceId = 'travel-map-selected-city-source';

  // ---------------------------------------------------------------------------
  // Layer IDs
  // ---------------------------------------------------------------------------

  static const _countryFillLayerId = 'travel-map-country-fill';
  static const _countryBorderLayerId = 'travel-map-country-border';
  static const _countryHighlightLayerId = 'travel-map-country-highlight';
  static const _selectionFillLayerId = 'travel-map-selection-fill';
  static const _selectionBorderLayerId = 'travel-map-selection-border';
  static const _cityCircleLayerId = 'travel-map-city-circles';
  static const _selectedCityCircleLayerId = 'travel-map-selected-city-circle';

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  late final WorldGeoJsonRepository _repository;

  String? _worldGeoJson;
  String? _highlightGeoJson;
  String? _appliedHighlightGeoJson;
  String? _selectionGeoJson;
  String? _appliedSelectionGeoJson;

  late String _cityGeoJson;
  String? _appliedCityGeoJson;

  bool _cityUpdating = false;

  late String _selectedCityGeoJson;
  String? _appliedSelectedCityGeoJson;

  bool _selectedCityUpdating = false;

  bool _selectionUpdating = false;

  bool _highlightUpdating = false;
  Object? _error;

  // ---------------------------------------------------------------------------
  // MapLibre lifecycle
  // ---------------------------------------------------------------------------

  MapController? _mapController;
  StyleController? _styleController;

  String? _currentStyle;

  bool _layersReady = false;
  bool _layersInitializing = false;

  // Invalidates asynchronous initialization belonging to an older style.
  int _styleGeneration = 0;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _repository =
        widget.worldRepository ??
        WorldGeoJsonRepository(
          assetPath: 'assets/geo/world_countries_complete.geojson',
        );

    _cityGeoJson = buildMapCityGeoJson(cities: widget.cities);

    _selectedCityGeoJson = buildMapCityGeoJson(
      cities: [if (widget.selectedCity != null) widget.selectedCity!],
    );

    _loadWorld();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final colors = Theme.of(context).colorScheme;
    final nextStyle = CountryMapStyle.build(colors);

    if (_currentStyle == nextStyle) {
      return;
    }

    _currentStyle = nextStyle;

    final controller = _mapController;

    if (controller == null) {
      return;
    }

    // The style is being replaced. Sources and layers from the old style
    // must no longer be considered available.
    _styleGeneration++;
    _styleController = null;
    _layersReady = false;
    _appliedHighlightGeoJson = null;
    _appliedCityGeoJson = null;
    _appliedSelectedCityGeoJson = null;

    // This changes the style without rebuilding the MapLibre renderer,
    // preserving the current camera.
    controller.setStyle(nextStyle);
  }

  @override
  void dispose() {
    _styleGeneration++;

    _mapController = null;
    _styleController = null;

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // World geometry
  // ---------------------------------------------------------------------------

  Future<void> _loadWorld() async {
    try {
      final geoJson = await _repository.load();

      if (!mounted) return;

      final highlightGeoJson = buildMapCountryHighlightGeoJson(
        worldGeoJson: geoJson,
        countryCodes: widget.highlightedCountryCodes,
      );
      final selectedCode = widget.selectedCountryCode;

      final selectionGeoJson = buildMapCountryHighlightGeoJson(
        worldGeoJson: geoJson,
        countryCodes: selectedCode == null ? const <String>{} : {selectedCode},
      );

      setState(() {
        _worldGeoJson = geoJson;
        _highlightGeoJson = highlightGeoJson;
        _selectionGeoJson = selectionGeoJson;
        _error = null;
      });

      await _initializeLayers();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // MapLibre callbacks
  // ---------------------------------------------------------------------------

  void _onMapCreated(MapController controller) {
    _mapController = controller;
  }

  Future<void> _onStyleLoaded(StyleController style) async {
    if (!mounted) return;

    _styleGeneration++;
    _styleController = style;
    _appliedHighlightGeoJson = null;
    _appliedCityGeoJson = null;
    _appliedSelectedCityGeoJson = null;

    setState(() {
      _layersReady = false;
      _error = null;
    });

    await _initializeLayers();
  }

  // ---------------------------------------------------------------------------
  // Layer initialization
  // ---------------------------------------------------------------------------

  bool _isCurrentStyle(StyleController style, int generation) {
    return mounted &&
        generation == _styleGeneration &&
        identical(_styleController, style);
  }

  Future<void> _initializeLayers() async {
    if (_layersReady || _layersInitializing || _worldGeoJson == null) {
      return;
    }

    final style = _styleController;

    if (style == null) return;

    _layersInitializing = true;

    final generation = _styleGeneration;
    final colors = Theme.of(context).colorScheme;

    try {
      // ---------------------------------------------------------------------
      // 1. World source
      // ---------------------------------------------------------------------

      await style.addSource(
        GeoJsonSource(id: _worldSourceId, data: _worldGeoJson!),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 2. Highlight source (Visited / Lived / Wishlist)
      // ---------------------------------------------------------------------

      final initialHighlightGeoJson =
          _highlightGeoJson ?? '{"type":"FeatureCollection","features":[]}';

      await style.addSource(
        GeoJsonSource(id: _highlightSourceId, data: initialHighlightGeoJson),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 3. Selection source
      // ---------------------------------------------------------------------

      final initialSelectionGeoJson =
          _selectionGeoJson ?? '{"type":"FeatureCollection","features":[]}';

      await style.addSource(
        GeoJsonSource(id: _selectionSourceId, data: initialSelectionGeoJson),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 4. City source
      // ---------------------------------------------------------------------

      final initialCityGeoJson = _cityGeoJson;

      await style.addSource(
        GeoJsonSource(id: _citySourceId, data: initialCityGeoJson),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // Selected city source
      // ---------------------------------------------------------------------

      final initialSelectedCityGeoJson = _selectedCityGeoJson;

      await style.addSource(
        GeoJsonSource(
          id: _selectedCitySourceId,
          data: initialSelectedCityGeoJson,
        ),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 5. Neutral country fills
      // ---------------------------------------------------------------------

      await style.addLayer(
        FillStyleLayer(
          id: _countryFillLayerId,
          sourceId: _worldSourceId,
          paint: {
            'fill-color': CountryMapStyle.colorToHex(
              colors.surfaceContainerHighest,
            ),
            'fill-opacity': 1.0,
          },
        ),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 6. Highlighted country fills (Visited / Lived / Wishlist)
      // ---------------------------------------------------------------------

      await style.addLayer(
        FillStyleLayer(
          id: _countryHighlightLayerId,
          sourceId: _highlightSourceId,
          paint: {
            'fill-color': CountryMapStyle.colorToHex(colors.primary),
            'fill-opacity': 0.85,
          },
        ),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 7. Selected country fill
      // ---------------------------------------------------------------------

      await style.addLayer(
        FillStyleLayer(
          id: _selectionFillLayerId,
          sourceId: _selectionSourceId,
          paint: {
            'fill-color': CountryMapStyle.colorToHex(colors.primary),
            'fill-opacity': 0.25,
          },
        ),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 8. Country borders
      // ---------------------------------------------------------------------

      await style.addLayer(
        LineStyleLayer(
          id: _countryBorderLayerId,
          sourceId: _worldSourceId,
          paint: {
            'line-color': CountryMapStyle.colorToHex(colors.outlineVariant),
            'line-width': 0.8,
          },
        ),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 9. Selected country border
      // ---------------------------------------------------------------------

      await style.addLayer(
        LineStyleLayer(
          id: _selectionBorderLayerId,
          sourceId: _selectionSourceId,
          paint: {
            'line-color': CountryMapStyle.colorToHex(colors.onSurface),
            'line-width': 2.5,
            'line-opacity': 1.0,
          },
        ),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // City markers
      // ---------------------------------------------------------------------

      await style.addLayer(
        CircleStyleLayer(
          id: _cityCircleLayerId,
          sourceId: _citySourceId,
          paint: {
            'circle-radius': 5.5,
            'circle-color': CountryMapStyle.colorToHex(colors.primary),
            'circle-opacity': 1.0,
            'circle-stroke-width': 1.5,
            'circle-stroke-color': CountryMapStyle.colorToHex(colors.surface),
          },
        ),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // Selected city marker
      // ---------------------------------------------------------------------

      await style.addLayer(
        CircleStyleLayer(
          id: _selectedCityCircleLayerId,
          sourceId: _selectedCitySourceId,
          paint: {
            'circle-radius': 8.0,
            'circle-color': CountryMapStyle.colorToHex(colors.primary),
            'circle-opacity': 1.0,
            'circle-stroke-width': 2.5,
            'circle-stroke-color': CountryMapStyle.colorToHex(colors.onSurface),
          },
        ),
      );

      if (!_isCurrentStyle(style, generation)) return;

      // ---------------------------------------------------------------------
      // 9. Mark sources as synchronized
      // ---------------------------------------------------------------------

      _appliedHighlightGeoJson = initialHighlightGeoJson;
      _appliedSelectionGeoJson = initialSelectionGeoJson;
      _appliedCityGeoJson = initialCityGeoJson;
      _appliedSelectedCityGeoJson = initialSelectedCityGeoJson;

      // ---------------------------------------------------------------------
      // 10. Initialization complete
      // ---------------------------------------------------------------------

      setState(() {
        _layersReady = true;
        _error = null;
      });

      // Apply any changes received while the style was initializing.
      unawaited(_synchronizeHighlights());
      unawaited(_synchronizeSelection());
      unawaited(_synchronizeCities());
      unawaited(_synchronizeSelectedCity());
    } catch (error, stackTrace) {
      if (!_isCurrentStyle(style, generation)) return;

      debugPrint('TravelMap: unable to initialize layers: $error');
      debugPrintStack(stackTrace: stackTrace);

      setState(() {
        _error = error;
      });
    } finally {
      _layersInitializing = false;

      // A newer style may have loaded while the previous style
      // was still initializing. Initialize the new style instead.
      if (mounted &&
          generation != _styleGeneration &&
          _styleController != null &&
          !_layersReady &&
          _error == null) {
        unawaited(_initializeLayers());
      }
    }
  }

  @override
  void didUpdateWidget(covariant TravelMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextCityGeoJson = buildMapCityGeoJson(cities: widget.cities);

    if (nextCityGeoJson != _cityGeoJson) {
      _cityGeoJson = nextCityGeoJson;

      unawaited(_synchronizeCities());
    }
    final nextSelectedCityGeoJson = buildMapCityGeoJson(
      cities: [if (widget.selectedCity != null) widget.selectedCity!],
    );

    if (nextSelectedCityGeoJson != _selectedCityGeoJson) {
      _selectedCityGeoJson = nextSelectedCityGeoJson;

      unawaited(_synchronizeSelectedCity());
    }

    final worldGeoJson = _worldGeoJson;

    if (worldGeoJson == null) return;

    if (!setEquals(
      oldWidget.highlightedCountryCodes,
      widget.highlightedCountryCodes,
    )) {
      _highlightGeoJson = buildMapCountryHighlightGeoJson(
        worldGeoJson: worldGeoJson,
        countryCodes: widget.highlightedCountryCodes,
      );

      unawaited(_synchronizeHighlights());
    }

    if (oldWidget.selectedCountryCode != widget.selectedCountryCode) {
      final selectedCode = widget.selectedCountryCode;

      _selectionGeoJson = buildMapCountryHighlightGeoJson(
        worldGeoJson: worldGeoJson,
        countryCodes: selectedCode == null ? const <String>{} : {selectedCode},
      );

      unawaited(_synchronizeSelection());
    }
  }

  Future<void> _synchronizeSelection() async {
    if (_selectionUpdating || !_layersReady) return;

    final style = _styleController;

    if (style == null) return;

    _selectionUpdating = true;

    final generation = _styleGeneration;

    try {
      while (_isCurrentStyle(style, generation) && _layersReady) {
        final desiredGeoJson = _selectionGeoJson;

        if (desiredGeoJson == null ||
            desiredGeoJson == _appliedSelectionGeoJson) {
          break;
        }

        await style.updateGeoJsonSource(
          id: _selectionSourceId,
          data: desiredGeoJson,
        );

        if (!_isCurrentStyle(style, generation)) break;

        _appliedSelectionGeoJson = desiredGeoJson;
      }
    } catch (error, stackTrace) {
      if (_isCurrentStyle(style, generation)) {
        debugPrint('TravelMap: unable to update selection: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _selectionUpdating = false;

      // A previous style update must not block the replacement style.
      if (mounted &&
          generation != _styleGeneration &&
          _layersReady &&
          _styleController != null) {
        unawaited(_synchronizeSelection());
      }
    }
  }

  Future<void> _synchronizeCities() async {
    if (_cityUpdating || !_layersReady) {
      return;
    }

    final style = _styleController;

    if (style == null) {
      return;
    }

    _cityUpdating = true;

    final generation = _styleGeneration;

    try {
      while (_isCurrentStyle(style, generation) && _layersReady) {
        final desiredGeoJson = _cityGeoJson;

        if (desiredGeoJson == _appliedCityGeoJson) {
          break;
        }

        await style.updateGeoJsonSource(
          id: _citySourceId,
          data: desiredGeoJson,
        );

        if (!_isCurrentStyle(style, generation)) {
          break;
        }

        _appliedCityGeoJson = desiredGeoJson;
      }
    } catch (error, stackTrace) {
      if (_isCurrentStyle(style, generation)) {
        debugPrint('TravelMap: unable to update cities: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _cityUpdating = false;

      // Ensure a replacement style can receive the latest city data
      // after an asynchronous update from the previous style finishes.
      if (mounted &&
          generation != _styleGeneration &&
          _layersReady &&
          _styleController != null) {
        unawaited(_synchronizeCities());
      }
    }
  }

  Future<void> _synchronizeSelectedCity() async {
    if (_selectedCityUpdating || !_layersReady) {
      return;
    }

    final style = _styleController;

    if (style == null) {
      return;
    }

    _selectedCityUpdating = true;

    final generation = _styleGeneration;

    try {
      while (_isCurrentStyle(style, generation) && _layersReady) {
        final desiredGeoJson = _selectedCityGeoJson;

        if (desiredGeoJson == _appliedSelectedCityGeoJson) {
          break;
        }

        await style.updateGeoJsonSource(
          id: _selectedCitySourceId,
          data: desiredGeoJson,
        );

        if (!_isCurrentStyle(style, generation)) {
          break;
        }

        _appliedSelectedCityGeoJson = desiredGeoJson;
      }
    } catch (error, stackTrace) {
      if (_isCurrentStyle(style, generation)) {
        debugPrint('TravelMap: unable to update selected city: $error');

        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _selectedCityUpdating = false;

      // A stale update must not prevent the replacement style
      // from receiving the latest selected city.
      if (mounted &&
          generation != _styleGeneration &&
          _layersReady &&
          _styleController != null) {
        unawaited(_synchronizeSelectedCity());
      }
    }
  }

  Future<void> _synchronizeHighlights() async {
    if (_highlightUpdating || !_layersReady) {
      return;
    }

    final style = _styleController;

    if (style == null) {
      return;
    }

    _highlightUpdating = true;

    final generation = _styleGeneration;

    try {
      while (_isCurrentStyle(style, generation) && _layersReady) {
        final desiredGeoJson = _highlightGeoJson;

        if (desiredGeoJson == null ||
            desiredGeoJson == _appliedHighlightGeoJson) {
          break;
        }

        await style.updateGeoJsonSource(
          id: _highlightSourceId,
          data: desiredGeoJson,
        );

        if (!_isCurrentStyle(style, generation)) {
          break;
        }

        _appliedHighlightGeoJson = desiredGeoJson;
      }
    } catch (error, stackTrace) {
      // An older style can disappear while a native update is in progress.
      // Only report failures affecting the currently active style.
      if (_isCurrentStyle(style, generation)) {
        debugPrint('TravelMap: unable to update highlights: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      _highlightUpdating = false;

      // If the style was replaced while an update was running,
      // initialization of the new style will restore the highlights.
    }
  }

  void _onMapClick(MapEventClick event) {
    if (!_layersReady) {
      return;
    }

    final controller = _mapController;

    if (controller == null) {
      return;
    }

    // ---------------------------------------------------------
    // 1. City markers have priority over country polygons.
    // ---------------------------------------------------------

    final cityFeatures = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: [_selectedCityCircleLayerId, _cityCircleLayerId],
    );

    for (final feature in cityFeatures) {
      final cityId = feature.properties['city_id'];

      if (cityId is int && cityId > 0) {
        widget.onCitySelected?.call(cityId);
        return;
      }

      // Defensive handling for numeric values decoded as doubles.
      if (cityId is num && cityId > 0 && cityId % 1 == 0) {
        widget.onCitySelected?.call(cityId.toInt());
        return;
      }
    }

    // ---------------------------------------------------------
    // 2. Fall back to country selection.
    // ---------------------------------------------------------

    final countryFeatures = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: [_countryFillLayerId],
    );

    if (countryFeatures.isEmpty) {
      widget.onCountrySelected?.call(null);
      return;
    }

    final countryCode = countryFeatures.first.properties['country_code'];

    if (countryCode is String && countryCode.isNotEmpty) {
      widget.onCountrySelected?.call(countryCode);

      unawaited(
        _focusCountry(
          countryCode: countryCode,
          tappedLatitude: event.point.lat,
          tappedLongitude: event.point.lon,
        ),
      );
    } else {
      widget.onCountrySelected?.call(null);
    }
  }

  Future<void> _focusCountry({
    required String countryCode,
    required double tappedLatitude,
    required double tappedLongitude,
  }) async {
    final controller = _mapController;
    final worldGeoJson = _worldGeoJson;

    if (controller == null || worldGeoJson == null || !_layersReady) {
      return;
    }

    try {
      final countryGeoJson = buildMapCountryHighlightGeoJson(
        worldGeoJson: worldGeoJson,
        countryCodes: {countryCode},
      );

      final bounds = calculateCountryCameraBounds(
        countryGeoJson: countryGeoJson,
        tappedLatitude: tappedLatitude,
        tappedLongitude: tappedLongitude,
      );

      if (bounds == null || !mounted) return;

      final size = context.size;

      if (size == null) return;

      final padding = calculateCountryFocusPadding(
        viewportSize: size,
        topSafeArea: MediaQuery.paddingOf(context).top,
      );

      final target = calculateMapCameraTarget(
        bounds: bounds,
        viewportSize: size,
        padding: padding,
        maxZoom: 5.0,
      );

      await controller.animateCamera(
        center: target.center,
        zoom: target.zoom - 0.35,
        nativeDuration: const Duration(milliseconds: 1400),
      );
    } catch (error, stackTrace) {
      debugPrint('TravelMap: unable to focus country: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_error != null) {
      return Center(
        child: Text(
          'Unable to load world map',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
      );
    }

    if (_worldGeoJson == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = calculateWorldMapViewport(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );

        return Stack(
          children: [
            MapLibreMap(
              options: MapOptions(
                initStyle: _currentStyle!,
                initCenter: Geographic(
                  lon: viewport.longitude,
                  lat: viewport.latitude,
                ),
                initZoom: viewport.zoom,
                minZoom: 1.0,
                initPitch: 0,
                initBearing: 0,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoaded: _onStyleLoaded,
              onEvent: (event) {
                if (event is MapEventClick) {
                  _onMapClick(event);
                }
              },
              layers: const [],
            ),

            if (!_layersReady)
              const Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        );
      },
    );
  }
}
