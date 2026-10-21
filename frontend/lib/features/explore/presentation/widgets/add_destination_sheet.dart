import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/explore_cubit.dart';
import '../../domain/country.dart';
import '../../application/add_country_visit_cubit.dart';
import '../../application/add_country_visit_state.dart';

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

    final selected = await showDatePicker(
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

    final selected = await showDatePicker(
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
        const _OptionSelector(options: ['Country', 'City'], selectedIndex: 0),
        const SizedBox(height: 16),
        const _OptionSelector(
          options: ['Been', 'Lived', 'Wish'],
          selectedIndex: 0,
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
            leading: const Icon(Icons.place_outlined),
            title: Text(_selectedCountry?.name ?? 'Select a country'),
            subtitle: _selectedCountry == null
                ? const Text('Search the country catalog')
                : Text(_selectedCountry!.code),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              setState(() {
                _selectingCountry = true;
                _searchQuery = '';
              });
            },
          ),
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
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('Start date'),
                  subtitle: Text(_formatDate(_startedOn)),
                  onTap: _pickStartDate,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: const Text('End date'),
                  subtitle: Text(_formatDate(_endedOn)),
                  onTap: _startedOn == null ? null : _pickEndDate,
                ),
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
    final countries = context.read<ExploreCubit>().state.countries;

    final query = _searchQuery.trim().toLowerCase();

    final filtered = countries
        .where((country) {
          return country.name.toLowerCase().contains(query) ||
              country.code.toLowerCase().contains(query) ||
              country.alpha3Code.toLowerCase().contains(query);
        })
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            key: const Key('destinationCountrySearch'),
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search countries...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        setState(() => _searchQuery = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
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
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final country = filtered[index];

                    return ListTile(
                      title: Text(country.name),
                      subtitle: Text(country.code),
                      trailing: _selectedCountry?.code == country.code
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCountry = country;
                          _selectingCountry = false;
                          _searchQuery = '';
                        });
                      },
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
                      : const Icon(Icons.check),
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

class _OptionSelector extends StatelessWidget {
  const _OptionSelector({required this.options, required this.selectedIndex});

  final List<String> options;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: index == selectedIndex
                    ? colors.primaryContainer
                    : colors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                options[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: index == selectedIndex
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant.withValues(alpha: 0.55),
                  fontWeight: index == selectedIndex
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ],
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
