import 'package:flutter/painting.dart';

import '../map_panel_layout.dart';

/// Read-only description of the area available for
/// contextual geographic camera framing.
///
/// The frame is expressed in logical Flutter pixels.
///
/// It does not interact with MapLibre or modify geographic data.
class MapCameraFocusFrame {
  const MapCameraFocusFrame({
    required this.viewportSize,
    required this.padding,
  });

  final Size viewportSize;

  /// Space excluded from the camera's usable viewport.
  final EdgeInsets padding;

  /// Rectangle representing the usable map area.
  Rect get visibleRect {
    return Rect.fromLTRB(
      padding.left,
      padding.top,
      viewportSize.width - padding.right,
      viewportSize.height - padding.bottom,
    );
  }

  /// Center of the usable viewport in screen coordinates.
  Offset get visibleCenter => visibleRect.center;

  /// Center of the complete viewport.
  Offset get viewportCenter =>
      Offset(viewportSize.width / 2, viewportSize.height / 2);

  /// Desired displacement of a geographic target on screen.
  ///
  /// Negative horizontal values move the target towards
  /// the left side of the viewport.
  Offset get targetScreenOffset => visibleCenter - viewportCenter;
}

/// Builds the contextual camera frame for the expected
/// initial panel layout.
///
/// In landscape, the right-side panel is excluded.
///
/// In portrait, the initial bottom-sheet area is excluded.
///
/// The calculation is deterministic and independent of
/// the currently selected geographic entity.
MapCameraFocusFrame calculateMapCameraFocusFrame({
  required Size viewportSize,
  required double topSafeArea,
}) {
  final width = viewportSize.width;
  final height = viewportSize.height;

  assert(width > 0 && height > 0);
  assert(topSafeArea >= 0);

  // ---------------------------------------------------------------------------
  // Landscape: reserve the contextual side panel.
  // ---------------------------------------------------------------------------

  if (MapPanelLayout.usesSidePanel(
    viewportWidth: width,
    viewportHeight: height,
  )) {
    final panelWidth = MapPanelLayout.sidePanelWidth(width);

    return MapCameraFocusFrame(
      viewportSize: viewportSize,
      padding: EdgeInsets.fromLTRB(55, topSafeArea + 55, panelWidth + 28, 55),
    );
  }

  // ---------------------------------------------------------------------------
  // Portrait: reserve the initial bottom panel.
  // ---------------------------------------------------------------------------

  final panelHeight = height * MapPanelLayout.initialExtent;

  return MapCameraFocusFrame(
    viewportSize: viewportSize,
    padding: EdgeInsets.fromLTRB(55, topSafeArea + 65, 55, panelHeight + 24),
  );
}
