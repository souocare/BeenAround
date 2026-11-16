import 'dart:async';

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../data/world_geojson_repository.dart';
import '../../domain/world_map_viewport.dart';
import 'country_map_style.dart';

class TravelMap extends StatefulWidget {
  const TravelMap({this.worldRepository, super.key});

  final WorldGeoJsonRepository? worldRepository;

  @override
  State<TravelMap> createState() => _TravelMapState();
}

class _TravelMapState extends State<TravelMap> {
  // ---------------------------------------------------------------------------
  // Source IDs
  // ---------------------------------------------------------------------------

  static const _worldSourceId = 'travel-map-world-source';

  // ---------------------------------------------------------------------------
  // Layer IDs
  // ---------------------------------------------------------------------------

  static const _countryFillLayerId = 'travel-map-country-fill';
  static const _countryBorderLayerId = 'travel-map-country-border';

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  late final WorldGeoJsonRepository _repository;

  String? _worldGeoJson;
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

    _repository = widget.worldRepository ?? WorldGeoJsonRepository();

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

      setState(() {
        _worldGeoJson = geoJson;
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
      // 2. Country fills
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
      // 3. Country borders
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
        aboveLayerId: _countryFillLayerId,
      );

      if (!_isCurrentStyle(style, generation)) return;

      setState(() {
        _layersReady = true;
        _error = null;
      });
    } catch (error, stackTrace) {
      if (!_isCurrentStyle(style, generation)) return;

      debugPrint('TravelMap: unable to initialize layers: $error');
      debugPrintStack(stackTrace: stackTrace);

      setState(() {
        _error = error;
      });
    } finally {
      _layersInitializing = false;

      // A new style may have finished loading while the previous style
      // was still initializing. Initialize that newer style now.
      if (mounted &&
          generation != _styleGeneration &&
          _styleController != null &&
          !_layersReady &&
          _error == null) {
        unawaited(_initializeLayers());
      }
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
