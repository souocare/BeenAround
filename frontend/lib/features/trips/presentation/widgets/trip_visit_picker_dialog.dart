import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/visit_date_precision.dart';

import '../../../explore/data/countries_repository.dart';
import '../../../geography/domain/city_visits_repository.dart';

/// Opens a picker for an existing country visit.
///
/// Returns the selected visit ID, or null when dismissed.
///
/// Opens a picker for existing country visits.
///
/// Returns selected visit IDs, or null when dismissed.
Future<List<String>?> showTripCountryVisitPicker({
  required BuildContext context,
  required Set<String> excludedVisitIds,
  Set<String> initiallySelectedVisitIds = const {},
}) {
  final repository = context.read<CountriesRepository>();

  return _showTripVisitPicker(
    context: context,
    title: 'Add country visits',
    searchHint: 'Search country visits',
    emptyMessage: 'No country visits available.',
    initiallySelectedVisitIds: initiallySelectedVisitIds,
    excludedVisitIds: excludedVisitIds,
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
}) {
  final repository = context.read<CityVisitsRepository>();

  return _showTripVisitPicker(
    context: context,
    title: 'Add city visits',
    searchHint: 'Search city visits',
    emptyMessage: 'No city visits available.',
    excludedVisitIds: excludedVisitIds,
    initiallySelectedVisitIds: initiallySelectedVisitIds,
    loadVisits: () async {
      final visits = await repository.getCityVisits();

      return visits
          .map((visit) {
            return _VisitOption(
              id: visit.id,
              title: visit.cityName,
              subtitle: visit.countryName,
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
}) {
  Widget buildPicker() {
    return _TripVisitPickerDialog(
      title: title,
      searchHint: searchHint,
      emptyMessage: emptyMessage,
      excludedVisitIds: excludedVisitIds,
      initiallySelectedVisitIds: initiallySelectedVisitIds,
      loadVisits: loadVisits,
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
    required this.searchText,
    required this.startedOn,
    required this.startedOnPrecision,
    required this.endedOn,
    required this.endedOnPrecision,
    this.subtitle,
  });

  final String id;
  final String title;
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
  });

  final String title;
  final String searchHint;
  final String emptyMessage;

  final Set<String> excludedVisitIds;
  final Set<String> initiallySelectedVisitIds;

  final Future<List<_VisitOption>> Function() loadVisits;

  @override
  State<_TripVisitPickerDialog> createState() => _TripVisitPickerDialogState();
}

class _TripVisitPickerDialogState extends State<_TripVisitPickerDialog> {
  final TextEditingController _searchController = TextEditingController();

  List<_VisitOption> _visits = const [];

  bool _isLoading = true;
  String? _errorMessage;

  int _loadGeneration = 0;
  late final Set<String> _selectedVisitIds;

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
      final visits = await widget.loadVisits();

      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _visits = List.unmodifiable(
          visits.where((visit) => !widget.excludedVisitIds.contains(visit.id)),
        );

        final availableIds = _visits.map((visit) => visit.id).toSet();

        _selectedVisitIds.removeWhere((id) => !availableIds.contains(id));

        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load your visits.';
      });
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

        return Card(
          key: Key('tripVisitOption-${visit.id}'),
          margin: const EdgeInsets.symmetric(vertical: 5),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              visit.title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (visit.subtitle != null) Text(visit.subtitle!),
                const SizedBox(height: 4),
                Text(_formatDateRange(visit)),
              ],
            ),
            trailing: Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => _toggleVisit(visit.id),
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
                'Select existing visits to add to this Trip.',
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

        const Divider(height: 1),

        Padding(
          padding: const EdgeInsets.all(16),
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
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('confirmTripVisitPickerButton'),
                      onPressed: selectedCount == 0
                          ? null
                          : () {
                              Navigator.of(
                                context,
                              ).pop(_selectedVisitIds.toList(growable: false));
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
      ],
    );
  }
}
