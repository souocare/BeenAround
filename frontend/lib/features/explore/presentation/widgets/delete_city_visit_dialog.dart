import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/delete_city_visit_cubit.dart';
import '../../application/delete_city_visit_state.dart';
import '../../domain/visited_city.dart';
import '../../../geography/domain/city_visit.dart';

class DeleteCityVisitDialog extends StatelessWidget {
  const DeleteCityVisitDialog({
    required this.city,
    required this.visit,
    super.key,
  });

  final VisitedCity city;
  final CityVisit visit;

  Future<void> _delete(BuildContext context) async {
    final success = await context.read<DeleteCityVisitCubit>().delete(
      visitId: visit.id,
    );

    if (!context.mounted || !success) return;

    Navigator.of(context).pop(true);
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String _formatVisitDates() {
    final start = visit.startedOn;
    final end = visit.endedOn;

    if (start == null && end == null) {
      return 'Dates not specified';
    }

    if (start != null && end == null) {
      return 'From ${_formatDate(start)}';
    }

    if (start == null && end != null) {
      return 'Until ${_formatDate(end)}';
    }

    return '${_formatDate(start!)} – ${_formatDate(end!)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return BlocBuilder<DeleteCityVisitCubit, DeleteCityVisitState>(
      builder: (context, state) {
        return AlertDialog(
          title: const Text('Delete visit?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this visit to '
                '${city.cityName}, ${city.countryName}?',
              ),

              const SizedBox(height: 12),

              Text(
                _formatVisitDates(),
                key: const Key('deleteCityVisitDates'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 12),

              const Text('This action cannot be undone.'),

              if (state.errorMessage != null) ...[
                const SizedBox(height: 16),

                Text(
                  state.errorMessage!,
                  style: TextStyle(color: colors.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              key: const Key('cancelDeleteCityVisit'),
              onPressed: state.isDeleting
                  ? null
                  : () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),

            FilledButton(
              key: const Key('confirmDeleteCityVisit'),
              onPressed:
                  state.isDeleting ||
                      state.phase == DeleteCityVisitPhase.success
                  ? null
                  : () => _delete(context),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
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
