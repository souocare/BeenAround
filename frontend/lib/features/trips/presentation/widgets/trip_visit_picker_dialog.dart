import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/visit_date_precision.dart';

import '../../../explore/data/countries_repository.dart';
import '../../../geography/domain/city_visits_repository.dart';
import '../../../../app/widgets/country_flag.dart';

/// Opens a picker for existing country visits.
///
/// Returns selected visit IDs, or null when dismissed.
Future<List<String>?> showTripCountryVisitPicker({
  required BuildContext context,
  required Set<String> excludedVisitIds,
  Set<String> initiallySelectedVisitIds = const {},
  Future<String?> Function()? createVisit,
}) {
  final repository = context.read<CountriesRepository>();

  return _showTripVisitPicker(
    context: context,
    title: 'Add country visits',
    searchHint: 'Search country visits',
    emptyMessage: 'No country visits available.',
    initiallySelectedVisitIds: initiallySelectedVisitIds,
    excludedVisitIds: excludedVisitIds,
    createVisit: createVisit,
    createLabel: 'Create new country visit',
    loadVisits: () async {
      final results = await Future.wait<Object>([
        repository.getCountries(),
        repository.getCountryVisits(),
      ]);

      final countries = results[0] as List<Country>;
      final visits = results[1] as List<CountryVisit>;

      final countryNames = {
        for (final country in countries) country.code: country.name,
      };

      return visits
          .map((visit) {
            final countryName =
                countryNames[visit.countryCode] ?? visit.countryCode;

            return _VisitOption(
              id: visit.id,
              title: countryName,
              countryCode: visit.countryCode,
              subtitle: countryName == visit.countryCode
                  ? null
                  : visit.countryCode,
              searchText: '$countryName ${visit.countryCode}',
              startedOn: visit.startedOn,
              startedOnPrecision: visit.startedOnPrecision,
              endedOn: visit.endedOn,
              endedOnPrecision: visit.endedOnPrecision,
            );
          })
          .toList(growable: false);
    },
  );
}

/// Opens a picker for an existing city visit.
///
/// Returns the selected visit ID, or null when dismissed.
/// Opens a picker for existing city visits.
///
/// Returns selected visit IDs, or null when dismissed.
Future<List<String>?> showTripCityVisitPicker({
  required BuildContext context,
  required Set<String> excludedVisitIds,
  Set<String> initiallySelectedVisitIds = const {},
  Future<String?> Function()? createVisit,
}) {
  final repository = context.read<CityVisitsRepository>();

  return _showTripVisitPicker(
    context: context,
    title: 'Add city visits',
    searchHint: 'Search city visits',
    emptyMessage: 'No city visits available.',
    excludedVisitIds: excludedVisitIds,
    initiallySelectedVisitIds: initiallySelectedVisitIds,
    createVisit: createVisit,
    createLabel: 'Create new city visit',
    loadVisits: () async {
      final visits = await repository.getCityVisits();

      return visits
          .map((visit) {
            return _VisitOption(
              id: visit.id,
              title: visit.cityName,
              subtitle: visit.countryName,
              countryCode: visit.countryCode,
              searchText:
                  '${visit.cityName} ${visit.countryName} '
                  '${visit.countryCode}',
              startedOn: visit.startedOn,
              startedOnPrecision: visit.startedOnPrecision,
              endedOn: visit.endedOn,
              endedOnPrecision: visit.endedOnPrecision,
            );
          })
          .toList(growable: false);
    },
  );
}

Future<List<String>?> _showTripVisitPicker({
  required BuildContext context,
  required String title,
  required String searchHint,
  required String emptyMessage,
  required Set<String> excludedVisitIds,
  required Set<String> initiallySelectedVisitIds,
  required Future<List<_VisitOption>> Function() loadVisits,
  required Future<String?> Function()? createVisit,
  required String createLabel,
}) {
  Widget buildPicker() {
    return _TripVisitPickerDialog(
      title: title,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
      excludedVisitIds: excludedVisitIds,
      initiallySelectedVisitIds: initiallySelectedVisitIds,
      loadVisits: loadVisits,
      createVisit: createVisit,
      createLabel: createLabel,
    );
  }

  if (MediaQuery.sizeOf(context).width >= 800) {
    return showDialog<List<String>>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
          child: buildPicker(),
        ),
      ),
    );
  }

  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      final height = MediaQuery.sizeOf(context).height * 0.9;

      return SizedBox(height: height, child: buildPicker());
    },
  );
}

/// Presentation-only representation of an existing visit.
///
/// This is not a new domain model.
class _VisitOption {
  const _VisitOption({
    required this.id,
    required this.title,
    required this.countryCode,
    required this.searchText,
    required this.startedOn,
    required this.startedOnPrecision,
    required this.endedOn,
    required this.endedOnPrecision,
    this.subtitle,
  });

  final String id;
  final String title;
  final String countryCode;
  final String? subtitle;
  final String searchText;

