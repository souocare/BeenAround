import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/presentation/widgets/country_map_style.dart';

void main() {
  group('CountryMapStyle', () {
    test('generates a valid MapLibre style', () {
      const colors = ColorScheme.dark();

      final source = CountryMapStyle.build(colors);

      final style = jsonDecode(source) as Map<String, dynamic>;

      expect(style['version'], 8);
      expect(style['sources'], isEmpty);
      expect(style['layers'], isNotEmpty);
    });

    test('uses the theme surface as background', () {
      const colors = ColorScheme.dark(surface: Color(0xFF101116));

      final source = CountryMapStyle.build(colors);

      final style = jsonDecode(source) as Map<String, dynamic>;

      final layers = style['layers'] as List<dynamic>;
      final background = layers.first as Map<String, dynamic>;
      final paint = background['paint'] as Map<String, dynamic>;

      expect(paint['background-color'], '#101116');
    });

    test('converts colors to hexadecimal', () {
      expect(CountryMapStyle.colorToHex(const Color(0xFFE53935)), '#E53935');

      expect(CountryMapStyle.colorToHex(const Color(0xFF353640)), '#353640');
    });
  });
}
