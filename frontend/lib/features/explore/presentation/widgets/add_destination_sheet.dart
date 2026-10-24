import 'package:beenaround/features/explore/presentation/widgets/adaptive_visit_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/explore_cubit.dart';
import '../../domain/country.dart';
import '../../application/add_country_visit_cubit.dart';
import '../../application/add_country_visit_state.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'country_flag.dart';

import 'dart:async';

import '../../application/add_city_visit_cubit.dart';
import '../../application/add_city_visit_state.dart';
import '../../../geography/domain/city.dart';
import '../../../geography/domain/city_repository.dart';

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

  DateTime? _cityStartedOn;
  DateTime? _cityEndedOn;

  bool get _isCountry => _selectedDestinationType == 0;

  DateTime? get _startedOn => _isCountry ? _countryStartedOn : _cityStartedOn;

  DateTime? get _endedOn => _isCountry ? _countryEndedOn : _cityEndedOn;

  int _selectedDestinationType = 0;

  City? _selectedCity;
  bool _selectingCity = false;

  String _citySearchQuery = '';
  List<City> _cityResults = const [];

  bool _citySearchLoading = false;
  String? _citySearchError;

  Timer? _citySearchDebounce;
  int _citySearchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
  }

  Future<void> _pickStartDate() async {
    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: _startedOn ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (!mounted || selected == null) return;

    setState(() {
      if (_isCountry) {
        _countryStartedOn = selected;

        if (_countryEndedOn != null && _countryEndedOn!.isBefore(selected)) {
          _countryEndedOn = null;
        }
      } else {
        _cityStartedOn = selected;

        if (_cityEndedOn != null && _cityEndedOn!.isBefore(selected)) {
          _cityEndedOn = null;
        }
      }
    });

    _clearActiveError();
  }

  Future<void> _pickEndDate() async {
    final startDate = _startedOn;

    if (startDate == null) return;

    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: _endedOn ?? startDate,
      firstDate: startDate,
      lastDate: DateTime(2100),
    );

    if (!mounted || selected == null) return;

    setState(() {
      if (_isCountry) {
        _countryEndedOn = selected;
      } else {
        _cityEndedOn = selected;
      }
    });

    _clearActiveError();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  void _clearActiveError() {
    if (_isCountry) {
      context.read<AddCountryVisitCubit>().clearError();
    } else {
      context.read<AddCityVisitCubit>().clearError();
    }
  }

  Future<void> _saveVisit() async {
    if (_selectedDestinationType == 0) {
      final country = _selectedCountry;

      if (country == null) return;

      final success = await context.read<AddCountryVisitCubit>().submit(
        countryCode: country.code,
        startedOn: _startedOn,
        endedOn: _endedOn,
      );

      if (!mounted || !success) return;

      Navigator.of(context).pop(true);
      return;
    }

    final city = _selectedCity;

    if (city == null) return;

    final success = await context.read<AddCityVisitCubit>().submit(
      cityId: city.id,
      startedOn: _startedOn,
      endedOn: _endedOn,
    );

    if (!mounted || !success) return;

    Navigator.of(context).pop(true);
  }

  void _onCitySearchChanged(String value) {
    _citySearchDebounce?.cancel();

    final query = value.trim();
    final generation = ++_citySearchGeneration;

    setState(() {
      _citySearchQuery = value;
      _citySearchError = null;
      _cityResults = const [];
      _citySearchLoading = query.isNotEmpty;
    });

    if (query.isEmpty) return;

    _citySearchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchCities(query, generation),
    );
  }

  Future<void> _searchCities(String query, int generation) async {
    try {
      final result = await context.read<CityRepository>().search(
        query: query,
        limit: 20,
      );

      if (!mounted || generation != _citySearchGeneration) return;

      setState(() {
        _cityResults = result.items;
        _citySearchLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _citySearchGeneration) return;

      setState(() {
        _citySearchLoading = false;
        _citySearchError = 'Unable to search cities. Please try again.';
      });
    }
  }

  void _selectDestinationType(int index) {
    if (_isAnySubmissionInProgress) return;

    if (_selectedDestinationType == index) return;

    _citySearchDebounce?.cancel();
    _citySearchGeneration++;

    setState(() {
      _selectedDestinationType = index;

      _selectingCountry = false;
      _selectingCity = false;

      _searchQuery = '';
      _citySearchLoading = false;
    });

    _clearActiveError();
  }

  Widget _buildCityPicker(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                  _citySearchDebounce?.cancel();
                  _citySearchGeneration++;

                  setState(() {
                    _selectingCity = false;
                    _citySearchLoading = false;
                  });
                },
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Select City',
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
                  key: const Key('destinationCitySearch'),
                  autofocus: true,
                  placeholder: 'Search cities...',
                  onChanged: _onCitySearchChanged,
                )
              : TextField(
                  key: const Key('destinationCitySearch'),
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search cities...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _onCitySearchChanged,
                ),
        ),
        Expanded(
          child: _citySearchLoading
              ? const Center(child: CircularProgressIndicator())
              : _citySearchError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _citySearchError!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.error),
                    ),
                  ),
                )
              : _citySearchQuery.trim().isEmpty
              ? Center(
                  child: Text(
                    'Search for a city to add to your history.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                )
              : _cityResults.isEmpty
              ? const Center(child: Text('No cities found.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: _cityResults.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final city = _cityResults[index];
                    final isSelected = _selectedCity?.id == city.id;

                    return Material(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _citySearchDebounce?.cancel();
                          _citySearchGeneration++;

                          setState(() {
                            _selectedCity = city;
                            _selectingCity = false;
                            _citySearchLoading = false;
                          });

                          context.read<AddCityVisitCubit>().clearError();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_city_outlined,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      city.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      city.countryName,
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
                BlocBuilder<AddCountryVisitCubit, AddCountryVisitState>(
                  builder: (context, countryState) {
                    return BlocBuilder<AddCityVisitCubit, AddCityVisitState>(
                      builder: (context, cityState) {
                        final isSubmitting =
                            countryState.isSubmitting || cityState.isSubmitting;

                        return IconButton(
                          tooltip: 'Close',
                          onPressed: isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close),
                        );
                      },
                    );
                  },
                ),
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
          'Where have you been?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add a destination to your travel history.',
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
        const _DestinationStatusSelector(),
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
        Text(
          'WHEN DID YOU VISIT?',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Dates are optional. You can add them later.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _VisitDateCard(
                label: 'START DATE',
                value: _formatDate(_startedOn),
                onTap: _pickStartDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _VisitDateCard(
                label: 'END DATE',
                value: _formatDate(_endedOn),
                onTap: _startedOn == null ? null : _pickEndDate,
              ),
            ),
          ],
        ),
        if (_startedOn != null || _endedOn != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() {
                  if (_isCountry) {
                    _countryStartedOn = null;
                    _countryEndedOn = null;
                  } else {
                    _cityStartedOn = null;
                    _cityEndedOn = null;
                  }
                });

                _clearActiveError();
              },
              child: const Text('Clear dates'),
            ),
          ),
        const SizedBox(height: 24),
        const _ComingLaterCard(
          title: 'Associated Trip',
          subtitle: 'Optionally organize this visit into a Trip later.',
          icon: Icons.luggage_outlined,
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
    return BlocBuilder<AddCountryVisitCubit, AddCountryVisitState>(
      builder: (context, countryState) {
        return BlocBuilder<AddCityVisitCubit, AddCityVisitState>(
          builder: (context, cityState) {
            final isCountry = _selectedDestinationType == 0;

            final isSubmitting =
                countryState.isSubmitting || cityState.isSubmitting;

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
                      onPressed: !hasSelection || isSubmitting || isSuccess
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
    return context.read<AddCountryVisitCubit>().state.isSubmitting ||
        context.read<AddCityVisitCubit>().state.isSubmitting;
  }

  @override
  void dispose() {
    _citySearchDebounce?.cancel();
    _citySearchGeneration++;
    super.dispose();
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
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

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
          constraints: const BoxConstraints(minHeight: 82),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: onTap == null
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
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
  const _DestinationStatusSelector();

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
          for (final option in ['Been', 'Lived', 'Wish'])
            Expanded(
              child: Tooltip(
                message: option == 'Been'
                    ? 'Record a visit'
                    : '$option coming later',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (option == 'Been') ...[
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
                          option,
                          style: TextStyle(
                            color: option == 'Been'
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            fontWeight: option == 'Been'
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
                        color: option == 'Been'
                            ? colors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
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
