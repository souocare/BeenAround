import 'package:flutter/material.dart';

/// Displays a country flag using its ISO 3166-1 alpha-2 code.
///
/// Falls back to a globe when the code is unavailable or invalid.
class CountryFlag extends StatelessWidget {
  const CountryFlag({
    required this.countryCode,
    this.size = 48,
    this.showBackground = true,
    super.key,
  });

  final String countryCode;
  final double size;

  /// Whether to display the decorative background.
  final bool showBackground;

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

    return SizedBox(
      width: size,
      height: size,
      child: Container(
        alignment: Alignment.center,
        decoration: showBackground
            ? BoxDecoration(
                color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Text(
          _emoji,
          style: TextStyle(
            fontSize: showBackground ? size * 0.56 : size * 0.85,
            height: 1,
          ),
        ),
      ),
    );
  }
}
