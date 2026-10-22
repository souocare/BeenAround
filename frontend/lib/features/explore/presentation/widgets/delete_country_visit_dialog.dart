import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/delete_country_visit_cubit.dart';
import '../../application/delete_country_visit_state.dart';
import '../../domain/country.dart';
import '../../domain/country_visit.dart';

class DeleteCountryVisitDialog extends StatelessWidget {
  const DeleteCountryVisitDialog({
    required this.country,
    required this.visit,
    super.key,
  });

  final Country country;
  final CountryVisit visit;

  Future<void> _delete(BuildContext context) async {
    final success = await context.read<DeleteCountryVisitCubit>().delete(
      visitId: visit.id,
    );

    if (!context.mounted || !success) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeleteCountryVisitCubit, DeleteCountryVisitState>(
      builder: (context, state) {
        return AlertDialog(
          title: const Text('Delete visit?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this visit to '
                '${country.name}?',
              ),
              const SizedBox(height: 12),
              const Text('This action cannot be undone.'),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: state.isDeleting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirmDeleteVisit'),
              onPressed:
                  state.isDeleting ||
                      state.phase == DeleteCountryVisitPhase.success
                  ? null
                  : () => _delete(context),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: state.isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Delete visit'),
            ),
          ],
        );
      },
    );
  }
}
