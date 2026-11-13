import 'package:flutter/material.dart';

/// Shared input decoration for flight forms.
///
/// Keeps text fields visually consistent across the
/// Add Flight and future Edit Flight experiences.
InputDecoration flightInputDecoration(
  BuildContext context, {
  String? hintText,
  Widget? prefixIcon,
}) {
  final colors = Theme.of(context).colorScheme;

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(
      color: colors.outlineVariant.withValues(alpha: 0.35),
    ),
  );

  return InputDecoration(
    hintText: hintText,
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: colors.surfaceContainerHigh,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: colors.primary.withValues(alpha: 0.65),
        width: 1.3,
      ),
    ),
  );
}
