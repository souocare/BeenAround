import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../data/country_geojson_parser.dart';
import '../../data/country_geometry_repository.dart';
import '../../data/world_geojson_repository.dart';
import '../../domain/country_geometry_bounds.dart';
import '../../domain/country_map_viewport.dart';
import 'country_map_style.dart';

class CountryMap extends StatefulWidget {
  const CountryMap({
    required this.countryCode,
    required this.isVisited,
    this.repository,
    this.worldRepository,
    super.key,
  });

  final String countryCode;
  final bool isVisited;

  final CountryGeometryRepository? repository;
  final WorldGeoJsonRepository? worldRepository;

  @override
  State<CountryMap> createState() => _CountryMapState();
}

class _CountryMapState extends State<CountryMap> {
  // ---------------------------------------------------------------------------
  // Sources
  // ---------------------------------------------------------------------------

  static const _worldSourceId = 'country-details-world-source';
  static const _countrySourceId = 'country-details-country-source';

  // ---------------------------------------------------------------------------
  // Layers
  // ---------------------------------------------------------------------------

  static const _worldFillLayerId = 'country-details-world-fill';
  static const _worldBorderLayerId = 'country-details-world-border';

  static const _countryFillLayerId = 'country-details-country-fill';
  static const _countryBorderLayerId = 'country-details-country-border';

  // ---------------------------------------------------------------------------
  // Repositories
  // ---------------------------------------------------------------------------

  late CountryGeometryRepository _repository;
  late WorldGeoJsonRepository _worldRepository;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  String? _countryGeoJson;
  String? _worldGeoJson;

  Object? _error;

  bool _layersReady = false;
  bool _layersInitializing = false;

  StyleController? _styleController;
  MapController? _mapController;

  void _onMapCreated(MapController controller) {
    _mapController = controller;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    _repository = widget.repository ?? CountryGeometryRepository();
    _worldRepository = widget.worldRepository ?? WorldGeoJsonRepository();

    _loadGeometries();
  }

