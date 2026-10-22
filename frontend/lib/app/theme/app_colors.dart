import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand identity — Nocturne Wayfarer.
  static const Color primary = Color(0xFFE53935);
  static const Color secondary = Color(0xFFF4511E);
  static const Color tertiary = Color(0xFFFB8C00);

  // Dark surfaces.
  static const Color darkBackground = Color(0xFF101116);
  static const Color darkSurface = Color(0xFF1C1D24);
  static const Color darkSurfaceElevated = Color(0xFF25262F);

  // Dark text and outlines.
  static const Color darkTextPrimary = Color(0xFFF5F3F4);
  static const Color darkTextSecondary = Color(0xFFA6A4AE);
  static const Color darkOutline = Color(0xFF353640);

  // Light surfaces.
  static const Color lightBackground = Color(0xFFFAF9F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1EFED);

  // Light brand variants.
  static const Color lightPrimary = Color(0xFFC62828);
  static const Color lightSecondary = Color(0xFFD84315);
  static const Color lightTertiary = Color(0xFFB65C00);

  // Light text and outlines.
  static const Color lightTextPrimary = Color(0xFF242329);
  static const Color lightTextSecondary = Color(0xFF68656D);
  static const Color lightOutline = Color(0xFFDDD9D7);

  // Semantic success colors.
  static const Color darkSuccess = Color(0xFF69C59B);
  static const Color lightSuccess = Color(0xFF237A55);

  static const Color darkSurfaceRecessed = Color(0xFF0B0C11);
  static const Color lightSurfaceRecessed = Color(0xFFF1EFED);
}
