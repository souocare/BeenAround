import 'package:beenaround/app/theme/app_action_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum _RecordAction { edit, delete }

class AdaptiveRecordActionsMenu extends StatelessWidget {
  const AdaptiveRecordActionsMenu({
    required this.onEdit,
    required this.onDelete,
    this.editLabel = 'Edit',
    this.deleteLabel = 'Delete',
    this.tooltip = 'Record actions',
    super.key,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  final String editLabel;
  final String deleteLabel;
  final String tooltip;

  bool get _useCupertino =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _showCupertinoActions(BuildContext context) async {
    final selected = await showCupertinoModalPopup<_RecordAction>(
      context: context,
      builder: (popupContext) {
        return CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              key: const Key('recordActionEdit'),
              onPressed: () =>
                  Navigator.of(popupContext).pop(_RecordAction.edit),
              child: Text(editLabel),
            ),
            CupertinoActionSheetAction(
              key: const Key('recordActionDelete'),
              isDestructiveAction: true,
              onPressed: () =>
                  Navigator.of(popupContext).pop(_RecordAction.delete),
              child: Text(deleteLabel),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            key: const Key('recordActionCancel'),
            onPressed: () => Navigator.of(popupContext).pop(),
            child: const Text('Cancel'),
          ),
        );
      },
    );

    if (!context.mounted || selected == null) return;

    switch (selected) {
      case _RecordAction.edit:
        onEdit();

      case _RecordAction.delete:
        onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_useCupertino) {
      return IconButton(
        key: const Key('recordActionsMenu'),
        tooltip: tooltip,
        icon: Icon(AppActionIcons.more(context)),
        onPressed: () => _showCupertinoActions(context),
      );
    }

    return PopupMenuButton<_RecordAction>(
      key: const Key('recordActionsMenu'),
      tooltip: tooltip,
      icon: Icon(AppActionIcons.more(context)),
      onSelected: (action) {
        switch (action) {
          case _RecordAction.edit:
            onEdit();

          case _RecordAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) {
        final colors = Theme.of(context).colorScheme;

        return [
          PopupMenuItem(
            value: _RecordAction.edit,
            child: Row(
              children: [
                Icon(AppActionIcons.edit(context), size: 20),
                const SizedBox(width: 12),
                Text(editLabel),
              ],
            ),
          ),
          PopupMenuItem(
            value: _RecordAction.delete,
            child: Row(
              children: [
                Icon(
                  AppActionIcons.delete(context),
                  size: 20,
                  color: colors.error,
                ),
                const SizedBox(width: 12),
                Text(deleteLabel, style: TextStyle(color: colors.error)),
              ],
            ),
          ),
        ];
      },
    );
  }
}
