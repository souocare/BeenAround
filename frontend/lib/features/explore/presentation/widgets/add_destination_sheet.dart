import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/explore_cubit.dart';
import '../../domain/country.dart';
import '../../application/add_country_visit_cubit.dart';
import '../../application/add_country_visit_state.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'country_flag.dart';

import '../../application/add_city_visit_cubit.dart';
import '../../application/add_city_visit_state.dart';
import '../../../geography/domain/city.dart';
import 'city_browser.dart';

import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';
import 'partial_visit_date_picker.dart';

import '../../data/countries_repository.dart';
import '../../domain/country_visit.dart';
import '../../../geography/domain/new_country_visit_input.dart';
import '../../domain/country_visit_date_validator.dart';
import 'country_visit_date_expansion_dialog.dart';
import '../../../wishlist/application/add_wishlist_entry_cubit.dart';
import '../../../wishlist/application/add_wishlist_entry_state.dart';
import '../../../wishlist/domain/wishlist_entry_input.dart';

import 'add_destination_wish_form.dart';
import '../../../residences/application/save_residence_cubit.dart';
import '../../../residences/application/save_residence_state.dart';
import '../../../residences/domain/residence_input.dart';

import 'add_destination_lived_form.dart';

import '../../domain/destination_status.dart';
import 'residence_overlap_confirmation_dialog.dart';

enum _CityCountryAssociationMode { none, existing, createNew }

class AddDestinationSheet extends StatefulWidget {
  const AddDestinationSheet({this.initialCountry, super.key});

  final Country? initialCountry;

  @override
  State<AddDestinationSheet> createState() => _AddDestinationSheetState();
}

class _AddDestinationSheetState extends State<AddDestinationSheet> {
  Country? _selectedCountry;
  bool _selectingCountry = false;
  String _searchQuery = '';
  DateTime? _countryStartedOn;
  DateTime? _countryEndedOn;
  VisitDatePrecision? _countryStartedOnPrecision;
  VisitDatePrecision? _countryEndedOnPrecision;
  bool _showDateErrors = false;

  DateTime? _cityStartedOn;
  DateTime? _cityEndedOn;

  VisitDatePrecision? _cityStartedOnPrecision;
  VisitDatePrecision? _cityEndedOnPrecision;
  String? _associationSelectionError;
  String? _newCountryDateError;

  DestinationStatus _selectedStatus = DestinationStatus.been;

  bool get _isBeen => _selectedStatus == DestinationStatus.been;
  bool get _isLived => _selectedStatus == DestinationStatus.lived;
  bool get _isWish => _selectedStatus == DestinationStatus.wish;

  bool get _isCountry => _selectedDestinationType == 0;

  DateTime? get _startedOn => _isCountry ? _countryStartedOn : _cityStartedOn;

  DateTime? get _endedOn => _isCountry ? _countryEndedOn : _cityEndedOn;

  bool get _startDateMissing => _showDateErrors && _startedOn == null;

  bool get _endDateMissing => _showDateErrors && _endedOn == null;

  VisitDatePrecision? get _startedOnPrecision =>
      _isCountry ? _countryStartedOnPrecision : _cityStartedOnPrecision;

  VisitDatePrecision? get _endedOnPrecision =>
      _isCountry ? _countryEndedOnPrecision : _cityEndedOnPrecision;

  int _selectedDestinationType = 0;

  City? _selectedCity;
  bool _selectingCity = false;

  String _wishlistNote = '';
  bool _wishlistIncludeCountry = false;

  // Explicit city-country visit association.
  // A city is independent by default.
  _CityCountryAssociationMode _associationMode =
      _CityCountryAssociationMode.none;

  String? _selectedCountryVisitId;

  DateTime? _newCountryStartedOn;
  DateTime? _newCountryEndedOn;

  VisitDatePrecision? _newCountryStartedOnPrecision;
  VisitDatePrecision? _newCountryEndedOnPrecision;

  List<CountryVisit> _availableCountryVisits = const [];
  bool _loadingCountryVisits = false;
  String? _countryVisitsError;
  bool _countryVisitsLoaded = false;
  DateTime? _residenceStartedOn;
  DateTime? _residenceEndedOn;

  VisitDatePrecision? _residenceStartedOnPrecision;
  VisitDatePrecision? _residenceEndedOnPrecision;

  String _residenceNote = '';

