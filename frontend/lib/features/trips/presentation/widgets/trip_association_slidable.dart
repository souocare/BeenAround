import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../app/theme/app_tokens.dart';

/// Provides a swipe-to-remove interaction for a Trip association.
///
/// This widget never deletes travel records itself.
/// Confirmation, mutation and error handling belong to the caller.
///
/// The caller updates the association state after a successful mutation.
class TripAssociationSlidable extends StatefulWidget {
  const TripAssociationSlidable({
    required this.associationId,
    required this.removeLabel,
    required this.onRemoveRequested,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final String associationId;
  final String removeLabel;
  final Future<void> Function() onRemoveRequested;
  final Widget child;
  final bool enabled;

  @override
  State<TripAssociationSlidable> createState() =>
      _TripAssociationSlidableState();
}

class _TripAssociationSlidableState extends State<TripAssociationSlidable> {
  bool _isRequestingRemoval = false;

  bool get _canRemove => widget.enabled && !_isRequestingRemoval;

  bool _showDesktopActions(BuildContext context) {
    if (kIsWeb) return true;

    final platform = Theme.of(context).platform;

    return platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
  }

  /// Prevents overlapping removal requests.
  ///
  /// The lock remains active during the confirmation dialog and
  /// any subsequent association mutation.
  Future<void> _requestRemoval() async {
    if (!_canRemove) return;

    setState(() {
      _isRequestingRemoval = true;
    });

    try {
      await widget.onRemoveRequested();
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingRemoval = false;
        });
      }
    }
  }

  Widget _buildSlidable(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Slidable(
      key: ValueKey('slidable-${widget.associationId}'),
      enabled: _canRemove,
      groupTag: 'trip-associations',
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.28,
        dismissible: DismissiblePane(
          closeOnCancel: true,

          // A full swipe requests confirmation but never directly
          // removes the association from the widget tree.
          confirmDismiss: () async {
            await _requestRemoval();
            return false;
          },

          onDismissed: () {},
        ),
        children: [
          SlidableAction(
            key: ValueKey('removeSwipe-${widget.associationId}'),
            onPressed: (_) {
              _requestRemoval();
            },
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
            borderRadius: BorderRadius.circular(AppRadius.md),
            icon: Icons.delete_outline,
            label: widget.removeLabel,
          ),
        ],
      ),

      // Screen readers can request removal without performing
      // a horizontal swipe.
      child: Semantics(
        container: true,
        customSemanticsActions: _canRemove
            ? {
                CustomSemanticsAction(
                  label: '${widget.removeLabel} association from Trip',
                ): () {
                  _requestRemoval();
                },
              }
            : const {},
        child: widget.child,
      ),
    );
  }

  Widget _buildDesktopMenu(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      key: ValueKey('associationMenu-${widget.associationId}'),
      tooltip: 'Association actions',
      enabled: _canRemove,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) {
        if (value == 'delete') {
          _requestRemoval();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: colors.error, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Text(widget.removeLabel, style: TextStyle(color: colors.error)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showDesktopActions(context)) {
      return _buildSlidable(context);
    }

    return Row(
      children: [
        Expanded(child: _buildSlidable(context)),
        _buildDesktopMenu(context),
      ],
    );
  }
}
