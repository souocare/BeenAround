import 'dart:convert';

import 'package:flutter/material.dart';

class CountryMapStyle {
  const CountryMapStyle._();

  static String build(ColorScheme colors) {
    final style = {
      'version': 8,
      'name': 'BeenAround Country Map',
      'sources': <String, dynamic>{},
      'layers': [
        {
          'id': 'background',
          'type': 'background',
          'paint': {'background-color': _toHex(colors.surface)},
        },
      ],
    };

    return jsonEncode(style);
  }

  static String colorToHex(Color color) {
    return _toHex(color);
  }

  static String _toHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;

    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
