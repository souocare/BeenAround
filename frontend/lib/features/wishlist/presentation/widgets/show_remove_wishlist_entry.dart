import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/wishlist_entry_actions_cubit.dart';
import '../../application/wishlist_entry_actions_state.dart';
import '../../domain/wishlist_entry.dart';
import '../../domain/wishlist_repository.dart';

Future<bool> showRemoveWishlistEntry({
  required BuildContext context,
  required WishlistEntry entry,
  required String destinationName,
}) async {
  final repository = context.read<WishlistRepository>();

  final removed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) => WishlistEntryActionsCubit(repository: repository),
      child: _RemoveWishlistEntryDialog(
        entry: entry,
        destinationName: destinationName,
      ),
    ),
  );

  return removed ?? false;
}

class _RemoveWishlistEntryDialog extends StatelessWidget {
  const _RemoveWishlistEntryDialog({
    required this.entry,
    required this.destinationName,
  });

  final WishlistEntry entry;
  final String destinationName;

  bool get _isCupertino =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _remove(BuildContext context) async {
    final success = await context.read<WishlistEntryActionsCubit>().deleteEntry(
      entryId: entry.id,
    );

    if (!context.mounted || !success) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BlocBuilder<WishlistEntryActionsCubit, WishlistEntryActionsState>(
      builder: (context, state) {
        final isSubmitting = state.isSubmitting;

        final message =
            'Remove $destinationName from your Wishlist? '
            'Your visits and residences will not be affected.';

        if (_isCupertino) {
          return CupertinoAlertDialog(
            title: const Text('Remove from Wishlist?'),
            content: Column(
              children: [
                const SizedBox(height: 8),
                Text(message),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage!,
                    key: const Key('removeWishlistError'),
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                ],
              ],
            ),
            actions: [
              CupertinoDialogAction(
                key: const Key('cancelRemoveWishlist'),
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                key: const Key('confirmRemoveWishlist'),
                isDestructiveAction: true,
                onPressed: isSubmitting ? null : () => _remove(context),
                child: Text(isSubmitting ? 'Removing...' : 'Remove'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: const Text('Remove from Wishlist?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  key: const Key('removeWishlistError'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const Key('cancelRemoveWishlist'),
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirmRemoveWishlist'),
              onPressed: isSubmitting ? null : () => _remove(context),
              child: Text(
                isSubmitting ? 'Removing...' : 'Remove',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}
