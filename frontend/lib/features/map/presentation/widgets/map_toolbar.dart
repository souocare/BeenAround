import 'package:flutter/material.dart';

import '../../domain/map_destination_status.dart';
import 'map_search_control.dart';
import 'map_status_filter.dart';
import '../../domain/map_layer_visibility.dart';
import 'map_layer_filter_control.dart';

/// Responsive toolbar for geographic search and status filtering.
///
/// The available width is controlled by the MapPage overlay layout.
///
/// This widget only decides how its controls should be presented
/// within those constraints.
class MapToolbar extends StatelessWidget {
  const MapToolbar({
    required this.selectedStatus,
    required this.onStatusSelected,
    required this.isSearchOpen,
    required this.onSearchOpen,
    required this.onSearchClose,
    required this.onSearchChanged,
    required this.layerVisibility,
    required this.onLayerVisibilityChanged,
    this.allowCompactFilter = true,
    super.key,
  });

  /// Below this width, use shorter filter labels.
  ///
  /// The search field keeps the remaining horizontal space.
  static const double compactBreakpoint = 390;

  final MapDestinationStatus selectedStatus;
  final ValueChanged<MapDestinationStatus> onStatusSelected;

  final bool isSearchOpen;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;
  final MapLayerVisibility layerVisibility;

  final ValueChanged<MapLayerVisibility> onLayerVisibilityChanged;

  /// Allows compact filter labels when horizontal space is constrained.
  ///
  /// Portrait layouts can disable compaction to preserve full labels.
  final bool allowCompactFilter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactFilter =
            allowCompactFilter && constraints.maxWidth < compactBreakpoint;

        return Row(
          children: [
            // ---------------------------------------------------------------
            // Geographic search
            // ---------------------------------------------------------------
            Expanded(
              child: MapSearchControl(
                isOpen: isSearchOpen,
                onOpen: onSearchOpen,
                onClose: onSearchClose,
                onQueryChanged: onSearchChanged,
              ),
            ),

            const SizedBox(width: 8),

            // ---------------------------------------------------------------
            // Destination status (Visited / Lived / Wishlist)
            // ---------------------------------------------------------------
            MapStatusFilter(
              selectedStatus: selectedStatus,
              compact: useCompactFilter,
              onSelected: onStatusSelected,
            ),

            const SizedBox(width: 8),

            // ---------------------------------------------------------------
            // Independent geographic layer visibility
            // ---------------------------------------------------------------
            MapLayerFilterControl(
              visibility: layerVisibility,
              onVisibilityChanged: onLayerVisibilityChanged,
              isSearchOpen: isSearchOpen,
              onSearchClose: onSearchClose,
            ),
          ],
        );
      },
    );
  }
}
