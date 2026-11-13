import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../../map/presentation/widgets/country_map_style.dart';
import '../../../map/data/world_geojson_repository.dart';
import '../../domain/airport.dart';
import '../../domain/flight_route_geometry.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'flight_route_viewport.dart';

/// MapLibre visualization of a single flight segment.
///
/// The displayed route is a great-circle approximation,
/// not a recorded aircraft track.
///
/// No location history or personal travel records are
/// transmitted to an external aviation service.
class FlightRouteMap extends StatefulWidget {
  const FlightRouteMap({
    required this.departure,
    required this.arrival,
    super.key,
  });

  final Airport? departure;
  final Airport? arrival;

  @override
  State<FlightRouteMap> createState() => _FlightRouteMapState();
}

class _FlightRouteMapState extends State<FlightRouteMap> {
  static const _routeSourceId = 'flight-details-route-source';
  static const _routeLayerId = 'flight-details-route-layer';

  static const _airportSourceId = 'flight-details-airports-source';
  static const _airportLayerId = 'flight-details-airports-layer';

  static const _worldSourceId = 'flight-details-world-source';
  static const _worldFillLayerId = 'flight-details-world-fill';
  static const _worldBorderLayerId = 'flight-details-world-border';

  bool _layersReady = false;
  bool _initializing = false;
  String? _error;
  bool _initialCameraApplied = false;

  Geographic? _targetCenter;
  double? _targetZoom;

  final WorldGeoJsonRepository _worldRepository = WorldGeoJsonRepository();
  String? _worldGeoJson;
  StyleController? _styleController;
  MapController? _mapController;

  bool get _hasCoordinates {
    final departure = widget.departure;
    final arrival = widget.arrival;

    return departure != null &&
        arrival != null &&
        departure.hasCoordinates &&
        arrival.hasCoordinates;
  }

