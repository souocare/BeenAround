import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/api_exception.dart';

import '../../domain/trip.dart';
import '../../domain/trip_repository.dart';

/// Optional selection of an existing Trip.
///
/// This widget never creates Trips or associates visits.
/// It only reports the user's explicit selection.
class TripSelectionField extends StatefulWidget {
  const TripSelectionField({
    required this.repository,
    required this.selectedTripId,
    required this.onChanged,
    this.enabled = true,
    this.onSelectionValidityChanged,
    super.key,
  });

  final TripRepository repository;
  final String? selectedTripId;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final ValueChanged<bool>? onSelectionValidityChanged;

  @override
  State<TripSelectionField> createState() => _TripSelectionFieldState();
}

class _TripSelectionFieldState extends State<TripSelectionField> {
  late Future<List<Trip>> _tripsFuture;

  bool? _lastReportedValidity;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  @override
  void didUpdateWidget(covariant TripSelectionField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.repository != widget.repository) {
      _loadTrips();

      // The new repository has not yet been checked.
      _lastReportedValidity = null;
    }
  }

  void _loadTrips() {
    _tripsFuture = widget.repository.getTrips();
  }

  void _retry() {
    setState(() {
      _lastReportedValidity = null;
      _loadTrips();
    });
  }

  void _notifySelectionValidity(bool isValid) {
    if (_lastReportedValidity == isValid) {
      return;
    }

    _lastReportedValidity = isValid;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      widget.onSelectionValidityChanged?.call(isValid);
    });
  }

  Future<void> _selectTrip(List<Trip> trips) async {
    if (!widget.enabled) {
      return;
    }

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return SimpleDialog(
          key: const Key('selectExistingTripDialog'),
          title: const Text('Select Trip'),
          children: [
            SimpleDialogOption(
              key: const Key('selectNoTripOption'),
              onPressed: () {
                Navigator.of(dialogContext).pop('');
              },
              child: const Text('None'),
            ),

            for (final trip in trips)
              SimpleDialogOption(
                key: Key('selectTrip-${trip.id}'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(trip.id);
                },
                child: Row(
                  children: [
                    Expanded(child: Text(trip.name)),
                    if (widget.selectedTripId == trip.id)
                      const Icon(Icons.check),
                  ],
                ),
              ),
          ],
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    // Empty string represents the explicit "None" option.
    widget.onChanged(selected.isEmpty ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return FutureBuilder<List<Trip>>(
      future: _tripsFuture,
      builder: (context, snapshot) {
        // Loading does not mean that a selected Trip is invalid.
        if (snapshot.connectionState != ConnectionState.done) {
          return const ListTile(
            key: Key('tripSelectionLoading'),
            title: Text('Add to Trip (optional)'),
            subtitle: LinearProgressIndicator(),
          );
        }

        // A network failure does not mean that the selected Trip
        // has been deleted.
        if (snapshot.hasError) {
          final error = snapshot.error;

          final message = error is ApiException
              ? error.message
              : 'Unable to load your Trips.';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to Trip (optional)', style: theme.textTheme.titleSmall),

              const SizedBox(height: AppSpacing.sm),

              Text(
                message,
                key: const Key('tripSelectionError'),
                style: TextStyle(color: colors.error),
              ),

              TextButton.icon(
                key: const Key('retryTripSelectionButton'),
                onPressed: widget.enabled ? _retry : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          );
        }

        final availableTrips = snapshot.data ?? const <Trip>[];

        Trip? selectedTrip;

        for (final trip in availableTrips) {
          if (trip.id == widget.selectedTripId) {
            selectedTrip = trip;
            break;
          }
        }

        final hasUnavailableSelection =
            widget.selectedTripId != null && selectedTrip == null;

        // Only report validity after a successful catalog load.
        _notifySelectionValidity(!hasUnavailableSelection);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add to Trip (optional)', style: theme.textTheme.titleSmall),

            const SizedBox(height: AppSpacing.sm),

            OutlinedButton(
              key: const Key('selectExistingTripButton'),
              onPressed: widget.enabled
                  ? () => _selectTrip(availableTrips)
                  : null,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasUnavailableSelection
                          ? 'Selected Trip unavailable'
                          : selectedTrip?.name ?? 'None selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),

            if (hasUnavailableSelection) ...[
              const SizedBox(height: AppSpacing.xs),

              Text(
                'The selected Trip is no longer available. '
                'Please choose another Trip or select None.',
                key: const Key('selectedTripUnavailableMessage'),
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],

            if (availableTrips.isEmpty && !hasUnavailableSelection) ...[
              const SizedBox(height: AppSpacing.xs),

              Text(
                'You have no Trips yet.',
                key: const Key('noTripsAvailableMessage'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
