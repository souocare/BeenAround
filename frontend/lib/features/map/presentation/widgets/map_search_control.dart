import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

class MapSearchControl extends StatefulWidget {
  const MapSearchControl({
    required this.isOpen,
    required this.onOpen,
    required this.onClose,
    required this.onQueryChanged,
    super.key,
  });

  final bool isOpen;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final ValueChanged<String> onQueryChanged;

  @override
  State<MapSearchControl> createState() => _MapSearchControlState();
}

class _MapSearchControlState extends State<MapSearchControl> {
  static const _controlHeight = 44.0;

  static const _animationDuration = Duration(milliseconds: 450);

  static const _contentAnimationDuration = Duration(milliseconds: 180);

  static const _borderRadius = 22.0;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  Timer? _focusTimer;

  // ---------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------

  @override
  void initState() {
    super.initState();

    if (widget.isOpen) {
      _scheduleFocus();
    }
  }

  @override
  void didUpdateWidget(covariant MapSearchControl oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isOpen && widget.isOpen) {
      _scheduleFocus();
    }

    if (oldWidget.isOpen && !widget.isOpen) {
      _focusTimer?.cancel();

      _focusNode.unfocus();
      _controller.clear();
    }
  }

  void _scheduleFocus() {
    _focusTimer?.cancel();

    _focusTimer = Timer(_animationDuration, () {
      if (!mounted || !widget.isOpen) {
        return;
      }

      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusTimer?.cancel();

    _controller.dispose();
    _focusNode.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------
  // Presentation
  // ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedWidth = constraints.maxWidth;

        return Align(
          alignment: Alignment.centerRight,
          child: AnimatedContainer(
            key: const Key('mapSearchControl'),
            duration: _animationDuration,
            curve: Curves.easeInOutCubic,
            width: widget.isOpen ? expandedWidth : _controlHeight,
            height: _controlHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_borderRadius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // Dark, subtle glass surface.
                    color: colors.surface.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(_borderRadius),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // ---------------------------------------
                      // Collapsed search button
                      // ---------------------------------------
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: widget.isOpen ? 0 : 1,
                          duration: _contentAnimationDuration,
                          curve: Curves.easeOut,
                          child: IgnorePointer(
                            ignoring: widget.isOpen,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: const Key('mapSearchOpen'),
                                onTap: widget.onOpen,
                                borderRadius: BorderRadius.circular(
                                  _borderRadius,
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.search_rounded,
                                    size: 22,
                                    color: colors.onSurface,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ---------------------------------------
                      // Expanded search content
                      // ---------------------------------------
                      Positioned.fill(
                        child: AnimatedOpacity(
                          opacity: widget.isOpen ? 1 : 0,
                          duration: _contentAnimationDuration,
                          curve: Curves.easeIn,
                          child: IgnorePointer(
                            ignoring: !widget.isOpen,
                            child: ClipRect(
                              child: OverflowBox(
                                alignment: Alignment.centerRight,
                                minWidth: expandedWidth,
                                maxWidth: expandedWidth,
                                child: _buildExpandedContent(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // Expanded content
  // ---------------------------------------------------------

  Widget _buildExpandedContent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: _controlHeight,
      child: Row(
        children: [
          const SizedBox(width: 14),

          Icon(Icons.search_rounded, size: 21, color: colors.onSurfaceVariant),

          const SizedBox(width: 10),

          Expanded(
            child: TextField(
              key: const Key('mapSearchField'),
              controller: _controller,
              focusNode: _focusNode,
              onChanged: widget.onQueryChanged,
              textInputAction: TextInputAction.search,
              cursorColor: colors.primary,
              cursorWidth: 1.5,
              maxLines: 1,
              style: TextStyle(fontSize: 14, color: colors.onSurface),
              decoration: InputDecoration(
                hintText: 'Search places',
                hintStyle: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          SizedBox(
            width: 40,
            height: _controlHeight,
            child: IconButton(
              key: const Key('mapSearchClose'),
              tooltip: 'Close search',
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.close_rounded,
                size: 19,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