  @override
  void didUpdateWidget(covariant FlightRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.departure != widget.departure ||
        oldWidget.arrival != widget.arrival) {
      _layersReady = false;
      _initializing = false;
      _error = null;

      _styleController = null;
      _mapController = null;
      _initialCameraApplied = false;
      _targetCenter = null;
      _targetZoom = null;
    }
  }

  Future<void> _onStyleLoaded(StyleController style) async {
    _styleController = style;

    await _initializeLayers();
  }

  void _onMapCreated(MapController controller) {
    _mapController = controller;
    _applyInitialCameraIfReady();
  }

  Future<void> _applyInitialCameraIfReady() async {
    if (!mounted || !_layersReady || _initialCameraApplied) {
      return;
    }

    final controller = _mapController;
    final center = _targetCenter;
    final zoom = _targetZoom;

    if (controller == null || center == null || zoom == null) {
      return;
    }

    _initialCameraApplied = true;

    try {
      await controller.animateCamera(
        center: center,
        zoom: zoom,
        bearing: 0,
        pitch: 0,
        nativeDuration: const Duration(milliseconds: 300),
      );
    } catch (error) {
      _initialCameraApplied = false;

      debugPrint('FlightRouteMap: initial camera failed: $error');
    }
  }

  Future<void> _initializeLayers() async {
    if (!mounted ||
        !_hasCoordinates ||
        _worldGeoJson == null ||
        _styleController == null ||
        _layersReady ||
        _initializing) {
      return;
    }

    final style = _styleController!;

    final departure = widget.departure!;
    final arrival = widget.arrival!;

    final route = FlightRouteGeometry.between(departure, arrival);

    if (route.length < 2) {
      setState(() {
        _error = 'Route unavailable';
      });
      return;
    }

    _initializing = true;

    try {
      final colors = Theme.of(context).colorScheme;
      final accent = CountryMapStyle.colorToHex(colors.primary);

      // --------------------------------------------------
      // World geography
      // --------------------------------------------------

      final worldFillColor = CountryMapStyle.colorToHex(
        colors.surfaceContainerHighest,
      );

      final worldBorderColor = CountryMapStyle.colorToHex(
        colors.outlineVariant,
      );

      await style.addSource(
        GeoJsonSource(id: _worldSourceId, data: _worldGeoJson!),
      );

      // Continents and countries.
      await style.addLayer(
        FillStyleLayer(
          id: _worldFillLayerId,
          sourceId: _worldSourceId,
          paint: {'fill-color': worldFillColor, 'fill-opacity': 0.7},
        ),
      );

      // Subtle geographic borders.
      await style.addLayer(
        LineStyleLayer(
          id: _worldBorderLayerId,
          sourceId: _worldSourceId,
          paint: {
            'line-color': worldBorderColor,
            'line-width': 0.65,
            'line-opacity': 0.35,
          },
        ),
        aboveLayerId: _worldFillLayerId,
      );

      // --------------------------------------------------
      // Route geometry
      // --------------------------------------------------
      //
      // Split the route at the antimeridian so MapLibre
      // never draws an artificial line across the map.
      final routeSegments = _splitAtAntimeridian(route);

      final routeGeoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          for (var index = 0; index < routeSegments.length; index++)
            {
              'type': 'Feature',
              'properties': {'segment': index},
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  for (final point in routeSegments[index])
                    [point.longitude, point.latitude],
                ],
              },
            },
        ],
      });

      await style.addSource(
        GeoJsonSource(id: _routeSourceId, data: routeGeoJson),
      );

      await style.addLayer(
        LineStyleLayer(
          id: _routeLayerId,
          sourceId: _routeSourceId,
          paint: {'line-color': accent, 'line-width': 3, 'line-opacity': 0.9},
        ),
        aboveLayerId: _worldBorderLayerId,
      );

      // --------------------------------------------------
      // Airport markers
      // --------------------------------------------------
      final airportGeoJson = jsonEncode({
        'type': 'FeatureCollection',
        'features': [
          for (final airport in [departure, arrival])
            {
              'type': 'Feature',
              'properties': {'code': airport.displayCode, 'name': airport.name},
              'geometry': {
                'type': 'Point',
                'coordinates': [airport.longitude, airport.latitude],
              },
            },
        ],
      });

      await style.addSource(
        GeoJsonSource(id: _airportSourceId, data: airportGeoJson),
      );

      await style.addLayer(
        CircleStyleLayer(
          id: _airportLayerId,
          sourceId: _airportSourceId,
          paint: {
            'circle-radius': 6,
            'circle-color': accent,
            'circle-stroke-color': CountryMapStyle.colorToHex(colors.surface),
            'circle-stroke-width': 2,
          },
        ),
        aboveLayerId: _routeLayerId,
      );

      if (!mounted) return;

      setState(() {
        _layersReady = true;
        _error = null;
      });
      await _applyInitialCameraIfReady();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to display the flight route.';
      });
    } finally {
      _initializing = false;
    }
  }

  ({Geographic center, double zoom}) _routeViewport({
    required double width,
    required double height,
  }) {
    final points = FlightRouteGeometry.between(
      widget.departure!,
      widget.arrival!,
    );

    final viewport = FlightRouteViewportCalculator.calculate(
      points: points,
      width: width,
      height: height,
    );

    if (viewport == null) {
      return (center: const Geographic(lon: 0, lat: 0), zoom: 2.0);
    }

    return (
      center: Geographic(lon: viewport.longitude, lat: viewport.latitude),
      zoom: viewport.zoom,
    );
  }

  Future<void> _recenterMap({
    required Geographic center,
    required double zoom,
  }) async {
    final controller = _mapController;

    if (controller == null) return;

    try {
      await controller.animateCamera(
        center: center,
        zoom: zoom,
        bearing: 0,
        pitch: 0,
        nativeDuration: const Duration(milliseconds: 650),
      );
    } catch (error) {
      debugPrint('FlightRouteMap: unable to recenter map: $error');
    }
  }

  /// Separates route segments that cross ±180° longitude.
  ///
  /// The actual boundary intersection is interpolated so
  /// that both segments meet at opposite sides of the map.
  List<List<FlightRoutePoint>> _splitAtAntimeridian(
    List<FlightRoutePoint> points,
  ) {
    if (points.length < 2) return const [];

    final segments = <List<FlightRoutePoint>>[];
    var current = <FlightRoutePoint>[points.first];

    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final next = points[index];

      final longitudeDelta = next.longitude - previous.longitude;

      if (longitudeDelta.abs() <= 180) {
        current.add(next);
        continue;
      }

      final crossesEastward = longitudeDelta < -180;

      final adjustedLongitude = crossesEastward
          ? next.longitude + 360
          : next.longitude - 360;

      final boundary = crossesEastward ? 180.0 : -180.0;

      final fraction =
          (boundary - previous.longitude) /
          (adjustedLongitude - previous.longitude);

      final latitude =
          previous.latitude + (next.latitude - previous.latitude) * fraction;

      current.add(FlightRoutePoint(latitude: latitude, longitude: boundary));

      segments.add(current);

      current = [
        FlightRoutePoint(latitude: latitude, longitude: -boundary),
        next,
      ];
    }

    segments.add(current);

    return segments;
  }

  /// Initial camera centered on the geographic route.
  ///
  /// This is an approximate viewport. A later refinement
  /// will fit the complete route to the available map size.

  @override
  void initState() {
    super.initState();

    _loadWorldGeometry();
  }

  Future<void> _loadWorldGeometry() async {
    try {
      final geoJson = await _worldRepository.load();

      if (!mounted) return;

      setState(() {
        _worldGeoJson = geoJson;
      });

      await _initializeLayers();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load geographic data.';
      });

      debugPrint('FlightRouteMap: world geometry error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (!_hasCoordinates) {
      return _FlightMapUnavailable(message: 'Airport coordinates unavailable');
    }

    final style = CountryMapStyle.build(colors);

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const mapHeight = 240.0;

          final viewport = _routeViewport(
            width: constraints.maxWidth,
            height: mapHeight,
          );

          _targetCenter = viewport.center;
          _targetZoom = viewport.zoom;

          return SizedBox(
            height: mapHeight,
            child: Stack(
              children: [
                // --------------------------------------------------
                // Interactive geographic map
                // --------------------------------------------------
                MapLibreMap(
                  key: ValueKey(
                    'flight-route-'
                    '${widget.departure!.id}-'
                    '${widget.arrival!.id}',
                  ),
                  options: MapOptions(
                    initStyle: style,
                    initCenter: viewport.center,
                    initZoom: viewport.zoom,
                    initPitch: 0,
                    initBearing: 0,
                  ),
                  onMapCreated: _onMapCreated,
                  onStyleLoaded: _onStyleLoaded,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer(),
                    ),
                  },
                  layers: const [],
                ),

                // --------------------------------------------------
                // Loading
                // --------------------------------------------------
                if (!_layersReady && _error == null)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),

                // --------------------------------------------------
                // Error
                // --------------------------------------------------
                if (_error != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: colors.surfaceContainerLow,
                      child: Center(
                        child: Text(
                          _error!,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),

                // --------------------------------------------------
                // Recenter
                // --------------------------------------------------
                if (_layersReady)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: colors.surface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(
                        key: const Key('flightMapRecenterButton'),
                        tooltip: 'Recenter flight route',
                        icon: Icon(
                          Icons.center_focus_strong_rounded,
                          size: 20,
                          color: colors.onSurface,
                        ),
                        onPressed: () => _recenterMap(
                          center: viewport.center,
                          zoom: viewport.zoom,
                        ),
                      ),
                    ),
                  ),

                // --------------------------------------------------
                // Route identification
                // --------------------------------------------------
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.departure!.displayCode} → '
                        '${widget.arrival!.displayCode}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FlightMapUnavailable extends StatelessWidget {
  const _FlightMapUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.public_off_outlined,
            color: colors.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: colors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
