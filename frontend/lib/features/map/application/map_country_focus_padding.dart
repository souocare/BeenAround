import 'package:flutter/widgets.dart';

import 'map_camera_focus_frame.dart';

/// Calculates camera padding for a selected country.
///
/// Delegates to the shared contextual camera frame so that
/// countries, cities and airports use the same responsive
/// viewport geometry.
///
/// Camera padding is calculated when geographic navigation
/// occurs. Dragging the contextual panel does not continuously
/// reposition the map.
///
/// Preserves the existing API for country camera framing.
EdgeInsets calculateCountryFocusPadding({
  required Size viewportSize,
  double topSafeArea = 0,
}) {
  if (!viewportSize.width.isFinite ||
      !viewportSize.height.isFinite ||
      viewportSize.width <= 0 ||
      viewportSize.height <= 0 ||
      !topSafeArea.isFinite ||
      topSafeArea < 0) {
    throw ArgumentError('Invalid viewport dimensions or safe area.');
  }

  return calculateMapCameraFocusFrame(
    viewportSize: viewportSize,
    topSafeArea: topSafeArea,
  ).padding;
}
