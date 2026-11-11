import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/api_exception.dart';

import '../../domain/trip.dart';
import '../../domain/trip_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Returns true only when the Trip was successfully deleted.
Future<bool> showDeleteTripDialog({
  required BuildContext context,
  required Trip trip,
}) async {
  final repository = context.read<TripRepository>();

  final useCupertino = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  final dialog = _DeleteTripDialog(
    trip: trip,
    repository: repository,
    useCupertino: useCupertino,
  );

  final bool? deleted;

  if (useCupertino) {
    deleted = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
  } else {
    deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
  }

  return deleted ?? false;
}

class _DeleteTripDialog extends StatefulWidget {
  const _DeleteTripDialog({
    required this.trip,
    required this.repository,
    required this.useCupertino,
  });

  final Trip trip;
  final TripRepository repository;
  final bool useCupertino;

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

  Widget _buildCupertinoDialog() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: theme.brightness,
        primaryColor: colors.primary,
      ),
      child: CupertinoAlertDialog(
        key: const Key('cupertinoDeleteTripDialog'),
        title: const Text('Delete Trip?'),
        content: Column(
          children: [
            const SizedBox(height: 12),

            Text('Are you sure you want to delete "${widget.trip.name}"?'),

            const SizedBox(height: 12),

            const Text(
              'This Trip will be permanently deleted. '
              'Your visits and flights will remain in your travel history.',
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 12),

              Text(
                _errorMessage!,
                key: const Key('deleteTripError'),
                style: TextStyle(
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(
            key: const Key('cancelDeleteTripButton'),
            onPressed: _isDeleting
                ? null
                : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),

          CupertinoDialogAction(
            key: const Key('confirmDeleteTripButton'),
            isDestructiveAction: true,
            onPressed: _isDeleting ? null : _delete,
            child: _isDeleting
                ? const CupertinoActivityIndicator()
                : const Text('Delete Trip'),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialDialog() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
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
              style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDeleting,
      child: widget.useCupertino
          ? _buildCupertinoDialog()
          : _buildMaterialDialog(),
    );
  }
}
