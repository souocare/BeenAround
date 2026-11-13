import 'package:beenaround/features/flights/presentation/formatters/flight_timing_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/widgets/app_error_state.dart';
import '../../../../app/widgets/app_loading_state.dart';

import '../../application/flight_details_cubit.dart';
import '../../application/flight_details_state.dart';

import '../../domain/airport.dart';
import '../../domain/flight.dart';
import '../../domain/flight_distance.dart';

import '../widgets/airline_avatar.dart';
import '../widgets/flight_route_map.dart';
import '../../domain/flight_timing.dart';
import '../widgets/show_edit_flight.dart';

import '../../../../app/widgets/adaptive_confirmation_dialog.dart';

import '../../application/delete_flight_cubit.dart';
import '../../application/delete_flight_state.dart';
import '../../domain/flight_repository.dart';

/// Details of an authenticated user's personal flight.
///
/// Supports editing and deleting a flight without modifying
/// visits, countries, cities or Trip associations.
class FlightDetailsPage extends StatelessWidget {
  const FlightDetailsPage({
    required this.flightId,
    this.onFlightUpdated,
    super.key,
  });

  final String flightId;

  /// Called after the user successfully updates this flight.
  ///
  /// The parent decides how to refresh its own data.
  final VoidCallback? onFlightUpdated;

  Future<void> _deleteFlight(BuildContext context) async {
    final deleteCubit = context.read<DeleteFlightCubit>();
    final detailsState = context.read<FlightDetailsCubit>().state;

    if (deleteCubit.state.isDeleting ||
        deleteCubit.state.isSuccess ||
        !detailsState.isReady ||
        detailsState.flight?.id != flightId) {
      return;
    }

    final confirmed = await showAdaptiveConfirmationDialog(
      context,
      title: 'Delete flight?',
      message:
          'This flight will be permanently removed from your '
          'travel history. This action cannot be undone.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete Flight',
      isDestructive: true,
    );

    if (!context.mounted || !confirmed) {
      return;
    }

    // The state might have changed while the confirmation
    // dialog was open.
    if (deleteCubit.isClosed ||
        deleteCubit.state.isDeleting ||
        deleteCubit.state.isSuccess) {
      return;
    }

    final deleted = await deleteCubit.deleteFlight(flightId);

    if (!context.mounted || !deleted) {
      return;
    }

    // Return a deletion result to the Flight History.
    Navigator.of(context).pop(true);
  }

