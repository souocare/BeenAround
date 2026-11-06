import 'package:flutter/material.dart';
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

  Future<void> _save() async {
    if (_submitting) return;

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
    return AlertDialog(
      title: const Text('Edit Wishlist Note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('wishlistNoteField'),
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Why do you want to visit?',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const Key('wishlistNoteError'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
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
          onPressed: _submitting ? null : _save,
          child: Text(_submitting ? 'Saving...' : 'Save'),
        ),
      ],
    );
  }
}
