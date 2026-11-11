import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../application/trip_suggestions.dart';
import '../../domain/trip_association_repository.dart';
import '../../domain/trip_date_compatibility.dart';

/// Suggests compatible Trips for an already persisted visit.
///
/// Closing this dialog never deletes or modifies the visit.
/// Associations require an explicit user action.
Future<void> showSuggestedTripsDialog({
  required BuildContext context,
  required String visitId,
  required bool isCountry,
  required String destinationName,
  required List<TripSuggestion> suggestions,
  required TripAssociationRepository associationRepository,
}) async {
  if (suggestions.isEmpty) return;

  final useCupertino = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  final dialog = _SuggestedTripsDialog(
    visitId: visitId,
    isCountry: isCountry,
    destinationName: destinationName,
    suggestions: suggestions,
    associationRepository: associationRepository,
    useCupertino: useCupertino,
  );

  if (useCupertino) {
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
  } else {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => dialog,
    );
  }
}

class _SuggestedTripsDialog extends StatefulWidget {
  const _SuggestedTripsDialog({
    required this.visitId,
    required this.isCountry,
    required this.destinationName,
    required this.suggestions,
    required this.associationRepository,
    required this.useCupertino,
  });

  final String visitId;
  final bool isCountry;
  final String destinationName;
  final List<TripSuggestion> suggestions;
  final TripAssociationRepository associationRepository;
  final bool useCupertino;

  @override
  State<_SuggestedTripsDialog> createState() => _SuggestedTripsDialogState();
}

class _SuggestedTripsDialogState extends State<_SuggestedTripsDialog> {
  final Set<String> _addedTripIds = {};
  final Map<String, String> _errors = {};

  String? _associatingTripId;

  bool get _isAssociating => _associatingTripId != null;

  Future<void> _addToTrip(TripSuggestion suggestion) async {
    if (_isAssociating || _addedTripIds.contains(suggestion.trip.id)) {
      return;
    }

    final tripId = suggestion.trip.id;

    setState(() {
      _associatingTripId = tripId;
      _errors.remove(tripId);
    });

    try {
      if (widget.isCountry) {
        await widget.associationRepository.addCountryVisit(
          tripId: tripId,
          visitId: widget.visitId,
        );
      } else {
        await widget.associationRepository.addCityVisit(
          tripId: tripId,
          visitId: widget.visitId,
        );
      }

      if (!mounted) return;

      setState(() {
        _addedTripIds.add(tripId);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errors[tripId] =
            'Your visit was saved, but could not be added to this Trip.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _associatingTripId = null;
        });
      }
    }
  }

  String _compatibilityLabel(TripDateCompatibility compatibility) {
    return switch (compatibility) {
      TripDateCompatibility.match => 'Dates overlap',
      TripDateCompatibility.possible => 'Possible date match',
      TripDateCompatibility.none => '',
    };
  }

  void _finish() {
    if (_isAssociating) return;
    Navigator.of(context).pop();
  }

  Widget _buildTripList({required bool cupertino}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView.separated(
      shrinkWrap: true,
      itemCount: widget.suggestions.length,
      separatorBuilder: (_, _) => SizedBox(height: cupertino ? 10 : 12),
      itemBuilder: (context, index) {
        final suggestion = widget.suggestions[index];
        final trip = suggestion.trip;

        final isAdded = _addedTripIds.contains(trip.id);
        final isLoading = _associatingTripId == trip.id;
        final error = _errors[trip.id];

        return Container(
          key: Key('suggestedTrip-${trip.id}'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cupertino
                ? colors.surfaceContainerHighest.withValues(alpha: 0.45)
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(cupertino ? 14 : 16),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trip.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _compatibilityLabel(suggestion.compatibility),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(
                  error,
                  key: Key('suggestedTripError-${trip.id}'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: isAdded
                    ? Row(
                        key: Key('suggestedTripAdded-${trip.id}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cupertino
                                ? CupertinoIcons.check_mark_circled_solid
                                : Icons.check_circle,
                            size: 17,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Added',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      )
                    : cupertino
                    ? CupertinoButton(
                        key: Key('addSuggestedTrip-${trip.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        onPressed: _isAssociating
                            ? null
                            : () => _addToTrip(suggestion),
                        child: isLoading
                            ? const CupertinoActivityIndicator()
                            : Text(error == null ? 'Add to Trip' : 'Retry'),
                      )
                    : TextButton.icon(
                        key: Key('addSuggestedTrip-${trip.id}'),
                        onPressed: _isAssociating
                            ? null
                            : () => _addToTrip(suggestion),
                        icon: isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_rounded, size: 18),
                        label: Text(error == null ? 'Add to Trip' : 'Retry'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCupertinoDialog() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final availableHeight = MediaQuery.sizeOf(context).height * 0.7;

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: theme.brightness,
        primaryColor: colors.primary,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 380,
            maxHeight: availableHeight,
          ),
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.airplane,
                          color: colors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Suggested Trips',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.destinationName} was saved successfully.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add this visit to a Trip?',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Flexible(child: _buildTripList(cupertino: true)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        key: const Key('finishSuggestedTrips'),
                        onPressed: _isAssociating ? null : _finish,
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialDialog() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      key: const Key('materialSuggestedTripsDialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: colors.primary, size: 22),
          const SizedBox(width: 10),
          const Expanded(child: Text('Suggested Trips')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.destinationName} was saved successfully.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Add this visit to a Trip?',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Flexible(child: _buildTripList(cupertino: false)),
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: const Key('finishSuggestedTrips'),
          onPressed: _isAssociating ? null : _finish,
          child: const Text('Done'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isAssociating,
      child: widget.useCupertino
          ? _buildCupertinoDialog()
          : _buildMaterialDialog(),
    );
  }
}
