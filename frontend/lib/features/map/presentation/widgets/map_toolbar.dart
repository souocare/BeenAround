import 'package:flutter/material.dart';

import '../../domain/map_destination_status.dart';
import 'map_status_filter.dart';

class MapToolbar extends StatelessWidget {
  const MapToolbar({
    required this.selectedStatus,
    required this.onStatusSelected,
    super.key,
  });

  final MapDestinationStatus selectedStatus;
  final ValueChanged<MapDestinationStatus> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MapStatusFilter(
          selectedStatus: selectedStatus,
          onSelected: onStatusSelected,
        ),
      ],
    );
  }
}
