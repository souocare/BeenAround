import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/api_exception.dart';

import '../../../flights/application/flight_catalog_resolver.dart';

import '../../../flights/domain/airline_repository.dart';
import '../../../flights/domain/airport_repository.dart';
import '../../../flights/domain/flight.dart';
import '../../../flights/domain/flight_repository.dart';
import '../../../../app/widgets/country_flag.dart';

/// Open a picker for existing personal flights.
///
/// Already-associated flights are excluded.
///
/// Returns selected Flight IDs, or null when dismissed.
Future<List<String>?> showTripFlightPicker({
  required BuildContext context,
  required Set<String> excludedFlightIds,
  Future<Flight?> Function()? createFlight,
}) {
  // Capture dependencies before opening a new route.
  final flightRepository = context.read<FlightRepository>();
  final airportRepository = context.read<AirportRepository>();
  final airlineRepository = context.read<AirlineRepository>();

  Widget buildPicker() {
    return _TripFlightPickerDialog(
      flightRepository: flightRepository,
      catalogResolver: FlightCatalogResolver(
        airportRepository: airportRepository,
        airlineRepository: airlineRepository,
      ),
      excludedFlightIds: excludedFlightIds,
      createFlight: createFlight,
    );
  }

  if (MediaQuery.sizeOf(context).width >= 800) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: buildPicker(),
        ),
      ),
    );
  }

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    builder: (_) => SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: buildPicker(),
    ),
  );
}

class _TripFlightPickerDialog extends StatefulWidget {
  const _TripFlightPickerDialog({
    required this.flightRepository,
    required this.catalogResolver,
    required this.excludedFlightIds,
    required this.createFlight,
  });

  final FlightRepository flightRepository;
  final FlightCatalogResolver catalogResolver;
  final Set<String> excludedFlightIds;
  final Future<Flight?> Function()? createFlight;

  @override
  State<_TripFlightPickerDialog> createState() =>
      _TripFlightPickerDialogState();
}

class _TripFlightPickerDialogState extends State<_TripFlightPickerDialog> {
  static const int _pageSize = 50;

  final TextEditingController _searchController = TextEditingController();

  final List<Flight> _flights = [];
  final Set<String> _selectedIds = {};
  final Set<String> _newlyCreatedIds = {};
  bool _isCreatingFlight = false;

  ResolvedFlightCatalog _catalog = ResolvedFlightCatalog(
    airports: const {},
    airlines: const {},
  );