  final DateTime? startedOn;
  final VisitDatePrecision? startedOnPrecision;

  final DateTime? endedOn;
  final VisitDatePrecision? endedOnPrecision;
}

class _TripVisitPickerDialog extends StatefulWidget {
  const _TripVisitPickerDialog({
    required this.title,
    required this.searchHint,
    required this.emptyMessage,
    required this.excludedVisitIds,
    required this.initiallySelectedVisitIds,
    required this.loadVisits,
    required this.createVisit,
    required this.createLabel,
  });

  final String title;
  final String searchHint;
  final String emptyMessage;

  final Set<String> excludedVisitIds;
  final Set<String> initiallySelectedVisitIds;
  final Future<String?> Function()? createVisit;
  final String createLabel;

  final Future<List<_VisitOption>> Function() loadVisits;

  @override
  State<_TripVisitPickerDialog> createState() => _TripVisitPickerDialogState();
}

class _TripVisitPickerDialogState extends State<_TripVisitPickerDialog> {
  final TextEditingController _searchController = TextEditingController();

  List<_VisitOption> _visits = const [];

  bool _isLoading = true;
  bool _isCreatingVisit = false;

  String? _errorMessage;

  int _loadGeneration = 0;

  late final Set<String> _selectedVisitIds;

  final Set<String> _newlyCreatedIds = {};

  /// Persisted visits awaiting confirmation from the repository.
  ///
  /// A pending visit is never selectable until it appears in a
  /// successful repository response.
  final Set<String> _pendingCreatedVisitIds = {};

  @override
  void initState() {
    super.initState();

    _selectedVisitIds = {...widget.initiallySelectedVisitIds}
      ..removeAll(widget.excludedVisitIds);

    _load();
  }

  @override
  void dispose() {
    ++_loadGeneration;
    _searchController.dispose();
    super.dispose();
  }

  void _toggleVisit(String visitId) {
    setState(() {
      if (!_selectedVisitIds.add(visitId)) {
        _selectedVisitIds.remove(visitId);
      }
    });
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loadedVisits = await widget.loadVisits();

      if (!mounted || generation != _loadGeneration) {
        return;
      }

      // Excluded visits cannot be selected or associated again.
      final availableVisits = loadedVisits
          .where((visit) => !widget.excludedVisitIds.contains(visit.id))
          .toList(growable: false);

      final availableById = <String, _VisitOption>{
        for (final visit in availableVisits) visit.id: visit,
      };

      final availableIds = availableById.keys.toSet();

      // A newly created visit must be confirmed by a successful
      // repository response before becoming selectable.
      final resolvedPendingIds = _pendingCreatedVisitIds
          .where(availableIds.contains)
          .toSet();

      final unresolvedPendingIds = _pendingCreatedVisitIds.difference(
        resolvedPendingIds,
      );

      // Do not silently lose a successfully persisted visit.
      //
      // Keep its ID pending so Retry can recover it without
      // creating another record.
      if (unresolvedPendingIds.isNotEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Your visit was created, but could not be found '
              'in the refreshed list. Please retry.';
        });

