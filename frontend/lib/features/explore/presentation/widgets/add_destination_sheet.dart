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

class AddDestinationSheet extends StatefulWidget {
  const AddDestinationSheet({super.key});

  @override
  State<AddDestinationSheet> createState() => _AddDestinationSheetState();
}

class _AddDestinationSheetState extends State<AddDestinationSheet> {
  Country? _selectedCountry;
  bool _selectingCountry = false;
  String _searchQuery = '';
  DateTime? _startedOn;
  DateTime? _endedOn;

  Future<void> _pickStartDate() async {
    final now = DateTime.now();

    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: _startedOn ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _startedOn = selected;

      if (_endedOn != null && _endedOn!.isBefore(selected)) {
        _endedOn = null;
      }
    });

    context.read<AddCountryVisitCubit>().clearError();
  }

  Future<void> _pickEndDate() async {
    if (_startedOn == null) return;

    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: _endedOn ?? _startedOn!,
      firstDate: _startedOn!,
      lastDate: DateTime(2100),
    );

    if (!mounted || selected == null) return;

    setState(() {
      _endedOn = selected;
    });

    context.read<AddCountryVisitCubit>().clearError();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _saveVisit() async {
    final country = _selectedCountry;

    if (country == null) return;

    final success = await context.read<AddCountryVisitCubit>().submit(
      countryCode: country.code,
      startedOn: _startedOn,
      endedOn: _endedOn,
    );

    if (!mounted || !success) return;

    Navigator.of(context).pop(true);
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
                  builder: (context, state) {
                    return IconButton(
                      tooltip: 'Close',
                      onPressed: state.isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
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
                : _buildForm(context, theme, colors),
          ),
          if (!_selectingCountry) _buildFooter(context),
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
        _DestinationTypeSelector(selectedIndex: 0, onSelected: (_) {}),
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
        _DestinationCountryCard(
          country: _selectedCountry,
          onTap: () {
            setState(() {
              _selectingCountry = true;
              _searchQuery = '';
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
                  _startedOn = null;
                  _endedOn = null;
                });

                context.read<AddCountryVisitCubit>().clearError();
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
      builder: (context, state) {
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
                      _selectedCountry == null ||
                          state.isSubmitting ||
                          state.phase == AddCountryVisitPhase.success
                      ? null
                      : _saveVisit,
                  icon: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(state.isSubmitting ? 'Saving...' : 'Save Visit'),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                onTap: index == 0 ? () => onSelected(index) : null,
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
