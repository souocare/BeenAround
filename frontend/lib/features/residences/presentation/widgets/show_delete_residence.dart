import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/delete_residence_cubit.dart';
import '../../application/delete_residence_state.dart';
import '../../domain/residence.dart';
import '../../domain/residence_repository.dart';

Future<bool> showDeleteResidence({
  required BuildContext context,
  required Residence residence,
}) async {
  final repository = context.read<ResidenceRepository>();

  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) => DeleteResidenceCubit(repository: repository),
      child: _DeleteResidenceDialog(residence: residence),
    ),
  );

  return deleted ?? false;
}

class _DeleteResidenceDialog extends StatelessWidget {
  const _DeleteResidenceDialog({required this.residence});

  final Residence residence;

  bool get _isCupertino =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> _delete(BuildContext context) async {
    final deleted = await context.read<DeleteResidenceCubit>().deleteResidence(
      residenceId: residence.id,
    );

    if (!context.mounted || !deleted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeleteResidenceCubit, DeleteResidenceState>(
      builder: (context, state) {
        final isDeleting = state.isDeleting;

        const message =
            'This residence period will be permanently removed. '
            'Your visits, trips and Wishlist will not be affected.';

        if (_isCupertino) {
          return CupertinoAlertDialog(
            title: const Text('Delete residence?'),
            content: Column(
              children: [
                const SizedBox(height: 8),
                const Text(message),
                if (state.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage!,
                    key: const Key('deleteResidenceError'),
                    style: const TextStyle(color: CupertinoColors.systemRed),
                  ),
                ],
              ],
            ),
            actions: [
              CupertinoDialogAction(
                key: const Key('cancelDeleteResidence'),
                onPressed: isDeleting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                key: const Key('confirmDeleteResidence'),
                isDestructiveAction: true,
                onPressed: isDeleting ? null : () => _delete(context),
                child: Text(isDeleting ? 'Deleting...' : 'Delete'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: const Text('Delete residence?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(message),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  key: const Key('deleteResidenceError'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const Key('cancelDeleteResidence'),
              onPressed: isDeleting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('confirmDeleteResidence'),
              onPressed: isDeleting ? null : () => _delete(context),
              child: Text(
                isDeleting ? 'Deleting...' : 'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
        );
      },
    );
  }
}
