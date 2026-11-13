import 'package:flutter/material.dart';

import '../../../../app/widgets/country_flag.dart';

import '../../domain/airport.dart';
import '../../domain/airline.dart';
import '../../domain/flight.dart';

import 'airline_avatar.dart';

/// Compact visual representation of an independent flight record.
///
/// All aviation catalog metadata is optional.
/// The flight remains displayable when catalog resolution fails.
///
/// This widget does not modify visits, Trips or other travel records.
class FlightCard extends StatelessWidget {
  const FlightCard({
    required this.flight,
    this.departureAirport,
    this.arrivalAirport,
    this.airline,
    this.airlineName,
    super.key,
  });

  final Flight flight;

  final Airport? departureAirport;
  final Airport? arrivalAirport;

  final Airline? airline;

  /// Resolved or manually entered airline name.
  final String? airlineName;

  String _airportCode(Airport? airport, int airportId) {
    return airport?.displayCode ?? '$airportId';
  }

  String _airportCity(Airport? airport) {
    if (airport == null) {
      return 'Unknown airport';
    }

    final municipality = airport.municipality?.trim();

    if (municipality != null && municipality.isNotEmpty) {
      return municipality;
    }

    final country = airport.countryName?.trim();

    if (country != null && country.isNotEmpty) {
      return country;
    }

    return airport.name;
  }

  String _formatDepartureDate(BuildContext context) {
    // Flight dates are local calendar dates.
    // Do not convert them into the device's timezone.
    final parts = flight.departureOn.split('-');

    if (parts.length != 3) {
      return flight.departureOn;
    }

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) {
      return flight.departureOn;
    }

    if (year < 1 ||
        year > 9999 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > DateUtils.getDaysInMonth(year, month)) {
      return flight.departureOn;
    }

    return MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime(year, month, day));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final departureCode = _airportCode(
      departureAirport,
      flight.departureAirportId,
    );

    final arrivalCode = _airportCode(arrivalAirport, flight.arrivalAirportId);

    final displayAirlineName =
        airline?.name ??
        airlineName ??
        flight.airlineName ??
        'Airline not recorded';

    final number = flight.flightNumber?.trim();

    final hasFlightNumber = number != null && number.isNotEmpty;

    return Container(
      key: ValueKey('flight-card-${flight.id}'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --------------------------------------------------------
          // Route
          // --------------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FlightAirport(
                  airport: departureAirport,
                  code: departureCode,
                  city: _airportCity(departureAirport),
                  alignment: CrossAxisAlignment.start,
                ),
              ),

              const SizedBox(width: 8),

              Padding(
                padding: const EdgeInsets.only(top: 13),
                child: _FlightRouteIndicator(color: colors.primary),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _FlightAirport(
                  airport: arrivalAirport,
                  code: arrivalCode,
                  city: _airportCity(arrivalAirport),
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.45),
          ),

          const SizedBox(height: 14),

          // --------------------------------------------------------
          // Airline and flight information
          // --------------------------------------------------------
          Row(
            children: [
              AirlineAvatar(airline: airline, size: 42),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayAirlineName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      [
                        if (hasFlightNumber) number,
                        _formatDepartureDate(context),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // --------------------------------------------------------
          // Status
          // --------------------------------------------------------
          Align(
            alignment: Alignment.centerLeft,
            child: _FlightStatusBadge(status: flight.status),
          ),
        ],
      ),
    );
  }
}

/// Airport code, flag and city displayed inside a flight route.
class _FlightAirport extends StatelessWidget {
  const _FlightAirport({
    required this.airport,
    required this.code,
    required this.city,
    required this.alignment,
  });

  final Airport? airport;
  final String code;
  final String city;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final isRightAligned = alignment == CrossAxisAlignment.end;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment: isRightAligned
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isRightAligned) ...[
              CountryFlag(countryCode: airport?.countryCode ?? '', size: 28),
              const SizedBox(width: 6),
            ],

            Flexible(
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            if (isRightAligned) ...[
              const SizedBox(width: 6),
              CountryFlag(countryCode: airport?.countryCode ?? '', size: 28),
            ],
          ],
        ),

        const SizedBox(height: 6),

        Text(
          city,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isRightAligned ? TextAlign.right : TextAlign.left,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Decorative flight route between two airport codes.
class _FlightRouteIndicator extends StatelessWidget {
  const _FlightRouteIndicator({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      child: Row(
        children: [
          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.45)),
          ),

          const SizedBox(width: 4),

          Icon(Icons.flight_rounded, size: 20, color: color),

          const SizedBox(width: 4),

          Expanded(
            child: Container(height: 1, color: color.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}

/// Subtle visual distinction between completed and planned flights.
class _FlightStatusBadge extends StatelessWidget {
  const _FlightStatusBadge({required this.status});

  final FlightStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final completed = status == FlightStatus.flown;

    final color = completed ? colors.primary : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            completed
                ? Icons.check_circle_outline_rounded
                : Icons.schedule_rounded,
            size: 15,
            color: color,
          ),

          const SizedBox(width: 6),

          Text(
            completed ? 'Completed' : 'Planned',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
