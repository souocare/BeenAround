import 'package:flutter/material.dart';

class WishlistEntryControls extends StatelessWidget {
  const WishlistEntryControls({
    required this.onRemove,
    required this.onEditNote,
    super.key,
  });

  final VoidCallback onRemove;
  final VoidCallback onEditNote;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionChip(
          key: const Key('wishlistStatusButton'),
          tooltip: 'Remove from Wishlist',
          onPressed: onRemove,
          avatar: Icon(Icons.favorite_rounded, color: colors.primary, size: 20),
          label: const Text('Wishlist'),
          backgroundColor: colors.primaryContainer,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          key: const Key('editWishlistNoteButton'),
          tooltip: 'Edit Wishlist note',
          onPressed: onEditNote,
          icon: const Icon(Icons.edit_outlined),
          iconSize: 20,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}
