import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../application/edit_country_visit_cubit.dart';
import '../../application/edit_country_visit_state.dart';
import '../../domain/country.dart';
import '../../domain/country_visit.dart';

class EditCountryVisitSheet extends StatefulWidget {
  const EditCountryVisitSheet({
    required this.country,
    required this.visit,
    super.key,
  });

  final Country country;
  final CountryVisit visit;

  @override
  State<EditCountryVisitSheet> createState() => _EditCountryVisitSheetState();
}

class _EditCountryVisitSheetState extends State<EditCountryVisitSheet> {
  DateTime? _startedOn;
  DateTime? _endedOn;

  @override
  void initState() {
    super.initState();

    _startedOn = widget.visit.startedOn;
    _endedOn = widget.visit.endedOn;
  }

  Future<void> _pickStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startedOn ?? DateTime.now(),
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

    context.read<EditCountryVisitCubit>().clearError();
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

    context.read<EditCountryVisitCubit>().clearError();
  }

  void _clearDates() {
    setState(() {
      _startedOn = null;
      _endedOn = null;
    });

    context.read<EditCountryVisitCubit>().clearError();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _saveChanges() async {
    final success = await context.read<EditCountryVisitCubit>().submit(
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
                BlocBuilder<EditCountryVisitCubit, EditCountryVisitState>(
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
                    'Edit Visit',
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
                  'Edit the dates associated with this visit.',
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
                    leading: const Icon(Icons.place_outlined),
                    title: Text(widget.country.name),
                    subtitle: Text(widget.country.code),
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
                  'Dates are optional. You can remove them at any time.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 16),

                BlocBuilder<EditCountryVisitCubit, EditCountryVisitState>(
                  builder: (context, state) {
                    return Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: ListTile(
                              key: const Key('editVisitStartDate'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: const Text('Start date'),
                              subtitle: Text(_formatDate(_startedOn)),
                              onTap: state.isSubmitting ? null : _pickStartDate,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Card(
                            child: ListTile(
                              key: const Key('editVisitEndDate'),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              title: const Text('End date'),
                              subtitle: Text(_formatDate(_endedOn)),
                              onTap: state.isSubmitting || _startedOn == null
                                  ? null
                                  : _pickEndDate,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                if (_startedOn != null || _endedOn != null)
                  BlocBuilder<EditCountryVisitCubit, EditCountryVisitState>(
                    builder: (context, state) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('editVisitClearDates'),
                          onPressed: state.isSubmitting ? null : _clearDates,
                          child: const Text('Clear dates'),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          BlocBuilder<EditCountryVisitCubit, EditCountryVisitState>(
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
                        key: const Key('editVisitSaveButton'),
                        onPressed:
                            state.isSubmitting ||
                                state.phase == EditCountryVisitPhase.success
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
