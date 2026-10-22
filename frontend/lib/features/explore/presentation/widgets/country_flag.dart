import 'package:flutter/material.dart';

class CountryFlag extends StatelessWidget {
  const CountryFlag({required this.countryCode, super.key});

  final String countryCode;

  String get _emoji {
    final code = countryCode.toUpperCase();

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) {
      return '🌍';
    }

    return String.fromCharCodes(code.codeUnits.map((unit) => unit + 127397));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_emoji, style: const TextStyle(fontSize: 27)),
    );
  }
}
