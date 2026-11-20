import 'package:flutter/material.dart';

import '../../../../app/widgets/country_flag.dart';
import '../../domain/map_airport_data.dart';
import '../../domain/map_search_destination.dart';
import 'map_context_panel_shell.dart';
import '../../application/map_state.dart';

/// Contextual information panel for a selected airport.
///
/// The airport identity comes from the geographic catalog.
///
/// Personal completed-flight statistics are optional because
/// an airport may be selected without belonging to the user's
/// recorded flight history.
///
/// This widget is read-only and independent of MapLibre.
class MapAirportPanel extends StatelessWidget {
  const MapAirportPanel({
    required this.destination,
    required this.onClose,
    this.airport,
    this.airportPhase = MapAirportPhase.ready,
    this.airportErrorMessage,
    this.compactRequestId = 0,
    this.panelScrollController,
    this.showDragHandle = true,
    super.key,
  });

  /// Selected geographic airport.
  final MapSearchDestination destination;

  /// Personal flight projection for this airport.
  ///
  /// Null means the airport is not represented in the loaded
  /// completed-flight projection.
  final MapAirportData? airport;

  final VoidCallback onClose;

  /// Requests compaction of the shared responsive panel.
  final int compactRequestId;

  /// Loading state of the authenticated user's airport projection.
  ///
  /// An absent airport must only be considered unused when
  /// the projection has finished loading successfully.
  final MapAirportPhase airportPhase;

  /// Optional failure message from the airport projection.
  final String? airportErrorMessage;

  /// Optional controller provided by a shared panel shell.
  final ScrollController? panelScrollController;

  /// Controls the drag handle in embedded mode.
  final bool showDragHandle;

  bool get _hasRecordedFlights =>
      airportPhase == MapAirportPhase.ready &&
      airport != null &&
      airport!.flightCount > 0;

  String get _airportCode {
    final code = destination.airportCode ?? airport?.code;

    if (code != null && code.trim().isNotEmpty) {
      return code.trim();
    }

    return destination.title;
  }

  String? get _location {
    final location = destination.airportLocation;

    if (location != null && location.trim().isNotEmpty) {
      return location.trim();
    }

    final subtitle = destination.subtitle.trim();

    if (subtitle.isNotEmpty && subtitle != _airportCode) {
      return subtitle;
    }

    return null;
  }

  String? get _countryCode {
    final code = destination.countryCode ?? airport?.countryCode;

    if (code == null || code.trim().isEmpty) {
      return null;
    }

    return code.trim().toUpperCase();
  }

  // ---------------------------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    assert(
      destination.type == MapSearchDestinationType.airport,
      'MapAirportPanel requires an airport destination.',
    );

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

  // ---------------------------------------------------------------------------
  // Airport content
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Loading state
  // ---------------------------------------------------------------------------

  Widget _buildLoadingState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('mapAirportPanelLoading'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircularProgressIndicator.adaptive(),

          const SizedBox(height: 16),

          Text(
            'Loading flight history...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Failure state
  // ---------------------------------------------------------------------------

  Widget _buildFailureState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('mapAirportPanelFailure'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error, size: 26),

          const SizedBox(height: 12),

          Text(
            'Unable to load flight history',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            airportErrorMessage ?? 'Your recorded flights could not be loaded.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---------------------------------------------------------
                // Drag handle
                // ---------------------------------------------------------
                if (showDragHandle) ...[
                  Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.onSurfaceVariant.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ] else
                  const SizedBox(height: 10),

                // ---------------------------------------------------------
                // Airport header
                // ---------------------------------------------------------
                _buildHeader(context),

                const SizedBox(height: 20),

                // ---------------------------------------------------------
                // Recorded-flight status
                // ---------------------------------------------------------
                // ---------------------------------------------------------
                // Airport flight-history state
                // ---------------------------------------------------------
                if (airportPhase == MapAirportPhase.initial ||
                    airportPhase == MapAirportPhase.loading) ...[
                  _buildLoadingState(context),
                ] else if (airportPhase == MapAirportPhase.failure) ...[
                  _buildFailureState(context),
                ] else ...[
                  // -------------------------------------------------------
                  // Flight projection is ready
                  // -------------------------------------------------------
                  _buildStatusBadge(context),

                  const SizedBox(height: 24),

                  if (_hasRecordedFlights)
                    _buildStatistics(context)
                  else
                    _buildEmptyState(context),

                  if (_hasRecordedFlights) ...[
                    const SizedBox(height: 24),

                    Text(
                      'Flight history',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      '${airport!.flightCount} completed '
                      '${airport!.flightCount == 1 ? 'flight' : 'flights'} '
                      'recorded for this airport.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Airport header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final countryCode = _countryCode;
    final location = _location;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.flight_rounded, color: colors.primary, size: 26),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _airportCode,
                key: const Key('mapAirportPanelCode'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),

              const SizedBox(height: 4),

              if (destination.title != _airportCode) ...[
                Text(
                  destination.title,
                  key: const Key('mapAirportPanelName'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),
              ],

              if (countryCode != null || location != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (countryCode != null) ...[
                      CountryFlag(
                        countryCode: countryCode,
                        size: 22,
                        showBackground: false,
                      ),

                      const SizedBox(width: 8),
                    ],

                    if (location != null)
                      Expanded(
                        child: Text(
                          location,
                          key: const Key('mapAirportPanelLocation'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),

        IconButton(
          key: const Key('mapAirportPanelClose'),
          tooltip: 'Close airport panel',
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Status badge
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // Status badge
  // ---------------------------------------------------------------------------

  Widget _buildStatusBadge(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isUsed = _hasRecordedFlights;

    final color = isUsed ? colors.primary : colors.onSurfaceVariant;

    return Container(
      key: const Key('mapAirportPanelStatus'),
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isUsed ? Icons.check_circle_outline_rounded : Icons.flight_outlined,
            size: 16,
            color: color,
          ),

          const SizedBox(width: 8),

          Flexible(
            child: Text(
              isUsed ? 'Used in flight history' : 'Not in flight history',
              softWrap: true,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Flight statistics
  // ---------------------------------------------------------------------------

  Widget _buildStatistics(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = airport!;

    return Container(
      key: const Key('mapAirportPanelStatistics'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AirportStatistic(
              value: '${data.flightCount}',
              label: 'Flights',
            ),
          ),

          _buildDivider(colors),

          Expanded(
            child: _AirportStatistic(
              value: '${data.departureCount}',
              label: 'Departures',
            ),
          ),

          _buildDivider(colors),

          Expanded(
            child: _AirportStatistic(
              value: '${data.arrivalCount}',
              label: 'Arrivals',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(ColorScheme colors) {
    return Container(width: 1, height: 42, color: colors.outlineVariant);
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      key: const Key('mapAirportPanelEmpty'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.flight_outlined, color: colors.onSurfaceVariant, size: 26),

          const SizedBox(height: 12),

          Text(
            'No flights recorded',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "This airport isn't part of your completed flight "
            'history yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Airport statistic
// -----------------------------------------------------------------------------

class _AirportStatistic extends StatelessWidget {
  const _AirportStatistic({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