  bool _showResidenceDateErrors = false;
  bool _overlapDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
  }

  Future<void> _loadCountryVisits() async {
    if (_loadingCountryVisits) return;

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
    final city = _selectedCity;

    if (city == null) {
      return const [];
    }

    return _availableCountryVisits
        .where((visit) => visit.countryCode == city.countryCode)
        .toList(growable: false);
  }

  void _onWishlistNoteChanged(String value) {
    if (_isAnySubmissionInProgress) return;

    _wishlistNote = value;

    context.read<AddWishlistEntryCubit>().clearError();
  }

  void _onWishlistIncludeCountryChanged(bool value) {
    if (_isAnySubmissionInProgress) return;

    setState(() {
      _wishlistIncludeCountry = value;
    });

    context.read<AddWishlistEntryCubit>().clearError();
  }

  void _selectStatus(DestinationStatus status) {
    if (_isAnySubmissionInProgress || _selectedStatus == status) {
      return;
    }

    setState(() {
      _selectedStatus = status;
      _showDateErrors = false;
      _associationSelectionError = null;
      _newCountryDateError = null;
    });

    // The existing Been error state belongs only to the Been form.
    if (_isBeen) {
      _clearActiveError();
    }
  }

  Future<void> _saveWish() async {
    if (!_isWish || _isAnySubmissionInProgress) {
      return;
    }

    final WishlistEntryInput input;

    if (_isCountry) {
      final country = _selectedCountry;

      if (country == null) return;

      input = WishlistEntryInput.country(
        countryCode: country.code,
        note: _wishlistNote,
      );
    } else {
      final city = _selectedCity;

      if (city == null) return;

      input = WishlistEntryInput.city(
        cityId: city.id,
        includeCountry: _wishlistIncludeCountry,
        note: _wishlistNote,
      );
    }

    final success = await context.read<AddWishlistEntryCubit>().submit(
      input: input,
    );

    if (!mounted || !success) return;

    // True means that the request completed successfully.
    // This also includes destinations that already existed.
    Navigator.of(context).pop(true);
  }

  Future<void> _pickNewCountryStartDate() async {
    if (_isAnySubmissionInProgress) return;

    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _newCountryStartedOn == null
          ? null
          : PartialVisitDate(
              date: _newCountryStartedOn!,
              precision:
                  _newCountryStartedOnPrecision ?? VisitDatePrecision.day,
            ),
    );

    if (!mounted || selected == null || _isAnySubmissionInProgress) return;

    setState(() {
      _newCountryStartedOn = selected.date;
      _newCountryStartedOnPrecision = selected.precision;
      _newCountryDateError = null;
    });

    _clearActiveError();
  }

  Future<void> _pickNewCountryEndDate() async {
    if (_isAnySubmissionInProgress) return;

    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _newCountryEndedOn == null
          ? null
          : PartialVisitDate(
              date: _newCountryEndedOn!,
              precision: _newCountryEndedOnPrecision ?? VisitDatePrecision.day,
            ),
    );

    if (!mounted || selected == null || _isAnySubmissionInProgress) return;

    setState(() {
      _newCountryEndedOn = selected.date;
      _newCountryEndedOnPrecision = selected.precision;
      _newCountryDateError = null;
    });

    _clearActiveError();
  }

  Future<void> _pickResidenceStartDate() async {
    if (_isAnySubmissionInProgress) return;

    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _residenceStartedOn == null
          ? null
          : PartialVisitDate(
              date: _residenceStartedOn!,
              precision: _residenceStartedOnPrecision ?? VisitDatePrecision.day,
            ),
      allowedPrecisions: const [
        VisitDatePrecision.day,
        VisitDatePrecision.month,
      ],
    );

    if (!mounted || selected == null || _isAnySubmissionInProgress) {
      return;
    }

    setState(() {
      _residenceStartedOn = selected.date;
      _residenceStartedOnPrecision = selected.precision;
      _showResidenceDateErrors = false;
    });

    _invalidateResidenceProposal();
  }

  Future<void> _pickResidenceEndDate() async {
    if (_isAnySubmissionInProgress) return;

    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _residenceEndedOn == null
          ? null
          : PartialVisitDate(
              date: _residenceEndedOn!,
              precision: _residenceEndedOnPrecision ?? VisitDatePrecision.day,
            ),
      allowedPrecisions: const [
        VisitDatePrecision.day,
        VisitDatePrecision.month,
      ],
    );

    if (!mounted || selected == null || _isAnySubmissionInProgress) {
      return;
    }

    setState(() {
      _residenceEndedOn = selected.date;
      _residenceEndedOnPrecision = selected.precision;
      _showResidenceDateErrors = false;
    });

    _invalidateResidenceProposal();
  }

  void _onResidenceNoteChanged(String value) {
    if (_isAnySubmissionInProgress) return;

    _residenceNote = value;

    _invalidateResidenceProposal();
  }

  Future<bool> _confirmCountryDateExpansion({
    required int cityId,
    required DateTime? startedOn,
    required DateTime? endedOn,
    required VisitDatePrecision? startedOnPrecision,
    required VisitDatePrecision? endedOnPrecision,
    required String countryVisitId,
  }) async {
    final cubit = context.read<AddCityVisitCubit>();

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

    // Repeat the exact original request with the backend proposal.
    // The Cubit validates that the request has not changed.
    final success = await cubit.submit(
      cityId: cityId,
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
      countryVisitId: countryVisitId,
      countryDateExpansion: expansion,
    );

    if (!mounted || cubit.isClosed) return false;

    if (!success && cubit.state.phase == AddCityVisitPhase.expansionRequired) {
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

  void _invalidateResidenceProposal() {
    final cubit = context.read<SaveResidenceCubit>();

    if (cubit.state.requiresConfirmation) {
      cubit.dismissOverlap();
    } else {
      cubit.clearError();
    }
  }

  Future<void> _handleResidenceOverlap(SaveResidenceCubit cubit) async {
    if (!mounted || _overlapDialogOpen) {
      return;
    }

    setState(() {
      _overlapDialogOpen = true;
    });

    try {
      while (mounted && !cubit.isClosed) {
        final state = cubit.state;

        if (!state.requiresConfirmation) {
          return;
        }

        final proposal = state.pendingProposal;

        if (proposal == null) {
          return;
        }

        final confirmed = await showResidenceOverlapConfirmationDialog(
          context,
          proposal: proposal,
        );

        if (!mounted || cubit.isClosed) {
          return;
        }

        if (!confirmed) {
          cubit.dismissOverlap();
          return;
        }

        final success = await cubit.confirmOverlap();

        if (!mounted || cubit.isClosed) {
          return;
        }

        if (success) {
          Navigator.of(context).pop(true);
          return;
        }

        // A stale confirmation or an API failure leaves the form open.
        // A new proposal requires another explicit user decision.
        if (!cubit.state.requiresConfirmation) {
          return;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _overlapDialogOpen = false;
        });
      }
    }
  }

  Widget _buildCountryVisitAssociation(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
  ) {
    final city = _selectedCity;

    if (_isCountry || city == null) {
      return const SizedBox.shrink();
    }

    final visits = _matchingCountryVisits;
    final isDisabled = _isAnySubmissionInProgress;

    final isNone = _associationMode == _CityCountryAssociationMode.none;
    final isExisting = _associationMode == _CityCountryAssociationMode.existing;
    final isCreateNew =
        _associationMode == _CityCountryAssociationMode.createNew;

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
          'Choose whether to associate this city visit with a visit '
          'to ${city.countryCode}. This is entirely optional.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),

        // OPTION 1: Keep the city visit independent.
        Card(
          child: ListTile(
            key: const Key('cityAssociationNone'),
            enabled: !isDisabled,
            leading: Icon(
              isNone
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isNone ? colors.primary : colors.onSurfaceVariant,
            ),
            title: const Text('Not associated'),
            subtitle: const Text('Keep this city visit independent.'),
            onTap: isDisabled
                ? null
                : () {
                    setState(() {
                      _associationMode = _CityCountryAssociationMode.none;
                      _selectedCountryVisitId = null;

                      _associationSelectionError = null;
                      _newCountryDateError = null;
                    });

                    _clearActiveError();
                  },
          ),
        ),

        // OPTION 2: Associate with an existing country visit.
        Card(
          child: ListTile(
            key: const Key('cityAssociationExisting'),
            enabled: !isDisabled,
            leading: Icon(
              isExisting
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isExisting ? colors.primary : colors.onSurfaceVariant,
            ),
            title: const Text('Link existing country visit'),
            subtitle: const Text(
              'Choose one of your previously recorded country visits.',
            ),
            onTap: isDisabled
                ? null
                : () {
                    setState(() {
                      _associationMode = _CityCountryAssociationMode.existing;

                      _associationSelectionError = null;
                      _newCountryDateError = null;
                    });

                    _clearActiveError();

                    if (!_countryVisitsLoaded && !_loadingCountryVisits) {
                      _loadCountryVisits();
                    }
                  },
          ),
        ),

        // OPTION 3: Create a new country visit together with the city.
        Card(
          child: ListTile(
            key: const Key('cityAssociationCreateNew'),
            enabled: !isDisabled,
            leading: Icon(
              isCreateNew
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isCreateNew ? colors.primary : colors.onSurfaceVariant,
            ),
            title: const Text('Create new country visit'),
            subtitle: const Text(
              'Record a new visit to this country together with the city.',
            ),
            onTap: isDisabled
                ? null
                : () {
                    setState(() {
                      _associationMode = _CityCountryAssociationMode.createNew;
                      _selectedCountryVisitId = null;

                      _associationSelectionError = null;
                      _newCountryDateError = null;
                    });

                    _clearActiveError();
                  },
          ),
        ),

        // Existing country visit selection.
        if (isExisting) ...[
          const SizedBox(height: 12),

          // Selection validation error.
          if (_associationSelectionError != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _associationSelectionError!,
                key: const Key('countryVisitSelectionError'),
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ),
          ],

          if (_loadingCountryVisits)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_countryVisitsError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _countryVisitsError!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
                TextButton.icon(
                  key: const Key('retryCountryVisits'),
                  onPressed: isDisabled ? null : _loadCountryVisits,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            )
          else if (_countryVisitsLoaded && visits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No country visits found for ${city.countryCode}.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            )
          else if (_countryVisitsLoaded)
            ...visits.map((visit) {
              final selected = _selectedCountryVisitId == visit.id;

              return Card(
                child: ListTile(
                  key: Key('countryVisitOption_${visit.id}'),
                  enabled: !isDisabled,
                  leading: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: selected ? colors.primary : colors.onSurfaceVariant,
                  ),
                  title: Text(
                    '${_formatDate(visit.startedOn, visit.startedOnPrecision)}'
                    ' – '
                    '${_formatDate(visit.endedOn, visit.endedOnPrecision)}',
                  ),
                  onTap: isDisabled
                      ? null
                      : () {
                          setState(() {
                            _selectedCountryVisitId = visit.id;
                            _associationSelectionError = null;
                          });

                          _clearActiveError();
                        },
                ),
              );
            }),
        ],

        // New country visit date fields.
        if (isCreateNew) ...[
          const SizedBox(height: 16),

          Text(
            'NEW COUNTRY VISIT DATES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'Choose the dates of your visit to ${city.countryCode}. '
            'These dates should include your city visit.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _VisitDateCard(
                  label: 'COUNTRY START',
                  value: _formatDate(
                    _newCountryStartedOn,
                    _newCountryStartedOnPrecision,
                  ),
                  onTap: isDisabled ? null : _pickNewCountryStartDate,
                  required: true,
                  hasError: _showDateErrors && _newCountryStartedOn == null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VisitDateCard(
                  label: 'COUNTRY END',
                  value: _formatDate(
                    _newCountryEndedOn,
                    _newCountryEndedOnPrecision,
                  ),
                  onTap: isDisabled ? null : _pickNewCountryEndDate,
                  required: true,
                  hasError: _showDateErrors && _newCountryEndedOn == null,
                ),
              ),
            ],
          ),

          // Country date validation error.
          if (_newCountryDateError != null) ...[
            const SizedBox(height: 8),
            Text(
              _newCountryDateError!,
              key: const Key('newCountryVisitDateError'),
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _pickStartDate() async {
    if (_isAnySubmissionInProgress) return;
    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _startedOn == null
          ? null
          : PartialVisitDate(
              date: _startedOn!,
              precision: _startedOnPrecision ?? VisitDatePrecision.day,
            ),
    );

    if (!mounted || selected == null || _isAnySubmissionInProgress) return;

    setState(() {
      if (_isCountry) {
        _countryStartedOn = selected.date;
        _countryStartedOnPrecision = selected.precision;
      } else {
        _cityStartedOn = selected.date;
        _cityStartedOnPrecision = selected.precision;
      }
    });

    _clearActiveError();
  }

  Future<void> _pickEndDate() async {
    if (_isAnySubmissionInProgress) return;
    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _endedOn == null
          ? null
          : PartialVisitDate(
              date: _endedOn!,
              precision: _endedOnPrecision ?? VisitDatePrecision.day,
            ),
    );

    if (!mounted || selected == null || _isAnySubmissionInProgress) return;

    setState(() {
      if (_isCountry) {
        _countryEndedOn = selected.date;
        _countryEndedOnPrecision = selected.precision;
      } else {
        _cityEndedOn = selected.date;
        _cityEndedOnPrecision = selected.precision;
      }
    });

    _clearActiveError();
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

  void _clearActiveError() {
    if (_isCountry) {
      context.read<AddCountryVisitCubit>().clearError();
    } else {
      context.read<AddCityVisitCubit>().clearError();
    }
  }

  Future<void> _saveVisit() async {
    if (!_isBeen || _isAnySubmissionInProgress) {
      return;
    }
    setState(() {
      _showDateErrors = true;
    });

    // COUNTRY VISIT
    if (_selectedDestinationType == 0) {
      final country = _selectedCountry;

      if (country == null) return;

      final success = await context.read<AddCountryVisitCubit>().submit(
        countryCode: country.code,
        startedOn: _startedOn,
        endedOn: _endedOn,
        startedOnPrecision: _startedOnPrecision,
        endedOnPrecision: _endedOnPrecision,
      );

      if (!mounted || !success) return;

      Navigator.of(context).pop(true);
      return;
    }

    // CITY VISIT
    final city = _selectedCity;

    if (city == null) return;

    // Validate explicit association with an existing country visit.
    if (_associationMode == _CityCountryAssociationMode.existing) {
      final selectedVisitId = _selectedCountryVisitId;

      final isValidSelection =
          selectedVisitId != null &&
          _countryVisitsLoaded &&
          _matchingCountryVisits.any((visit) => visit.id == selectedVisitId);

      if (!isValidSelection) {
        setState(() {
          _associationSelectionError = 'Please select a country visit.';
        });

        return;
      }
    }

    // Validate dates when creating a new country visit.
    NewCountryVisitInput? newCountryVisit;

    if (_associationMode == _CityCountryAssociationMode.createNew) {
      final dateError = CountryVisitDateValidator.validate(
        startedOn: _newCountryStartedOn,
        endedOn: _newCountryEndedOn,
        startedOnPrecision: _newCountryStartedOnPrecision,
        endedOnPrecision: _newCountryEndedOnPrecision,
      );

      if (dateError != null) {
        setState(() {
          _newCountryDateError = dateError;
          _showDateErrors = true;
        });

        return;
      }

      newCountryVisit = NewCountryVisitInput(
        startedOn: _newCountryStartedOn!,
        endedOn: _newCountryEndedOn!,
        startedOnPrecision:
            _newCountryStartedOnPrecision ?? VisitDatePrecision.day,
        endedOnPrecision: _newCountryEndedOnPrecision ?? VisitDatePrecision.day,
      );
    }

    // No association is inferred or created automatically.
    final countryVisitId =
        _associationMode == _CityCountryAssociationMode.existing
        ? _selectedCountryVisitId
        : null;

    final cityCubit = context.read<AddCityVisitCubit>();

    final startedOn = _startedOn;
    final endedOn = _endedOn;
    final startedOnPrecision = _startedOnPrecision;
    final endedOnPrecision = _endedOnPrecision;

    var success = await cityCubit.submit(
      cityId: city.id,
      startedOn: startedOn,
      endedOn: endedOn,
      startedOnPrecision: startedOnPrecision,
      endedOnPrecision: endedOnPrecision,
      countryVisitId: countryVisitId,
      newCountryVisit: newCountryVisit,
    );

    if (!mounted) return;

    // A country date expansion must always be explicitly confirmed.
    if (!success &&
        cityCubit.state.phase == AddCityVisitPhase.expansionRequired &&
        countryVisitId != null) {
      success = await _confirmCountryDateExpansion(
        cityId: city.id,
        startedOn: startedOn,
        endedOn: endedOn,
        startedOnPrecision: startedOnPrecision,
        endedOnPrecision: endedOnPrecision,
        countryVisitId: countryVisitId,
      );
    }

    if (!mounted || !success) return;

    Navigator.of(context).pop(true);
  }

  Future<void> _saveResidence() async {
    if (!_isLived || _isAnySubmissionInProgress) {
      return;
    }

    final countryCode = _isCountry
        ? _selectedCountry?.code
        : _selectedCity?.countryCode;

    final cityId = _isCountry ? null : _selectedCity?.id;

    if (countryCode == null) return;

    final startedOn = _residenceStartedOn;
    final endedOn = _residenceEndedOn;

    final startedPrecision = _residenceStartedOnPrecision;
    final endedPrecision = _residenceEndedOnPrecision;

    if (startedOn == null ||
        endedOn == null ||
        startedPrecision == null ||
        endedPrecision == null) {
      setState(() {
        _showResidenceDateErrors = true;
      });

      return;
    }

    final input = ResidenceInput(
      countryCode: countryCode,
      cityId: cityId,
      startedOn: startedOn,
      startedOnPrecision: startedPrecision,
      endedOn: endedOn,
      endedOnPrecision: endedPrecision,
      note: _residenceNote,
    );

    final cubit = context.read<SaveResidenceCubit>();

    final success = await cubit.create(input: input);

    if (!mounted || cubit.isClosed) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    if (cubit.state.requiresConfirmation) {
      await _handleResidenceOverlap(cubit);
    }
  }

  void _selectDestinationType(int index) {
    if (_isAnySubmissionInProgress) return;

    if (_selectedDestinationType == index) return;

    setState(() {
      _selectedDestinationType = index;
      _selectingCountry = false;
      _selectingCity = false;
      _searchQuery = '';
      _showDateErrors = false;
      _wishlistIncludeCountry = false;
    });

    _clearActiveError();
  }

  Widget _buildCityPicker(BuildContext context) {
    return CityBrowser(
      onBack: () {
        setState(() {
          _selectingCity = false;
        });
      },
      onCitySelected: (city) {
        setState(() {
          final countryChanged = _selectedCity?.countryCode != city.countryCode;

          final cityChanged = _selectedCity?.id != city.id;

          if (cityChanged) {
            _wishlistIncludeCountry = false;
          }

          _selectedCity = city;
          _selectingCity = false;

          if (countryChanged) {
            _associationMode = _CityCountryAssociationMode.none;
            _selectedCountryVisitId = null;

            _newCountryStartedOn = null;
            _newCountryEndedOn = null;
            _newCountryStartedOnPrecision = null;
            _newCountryEndedOnPrecision = null;
            _associationSelectionError = null;
            _newCountryDateError = null;
          }
        });

        context.read<AddCityVisitCubit>().clearError();
      },
    );
  }

  Widget _buildWishFooter(BuildContext context) {
    return BlocBuilder<AddWishlistEntryCubit, AddWishlistEntryState>(
      builder: (context, state) {
        final hasSelection = _isCountry
            ? _selectedCountry != null
            : _selectedCity != null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('saveWishlistButton'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed:
                      !hasSelection || state.isSubmitting || state.isSuccess
                      ? null
                      : _saveWish,
                  icon: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.favorite_border, size: 20),
                  label: Text(
                    state.isSubmitting ? 'Saving...' : 'Add to Wishlist',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResidenceFooter(BuildContext context) {
    return BlocBuilder<SaveResidenceCubit, SaveResidenceState>(
      builder: (context, state) {
        final hasSelection = _isCountry
            ? _selectedCountry != null
            : _selectedCity != null;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.errorMessage != null) ...[
                Text(
                  state.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],

              // if (state.requiresConfirmation) ...[
              //   const Text(
              //     'This residence overlaps an existing period. '
              //     'Explicit confirmation is required before saving.',
              //   ),
              //   const SizedBox(height: 12),
              //   TextButton(
              //     onPressed: () {
              //       context.read<SaveResidenceCubit>().dismissOverlap();
              //     },
              //     child: const Text('Edit residence dates'),
              //   ),
              //   const SizedBox(height: 12),
              // ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('saveResidenceButton'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed:
                      !hasSelection ||
                          _overlapDialogOpen ||
                          state.isSubmitting ||
                          state.isSuccess ||
                          state.requiresConfirmation
                      ? null
                      : _saveResidence,
                  icon: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.home_outlined, size: 20),
                  label: Text(
                    state.isSubmitting ? 'Saving...' : 'Save Residence',
                  ),
                ),
              ),
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
                if (!_selectingCountry && !_selectingCity)
                  BlocBuilder<AddCountryVisitCubit, AddCountryVisitState>(
                    builder: (context, countryState) {
                      return BlocBuilder<AddCityVisitCubit, AddCityVisitState>(
                        builder: (context, cityState) {
                          final isSubmitting =
                              countryState.isSubmitting ||
                              cityState.isSubmitting;

                          return BlocBuilder<
                            AddWishlistEntryCubit,
                            AddWishlistEntryState
                          >(
                            builder: (context, wishlistState) {
                              return IconButton(
                                tooltip: 'Close',
                                onPressed:
                                    isSubmitting || wishlistState.isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                icon: const Icon(Icons.close),
                              );
                            },
                          );
                        },
                      );
                    },
                  )
                else
                  const SizedBox(width: 48),
                const Expanded(
                  child: Text(
                    'Add Destination',
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
            child: _selectingCountry
                ? _buildCountryPicker(context)
                : _selectingCity
                ? _buildCityPicker(context)
                : _buildForm(context, theme, colors),
          ),
          if (!_selectingCountry && !_selectingCity) _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, ThemeData theme, ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          switch (_selectedStatus) {
            DestinationStatus.been => 'Where have you been?',
            DestinationStatus.lived => 'Where have you lived?',
            DestinationStatus.wish => 'Where do you want to go?',
          },
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          switch (_selectedStatus) {
            DestinationStatus.been =>
              'Add a destination to your travel history.',
            DestinationStatus.lived => 'Record a place where you lived.',
            DestinationStatus.wish =>
              'Save a destination you would like to visit.',
          },
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _DestinationTypeSelector(
          selectedIndex: _selectedDestinationType,
          onSelected: _selectDestinationType,
        ),
        const SizedBox(height: 16),
        _DestinationStatusSelector(
          selectedStatus: _selectedStatus,
          onSelected: _selectStatus,
        ),
        const SizedBox(height: 24),
        Text(
          'DESTINATION',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        if (_selectedDestinationType == 0)
          _DestinationCountryCard(
            country: _selectedCountry,
            onTap: () {
              setState(() {
                _selectingCountry = true;
                _searchQuery = '';
              });
            },
          )
        else
          _DestinationCityCard(
            city: _selectedCity,
            onTap: () {
              setState(() {
                _selectingCity = true;
              });
            },
          ),
        const SizedBox(height: 24),

        if (_isBeen) ...[
          Text(
            'WHEN DID YOU VISIT?',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start and end dates are required. Choose an exact date, month, or year.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _VisitDateCard(
                  label: 'START DATE',
                  value: _formatDate(_startedOn, _startedOnPrecision),
                  onTap: _isAnySubmissionInProgress ? null : _pickStartDate,
                  required: true,
                  hasError: _startDateMissing,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _VisitDateCard(
                  label: 'END DATE',
                  value: _formatDate(_endedOn, _endedOnPrecision),
                  onTap: _isAnySubmissionInProgress ? null : _pickEndDate,
                  required: true,
                  hasError: _endDateMissing,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          if (!_isCountry && _selectedCity != null) ...[
            _buildCountryVisitAssociation(context, theme, colors),
            const SizedBox(height: 24),
          ],

          const _ComingLaterCard(
            title: 'Associated Trip',
            subtitle: 'Optionally organize this visit into a Trip later.',
            icon: Icons.luggage_outlined,
          ),
        ],
        if (_isWish)
          AddDestinationWishForm(
            key: const ValueKey('addDestinationWishForm'),
            note: _wishlistNote,
            onNoteChanged: _onWishlistNoteChanged,
            includeCountry: _wishlistIncludeCountry,
            onIncludeCountryChanged: _onWishlistIncludeCountryChanged,
            enabled: !_isAnySubmissionInProgress,
            cityCountryName: !_isCountry ? _selectedCity?.countryName : null,
          ),

        if (_isLived)
          AddDestinationLivedForm(
            key: const ValueKey('addDestinationLivedForm'),
            startDateLabel: _formatDate(
              _residenceStartedOn,
              _residenceStartedOnPrecision,
            ),
            endDateLabel: _formatDate(
              _residenceEndedOn,
              _residenceEndedOnPrecision,
            ),
            onStartDateTap: _pickResidenceStartDate,
            onEndDateTap: _pickResidenceEndDate,
            note: _residenceNote,
            onNoteChanged: _onResidenceNoteChanged,
            enabled: !_isAnySubmissionInProgress,
            showDateErrors: _showResidenceDateErrors,
            startDateMissing: _residenceStartedOn == null,
            endDateMissing: _residenceEndedOn == null,
          ),
      ],
    );
  }

  Widget _buildCountryPicker(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final countries = context.read<ExploreCubit>().state.countries;

    final query = _searchQuery.trim().toLowerCase();

    final filtered = countries
        .where((country) {
          return country.name.toLowerCase().contains(query) ||
              country.code.toLowerCase().contains(query) ||
              country.alpha3Code.toLowerCase().contains(query);
        })
        .toList(growable: false);

    final useCupertinoSearch =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 20, 8),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back to Add Destination',
                onPressed: () {
                  setState(() {
                    _selectingCountry = false;
                    _searchQuery = '';
                  });
                },
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'Select Country',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: useCupertinoSearch
              ? CupertinoSearchTextField(
                  key: const Key('destinationCountrySearch'),
                  autofocus: true,
                  placeholder: 'Search countries...',
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                )
              : TextField(
                  key: const Key('destinationCountrySearch'),
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search countries...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No countries found.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final country = filtered[index];

                    final isSelected = _selectedCountry?.code == country.code;

                    return Material(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          setState(() {
                            _selectedCountry = country;
                            _selectingCountry = false;
                            _searchQuery = '';
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : colors.outline.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Row(
                            children: [
                              CountryFlag(countryCode: country.code, size: 36),
                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      country.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      country.code,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),

                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.chevron_right,
                                color: isSelected
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    if (_isWish) {
      return _buildWishFooter(context);
    }

    if (_isLived) {
      return _buildResidenceFooter(context);
    }

    return BlocBuilder<AddCountryVisitCubit, AddCountryVisitState>(
      builder: (context, countryState) {
        return BlocBuilder<AddCityVisitCubit, AddCityVisitState>(
          builder: (context, cityState) {
            final isCountry = _selectedDestinationType == 0;

            final isSubmitting =
                countryState.isSubmitting || cityState.isSubmitting;

            final isAwaitingConfirmation =
                cityState.phase == AddCityVisitPhase.expansionRequired;

            final isSuccess = isCountry
                ? countryState.phase == AddCountryVisitPhase.success
                : cityState.phase == AddCityVisitPhase.success;

            final errorMessage = isCountry
                ? countryState.errorMessage
                : cityState.errorMessage;

            final hasSelection = isCountry
                ? _selectedCountry != null
                : _selectedCity != null;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null) ...[
                    Text(
                      errorMessage,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed:
                          !_isBeen ||
                              !hasSelection ||
                              isSubmitting ||
                              isSuccess ||
                              isAwaitingConfirmation
                          ? null
                          : _saveVisit,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check, size: 20),
                      label: Text(isSubmitting ? 'Saving...' : 'Save Visit'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool get _isAnySubmissionInProgress {
    final countryState = context.read<AddCountryVisitCubit>().state;

    final cityState = context.read<AddCityVisitCubit>().state;

    final wishlistState = context.read<AddWishlistEntryCubit>().state;

    final residenceState = context.read<SaveResidenceCubit>().state;

    return _overlapDialogOpen ||
        countryState.isSubmitting ||
        cityState.isSubmitting ||
        cityState.phase == AddCityVisitPhase.expansionRequired ||
        wishlistState.isSubmitting ||
        residenceState.isSubmitting;
  }
}

class _ComingLaterCard extends StatelessWidget {
  const _ComingLaterCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: colors.onSurfaceVariant),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _VisitDateCard extends StatelessWidget {
  const _VisitDateCard({
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
    this.hasError = false,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  final bool required;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              constraints: const BoxConstraints(minHeight: 82),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasError
                      ? colors.error
                      : colors.outlineVariant.withValues(alpha: 0.4),
                  width: hasError ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                label,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: hasError
                                      ? colors.error
                                      : colors.onSurfaceVariant,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            if (required) ...[
                              const SizedBox(width: 3),
                              Text(
                                '*',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.error,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 15,
                        color: hasError
                            ? colors.error
                            : colors.onSurfaceVariant,
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    value == 'Not set' ? 'Select date' : value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: hasError
                          ? colors.error
                          : onTap == null
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Required',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DestinationTypeSelector extends StatelessWidget {
  const _DestinationTypeSelector({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    const options = ['Country', 'City'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var index = 0; index < options.length; index++)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(index),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selectedIndex == index
                        ? colors.surfaceContainerHigh
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (selectedIndex == index) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                      Text(
                        options[index],
                        style: TextStyle(
                          color: index == selectedIndex
                              ? colors.onSurface
                              : colors.onSurfaceVariant,
                          fontWeight: index == selectedIndex
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DestinationStatusSelector extends StatelessWidget {
  const _DestinationStatusSelector({
    required this.selectedStatus,
    required this.onSelected,
  });

  final DestinationStatus selectedStatus;
  final ValueChanged<DestinationStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final status in DestinationStatus.values)
            Expanded(
              child: Tooltip(
                message: status.description,
                child: InkWell(
                  onTap: () => onSelected(status),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (status == selectedStatus) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            status.label,
                            style: TextStyle(
                              color: status == selectedStatus
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                              fontWeight: status == selectedStatus
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 2,
                        width: 34,
                        decoration: BoxDecoration(
                          color: status == selectedStatus
                              ? colors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DestinationCountryCard extends StatelessWidget {
  const _DestinationCountryCard({required this.country, required this.onTap});

  final Country? country;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: country == null
                    ? Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.place,
                          color: colors.primary,
                          size: 24,
                        ),
                      )
                    : CountryFlag(countryCode: country!.code, size: 46),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      country?.name ?? 'Select a country',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      country == null
                          ? 'Search the country catalog'
                          : country!.code,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationCityCard extends StatelessWidget {
  const _DestinationCityCard({required this.city, required this.onTap});

  final City? city;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_city_outlined,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      city?.name ?? 'Select a city',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      city?.countryName ?? 'Search the city catalog',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
