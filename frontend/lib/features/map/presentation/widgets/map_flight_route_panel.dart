import 'package:flutter/material.dart';

import '../../domain/map_airport_data.dart';
import '../../domain/map_flight_route.dart';

import 'map_context_panel_shell.dart';

/// Read-only contextual information for one completed-flight
/// connection between two airports.
///
/// Multiple completed flights between the same airports share
/// one geographic connection.
///
/// Flight direction and local departure dates are preserved.
///
/// This widget does not perform repository requests, modify
/// flight records or interact directly with MapLibre.
class MapFlightRoutePanel extends StatelessWidget {
  const MapFlightRoutePanel({
    required this.route,
    required this.onClose,
    this.firstAirport,
    this.secondAirport,
    this.compactRequestId = 0,
    this.panelScrollController,
    this.showDragHandle = true,
    super.key,
  });

  final MapFlightRoute route;

  final MapAirportData? firstAirport;
  final MapAirportData? secondAirport;

  final VoidCallback onClose;

  final int compactRequestId;

  final ScrollController? panelScrollController;

  final bool showDragHandle;

  // ---------------------------------------------------------------------------
  // Airport identity
  // ---------------------------------------------------------------------------

  String _airportCode(int airportId) {
    final airport = airportId == route.firstAirportId
        ? firstAirport
        : airportId == route.secondAirportId
        ? secondAirport
        : null;

    final code = airport?.code.trim();

    if (code != null && code.isNotEmpty) {
      return code;
    }

    return 'Airport $airportId';
  }

  String _airportName(MapAirportData? airport) {
    final name = airport?.name.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    return 'Airport information unavailable';
  }

  // ---------------------------------------------------------------------------
  // Flight presentation
  // ---------------------------------------------------------------------------

  String _formatDepartureDate(String? departureOn) {
    if (departureOn == null || departureOn.trim().isEmpty) {
      return 'Date unavailable';
    }

    final parts = departureOn.split('-');

    if (parts.length != 3) {
      return departureOn;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null ||
        month == null ||
        day == null ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return departureOn;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '$day ${months[month - 1]} $year';
  }

  // ---------------------------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final externalController = panelScrollController;

    if (externalController != null) {
      return _buildContent(
        context,
        scrollController: externalController,
        showDragHandle: showDragHandle,
      );
    }

    return MapContextPanelShell(
      compactRequestId: compactRequestId,
      onClose: onClose,
      contentBuilder: (context, scrollController, showDragHandle) {
        return _buildContent(
          context,
          scrollController: scrollController,
          showDragHandle: showDragHandle,
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required ScrollController scrollController,
    required bool showDragHandle,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CustomScrollView(
      key: const Key('mapFlightRoutePanelScrollView'),
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // -----------------------------------------------------------
                // Drag handle
                // -----------------------------------------------------------
                if (showDragHandle) ...[
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // -----------------------------------------------------------
                // Header
                // -----------------------------------------------------------
                Row(
                  children: [
                    Icon(Icons.route_rounded, size: 19, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'FLIGHT ROUTE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('mapFlightRoutePanelClose'),
                      onPressed: onClose,
                      tooltip: 'Close route',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // -----------------------------------------------------------
                // Route identity
                // -----------------------------------------------------------
                Text(
                  '${_airportCode(route.firstAirportId)} ↔ '
                  '${_airportCode(route.secondAirportId)}',
                  key: const Key('mapFlightRoutePanelTitle'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  '${_airportName(firstAirport)} · '
                  '${_airportName(secondAirport)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 22),

                // -----------------------------------------------------------
                // Completed-flight summary
                // -----------------------------------------------------------
                Container(
                  key: const Key('mapFlightRoutePanelSummary'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.flight_takeoff_rounded,
                        color: colors.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${route.flightCount}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              route.flightCount == 1
                                  ? 'Completed flight'
                                  : 'Completed flights',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // -----------------------------------------------------------
                // Flight history heading
                // -----------------------------------------------------------
                Text(
                  'FLIGHT HISTORY',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // -------------------------------------------------------------------
        // Individual flights
        //
        // Flights are already ordered newest-first by the
        // application projection.
        // -------------------------------------------------------------------
        SliverList.builder(
          itemCount: route.flights.length,
          itemBuilder: (context, index) {
            final flight = route.flights[index];

            return _buildFlightTile(context, flight);
          },
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 28)),
      ],
    );
  }

  Widget _buildFlightTile(BuildContext context, MapFlightRouteFlight flight) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final departureCode = _airportCode(flight.departureAirportId);

    final arrivalCode = _airportCode(flight.arrivalAirportId);

    final flightNumber = flight.flightNumber?.trim();
    final airlineName = flight.airlineName?.trim();

    return Padding(
      key: ValueKey('mapFlightRouteFlight:${flight.flightId}'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.flight_rounded, size: 21, color: colors.primary),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$departureCode → $arrivalCode',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _formatDepartureDate(flight.departureOn),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),

                  if (flightNumber != null && flightNumber.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      flightNumber,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],

                  if (airlineName != null && airlineName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      airlineName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
