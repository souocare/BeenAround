import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../map_panel_layout.dart';

/// Layout of the Map toolbar and geographic search results.
///
/// All dimensions use logical Flutter pixels.
///
/// This is presentation geometry only. It does not depend
/// on the geographic selection type or access application data.
class MapOverlayLayout {
  const MapOverlayLayout({
    required this.left,
    required this.right,
    required this.toolbarTop,
    required this.resultsTop,
    required this.resultsMaxHeight,
    required this.hasSidePanel,
  });

  final double left;
  final double right;

  final double toolbarTop;
  final double resultsTop;
  final double resultsMaxHeight;

  final bool hasSidePanel;
}

/// Calculates the available layout for Map controls.
///
/// When a contextual side panel is visible, the toolbar and
/// search results are constrained to the remaining map area.
///
/// In portrait or without a visible side panel, the existing
/// full-width presentation is preserved.
///
/// Search results account for safe areas and the keyboard,
/// preventing them from extending beyond the viewport.
MapOverlayLayout calculateMapOverlayLayout({
  required Size viewportSize,
  required EdgeInsets safePadding,
  required bool hasSelection,
  double keyboardInset = 0,
}) {
  if (!viewportSize.width.isFinite ||
      !viewportSize.height.isFinite ||
      viewportSize.width <= 0 ||
      viewportSize.height <= 0 ||
      !keyboardInset.isFinite ||
      keyboardInset < 0) {
    throw ArgumentError('Invalid Map overlay dimensions.');
  }

  final usesSidePanel =
      hasSelection &&
      MapPanelLayout.usesSidePanel(
        viewportWidth: viewportSize.width,
        viewportHeight: viewportSize.height,
      );

  // -------------------------------------------------------------------------
  // Horizontal positioning
  // -------------------------------------------------------------------------

  final left = safePadding.left + 16;

  final right = usesSidePanel
      ? safePadding.right +
            12 +
            MapPanelLayout.sidePanelWidth(viewportSize.width) +
            16
      : safePadding.right + 16;

  // -------------------------------------------------------------------------
  // Vertical positioning
  // -------------------------------------------------------------------------

  final toolbarTop = safePadding.top + 12;

  // Preserve a small separation between the toolbar and results.
  //
  // The current Map toolbar uses a single horizontal row.
  final resultsTop = safePadding.top + 72;

  // When the keyboard is visible, its inset already represents
  // the obscured area at the bottom of the viewport.
  //
  // We must not add the bottom safe area to it a second time.
  final bottomInset = math.max(safePadding.bottom, keyboardInset);

  const bottomMargin = 12.0;
  const maximumResultsHeight = 420.0;

  final availableHeight =
      viewportSize.height - resultsTop - bottomInset - bottomMargin;

  final resultsMaxHeight = availableHeight
      .clamp(0.0, maximumResultsHeight)
      .toDouble();

  return MapOverlayLayout(
    left: left,
    right: right,
    toolbarTop: toolbarTop,
    resultsTop: resultsTop,
    resultsMaxHeight: resultsMaxHeight,
    hasSidePanel: usesSidePanel,
  );
}
