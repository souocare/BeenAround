import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../data/demo_country_loader.dart';

class MapExperimentPage extends StatefulWidget {
  const MapExperimentPage({super.key});

  @override
  State<MapExperimentPage> createState() => _MapExperimentPageState();
}

class _MapExperimentPageState extends State<MapExperimentPage> {
  static const _demoStyle = 'https://demotiles.maplibre.org/style.json';

  static const _initialOptions = MapOptions(
    initStyle: _demoStyle,
    initCenter: Geographic(lon: 10.0, lat: 48.0),
    initZoom: 3.5,
    initPitch: 0,
    initBearing: 0,
  );

  // ---------------------------------------------------------------------------
  // Source IDs
  // ---------------------------------------------------------------------------

  static const _countrySourceId = 'experiment-countries-source';
  static const _borderSourceId = 'experiment-borders-source';
  static const _flightSourceId = 'experiment-flights-source';
  static const _airportSourceId = 'experiment-airports-source';
  static const _citySourceId = 'experiment-cities-source';

  // ---------------------------------------------------------------------------
  // Layer IDs
  // ---------------------------------------------------------------------------

  static const _countryLayerId = 'experiment-countries-fill';
  static const _borderLayerId = 'experiment-countries-border';
  static const _flightLayerId = 'experiment-flights-line';
  static const _airportLayerId = 'experiment-airports-symbol';
  static const _cityLayerId = 'experiment-cities-symbol';

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  bool _styleLoaded = false;
  bool _countriesLoaded = false;
  bool _layersReady = false;
  bool _layersInitializing = false;

  String? _mapError;

  StyleController? _styleController;

  List<Feature<Polygon>> _visitedCountries = [];
  List<Feature<LineString>> _countryBorders = [];

  // ---------------------------------------------------------------------------
  // Demo cities
  // ---------------------------------------------------------------------------

  static final List<Feature<Point>> _demoCities = [
    Feature<Point>(
      id: 'lisbon',
      geometry: Point.build([-9.1393, 38.7223]),
      properties: {'name': 'Lisbon'},
    ),
    Feature<Point>(
      id: 'barcelona',
      geometry: Point.build([2.1734, 41.3851]),
      properties: {'name': 'Barcelona'},
    ),
    Feature<Point>(
      id: 'london',
      geometry: Point.build([-0.1276, 51.5072]),
      properties: {'name': 'London'},
    ),
  ];

  // ---------------------------------------------------------------------------
  // Demo airports
  // ---------------------------------------------------------------------------

  static final List<Feature<Point>> _demoAirports = [
    Feature<Point>(
      id: 'LIS',
      geometry: Point.build([-9.1359, 38.7813]),
      properties: {'name': 'Lisbon Airport'},
    ),
    Feature<Point>(
      id: 'LHR',
      geometry: Point.build([-0.4543, 51.4700]),
      properties: {'name': 'London Heathrow'},
    ),
  ];

  // ---------------------------------------------------------------------------
  // Demo flights
  // ---------------------------------------------------------------------------

  static final List<Feature<LineString>> _demoFlights = [
    Feature<LineString>(
      id: 'lisbon-london',
      geometry: LineString(
        [-9.1359, 38.7813, -0.4543, 51.4700].positions(Coords.xy),
      ),
      properties: {'name': 'LIS → LHR'},
    ),
  ];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  // ---------------------------------------------------------------------------
  // Load country geometries
  // ---------------------------------------------------------------------------

  Future<void> _loadCountries() async {
    try {
      final countryData = await const DemoCountryLoader().load();

      if (!mounted) return;

      setState(() {
        _visitedCountries = countryData.polygons;
        _countryBorders = countryData.borders;
        _countriesLoaded = true;
        _mapError = null;
      });

      debugPrint(
        'MapLibre experiment: loaded '
        '${countryData.polygons.length} country polygons and '
        '${countryData.borders.length} border lines.',
      );

      await _initializeLayersIfReady();
    } catch (error) {
      _reportError('Failed to load country geometries', error);
    }
  }

  // ---------------------------------------------------------------------------
  // Style loaded
  // ---------------------------------------------------------------------------

  Future<void> _onStyleLoaded(StyleController style) async {
    _styleController = style;

    if (!mounted) return;

    setState(() {
      _styleLoaded = true;
    });

    await _initializeLayersIfReady();
  }

  // ---------------------------------------------------------------------------
  // Initialize map layers
  // ---------------------------------------------------------------------------

