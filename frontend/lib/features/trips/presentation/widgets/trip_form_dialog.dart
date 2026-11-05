import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';

import '../../../explore/presentation/widgets/partial_visit_date_picker.dart';

import '../../application/save_trip_cubit.dart';
import '../../application/save_trip_state.dart';
import '../../domain/trip.dart';
import '../../domain/trip_input.dart';
import '../../domain/trip_repository.dart';

/// Opens the Create/Edit Trip form.
///
/// Uses a bottom sheet on compact screens and a dialog on larger screens.
/// Returns true only when the Trip was successfully persisted.
Future<bool> showTripFormDialog({
  required BuildContext context,
  Trip? trip,
}) async {
  final repository = context.read<TripRepository>();
  final width = MediaQuery.sizeOf(context).width;

  Widget buildContent() {
    return BlocProvider(
      create: (_) => SaveTripCubit(repository: repository),
      child: TripFormDialog(trip: trip),
    );
  }

  if (width >= 800) {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: buildContent(),
        ),
      ),
    );

    return result ?? false;
  }

  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: false,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height * 0.94;

      return AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              const SizedBox(height: 10),

              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      sheetContext,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Expanded(child: buildContent()),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}

/// Shared form used to create and edit Trips.
class TripFormDialog extends StatefulWidget {
  const TripFormDialog({this.trip, super.key});

  final Trip? trip;

  @override
  State<TripFormDialog> createState() => _TripFormDialogState();
}

class _TripFormDialogState extends State<TripFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  PartialVisitDate? _startedOn;
  PartialVisitDate? _endedOn;

  bool get _isEditing => widget.trip != null;

  @override
  void initState() {
    super.initState();

    final trip = widget.trip;

    _nameController = TextEditingController(text: trip?.name ?? '');

    _descriptionController = TextEditingController(
      text: trip?.description ?? '',
    );

    _startedOn = trip?.startedOn;
    _endedOn = trip?.endedOn;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _selectDate({required bool isStart}) async {
    final current = isStart ? _startedOn : _endedOn;

    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: current,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startedOn = selected;
      } else {
        _endedOn = selected;
      }
    });
  }

  void _clearDate({required bool isStart}) {
    setState(() {
      if (isStart) {
        _startedOn = null;
      } else {
        _endedOn = null;
      }
    });
  }

  String _formatDate(PartialVisitDate? value) {
    if (value == null) {
      return 'Not specified';
    }

    final date = value.date;
    final localization = MaterialLocalizations.of(context);

    return switch (value.precision) {
      VisitDatePrecision.day => localization.formatMediumDate(date),

      VisitDatePrecision.month => localization.formatMonthYear(date),

      VisitDatePrecision.year => '${date.year}',
    };
  }

  String? _validateName(String? value) {
    final normalized = value?.trim() ?? '';

    if (normalized.isEmpty) {
      return 'Enter a Trip name.';
    }

    if (normalized.length > 160) {
      return 'Trip name cannot exceed 160 characters.';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final input = TripInput(
      name: _nameController.text,
      description: _descriptionController.text,
      startedOn: _startedOn,
      endedOn: _endedOn,
    );

    final cubit = context.read<SaveTripCubit>();

    if (_isEditing) {
      cubit.update(tripId: widget.trip!.id, input: input);
    } else {
      cubit.create(input: input);
    }
  }

  Widget _buildDateField({
    required String label,
    required bool isStart,
    required bool isSubmitting,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final value = isStart ? _startedOn : _endedOn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        Material(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            key: Key(isStart ? 'tripStartDateField' : 'tripEndDateField'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: isSubmitting ? null : () => _selectDate(isStart: isStart),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: colors.primary,
                  ),

                  const SizedBox(width: AppSpacing.md),

                  Expanded(
                    child: Text(
                      _formatDate(value),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: value == null
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                  ),

                  if (value != null)
                    IconButton(
                      key: Key(
                        isStart ? 'clearTripStartDate' : 'clearTripEndDate',
                      ),
                      tooltip: 'Remove $label',
                      onPressed: isSubmitting
                          ? null
                          : () => _clearDate(isStart: isStart),
                      icon: const Icon(Icons.close, size: 18),
                    )
                  else
                    Icon(Icons.chevron_right, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _tripInputDecoration({required String hint}) {
    final colors = Theme.of(context).colorScheme;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );

    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
      errorBorder: border.copyWith(borderSide: BorderSide(color: colors.error)),
      focusedErrorBorder: border.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      counterText: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocConsumer<SaveTripCubit, SaveTripState>(
      listenWhen: (previous, current) =>
          previous.phase != current.phase &&
          current.phase == SaveTripPhase.success,
      listener: (context, state) {
        Navigator.of(context).pop(true);
      },
      builder: (context, state) {
        final isSubmitting = state.isSubmitting;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit Trip' : 'New Trip',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    IconButton(
                      tooltip: 'Close',
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),

                Text(
                  _isEditing
                      ? 'Update your journey details.'
                      : 'Give your journey a name. You can add destinations later.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                TextFormField(
                  key: const Key('tripNameField'),
                  controller: _nameController,
                  enabled: !isSubmitting,
                  maxLength: 160,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _validateName,
                  style: theme.textTheme.bodyLarge,
                  decoration: _tripInputDecoration(hint: 'Trip name'),
                ),

                const SizedBox(height: 12),

                TextFormField(
                  key: const Key('tripDescriptionField'),
                  controller: _descriptionController,
                  enabled: !isSubmitting,
                  maxLength: 5000,
                  minLines: 2,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  style: theme.textTheme.bodyLarge,
                  decoration: _tripInputDecoration(
                    hint: 'Description (optional)',
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                Text(
                  'When did this trip happen?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  'Dates are optional. You can record an exact day, a month or just a year.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                _buildDateField(
                  label: 'Start date',
                  isStart: true,
                  isSubmitting: isSubmitting,
                ),

                const SizedBox(height: AppSpacing.lg),

                _buildDateField(
                  label: 'End date',
                  isStart: false,
                  isSubmitting: isSubmitting,
                ),

                if (state.hasError) ...[
                  const SizedBox(height: AppSpacing.lg),

                  Container(
                    key: const Key('tripSaveError'),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Text(
                      state.errorMessage ?? 'Unable to save your Trip.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onErrorContainer,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.xl),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),

                    const SizedBox(width: AppSpacing.sm),

                    Flexible(
                      child: FilledButton.icon(
                        key: const Key('saveTripButton'),
                        onPressed: isSubmitting ? null : _submit,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check),
                        label: Text(
                          isSubmitting
                              ? 'Saving...'
                              : _isEditing
                              ? 'Save Changes'
                              : 'Create Trip',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
