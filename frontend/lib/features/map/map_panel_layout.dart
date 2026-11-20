/// Shared layout configuration for contextual geographic Map panels.
///
/// Panel presentation and camera framing must use the
/// same responsive geometry.
abstract final class MapPanelLayout {
  // ---------------------------------------------------------------------------
  // Bottom panel
  // ---------------------------------------------------------------------------

  static const double closedExtent = 0.0;
  static const double compactExtent = 0.25;
  static const double initialExtent = 0.42;
  static const double expandedExtent = 0.85;

  // ---------------------------------------------------------------------------
  // Responsive side panel
  // ---------------------------------------------------------------------------

  static const double sidePanelBreakpoint = 600.0;
  static const double sidePanelWidthFraction = 0.42;
  static const double minSidePanelWidth = 300.0;
  static const double maxSidePanelWidth = 390.0;

  /// Whether the viewport supports the contextual side panel.
  ///
  /// Matches the responsive rule used by MapContextPanelShell.
  static bool usesSidePanel({
    required double viewportWidth,
    required double viewportHeight,
  }) {
    return viewportWidth > viewportHeight &&
        viewportWidth >= sidePanelBreakpoint;
  }

  /// Responsive width of the contextual side panel.
  ///
  /// The result excludes the panel's outer safe-area padding.
  static double sidePanelWidth(double viewportWidth) {
    return (viewportWidth * sidePanelWidthFraction)
        .clamp(minSidePanelWidth, maxSidePanelWidth)
        .toDouble();
  }
}