  Future<void> _editFlight(
    BuildContext context,
    FlightDetailsState state,
  ) async {
    final flight = state.flight;
    final departure = state.departureAirport;
    final arrival = state.arrivalAirport;
    final airline = state.airline;

    // The edit flow requires resolved catalog metadata.
    //
    // Never initialize an editable form with missing or
    // mismatched airport / catalog airline information.
    if (flight == null ||
        departure?.id != flight.departureAirportId ||
        arrival?.id != flight.arrivalAirportId ||
        (flight.airlineId != null && airline?.id != flight.airlineId)) {
      return;
    }

    // Capture the Cubit before opening the modal route.
    final detailsCubit = context.read<FlightDetailsCubit>();

    final updated = await showEditFlight(
      context,
      flight: flight,
      departureAirport: departure!,
      arrivalAirport: arrival!,
      airline: airline,
    );

    if (!updated || !context.mounted || detailsCubit.isClosed) {
      return;
    }

    // Notify the parent that the persisted flight changed.
    //
    // The Flight History will refresh when the user returns.
    onFlightUpdated?.call();

    // Reload the detail from the backend.
    //
    // This refreshes:
    // - Flight fields.
    // - UTC offsets and duration.
    // - Airport metadata.
    // - Airline metadata.
    // - Route map and geographic distance.
    await detailsCubit.load(flightId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BlocListener<DeleteFlightCubit, DeleteFlightState>(
      listenWhen: (previous, current) =>
          previous.phase != current.phase && current.hasError,

      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.errorMessage ?? 'Unable to delete your flight.',
            ),
          ),
        );
      },

      child: BlocBuilder<DeleteFlightCubit, DeleteFlightState>(
        builder: (context, deleteState) {
          return PopScope<bool>(
            canPop: !deleteState.isDeleting,

            child: Scaffold(
              appBar: AppBar(
                title: const Text('Flight Details'),
                centerTitle: false,
                backgroundColor: colors.surface,
                actions: [
                  BlocBuilder<FlightDetailsCubit, FlightDetailsState>(
                    builder: (context, state) {
                      final flight = state.flight;
                      final isDeleting = context.select(
                        (DeleteFlightCubit cubit) => cubit.state.isDeleting,
                      );

                      final canEdit =
                          !isDeleting &&
                          state.isReady &&
                          flight != null &&
                          state.departureAirport?.id ==
                              flight.departureAirportId &&
                          state.arrivalAirport?.id == flight.arrivalAirportId &&
                          (flight.airlineId == null ||
                              state.airline?.id == flight.airlineId);

                      return IconButton(
                        key: const Key('editFlightButton'),
                        tooltip: canEdit
                            ? 'Edit flight'
                            : 'Flight information must finish loading before editing',
                        onPressed: canEdit
                            ? () => _editFlight(context, state)
                            : null,
                        icon: const Icon(Icons.edit_outlined),
                      );
                    },
                  ),
                  BlocBuilder<DeleteFlightCubit, DeleteFlightState>(
                    builder: (context, deleteState) {
                      final detailsState = context
                          .watch<FlightDetailsCubit>()
                          .state;

                      final canDelete =
                          detailsState.isReady &&
                          detailsState.flight?.id == flightId &&
                          !deleteState.isDeleting &&
                          !deleteState.isSuccess;

                      return IconButton(
                        key: const Key('deleteFlightButton'),
                        tooltip: 'Delete flight',
                        onPressed: canDelete
                            ? () => _deleteFlight(context)
                            : null,
                        icon: deleteState.isDeleting
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              )
                            : Icon(
                                Icons.delete_outline_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                      );
                    },
                  ),
                ],
              ),
              body: BlocBuilder<FlightDetailsCubit, FlightDetailsState>(
                builder: (context, state) {
                  if (state.isLoading ||
                      state.phase == FlightDetailsPhase.initial) {
                    return const AppLoadingState(
                      message: 'Loading flight details...',
                    );
                  }

                  if (state.hasError) {
                    return AppErrorState(
                      title: 'Unable to load flight',
                      message:
                          state.errorMessage ??
                          'Something went wrong while loading this flight.',
                      onRetry: () {
                        context.read<FlightDetailsCubit>().load(flightId);
                      },
                    );
                  }

                  final flight = state.flight;

                  if (flight == null) {
                    return const Center(child: Text('Flight unavailable'));
                  }

                  return _FlightDetailsContent(flight: flight, state: state);
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FlightDetailsContent extends StatelessWidget {
  const _FlightDetailsContent({required this.flight, required this.state});

  final Flight flight;
  final FlightDetailsState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final departure = state.departureAirport;
    final arrival = state.arrivalAirport;

    final distance = FlightDistance.between(departure, arrival);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _FlightDetailsHero(flight: flight, state: state),

        const SizedBox(height: 14),

        // The route map can only be displayed when
        // valid airport coordinates are available.
        FlightRouteMap(departure: departure, arrival: arrival),

        const SizedBox(height: 14),

        _FlightStatistics(
          distanceKm: distance,
          durationMinutes: state.timing?.durationMinutes,
          cabinClass: flight.cabinClass,
        ),

        const SizedBox(height: 24),

        const _FlightSectionTitle('Flight Schedule'),

        const SizedBox(height: 10),

        _FlightScheduleCard(
          flight: flight,
          departure: departure,
          arrival: arrival,
          timing: state.timing,
        ),

        const SizedBox(height: 24),

        const _FlightSectionTitle('Flight Information'),

        const SizedBox(height: 10),

        _FlightInformationCard(flight: flight, airlineName: state.airlineName),

        const SizedBox(height: 24),

        const _FlightSectionTitle('Personal Notes'),

        const SizedBox(height: 10),

        _FlightNotesCard(notes: flight.notes),

        const SizedBox(height: 24),

        Center(
          child: Text(
            'Flight record preserved in your personal archive',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _FlightDetailsHero extends StatelessWidget {
  const _FlightDetailsHero({required this.flight, required this.state});

  final Flight flight;
  final FlightDetailsState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    final departure = state.departureAirport;
    final arrival = state.arrivalAirport;

    final departureCode =
        departure?.displayCode ?? '${flight.departureAirportId}';

    final arrivalCode = arrival?.displayCode ?? '${flight.arrivalAirportId}';

    final airlineName = state.airlineName ?? 'Airline not recorded';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _HeroAirport(
                  code: departureCode,
                  city: _airportCity(departure),
                  alignRight: false,
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.flight_rounded,
                  color: colors.primary,
                  size: 28,
                ),
              ),

              Expanded(
                child: _HeroAirport(
                  code: arrivalCode,
                  city: _airportCity(arrival),
                  alignRight: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              AirlineAvatar(airline: state.airline, size: 32),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      airlineName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (flight.flightNumber?.trim().isNotEmpty == true)
                      Text(
                        flight.flightNumber!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),

              _FlightStatusLabel(status: flight.status),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroAirport extends StatelessWidget {
  const _HeroAirport({
    required this.code,
    required this.city,
    required this.alignRight,
  });

  final String code;
  final String city;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          code,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FlightStatusLabel extends StatelessWidget {
  const _FlightStatusLabel({required this.status});

  final FlightStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final completed = status == FlightStatus.flown;

    final color = completed ? colors.primary : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        completed ? 'Completed' : 'Planned',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

class _FlightStatistics extends StatelessWidget {
  const _FlightStatistics({
    required this.distanceKm,
    required this.durationMinutes,
    required this.cabinClass,
  });

  final double? distanceKm;
  final int? durationMinutes;
  final FlightCabinClass? cabinClass;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatisticValue(
              label: 'DISTANCE',
              value: distanceKm == null ? '—' : '${distanceKm!.round()} km',
            ),
          ),

          Expanded(
            child: _StatisticValue(
              label: 'DURATION',
              value: FlightTimingFormatter.duration(durationMinutes),
            ),
          ),

          Expanded(
            child: _StatisticValue(
              label: 'CABIN',
              value: _cabinLabel(cabinClass),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticValue extends StatelessWidget {
  const _StatisticValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule
// ---------------------------------------------------------------------------

class _FlightScheduleCard extends StatelessWidget {
  const _FlightScheduleCard({
    required this.flight,
    required this.departure,
    required this.arrival,
    required this.timing,
  });

  final Flight flight;

  final Airport? departure;
  final Airport? arrival;

  final FlightTiming? timing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _ScheduleStop(
            icon: Icons.flight_takeoff_rounded,
            code: departure?.displayCode ?? '${flight.departureAirportId}',
            name: departure?.name ?? 'Unknown airport',
            date: flight.departureOn,
            time: flight.departureTime,
            localTime: timing?.departure,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                const SizedBox(width: 17),

                SizedBox(
                  height: 28,
                  child: VerticalDivider(
                    color: colors.primary.withValues(alpha: 0.4),
                    width: 1,
                    thickness: 1,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Text(
                    'Flight segment',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _ScheduleStop(
            icon: Icons.flight_land_rounded,
            code: arrival?.displayCode ?? '${flight.arrivalAirportId}',
            name: arrival?.name ?? 'Unknown airport',
            date: flight.arrivalOn,
            time: flight.arrivalTime,
            localTime: timing?.arrival,
          ),
        ],
      ),
    );
  }
}

class _ScheduleStop extends StatelessWidget {
  const _ScheduleStop({
    required this.icon,
    required this.code,
    required this.name,
    required this.date,
    required this.time,
    required this.localTime,
  });

  final IconData icon;
  final String code;
  final String name;

  final String? date;
  final String? time;

  final FlightLocalTime? localTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final offsetLabel = FlightTimingFormatter.localTimeOffset(localTime);

    final statusDescription = FlightTimingFormatter.statusDescription(
      localTime,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: colors.primary),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                code,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: 5),

              Text(
                date ?? 'Date not recorded',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _displayTime(time),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              offsetLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            if (statusDescription != null &&
                localTime?.status != FlightLocalTimeStatus.unavailable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tooltip(
                  message: statusDescription,
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: colors.tertiary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Flight information
// ---------------------------------------------------------------------------

class _FlightInformationCard extends StatelessWidget {
  const _FlightInformationCard({
    required this.flight,
    required this.airlineName,
  });

  final Flight flight;
  final String? airlineName;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _InformationRow(
            label: 'Airline',
            value: airlineName ?? 'Not recorded',
          ),

          _InformationRow(
            label: 'Flight Number',
            value: flight.flightNumber ?? 'Not recorded',
          ),

          _InformationRow(
            label: 'Cabin Class',
            value: _cabinLabel(flight.cabinClass),
          ),

          _InformationRow(
            label: 'Aircraft',
            value: flight.aircraftType ?? 'Not recorded',
          ),

          _InformationRow(
            label: 'Registration',
            value: flight.aircraftRegistration ?? 'Not recorded',
          ),

          _InformationRow(
            label: 'Seat',
            value: flight.seat ?? 'Not recorded',
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Flexible(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (showDivider)
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notes and section titles
// ---------------------------------------------------------------------------

class _FlightNotesCard extends StatelessWidget {
  const _FlightNotesCard({required this.notes});

  final String? notes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final value = notes?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        value == null || value.isEmpty
            ? 'No notes recorded for this flight.'
            : value,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: value == null || value.isEmpty
              ? colors.onSurfaceVariant
              : colors.onSurface,
        ),
      ),
    );
  }
}

class _FlightSectionTitle extends StatelessWidget {
  const _FlightSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelLarge?.copyWith(
        color: colors.onSurfaceVariant,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Presentation-only formatting
// ---------------------------------------------------------------------------

String _airportCity(Airport? airport) {
  if (airport == null) return 'Unknown airport';

  final municipality = airport.municipality?.trim();

  if (municipality != null && municipality.isNotEmpty) {
    return municipality;
  }

  return airport.displayLocation;
}

String _displayTime(String? value) {
  if (value == null || value.trim().isEmpty) {
    return '—';
  }

  // Preserve the airport's local wall-clock time.
  // The API may include seconds or fractional seconds.
  final parts = value.split(':');

  if (parts.length < 2) {
    return value;
  }

  return '${parts[0]}:${parts[1]}';
}

String _cabinLabel(FlightCabinClass? cabin) {
  return switch (cabin) {
    FlightCabinClass.economy => 'Economy',
    FlightCabinClass.premiumEconomy => 'Premium Economy',
    FlightCabinClass.business => 'Business',
    FlightCabinClass.first => 'First',
    null => '—',
  };
}
