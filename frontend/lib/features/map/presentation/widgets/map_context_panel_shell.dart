import 'package:flutter/material.dart';

import '../../map_panel_layout.dart';

/// Builds the content of a contextual Map panel.
///
/// The provided scroll controller must be attached to the
/// primary scrollable inside the panel content.
typedef MapContextPanelContentBuilder =
    Widget Function(
      BuildContext context,
      ScrollController scrollController,
      bool showDragHandle,
    );

/// Shared responsive presentation shell for geographic
/// contextual panels.
///
/// Responsibilities:
/// - Portrait bottom sheet.
/// - Landscape/desktop side panel.
/// - Draggable resizing.
/// - Programmatic compaction.
/// - Dismissal by dragging.
/// - Surface styling.
///
/// Geographic content and travel records remain the
/// responsibility of the individual panel widgets.
class MapContextPanelShell extends StatefulWidget {
  const MapContextPanelShell({
    required this.contentBuilder,
    required this.onClose,
    this.selectionKey,
    this.compactRequestId = 0,
    super.key,
  });

  final MapContextPanelContentBuilder contentBuilder;

  final VoidCallback onClose;

  /// Incremented when the parent requests a compact presentation.
  ///
  /// Rebuilds with the same value do not trigger new animations.
  final int compactRequestId;

  /// Identity of the currently displayed geographic entity.
  ///
  /// Changes reset content scroll without resizing the panel.
  final String? selectionKey;

  @override
  State<MapContextPanelShell> createState() => _MapContextPanelShellState();
}

class _MapContextPanelShellState extends State<MapContextPanelShell> {
  ScrollController? _bottomScrollController;
  static const _compactAnimationDuration = Duration(milliseconds: 420);

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  final ScrollController _sideScrollController = ScrollController();

  bool _dismissalScheduled = false;

  @override
  void didUpdateWidget(covariant MapContextPanelShell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.compactRequestId != widget.compactRequestId) {
      _scheduleCompaction();
    }

    if (oldWidget.selectionKey != widget.selectionKey) {
      _scheduleScrollReset();
    }
  }
  // ---------------------------------------------------------------------------
  // Content scroll reset
  // ---------------------------------------------------------------------------

  void _scheduleScrollReset() {
    final selectionKey = widget.selectionKey;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || selectionKey != widget.selectionKey) {
        return;
      }

      final controller = _bottomScrollController;

      if (controller != null && controller.hasClients) {
        controller.jumpTo(0);
      }

      if (_sideScrollController.hasClients) {
        _sideScrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _sideScrollController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Programmatic compaction
  // ---------------------------------------------------------------------------

  void _scheduleCompaction() {
    final requestId = widget.compactRequestId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          requestId != widget.compactRequestId ||
          !_sheetController.isAttached) {
        return;
      }

      if (_sheetController.size <= MapPanelLayout.compactExtent) {
        return;
      }

      _sheetController.animateTo(
        MapPanelLayout.compactExtent,
        duration: _compactAnimationDuration,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Dismissal
  // ---------------------------------------------------------------------------

  void _scheduleDismissal() {
    if (_dismissalScheduled) return;

    _dismissalScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dismissalScheduled = false;

      if (!mounted) return;

      widget.onClose();
    });
  }

  // ---------------------------------------------------------------------------
  // Responsive presentation
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (isLandscape &&
            constraints.maxWidth >= MapPanelLayout.sidePanelBreakpoint) {
          return _buildSidePanel(context, constraints);
        }

        return _buildBottomPanel(context);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Portrait / narrow viewport
  // ---------------------------------------------------------------------------

  Widget _buildBottomPanel(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: NotificationListener<DraggableScrollableNotification>(
        onNotification: (notification) {
          // Ignore notifications from nested draggable sheets.
          if (notification.depth != 0) {
            return false;
          }

          if (notification.extent <= 0.02) {
            _scheduleDismissal();
          }

          return false;
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          child: DraggableScrollableSheet(
            controller: _sheetController,
            initialChildSize: MapPanelLayout.initialExtent,
            minChildSize: MapPanelLayout.closedExtent,
            maxChildSize: MapPanelLayout.expandedExtent,
            snap: true,
            snapSizes: const [
              MapPanelLayout.compactExtent,
              MapPanelLayout.initialExtent,
            ],
            snapAnimationDuration: const Duration(milliseconds: 320),
            expand: false,
            builder: (context, scrollController) {
              _bottomScrollController = scrollController;

              return Material(
                color: colors.surfaceContainerLow,
                elevation: 16,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: colors.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                child: widget.contentBuilder(context, scrollController, true),
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Landscape / wide viewport
  // ---------------------------------------------------------------------------

  Widget _buildSidePanel(BuildContext context, BoxConstraints constraints) {
    final colors = Theme.of(context).colorScheme;
    final safeArea = MediaQuery.paddingOf(context);

    final width = MapPanelLayout.sidePanelWidth(constraints.maxWidth);

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          0,
          safeArea.top + 12,
          safeArea.right + 12,
          safeArea.bottom + 12,
        ),
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: Material(
            color: colors.surfaceContainerLow,
            elevation: 12,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(24),
            child: widget.contentBuilder(context, _sideScrollController, false),
          ),
        ),
      ),
    );
  }
}