  Future<void> _initializeLayersIfReady() async {
    if (!_styleLoaded ||
        !_countriesLoaded ||
        _layersReady ||
        _layersInitializing) {
      return;
    }

    final style = _styleController;

    if (style == null) return;

    _layersInitializing = true;

    try {
      // -----------------------------------------------------------------------
      // 1. Register icons
      // -----------------------------------------------------------------------

      await _registerMapIcons(style);

      // -----------------------------------------------------------------------
      // 2. Country fills
      // -----------------------------------------------------------------------

      await style.addSource(
        GeoJsonSource(
          id: _countrySourceId,
          data: FeatureCollection(_visitedCountries).toText(),
        ),
      );

      await style.addLayer(
        const FillStyleLayer(
          id: _countryLayerId,
          sourceId: _countrySourceId,
          paint: {'fill-color': '#22C55E', 'fill-opacity': 0.6},
        ),
      );

      // -----------------------------------------------------------------------
      // 3. Country borders
      // -----------------------------------------------------------------------

      await style.addSource(
        GeoJsonSource(
          id: _borderSourceId,
          data: FeatureCollection(_countryBorders).toText(),
        ),
      );

      await style.addLayer(
        const LineStyleLayer(
          id: _borderLayerId,
          sourceId: _borderSourceId,
          paint: {'line-color': '#064E3B', 'line-width': 1.5},
        ),
        aboveLayerId: _countryLayerId,
      );

      // -----------------------------------------------------------------------
      // 4. Flight routes
      // -----------------------------------------------------------------------

      await style.addSource(
        GeoJsonSource(
          id: _flightSourceId,
          data: FeatureCollection(_demoFlights).toText(),
        ),
      );

      await style.addLayer(
        const LineStyleLayer(
          id: _flightLayerId,
          sourceId: _flightSourceId,
          paint: {'line-color': '#38BDF8', 'line-width': 3},
        ),
        aboveLayerId: _borderLayerId,
      );

      // -----------------------------------------------------------------------
      // 5. Airports
      // -----------------------------------------------------------------------

      await style.addSource(
        GeoJsonSource(
          id: _airportSourceId,
          data: FeatureCollection(_demoAirports).toText(),
        ),
      );

      await style.addLayer(
        const SymbolStyleLayer(
          id: _airportLayerId,
          sourceId: _airportSourceId,
          minZoom: 6,
          layout: {
            'icon-image': 'airport',
            'icon-size': 0.7,
            'icon-allow-overlap': true,
          },
        ),
        aboveLayerId: _flightLayerId,
      );

      // -----------------------------------------------------------------------
      // 6. Visited cities
      // -----------------------------------------------------------------------

      await style.addSource(
        GeoJsonSource(
          id: _citySourceId,
          data: FeatureCollection(_demoCities).toText(),
        ),
      );

      await style.addLayer(
        const SymbolStyleLayer(
          id: _cityLayerId,
          sourceId: _citySourceId,
          layout: {
            'icon-image': 'visited-city',
            'icon-size': 0.85,
            'icon-anchor': 'bottom',
            'icon-allow-overlap': true,
          },
        ),
        aboveLayerId: _airportLayerId,
      );

      if (!mounted) return;

      setState(() {
        _layersReady = true;
        _mapError = null;
      });

      debugPrint('MapLibre experiment: all layers initialized successfully.');
    } catch (error) {
      _reportError('Failed to initialize map layers', error);
    } finally {
      _layersInitializing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Register map icons
  // ---------------------------------------------------------------------------

  Future<void> _registerMapIcons(StyleController style) async {
    await style.addImageFromIconData(
      id: 'visited-city',
      iconData: Icons.location_on_rounded,
      size: 64,
      color: const Color(0xFF22C55E),
    );

    await style.addImageFromIconData(
      id: 'airport',
      iconData: Icons.flight_rounded,
      size: 48,
      color: const Color(0xFF38BDF8),
    );
  }

  // ---------------------------------------------------------------------------
  // Error handling
  // ---------------------------------------------------------------------------

  void _reportError(String message, Object error) {
    debugPrint('MapLibre experiment: $message: $error');

    if (!mounted) return;

    setState(() {
      _mapError = '$message: $error';
    });
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('MapLibre Experiment')),
      body: Stack(
        children: [
          MapLibreMap(
            options: _initialOptions,
            onStyleLoaded: _onStyleLoaded,

            // All experiment layers are managed through StyleController.
            layers: const [],
          ),

          // -------------------------------------------------------------------
          // Loading indicator
          // -------------------------------------------------------------------
          if (!_layersReady && _mapError == null)
            Positioned(
              top: AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                elevation: 2,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(child: Text('Loading map layers...')),
                    ],
                  ),
                ),
              ),
            ),

          // -------------------------------------------------------------------
          // Success indicator
          // -------------------------------------------------------------------
          if (_layersReady)
            Positioned(
              top: AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                elevation: 2,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline, size: 20),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text('Map layers loaded successfully')),
                    ],
                  ),
                ),
              ),
            ),

          // -------------------------------------------------------------------
          // Country count
          // -------------------------------------------------------------------
          if (_countriesLoaded)
            Positioned(
              bottom: AppSpacing.lg,
              left: AppSpacing.lg,
              child: Material(
                color: colors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.public, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${_visitedCountries.length} country polygons loaded',
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // -------------------------------------------------------------------
          // Error indicator
          // -------------------------------------------------------------------
          if (_mapError != null)
            Positioned(
              bottom: AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Material(
                color: colors.errorContainer,
                borderRadius: BorderRadius.circular(AppRadius.md),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.onErrorContainer),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _mapError!,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
