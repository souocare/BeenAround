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

class TravelMap extends StatefulWidget {
  const TravelMap({
    this.worldRepository,
    this.highlightedCountryCodes = const <String>{},
    this.onCountrySelected,
    this.selectedCountryCode,
    super.key,
  });

  final WorldGeoJsonRepository? worldRepository;

  final Set<String> highlightedCountryCodes;

  /// Reports the tapped country code, or null when tapping outside a country.
  final ValueChanged<String?>? onCountrySelected;
  final String? selectedCountryCode;

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

  // ---------------------------------------------------------------------------
  // Layer IDs
  // ---------------------------------------------------------------------------

  static const _countryFillLayerId = 'travel-map-country-fill';
  static const _countryBorderLayerId = 'travel-map-country-border';
  static const _countryHighlightLayerId = 'travel-map-country-highlight';
  static const _selectionFillLayerId = 'travel-map-selection-fill';
  static const _selectionBorderLayerId = 'travel-map-selection-border';

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  late final WorldGeoJsonRepository _repository;

  String? _worldGeoJson;
  String? _highlightGeoJson;
  String? _appliedHighlightGeoJson;
  String? _selectionGeoJson;
  String? _appliedSelectionGeoJson;

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
      // 4. Neutral country fills
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
      // 5. Highlighted country fills (Visited / Lived / Wishlist)
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
      // 6. Selected country fill
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
      // 7. Country borders
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
      // 8. Selected country border
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
      // 9. Mark sources as synchronized
      // ---------------------------------------------------------------------

      _appliedHighlightGeoJson = initialHighlightGeoJson;
      _appliedSelectionGeoJson = initialSelectionGeoJson;

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

    final features = controller.featuresAtPoint(
      event.screenPoint,
      layerIds: [_countryFillLayerId],
    );

    if (features.isEmpty) {
      widget.onCountrySelected?.call(null);
      return;
    }

    final countryCode = features.first.properties['country_code'];

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
