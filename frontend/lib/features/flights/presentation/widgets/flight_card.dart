import 'package:flutter/material.dart';

import '../../../../app/widgets/country_flag.dart';

import '../../domain/airport.dart';
import '../../domain/airline.dart';
import '../../domain/flight.dart';

import 'airline_avatar.dart';

/// Compact visual representation of an independent flight record.
///
/// Catalog metadata is optional. Flights remain displayable even
/// when airport or airline resolution is unavailable.
///
/// Dates are local calendar dates and must never be converted
/// using the device timezone.
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --------------------------------------------------
          // Header: airline / date / status
          // --------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AirlineAvatar(airline: airline, size: 38),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  displayAirlineName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatDepartureDate(context),
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 5),

                  _FlightStatusIndicator(status: flight.status),
                ],
              ),
            ],
          ),

          const SizedBox(height: 22),

          // --------------------------------------------------
          // Route
          // --------------------------------------------------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: _FlightAirport(
                  airport: departureAirport,
                  code: departureCode,
                  city: _airportCity(departureAirport),
                  alignment: CrossAxisAlignment.start,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                flex: 3,
                child: _FlightRouteIndicator(
                  color: colors.primary,
                  flightNumber: hasFlightNumber ? number : null,
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                flex: 3,
                child: _FlightAirport(
                  airport: arrivalAirport,
                  code: arrivalCode,
                  city: _airportCity(arrivalAirport),
                  alignment: CrossAxisAlignment.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Airport code, country flag and city displayed in a flight route.
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: isRightAligned
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isRightAligned) ...[
              CountryFlag(countryCode: airport?.countryCode ?? '', size: 22),
              const SizedBox(width: 5),
            ],

            Flexible(
              child: Text(
                code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  height: 1.1,
                  color: colors.onSurface,
                ),
              ),
            ),

            if (isRightAligned) ...[
              const SizedBox(width: 5),
              CountryFlag(countryCode: airport?.countryCode ?? '', size: 22),
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
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

/// Decorative route indicator between the departure and arrival.
///
/// No duration is shown until timezone-aware flight duration
/// calculations are supported.
class _FlightRouteIndicator extends StatelessWidget {
  const _FlightRouteIndicator({required this.color, this.flightNumber});

  final Color color;
  final String? flightNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),

            Expanded(
              child: Container(
                height: 1.5,
                color: color.withValues(alpha: 0.35),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.flight_rounded, size: 21, color: color),
            ),

            Expanded(
              child: Container(
                height: 1.5,
                color: color.withValues(alpha: 0.35),
              ),
            ),

            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        Text(
          flightNumber ?? 'Flight',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Minimal status indicator matching the compact card design.
class _FlightStatusIndicator extends StatelessWidget {
  const _FlightStatusIndicator({required this.status});

  final FlightStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final completed = status == FlightStatus.flown;

    final color = completed ? colors.primary : colors.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          completed
              ? Icons.check_circle_outline_rounded
              : Icons.schedule_rounded,
          color: color,
          size: 13,
        ),

        const SizedBox(width: 4),

        Text(
          completed ? 'Completed' : 'Planned',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
