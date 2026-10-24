import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/edit_city_visit_cubit.dart';
import '../../application/edit_city_visit_state.dart';
import '../../domain/visited_city.dart';
import '../../../geography/domain/city_visit.dart';
import 'adaptive_visit_date_picker.dart';

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

  @override
  void initState() {
    super.initState();

    _startedOn = widget.visit.startedOn;
    _endedOn = widget.visit.endedOn;
  }

  Future<void> _pickStartDate() async {
    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: _startedOn ?? _endedOn ?? DateTime.now(),
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

    context.read<EditCityVisitCubit>().clearError();
  }

  Future<void> _pickEndDate() async {
    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: _endedOn ?? _startedOn ?? DateTime.now(),
      firstDate: _startedOn ?? DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (!mounted || selected == null) return;

    setState(() => _endedOn = selected);

    context.read<EditCityVisitCubit>().clearError();
  }

  void _clearStartDate() {
    setState(() => _startedOn = null);
    context.read<EditCityVisitCubit>().clearError();
  }

  void _clearEndDate() {
    setState(() => _endedOn = null);
    context.read<EditCityVisitCubit>().clearError();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _saveChanges() async {
    final success = await context.read<EditCityVisitCubit>().submit(
      visitId: widget.visit.id,
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
                BlocBuilder<EditCityVisitCubit, EditCityVisitState>(
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
                  'Dates are optional. You can clear each date independently.',
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
                                  subtitle: Text(_formatDate(_startedOn)),
                                  onTap: state.isSubmitting
                                      ? null
                                      : _pickStartDate,
                                ),

                                if (_startedOn != null)
                                  TextButton(
                                    key: const Key(
                                      'editCityVisitClearStartDate',
                                    ),
                                    onPressed: state.isSubmitting
                                        ? null
                                        : _clearStartDate,
                                    child: const Text('Clear'),
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
                                  subtitle: Text(_formatDate(_endedOn)),
                                  onTap: state.isSubmitting
                                      ? null
                                      : _pickEndDate,
                                ),

                                if (_endedOn != null)
                                  TextButton(
                                    key: const Key('editCityVisitClearEndDate'),
                                    onPressed: state.isSubmitting
                                        ? null
                                        : _clearEndDate,
                                    child: const Text('Clear'),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
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
                                state.phase == EditCityVisitPhase.success
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