        return;
      }

      setState(() {
        // Reconcile selections with the repository.
        //
        // Stale or excluded IDs must never be returned to the caller.
        _selectedVisitIds.removeWhere((id) => !availableIds.contains(id));

        // Resolve newly created visits only after verifying that
        // they exist in the repository response.
        for (final visitId in resolvedPendingIds) {
          _pendingCreatedVisitIds.remove(visitId);
          _newlyCreatedIds.add(visitId);
          _selectedVisitIds.add(visitId);
        }

        // Display newly created visits first, newest first.
        final newVisits = _newlyCreatedIds
            .toList()
            .reversed
            .where(availableById.containsKey)
            .map((id) => availableById[id]!)
            .toList(growable: false);

        final existingVisits = availableById.values
            .where((visit) => !_newlyCreatedIds.contains(visit.id))
            .toList(growable: false);

        _visits = List.unmodifiable([...newVisits, ...existingVisits]);

        // A search should not hide the visit that was just created.
        if (resolvedPendingIds.isNotEmpty) {
          _searchController.clear();
        }

        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      setState(() {
        _isLoading = false;

        _errorMessage = _pendingCreatedVisitIds.isNotEmpty
            ? 'Your visit was created, but the list could not '
                  'be refreshed. Please retry.'
            : 'Unable to load your visits.';
      });
    }
  }

  Future<void> _createVisit() async {
    final createVisit = widget.createVisit;

    if (createVisit == null ||
        _isCreatingVisit ||
        _isLoading ||
        _pendingCreatedVisitIds.isNotEmpty) {
      return;
    }

    setState(() {
      _isCreatingVisit = true;
    });

    try {
      final createdVisitId = await createVisit();

      if (!mounted) {
        return;
      }

      // Canceling the creation form changes nothing.
      if (createdVisitId == null) {
        return;
      }

      // The record already exists independently of any Trip.
      //
      // Keep the ID until the repository confirms it.
      _pendingCreatedVisitIds.add(createdVisitId);

      // Reload and reconcile all selections.
      //
      // If loading fails, the ID remains pending and can be
      // recovered through Retry.
      await _load();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to complete visit creation. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingVisit = false;
        });
      }
    }
  }

  List<_VisitOption> get _filteredVisits {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return _visits;
    }

    return _visits
        .where((visit) => visit.searchText.toLowerCase().contains(query))
        .toList(growable: false);
  }

  String _formatDate(DateTime date, VisitDatePrecision? precision) {
    final localization = MaterialLocalizations.of(context);

    return switch (precision ?? VisitDatePrecision.day) {
      VisitDatePrecision.day => localization.formatMediumDate(date),
      VisitDatePrecision.month => localization.formatMonthYear(date),
      VisitDatePrecision.year => '${date.year}',
    };
  }

  String _formatDateRange(_VisitOption visit) {
    final start = visit.startedOn;
    final end = visit.endedOn;

    if (start == null && end == null) {
      return 'Dates unknown';
    }

    if (start != null && end == null) {
      return 'From ${_formatDate(start, visit.startedOnPrecision)}';
    }

    if (start == null && end != null) {
      return 'Until ${_formatDate(end, visit.endedOnPrecision)}';
    }

    return '${_formatDate(start!, visit.startedOnPrecision)} – '
        '${_formatDate(end!, visit.endedOnPrecision)}';
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(key: Key('tripVisitPickerLoading')),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              key: const Key('tripVisitPickerError'),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              key: const Key('retryTripVisitPickerButton'),
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final visits = _filteredVisits;

    if (visits.isEmpty) {
      final hasSearch = _searchController.text.trim().isNotEmpty;

      return Center(
        child: Text(
          hasSearch ? 'No matching visits.' : widget.emptyMessage,
          key: const Key('tripVisitPickerEmpty'),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      key: const Key('tripVisitPickerList'),
      itemCount: visits.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final visit = visits[index];

        final selected = _selectedVisitIds.contains(visit.id);

        return CheckboxListTile.adaptive(
          key: Key('tripVisitOption-${visit.id}'),

          value: selected,

          onChanged: (_) => _toggleVisit(visit.id),

          controlAffinity: ListTileControlAffinity.leading,

          activeColor: Theme.of(context).colorScheme.primary,
          checkColor: Theme.of(context).colorScheme.onPrimary,

          tileColor: Colors.transparent,
          selectedTileColor: Colors.transparent,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),

          title: Row(
            children: [
              CountryFlag(countryCode: visit.countryCode, size: 22),

              const SizedBox(width: AppSpacing.sm),

              Expanded(
                child: Text(
                  visit.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (_newlyCreatedIds.contains(visit.id)) ...[
                const SizedBox(width: AppSpacing.sm),

                const Badge(label: Text('NEW')),
              ],
            ],
          ),

          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visit.subtitle != null) ...[
                Text(
                  visit.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: AppSpacing.xs),
              ],

              Text(_formatDateRange(visit), maxLines: 2),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final selectedCount = _selectedVisitIds.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.createVisit == null
                    ? 'Select existing visits to add to this Trip.'
                    : 'Select existing visits or create a new one.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            key: const Key('tripVisitPickerSearch'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildContent(),
          ),
        ),

        if (widget.createVisit != null) ...[
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: OutlinedButton.icon(
              key: const Key('createVisitFromPickerButton'),
              onPressed:
                  _isCreatingVisit ||
                      _isLoading ||
                      _pendingCreatedVisitIds.isNotEmpty
                  ? null
                  : _createVisit,
              icon: Icon(
                _isCreatingVisit
                    ? Icons.hourglass_top_rounded
                    : Icons.add_circle_outline_rounded,
              ),
              label: Text(
                _isCreatingVisit ? 'Creating visit...' : widget.createLabel,
              ),
            ),
          ),
        ],

        const Divider(height: 1),

        const Divider(height: 1),

        SafeArea(
          top: false,
          left: false,
          right: false,
          minimum: const EdgeInsets.only(bottom: AppSpacing.xxl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$selectedCount '
                  '${selectedCount == 1 ? 'visit' : 'visits'} selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        key: const Key('cancelTripVisitPickerButton'),
                        onPressed: _isCreatingVisit
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        key: const Key('confirmTripVisitPickerButton'),
                        onPressed:
                            selectedCount == 0 ||
                                _isCreatingVisit ||
                                _isLoading ||
                                _errorMessage != null ||
                                _pendingCreatedVisitIds.isNotEmpty
                            ? null
                            : () {
                                Navigator.of(context).pop(
                                  _selectedVisitIds.toList(growable: false),
                                );
                              },
                        child: Text(
                          'Add $selectedCount '
                          '${selectedCount == 1 ? 'visit' : 'visits'}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
