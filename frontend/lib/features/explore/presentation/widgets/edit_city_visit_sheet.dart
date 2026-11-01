import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/edit_city_visit_cubit.dart';
import '../../application/edit_city_visit_state.dart';
import '../../domain/visited_city.dart';
import '../../../geography/domain/city_visit.dart';
import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';
import '../../domain/country_visit_date_validator.dart';
import 'partial_visit_date_picker.dart';
import 'country_visit_date_expansion_dialog.dart';
import '../../data/countries_repository.dart';
import '../../domain/country_visit.dart';

class EditCityVisitSheet extends StatefulWidget {
  const EditCityVisitSheet({
    required this.city,
    required this.visit,
    super.key,
  });

  final VisitedCity city;
  final CityVisit visit;

  @override
  State<EditCityVisitSheet> createState() => _EditCityVisitSheetState();
}

class _EditCityVisitSheetState extends State<EditCityVisitSheet> {
  DateTime? _startedOn;
  DateTime? _endedOn;
  VisitDatePrecision? _startedOnPrecision;
  VisitDatePrecision? _endedOnPrecision;
  String? _selectedCountryVisitId;

  List<CountryVisit> _availableCountryVisits = const [];

  bool _loadingCountryVisits = false;
  bool _countryVisitsLoaded = false;

  String? _countryVisitsError;
  String? _associationSelectionError;
  bool _showCountryVisitOptions = false;