  int _total = 0;
  int _offset = 0;

  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _errorMessage;

  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadNextPage();
  }

  @override
  void dispose() {
    ++_generation;
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasMore => !_hasLoaded || _offset < _total;

  List<Flight> get _availableFlights {
    return _flights
        .where((flight) => !widget.excludedFlightIds.contains(flight.id))
        .toList(growable: false);
  }

  String _airportName(int airportId) {
    final airport = _catalog.airportFor(airportId);

    if (airport == null) {
      return 'Airport $airportId';
    }

    return airport.displayCode;
  }

  String? _airportLocation(int airportId) {
    return _catalog.airportFor(airportId)?.displayLocation;
  }

  Future<void> _createFlight() async {
    final createFlight = widget.createFlight;

    if (createFlight == null || _isCreatingFlight) {
      return;
    }

    setState(() {
      _isCreatingFlight = true;
    });

    try {
      final createdFlight = await createFlight();

      if (!mounted || createdFlight == null) {
        return;
      }

      // A newly created Flight is independent of the Trip.
      //
      // Creating it only updates the picker's local selection.
      // The association is created later, after explicit confirmation.
      setState(() {
        _flights.removeWhere((flight) => flight.id == createdFlight.id);

        _flights.insert(0, createdFlight);

        _selectedIds.add(createdFlight.id);
        _newlyCreatedIds.add(createdFlight.id);

        // Ensure the newly created record is visible.
        _searchController.clear();
      });

      // Catalog resolution is optional presentation metadata.
      // A failure must not discard the new Flight.
      try {
        final catalog = await widget.catalogResolver.resolve(_flights);

        if (!mounted) return;

        setState(() {
          _catalog = catalog;
        });
      } catch (_) {
        // Keep the created Flight selected even if
        // aviation metadata cannot be resolved.
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingFlight = false;
        });
      }
    }
  }

  String _flightTitle(Flight flight) {
    final departure = _airportName(flight.departureAirportId);
    final arrival = _airportName(flight.arrivalAirportId);

    return '$departure → $arrival';
  }

  String _flightSubtitle(Flight flight) {
    final date = DateTime.tryParse(flight.departureOn);

    final dateLabel = date == null
        ? flight.departureOn
        : MaterialLocalizations.of(context).formatMediumDate(date);

    final number = flight.flightNumber;

    if (number == null || number.isEmpty) {
      return dateLabel;
    }

    return '$dateLabel · $number';
  }

  List<Flight> get _filteredFlights {
    final query = _searchController.text.trim().toLowerCase();

    final available = _availableFlights;

    if (query.isEmpty) {
      return available;
    }

    return available
        .where((flight) {
          final airline = _catalog.airlineNameFor(flight) ?? '';

          final departure = _catalog.airportFor(flight.departureAirportId);

          final arrival = _catalog.airportFor(flight.arrivalAirportId);

          final searchable = [
            departure?.displayCode ?? '',
            departure?.name ?? '',
            departure?.displayLocation ?? '',
            arrival?.displayCode ?? '',
            arrival?.name ?? '',
            arrival?.displayLocation ?? '',
            flight.departureOn,
            flight.flightNumber ?? '',
            airline,
            flight.status.apiValue,
          ].join(' ').toLowerCase();

          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  Widget _airportLabel(int airportId) {
    final airport = _catalog.airportFor(airportId);

    final countryCode = airport?.countryCode;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (countryCode != null && countryCode.isNotEmpty) ...[
          CountryFlag(countryCode: countryCode, size: 20),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            _airportName(airportId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || (_hasLoaded && !_hasMore)) {
      return;
    }

    final generation = ++_generation;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await widget.flightRepository.getFlights(
        limit: _pageSize,
        offset: _offset,
      );

      if (!mounted || generation != _generation) return;

      final existingIds = _flights.map((flight) => flight.id).toSet();

      for (final flight in page.items) {
        if (existingIds.add(flight.id)) {
          _flights.add(flight);
        }
      }

      // Offset advances by returned rows, not by deduplicated rows.
      _offset += page.items.length;

      _total = page.items.isEmpty ? _offset : page.total;

      _hasLoaded = true;

      // Resolve catalog metadata without making flight
      // association management depend on its availability.
      final catalog = await widget.catalogResolver.resolve(_flights);

      if (!mounted || generation != _generation) return;

      setState(() {
        _catalog = catalog;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _generation) return;

      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;

      setState(() {
        _errorMessage = 'Unable to load flights.';
        _isLoading = false;
      });
    }
  }

  void _toggleFlight(String flightId) {
    setState(() {
      if (!_selectedIds.add(flightId)) {
        _selectedIds.remove(flightId);
      }
    });
  }

  void _confirm() {
    if (_selectedIds.isEmpty) return;

    Navigator.of(context).pop(_selectedIds.toList(growable: false));
  }

  Widget _buildFlightTile(Flight flight) {
    final selected = _selectedIds.contains(flight.id);
    final isNew = _newlyCreatedIds.contains(flight.id);

    return CheckboxListTile.adaptive(
      key: Key('tripFlightPicker-${flight.id}'),
      value: selected,
      activeColor: Theme.of(context).colorScheme.primary,
      checkColor: Theme.of(context).colorScheme.onPrimary,
      tileColor: Colors.transparent,
      selectedTileColor: Colors.transparent,
      onChanged: (_) => _toggleFlight(flight.id),
      title: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(child: _airportLabel(flight.departureAirportId)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Icon(Icons.arrow_forward, size: 16),
                ),
                Flexible(child: _airportLabel(flight.arrivalAirportId)),
              ],
            ),
          ),
          if (isNew) ...[
            const SizedBox(width: AppSpacing.sm),
            const Badge(label: Text('NEW')),
          ],
        ],
      ),
      subtitle: Text(_flightSubtitle(flight)),
      secondary: const Icon(Icons.flight_outlined),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  Widget _buildList() {
    if (_isLoading && !_hasLoaded && _flights.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(key: Key('tripFlightPickerLoading')),
      );
    }

    final flights = _filteredFlights;

    return ListView(
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  key: const Key('retryTripFlightPicker'),
                  onPressed: _isLoading ? null : _loadNextPage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),

        if (flights.isEmpty && _errorMessage == null)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              _searchController.text.trim().isNotEmpty
                  ? 'No matching flights in the loaded results.'
                  : 'No available flights to associate.',
              key: const Key('tripFlightPickerEmpty'),
              textAlign: TextAlign.center,
            ),
          ),

        for (final flight in flights) _buildFlightTile(flight),

        if (_hasLoaded && _hasMore)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: OutlinedButton.icon(
              key: const Key('tripFlightPickerLoadMore'),
              onPressed: _isLoading ? null : _loadNextPage,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: const Text('Load more flights'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final count = _selectedIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add flights', style: theme.textTheme.headlineSmall),

              const SizedBox(height: AppSpacing.xs),

              Text(
                'Select existing flights to associate with this Trip.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: TextField(
            key: const Key('tripFlightPickerSearch'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search loaded flights',
              border: OutlineInputBorder(),
            ),
          ),
        ),

        Expanded(child: _buildList()),

        if (widget.createFlight != null) ...[
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: OutlinedButton.icon(
              key: const Key('createFlightFromPickerButton'),
              onPressed: _isCreatingFlight ? null : _createFlight,
              icon: Icon(
                _isCreatingFlight
                    ? Icons.hourglass_top_rounded
                    : Icons.add_circle_outline_rounded,
              ),
              label: Text(
                _isCreatingFlight ? 'Creating flight...' : 'Create new flight',
              ),
            ),
          ),
        ],

        const Divider(height: 1),
        const Divider(height: 1),

        SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count == 0
                      ? 'No flights selected'
                      : '$count ${count == 1 ? 'flight' : 'flights'} selected',
                  key: const Key('tripFlightPickerSelectionCount'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isCreatingFlight
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.sm),

                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const Key('confirmTripFlightSelection'),
                        onPressed: count == 0 || _isCreatingFlight
                            ? null
                            : _confirm,
                        child: Text(
                          count == 1 ? 'Add 1 flight' : 'Add $count flights',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
