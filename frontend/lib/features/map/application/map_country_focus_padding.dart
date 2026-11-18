import 'package:flutter/widgets.dart';
import '../map_panel_layout.dart';

/// Calculates camera padding for a selected country.
///
/// The initial country panel occupies 42% of the available map height
/// in portrait mode.
///
/// In landscape, a sufficiently wide viewport displays a side panel.
///
/// Camera padding is calculated once when a country is selected.
/// Dragging the panel does not continuously reposition the map.
EdgeInsets calculateCountryFocusPadding({
  required Size viewportSize,
  double topSafeArea = 0,
}) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) {
    throw ArgumentError('Invalid viewport dimensions.');
  }

  final isLandscape = viewportSize.width > viewportSize.height;

  // Matches the current MapCountryPanel layout.
  final hasSidePanel =
      isLandscape && viewportSize.width >= MapPanelLayout.sidePanelBreakpoint;

  if (hasSidePanel) {
    final panelWidth =
        (viewportSize.width * MapPanelLayout.sidePanelWidthFraction)
            .clamp(
              MapPanelLayout.minSidePanelWidth,
              MapPanelLayout.maxSidePanelWidth,
            )
            .toDouble();

    return EdgeInsets.fromLTRB(55, topSafeArea + 55, panelWidth + 28, 55);
  }

  // Match the initial DraggableScrollableSheet height.
  final panelHeight = viewportSize.height * MapPanelLayout.initialExtent;

  return EdgeInsets.fromLTRB(55, topSafeArea + 65, 55, panelHeight + 24);
}