  @override
  void initState() {
    super.initState();
    _selectedCountryVisitId = widget.visit.countryVisitId;
    _showCountryVisitOptions = _selectedCountryVisitId != null;
    _startedOn = widget.visit.startedOn;
    _endedOn = widget.visit.endedOn;

    _startedOnPrecision = widget.visit.startedOnPrecision;
    _endedOnPrecision = widget.visit.endedOnPrecision;

    if (_selectedCountryVisitId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadCountryVisits();
        }
      });
    }
  }

  Future<void> _loadCountryVisits() async {
    if (_loadingCountryVisits || _countryVisitsLoaded) return;

    setState(() {
      _loadingCountryVisits = true;
      _countryVisitsError = null;
    });

    try {
      final visits = await context
          .read<CountriesRepository>()
          .getCountryVisits();

      if (!mounted) return;

      setState(() {
        _availableCountryVisits = visits;
        _countryVisitsLoaded = true;
        _loadingCountryVisits = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingCountryVisits = false;
        _countryVisitsError =
            'Unable to load your country visits. Please try again.';
      });
    }
  }

  List<CountryVisit> get _matchingCountryVisits {
    return _availableCountryVisits
        .where((visit) => visit.countryCode == widget.visit.countryCode)
        .toList(growable: false);
  }

  bool get _isInteractionBlocked {
    final state = context.read<EditCityVisitCubit>().state;

    return state.isSubmitting ||
        state.phase == EditCityVisitPhase.expansionRequired;
  }

  void _selectCountryVisit(String? countryVisitId) {
    if (_isInteractionBlocked) return;

    setState(() {
      _selectedCountryVisitId = countryVisitId;
      _showCountryVisitOptions = countryVisitId != null;
      _associationSelectionError = null;
    });

    context.read<EditCityVisitCubit>().clearError();
  }

  Widget _buildCountryVisitAssociation() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final matchingVisits = _matchingCountryVisits;
    final selectedVisitMissing =
        _countryVisitsLoaded &&
        _selectedCountryVisitId != null &&
        !matchingVisits.any((visit) => visit.id == _selectedCountryVisitId);

    return BlocBuilder<EditCityVisitCubit, EditCityVisitState>(
      builder: (context, state) {
        final disabled =
            state.isSubmitting ||
            state.phase == EditCityVisitPhase.expansionRequired ||
            state.phase == EditCityVisitPhase.success;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'COUNTRY VISIT ASSOCIATION',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Optionally link this city visit to an existing visit '
              'to ${widget.city.countryName}.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  ListTile(
                    key: const Key('editCityAssociationNone'),
                    leading: Icon(
                      _selectedCountryVisitId == null
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: const Text('Not associated'),
                    subtitle: const Text('Keep this city visit independent.'),
                    onTap: disabled ? null : () => _selectCountryVisit(null),
                  ),

                  const Divider(height: 1),

                  ListTile(
                    key: const Key('editCityAssociationExisting'),
                    leading: Icon(
                      _selectedCountryVisitId != null
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                    ),
                    title: const Text('Link existing country visit'),
                    subtitle: const Text('Choose a visit to this country.'),
                    onTap: disabled
                        ? null
                        : () {
                            setState(() {
                              _showCountryVisitOptions = true;
                              _associationSelectionError = null;
                            });

                            _loadCountryVisits();
                          },
                  ),
                ],
              ),
            ),

            if (_showCountryVisitOptions && _loadingCountryVisits) ...[
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],

            if (_showCountryVisitOptions && _countryVisitsError != null) ...[
              const SizedBox(height: 12),

              Text(_countryVisitsError!, style: TextStyle(color: colors.error)),

              TextButton(
                onPressed: disabled ? null : _loadCountryVisits,
                child: const Text('Retry'),
              ),
            ],

            if (_showCountryVisitOptions && _countryVisitsLoaded) ...[
              const SizedBox(height: 12),

              if (matchingVisits.isEmpty)
                Text(
                  'No country visits available for '
                  '${widget.city.countryName}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (final visit in matchingVisits)
                        ListTile(
                          key: Key('editCountryVisitOption_${visit.id}'),
                          leading: Icon(
                            _selectedCountryVisitId == visit.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(
                            '${_formatDate(visit.startedOn, visit.startedOnPrecision)} – ${_formatDate(visit.endedOn, visit.endedOnPrecision)}',
                          ),
                          onTap: disabled
                              ? null
                              : () => _selectCountryVisit(visit.id),
                        ),
                    ],
                  ),
                ),
            ],

            // NEW: Warn when the selected country visit is unavailable.
            if (_showCountryVisitOptions && selectedVisitMissing) ...[
              const SizedBox(height: 12),

              Text(
                'The currently selected country visit is no longer available. '
                'Choose another visit or remove the association.',
                style: TextStyle(color: colors.error),
              ),
            ],

            // Existing validation error.
            if (_associationSelectionError != null) ...[
              const SizedBox(height: 12),

              Text(
                _associationSelectionError!,
                style: TextStyle(color: colors.error),
              ),
            ],

            if (_associationSelectionError != null) ...[
              const SizedBox(height: 12),

              Text(
                _associationSelectionError!,
                style: TextStyle(color: colors.error),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _pickStartDate() async {
    if (_isInteractionBlocked) return;
    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _startedOn == null
          ? null
          : PartialVisitDate(
              date: _startedOn!,
              precision: _startedOnPrecision ?? VisitDatePrecision.day,
            ),
    );

    if (!mounted || selected == null || _isInteractionBlocked) return;

    setState(() {
      _startedOn = selected.date;
      _startedOnPrecision = selected.precision;
    });

    context.read<EditCityVisitCubit>().clearError();
  }

  Future<void> _pickEndDate() async {
    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _endedOn == null
          ? null
          : PartialVisitDate(
              date: _endedOn!,
              precision: _endedOnPrecision ?? VisitDatePrecision.day,
            ),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _endedOn = selected.date;
      _endedOnPrecision = selected.precision;
    });

    context.read<EditCityVisitCubit>().clearError();
  }

  String _formatDate(DateTime? date, VisitDatePrecision? precision) {
    if (date == null) return 'Not set';

    switch (precision ?? VisitDatePrecision.day) {
      case VisitDatePrecision.day:
        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        return '$day/$month/${date.year}';

      case VisitDatePrecision.month:
        return MaterialLocalizations.of(context).formatMonthYear(date);

      case VisitDatePrecision.year:
        return '${date.year}';
    }
  }

  Future<void> _saveChanges() async {
    final dateError = CountryVisitDateValidator.validate(
      startedOn: _startedOn,
      endedOn: _endedOn,
      startedOnPrecision: _startedOnPrecision,
      endedOnPrecision: _endedOnPrecision,
    );

    if (_selectedCountryVisitId != widget.visit.countryVisitId) {
      if (_selectedCountryVisitId != null) {
        final isValidSelection =
            _countryVisitsLoaded &&
            _matchingCountryVisits.any(
              (visit) => visit.id == _selectedCountryVisitId,
            );

        if (!isValidSelection) {
          setState(() {
            _associationSelectionError =
                'Please select a valid visit to this country.';
          });
          return;
        }
      }
    }

    if (dateError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(dateError)));
      return;
    }

    final changes = <String, dynamic>{};

    final startedOn = _startedOn!;
    final endedOn = _endedOn!;

    final startedOnPrecision = _startedOnPrecision ?? VisitDatePrecision.day;

    final endedOnPrecision = _endedOnPrecision ?? VisitDatePrecision.day;

    final originalStartedOnPrecision =
        widget.visit.startedOnPrecision ?? VisitDatePrecision.day;

    final originalEndedOnPrecision =
        widget.visit.endedOnPrecision ?? VisitDatePrecision.day;

    if (startedOn != widget.visit.startedOn ||
        startedOnPrecision != originalStartedOnPrecision) {
      changes['started_on'] = startedOn;
      changes['started_on_precision'] = startedOnPrecision;
    }

    if (endedOn != widget.visit.endedOn ||
        endedOnPrecision != originalEndedOnPrecision) {
      changes['ended_on'] = endedOn;
      changes['ended_on_precision'] = endedOnPrecision;
    }

    if (_selectedCountryVisitId != widget.visit.countryVisitId) {
      changes['country_visit_id'] = _selectedCountryVisitId;
    }

    if (changes.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }

    final cubit = context.read<EditCityVisitCubit>();

    var success = await cubit.submit(
      visitId: widget.visit.id,
      changes: changes,
    );

    if (!mounted) return;

    // A backend-proposed expansion requires explicit user confirmation.
    if (!success && cubit.state.phase == EditCityVisitPhase.expansionRequired) {
      success = await _confirmCountryDateExpansion(
        visitId: widget.visit.id,
        changes: changes,
      );
    }

    if (!mounted || !success) return;

    Navigator.of(context).pop(true);
  }

  Future<bool> _confirmCountryDateExpansion({
    required String visitId,
    required Map<String, dynamic> changes,
  }) async {
    final cubit = context.read<EditCityVisitCubit>();
    final expansion = cubit.state.pendingExpansion;

    if (expansion == null) {
      return false;
    }

    final confirmed = await showCountryVisitDateExpansionDialog(
      context,
      expansion: expansion,
    );

    if (!mounted || cubit.isClosed) {
      return false;
    }

    if (!confirmed) {
      cubit.dismissExpansion();
      return false;
    }

    // Repeat the exact original PATCH with the backend proposal.
    // The Cubit validates that the request has not changed.
    final success = await cubit.submit(
      visitId: visitId,
      changes: changes,
      countryDateExpansion: expansion,
    );

    if (!mounted || cubit.isClosed) return false;

    if (!success && cubit.state.phase == EditCityVisitPhase.expansionRequired) {
      cubit.dismissExpansion();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The country visit dates have changed. '
            'Please review and save again.',
          ),
        ),
      );
    }

    return success;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          const SizedBox(height: 10),

          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                BlocBuilder<EditCityVisitCubit, EditCityVisitState>(
                  builder: (context, state) {
                    return IconButton(
                      tooltip: 'Close',
                      onPressed:
                          state.isSubmitting ||
                              state.phase ==
                                  EditCityVisitPhase.expansionRequired
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    );
                  },
                ),

                const Expanded(
                  child: Text(
                    'Edit City Visit',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
                  ),
                ),

                const SizedBox(width: 48),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Update your visit',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Edit the dates associated with this city visit.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'DESTINATION',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 10),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_city_outlined),
                    title: Text(widget.city.cityName),
                    subtitle: Text(widget.city.countryName),
                  ),
                ),

                const SizedBox(height: 28),

                Text(
                  'WHEN DID YOU VISIT?',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'Start and end dates are required. Tap a date to change it.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 16),

                BlocBuilder<EditCityVisitCubit, EditCityVisitState>(
                  builder: (context, state) {
                    return Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: Column(
                              children: [
                                ListTile(
                                  key: const Key('editCityVisitStartDate'),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  title: const Text('Start date'),
                                  subtitle: Text(
                                    _formatDate(
                                      _startedOn,
                                      _startedOnPrecision,
                                    ),
                                  ),
                                  onTap:
                                      state.isSubmitting ||
                                          state.phase ==
                                              EditCityVisitPhase
                                                  .expansionRequired
                                      ? null
                                      : _pickStartDate,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Card(
                            child: Column(
                              children: [
                                ListTile(
                                  key: const Key('editCityVisitEndDate'),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  title: const Text('End date'),
                                  subtitle: Text(
                                    _formatDate(_endedOn, _endedOnPrecision),
                                  ),
                                  onTap:
                                      state.isSubmitting ||
                                          state.phase ==
                                              EditCityVisitPhase
                                                  .expansionRequired
                                      ? null
                                      : _pickEndDate,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),

                _buildCountryVisitAssociation(),
              ],
            ),
          ),

          BlocBuilder<EditCityVisitCubit, EditCityVisitState>(
            builder: (context, state) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.errorMessage != null) ...[
                      Text(
                        state.errorMessage!,
                        style: TextStyle(color: colors.error),
                      ),

                      const SizedBox(height: 12),
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('editCityVisitSaveButton'),
                        onPressed:
                            state.isSubmitting ||
                                state.phase == EditCityVisitPhase.success ||
                                state.phase ==
                                    EditCityVisitPhase.expansionRequired
                            ? null
                            : _saveChanges,
                        icon: state.isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          state.isSubmitting ? 'Saving...' : 'Save Changes',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
