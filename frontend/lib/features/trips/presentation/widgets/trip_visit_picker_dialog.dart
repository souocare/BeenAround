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
Future<String?> showTripCountryVisitPicker({
  required BuildContext context,
  required Set<String> excludedVisitIds,
}) {
  final repository = context.read<CountriesRepository>();

  return showDialog<String>(
    context: context,
    builder: (_) => _TripVisitPickerDialog(
      title: 'Add country visit',
      searchHint: 'Search country visits',
      emptyMessage: 'No country visits available.',
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
    ),
  );
}

/// Opens a picker for an existing city visit.
///
/// Returns the selected visit ID, or null when dismissed.
Future<String?> showTripCityVisitPicker({
  required BuildContext context,
  required Set<String> excludedVisitIds,
}) {
  final repository = context.read<CityVisitsRepository>();

  return showDialog<String>(
    context: context,
    builder: (_) => _TripVisitPickerDialog(
      title: 'Add city visit',
      searchHint: 'Search city visits',
      emptyMessage: 'No city visits available.',
      excludedVisitIds: excludedVisitIds,
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
    ),
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
    required this.loadVisits,
  });

  final String title;
  final String searchHint;
  final String emptyMessage;

  final Set<String> excludedVisitIds;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    ++_loadGeneration;
    _searchController.dispose();
    super.dispose();
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

        return ListTile(
          key: Key('tripVisitOption-${visit.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          title: Text(visit.title),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (visit.subtitle != null) Text(visit.subtitle!),
              Text(_formatDateRange(visit)),
            ],
          ),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () {
            Navigator.of(context).pop(visit.id);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              key: const Key('tripVisitPickerSearch'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Expanded(child: _buildContent()),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancelTripVisitPickerButton'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
