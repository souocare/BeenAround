import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/api_exception.dart';

import '../../domain/trip.dart';
import '../../domain/trip_repository.dart';

/// Returns true only when the Trip was successfully deleted.
Future<bool> showDeleteTripDialog({
  required BuildContext context,
  required Trip trip,
}) async {
  final repository = context.read<TripRepository>();

  final deleted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteTripDialog(trip: trip, repository: repository),
  );

  return deleted ?? false;
}

class _DeleteTripDialog extends StatefulWidget {
  const _DeleteTripDialog({required this.trip, required this.repository});

  final Trip trip;
  final TripRepository repository;

  @override
  State<_DeleteTripDialog> createState() => _DeleteTripDialogState();
}

class _DeleteTripDialogState extends State<_DeleteTripDialog> {
  bool _isDeleting = false;
  String? _errorMessage;

  Future<void> _delete() async {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await widget.repository.deleteTrip(tripId: widget.trip.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isDeleting = false;
        _errorMessage = 'Unable to delete this Trip. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return PopScope(
      canPop: !_isDeleting,
      child: AlertDialog(
        title: const Text('Delete Trip?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${widget.trip.name}"?'),

            const SizedBox(height: AppSpacing.md),

            Text(
              'This Trip will be permanently deleted. '
              'Your country visits, city visits and flights '
              'will not be deleted.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.lg),

              Text(
                _errorMessage!,
                key: const Key('deleteTripError'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.error,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            key: const Key('cancelDeleteTripButton'),
            onPressed: _isDeleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),

          FilledButton(
            key: const Key('confirmDeleteTripButton'),
            onPressed: _isDeleting ? null : _delete,
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            child: _isDeleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Delete Trip'),
          ),
        ],
      ),
    );
  }
}
