import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/wishlist_entry_actions_cubit.dart';
import '../../domain/wishlist_entry.dart';
import '../../domain/wishlist_repository.dart';

Future<bool> showEditWishlistNote({
  required BuildContext context,
  required WishlistEntry entry,
}) async {
  final repository = context.read<WishlistRepository>();

  final updated = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) => WishlistEntryActionsCubit(repository: repository),
      child: _EditWishlistNoteDialog(entry: entry),
    ),
  );

  return updated ?? false;
}

class _EditWishlistNoteDialog extends StatefulWidget {
  const _EditWishlistNoteDialog({required this.entry});

  final WishlistEntry entry;

  @override
  State<_EditWishlistNoteDialog> createState() =>
      _EditWishlistNoteDialogState();
}

class _EditWishlistNoteDialogState extends State<_EditWishlistNoteDialog> {
  late final TextEditingController _controller;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.entry.note ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    return _controller.text.trim() != (widget.entry.note ?? '').trim();
  }

  Future<void> _save() async {
    if (_submitting || !_hasChanges) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final note = _controller.text.trim();

    final cubit = context.read<WishlistEntryActionsCubit>();

    final success = await cubit.updateNote(
      entryId: widget.entry.id,
      note: note.isEmpty ? null : note,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _submitting = false;
      _error = cubit.state.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      scrollable: true,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Text('Edit Wishlist Note'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What makes this destination special to you?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              key: const Key('wishlistNoteField'),
              controller: _controller,
              autofocus: true,
              enabled: !_submitting,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              onChanged: (_) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Why would you like to visit this place?',
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('wishlistNoteError'),
                style: TextStyle(color: colors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('saveWishlistNoteButton'),
          onPressed: _submitting || !_hasChanges ? null : _save,
          child: Text(_submitting ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
