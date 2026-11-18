import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../domain/map_destination_status.dart';

class MapStatusFilter extends StatelessWidget {
  const MapStatusFilter({
    required this.selectedStatus,
    required this.onSelected,
    super.key,
  });

  final MapDestinationStatus selectedStatus;
  final ValueChanged<MapDestinationStatus> onSelected;

  String _label(MapDestinationStatus status) {
    return switch (status) {
      MapDestinationStatus.visited => 'Visited',
      MapDestinationStatus.lived => 'Lived',
      MapDestinationStatus.wishlist => 'Wishlist',
    };
  }

  dynamic _icon(MapDestinationStatus status) {
    if (PlatformInfo.isIOS26OrHigher()) {
      return switch (status) {
        MapDestinationStatus.visited => 'globe.europe.africa',
        MapDestinationStatus.lived => 'house',
        MapDestinationStatus.wishlist => 'bookmark',
      };
    }

    return switch (status) {
      MapDestinationStatus.visited => Icons.public_outlined,
      MapDestinationStatus.lived => Icons.home_outlined,
      MapDestinationStatus.wishlist => Icons.bookmark_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: const Key('mapStatusFilter'),
      child: AdaptivePopupMenuButton.text<MapDestinationStatus>(
        label: '${_label(selectedStatus)}  ▾',
        height: 44,
        buttonStyle: PopupButtonStyle.glass,
        items: [
          for (final status in MapDestinationStatus.values)
            AdaptivePopupMenuItem<MapDestinationStatus>(
              label: _label(status),
              value: status,
              icon: _icon(status),
              selected: status == selectedStatus,
            ),
        ],
        onSelected: (index, item) {
          final status = item.value;

          if (status != null) {
            onSelected(status);
          }
        },
      ),
    );
  }
}
