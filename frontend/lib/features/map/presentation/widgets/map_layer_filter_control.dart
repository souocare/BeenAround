import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/map_layer_visibility.dart';

/// Compact Map layer visibility control.
///
/// The button matches the Map search control's circular
/// glass appearance.
///
/// Visibility changes are delegated to the application
/// layer and never modify travel records.
///
/// The popover remains open while toggling layers.
class MapLayerFilterControl extends StatefulWidget {
  const MapLayerFilterControl({
    required this.visibility,
    required this.onVisibilityChanged,
    this.isSearchOpen = false,
    this.onSearchClose,
    super.key,
  });

  final MapLayerVisibility visibility;

  final ValueChanged<MapLayerVisibility> onVisibilityChanged;

  final bool isSearchOpen;

  final VoidCallback? onSearchClose;

  @override
  State<MapLayerFilterControl> createState() => _MapLayerFilterControlState();
}

class _MapLayerFilterControlState extends State<MapLayerFilterControl> {
  static const double _buttonSize = 44;
  static const double _borderRadius = 22;
  static const double _panelWidth = 248;

  final MenuController _menuController = MenuController();

  @override
  void didUpdateWidget(covariant MapLayerFilterControl oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isSearchOpen && widget.isSearchOpen) {
      _menuController.close();
    }
  }

  void _toggleMenu() {
    if (_menuController.isOpen) {
      _menuController.close();
      return;
    }

    if (widget.isSearchOpen) {
      widget.onSearchClose?.call();
    }

    _menuController.open();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return MenuAnchor(
      controller: _menuController,

      // Align the right edge of the popover with the
      // right edge of the filter button.
      style: const MenuStyle(
        alignment: AlignmentDirectional.bottomEnd,
        backgroundColor: WidgetStatePropertyAll(Colors.transparent),
        elevation: WidgetStatePropertyAll(0),
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),

      alignmentOffset: const Offset(0, 8),

      // Allow the panel to be wider than the button.
      crossAxisUnconstrained: true,

      // Taps outside dismiss the popover without swallowing
      // unrelated Map interactions.
      consumeOutsideTap: false,

      onOpen: () {
        if (mounted) setState(() {});
      },

      onClose: () {
        if (mounted) setState(() {});
      },

      menuChildren: [_buildPanel(context)],

      builder: (context, controller, child) {
        return SizedBox(
          width: _buttonSize,
          height: _buttonSize,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(_borderRadius),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(
                      alpha: controller.isOpen ? 0.45 : 0.18,
                    ),
                    width: 0.8,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('mapLayersButton'),
                    onTap: _toggleMenu,
                    borderRadius: BorderRadius.circular(_borderRadius),
                    child: Tooltip(
                      message: 'Map layers',
                      child: Center(
                        child: Icon(
                          Icons.tune_rounded,
                          size: 22,
                          color: controller.isOpen
                              ? colors.primary
                              : colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanel(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return SizedBox(
      width: _panelWidth,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.25),
                width: 0.8,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'MAP LAYERS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  _buildLayerSwitch(
                    title: 'Countries',
                    icon: Icons.public_outlined,
                    value: widget.visibility.countries,
                    onChanged: (value) {
                      widget.onVisibilityChanged(
                        widget.visibility.copyWith(countries: value),
                      );
                    },
                  ),

                  _buildLayerSwitch(
                    title: 'Cities',
                    icon: Icons.location_city_outlined,
                    value: widget.visibility.cities,
                    onChanged: (value) {
                      widget.onVisibilityChanged(
                        widget.visibility.copyWith(cities: value),
                      );
                    },
                  ),

                  _buildLayerSwitch(
                    title: 'Airports',
                    icon: Icons.flight_takeoff_outlined,
                    value: widget.visibility.airports,
                    onChanged: (value) {
                      widget.onVisibilityChanged(
                        widget.visibility.copyWith(airports: value),
                      );
                    },
                  ),

                  _buildLayerSwitch(
                    title: 'Flight routes',
                    icon: Icons.route_rounded,
                    value: widget.visibility.flightRoutes,
                    onChanged: (value) {
                      widget.onVisibilityChanged(
                        widget.visibility.copyWith(flightRoutes: value),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerSwitch({
    required String title,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Icon(icon, size: 19, color: colors.onSurfaceVariant),

          const SizedBox(width: 12),

          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
          ),

          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              key: Key('mapLayerSwitch:$title'),
              value: value,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
