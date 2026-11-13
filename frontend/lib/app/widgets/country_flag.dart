import 'package:flutter/material.dart';

/// Displays a country flag using its ISO 3166-1 alpha-2 code.
///
/// Falls back to a globe when the code is unavailable or invalid.
class CountryFlag extends StatelessWidget {
  const CountryFlag({required this.countryCode, this.size = 48, super.key});

  final String countryCode;
  final double size;

  String get _emoji {
    final code = countryCode.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      return '🌍';
    }

    return String.fromCharCodes(code.codeUnits.map((unit) => unit + 127397));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_emoji, style: TextStyle(fontSize: size * 0.56)),
    );
  }
}
