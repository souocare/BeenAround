import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';

import '../../domain/map_destination_status.dart';

/// Geographic destination-status filter.
///
/// Supports a compact label for narrow Map toolbars while
/// preserving the same menu items and selection behavior.
class MapStatusFilter extends StatelessWidget {
  const MapStatusFilter({
    required this.selectedStatus,
    required this.onSelected,
    this.compact = false,
    super.key,
  });

  final MapDestinationStatus selectedStatus;
  final ValueChanged<MapDestinationStatus> onSelected;

  /// Uses a shorter button label when horizontal space is limited.
  ///
  /// Menu items always retain their full descriptive labels.
  final bool compact;

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  String _label(MapDestinationStatus status) {
    return switch (status) {
      MapDestinationStatus.visited => 'Visited',
      MapDestinationStatus.lived => 'Lived',
      MapDestinationStatus.wishlist => 'Wishlist',
    };
  }

  String _compactLabel(MapDestinationStatus status) {
    return switch (status) {
      MapDestinationStatus.visited => 'VIS',
      MapDestinationStatus.lived => 'LIV',
      MapDestinationStatus.wishlist => 'WISH',
    };
  }

  // ---------------------------------------------------------------------------
  // Icons
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final fullLabel = _label(selectedStatus);

    final buttonLabel = compact ? _compactLabel(selectedStatus) : fullLabel;

    return KeyedSubtree(
      key: const Key('mapStatusFilter'),
      child: Tooltip(
        message: 'Map filter: $fullLabel',
        child: AdaptivePopupMenuButton.text<MapDestinationStatus>(
          label: '$buttonLabel  ▾',
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
      ),
    );
  }
}
