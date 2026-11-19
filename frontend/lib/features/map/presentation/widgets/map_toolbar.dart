import 'package:flutter/material.dart';

import '../../domain/map_destination_status.dart';
import 'map_search_control.dart';
import 'map_status_filter.dart';

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

  final MapDestinationStatus selectedStatus;
  final ValueChanged<MapDestinationStatus> onStatusSelected;

  final bool isSearchOpen;
  final VoidCallback onSearchOpen;
  final VoidCallback onSearchClose;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: MapSearchControl(
            isOpen: isSearchOpen,
            onOpen: onSearchOpen,
            onClose: onSearchClose,
            onQueryChanged: onSearchChanged,
          ),
        ),

        const SizedBox(width: 8),

        MapStatusFilter(
          selectedStatus: selectedStatus,
          onSelected: onStatusSelected,
        ),
      ],
    );
  }
}
