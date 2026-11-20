import 'package:flutter/material.dart';

import '../../domain/map_destination_status.dart';
import 'map_search_control.dart';
import 'map_status_filter.dart';

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useCompactFilter = constraints.maxWidth < compactBreakpoint;

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
            // Destination status filter
            // ---------------------------------------------------------------
            MapStatusFilter(
              selectedStatus: selectedStatus,
              compact: useCompactFilter,
              onSelected: onStatusSelected,
            ),
          ],
        );
      },
    );
  }
}
