import 'package:flutter/material.dart';

import '../../domain/airline.dart';

/// Visual identity for an airline.
///
/// Displays its aviation code until a supported logo
/// source is available.
///
/// This widget is presentation-only and does not fetch
/// external resources.
class AirlineAvatar extends StatelessWidget {
  const AirlineAvatar({required this.airline, this.size = 48, super.key});

  final Airline? airline;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final code = airline?.displayCode?.trim();

    final hasCode = code != null && code.isNotEmpty;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: hasCode
          ? FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  code,
                  maxLines: 1,
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            )
          : Icon(Icons.flight_rounded, color: colors.primary, size: size * 0.5),
    );
  }
}