  @override
  void didUpdateWidget(covariant CountryMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.countryCode != widget.countryCode) {
      _countryGeoJson = null;
      _error = null;

      _layersReady = false;
      _layersInitializing = false;
      _styleController = null;
      _mapController = null;

      _loadGeometries();
    }
  }

  // ---------------------------------------------------------------------------
  // Geometry loading
  // ---------------------------------------------------------------------------

  Future<void> _loadGeometries() async {
    final requestedCountryCode = widget.countryCode;

    try {
      final countryGeoJson = await _repository.load(requestedCountryCode);
      final worldGeoJson = await _worldRepository.load();

      if (!mounted || widget.countryCode != requestedCountryCode) {
        return;
      }

      setState(() {
        _countryGeoJson = countryGeoJson;
        _worldGeoJson = worldGeoJson;
        _error = null;
      });

      await _initializeLayers();
    } catch (error) {
      if (!mounted || widget.countryCode != requestedCountryCode) {
        return;
      }

      setState(() {
        _error = error;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // MapLibre lifecycle
  // ---------------------------------------------------------------------------

  Future<void> _onStyleLoaded(StyleController style) async {
    _styleController = style;
    await _initializeLayers();
  }

  // ---------------------------------------------------------------------------
  // Layer initialization
  // ---------------------------------------------------------------------------

  Future<void> _recenterMap(CountryMapViewport viewport) async {
    final controller = _mapController;

    if (controller == null) return;

    try {
      await controller.animateCamera(
        center: Geographic(lon: viewport.longitude, lat: viewport.latitude),
        zoom: viewport.zoom,
        bearing: 0,
        pitch: 0,
        nativeDuration: const Duration(milliseconds: 650),
      );
    } catch (error) {
      debugPrint('CountryMap: unable to recenter map: $error');
    }
  }

  Future<void> _initializeLayers() async {
    if (_layersReady ||
        _layersInitializing ||
        _countryGeoJson == null ||
        _worldGeoJson == null) {
      return;
    }

    final style = _styleController;

    if (style == null) return;

    _layersInitializing = true;

    final colors = Theme.of(context).colorScheme;

    final worldFillColor = CountryMapStyle.colorToHex(
      colors.surfaceContainerHighest,
    );

    final selectedFillColor = CountryMapStyle.colorToHex(
      widget.isVisited ? colors.primary : colors.surfaceContainerHighest,
    );

    final borderColor = CountryMapStyle.colorToHex(colors.outlineVariant);

    try {
      // ---------------------------------------------------------------------
      // 1. World context
      // ---------------------------------------------------------------------

      await style.addSource(
        GeoJsonSource(id: _worldSourceId, data: _worldGeoJson!),
      );

      await style.addLayer(
        FillStyleLayer(
          id: _worldFillLayerId,
          sourceId: _worldSourceId,
          paint: {'fill-color': worldFillColor, 'fill-opacity': 1.0},
        ),
      );

      await style.addLayer(
        LineStyleLayer(
          id: _worldBorderLayerId,
          sourceId: _worldSourceId,
          paint: {'line-color': borderColor, 'line-width': 0.8},
        ),
        aboveLayerId: _worldFillLayerId,
      );

      // ---------------------------------------------------------------------
      // 2. Selected country
      // ---------------------------------------------------------------------

      await style.addSource(
        GeoJsonSource(id: _countrySourceId, data: _countryGeoJson!),
      );

      await style.addLayer(
        FillStyleLayer(
          id: _countryFillLayerId,
          sourceId: _countrySourceId,
          paint: {'fill-color': selectedFillColor, 'fill-opacity': 1.0},
        ),
        aboveLayerId: _worldBorderLayerId,
      );

      await style.addLayer(
        LineStyleLayer(
          id: _countryBorderLayerId,
          sourceId: _countrySourceId,
          paint: {'line-color': borderColor, 'line-width': 1.2},
        ),
        aboveLayerId: _countryFillLayerId,
      );

      if (!mounted) return;

      setState(() {
        _layersReady = true;
        _error = null;
      });
    } catch (error, stackTrace) {
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = error;
      });
    } finally {
      _layersInitializing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final mapStyle = CountryMapStyle.build(colors);

    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (_error != null) {
              return const _MapMessage(
                icon: Icons.error_outline,
                message: 'Unable to load country map',
              );
            }

            final countryGeoJson = _countryGeoJson;
            final worldGeoJson = _worldGeoJson;

            if (countryGeoJson == null || worldGeoJson == null) {
              return const _MapMessage(
                icon: Icons.public,
                message: 'Loading country map...',
              );
            }

            final geometry = const CountryGeoJsonParser().parse(countryGeoJson);

            final bounds = calculateCountryBounds(geometry);

            if (bounds == null) {
              return const _MapMessage(
                icon: Icons.map_outlined,
                message: 'Country geometry unavailable',
              );
            }

            final viewport = calculateCountryMapViewport(
              bounds: bounds,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            );

            return Stack(
              children: [
                MapLibreMap(
                  key: ValueKey(widget.countryCode),
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  options: MapOptions(
                    initStyle: mapStyle,
                    initCenter: Geographic(
                      lon: viewport.longitude,
                      lat: viewport.latitude,
                    ),
                    initZoom: viewport.zoom,
                    initPitch: 0,
                    initBearing: 0,
                  ),
                  onStyleLoaded: _onStyleLoaded,
                  onMapCreated: _onMapCreated,
                  layers: const [],
                ),

                if (!_layersReady)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (_layersReady)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: colors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(
                        key: const Key('countryMapRecenterButton'),
                        tooltip: 'Recenter country map',
                        icon: Icon(
                          Icons.center_focus_strong_rounded,
                          color: colors.onSurface,
                          size: 20,
                        ),
                        onPressed: () => _recenterMap(viewport),
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

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colors.surfaceContainer,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: colors.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(message, style: TextStyle(color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
