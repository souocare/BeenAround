/// Shared layout configuration for the country preview panel.
///
/// The panel and contextual camera must use the same dimensions.
abstract final class MapPanelLayout {
  // Bottom panel positions.
  static const double closedExtent = 0.0;
  static const double compactExtent = 0.25;
  static const double initialExtent = 0.42;
  static const double expandedExtent = 0.85;

  // Responsive layout.
  static const double sidePanelBreakpoint = 600.0;
  static const double sidePanelWidthFraction = 0.42;
  static const double minSidePanelWidth = 300.0;
  static const double maxSidePanelWidth = 390.0;
}
