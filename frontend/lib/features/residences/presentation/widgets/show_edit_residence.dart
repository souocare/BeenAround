import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';
import '../../../explore/presentation/widgets/add_destination_lived_form.dart';
import '../../../explore/presentation/widgets/partial_visit_date_picker.dart';
import '../../../explore/presentation/widgets/residence_overlap_confirmation_dialog.dart';
import '../../application/save_residence_cubit.dart';
import '../../application/save_residence_state.dart';
import '../../domain/residence.dart';
import '../../domain/residence_changes.dart';
import '../../domain/residence_repository.dart';

Future<bool> showEditResidence({
  required BuildContext context,
  required Residence residence,
}) async {
  final repository = context.read<ResidenceRepository>();

  final updated = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider(
      create: (_) => SaveResidenceCubit(repository: repository),
      child: _EditResidenceDialog(residence: residence),
    ),
  );

  return updated ?? false;
}

class _EditResidenceDialog extends StatefulWidget {
  const _EditResidenceDialog({required this.residence});

  final Residence residence;

  @override
  State<_EditResidenceDialog> createState() => _EditResidenceDialogState();
}

class _EditResidenceDialogState extends State<_EditResidenceDialog> {
  late PartialVisitDate _startDate;
  late PartialVisitDate _endDate;
  late String _note;

  bool _overlapDialogOpen = false;

  String? _validationError;

  @override
  void initState() {
    super.initState();

    final residence = widget.residence;

    _startDate = PartialVisitDate(
      date: residence.startedOn,
      precision: residence.startedOnPrecision,
    );

    _endDate = PartialVisitDate(
      date: residence.endedOn,
      precision: residence.endedOnPrecision,
    );

    _note = residence.note ?? '';
  }

  String _formatDate(PartialVisitDate value) {
    final date = value.date;

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    if (value.precision == VisitDatePrecision.month) {
      return '${months[date.month - 1]} ${date.year}';
    }

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool get _hasChanges {
    final residence = widget.residence;

    return _startDate.date != residence.startedOn ||
        _startDate.precision != residence.startedOnPrecision ||
        _endDate.date != residence.endedOn ||
        _endDate.precision != residence.endedOnPrecision ||
        _note.trim() != (residence.note ?? '').trim();
  }

  void _invalidatePendingProposal() {
    final cubit = context.read<SaveResidenceCubit>();

    if (cubit.state.requiresConfirmation) {
      cubit.dismissOverlap();
    } else {
      cubit.clearError();
    }

    _validationError = null;
  }

  Future<void> _pickStartDate() async {
    final cubit = context.read<SaveResidenceCubit>();

    if (cubit.state.isSubmitting || _overlapDialogOpen) return;

    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _startDate,
      allowedPrecisions: const [
        VisitDatePrecision.day,
        VisitDatePrecision.month,
      ],
    );

    if (!mounted || selected == null) return;

    setState(() {
      _startDate = selected;
      _invalidatePendingProposal();
    });
  }

  Future<void> _pickEndDate() async {
    final cubit = context.read<SaveResidenceCubit>();

    if (cubit.state.isSubmitting || _overlapDialogOpen) return;

    final selected = await showPartialVisitDatePicker(
      context: context,
      initialValue: _endDate,
      allowedPrecisions: const [
        VisitDatePrecision.day,
        VisitDatePrecision.month,
      ],
    );

    if (!mounted || selected == null) return;

    setState(() {
      _endDate = selected;
      _invalidatePendingProposal();
    });
  }

  void _onNoteChanged(String value) {
    if (_overlapDialogOpen) return;

    setState(() {
      _note = value;
      _invalidatePendingProposal();
    });
  }

  ResidenceChanges? _buildChanges() {
    final residence = widget.residence;

    final startChanged =
        _startDate.date != residence.startedOn ||
        _startDate.precision != residence.startedOnPrecision;

    final endChanged =
        _endDate.date != residence.endedOn ||
        _endDate.precision != residence.endedOnPrecision;

    final noteChanged = _note.trim() != (residence.note ?? '').trim();

    if (!startChanged && !endChanged && !noteChanged) {
      return null;
    }

    return ResidenceChanges(
      startedOn: startChanged ? _startDate.date : null,
      startedOnPrecision: startChanged ? _startDate.precision : null,
      endedOn: endChanged ? _endDate.date : null,
      endedOnPrecision: endChanged ? _endDate.precision : null,
      note: noteChanged ? (_note.trim().isEmpty ? null : _note.trim()) : null,
      updateNote: noteChanged,
    );
  }

  Future<void> _save() async {
    final cubit = context.read<SaveResidenceCubit>();

    if (cubit.state.isSubmitting ||
        cubit.state.isSuccess ||
        _overlapDialogOpen) {
      return;
    }

    final changes = _buildChanges();

    if (changes == null) return;

    setState(() {
      _validationError = null;
    });

    final success = await cubit.update(
      residenceId: widget.residence.id,
      changes: changes,
    );

    if (!mounted || cubit.isClosed) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    if (cubit.state.requiresConfirmation) {
      await _handleOverlap(cubit);
    }
  }

  Future<void> _handleOverlap(SaveResidenceCubit cubit) async {
    if (!mounted || _overlapDialogOpen) return;

    setState(() {
      _overlapDialogOpen = true;
    });

    try {
      while (mounted && !cubit.isClosed) {
        final state = cubit.state;

        if (!state.requiresConfirmation) return;

        final proposal = state.pendingProposal;

        if (proposal == null) return;

        final confirmed = await showResidenceOverlapConfirmationDialog(
          context,
          proposal: proposal,
        );

        if (!mounted || cubit.isClosed) return;

        if (!confirmed) {
          cubit.dismissOverlap();
          return;
        }

        final success = await cubit.confirmOverlap();

        if (!mounted || cubit.isClosed) return;

        if (success) {
          Navigator.of(context).pop(true);
          return;
        }

        // A stale proposal or API failure leaves the form open.
        // A new proposal must be confirmed explicitly.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<SaveResidenceCubit, SaveResidenceState>(
      builder: (context, state) {
        final isBusy = state.isSubmitting || _overlapDialogOpen;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Residence',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'Update the dates or notes for this residence.',
                    style: theme.textTheme.bodySmall,
                  ),

                  const SizedBox(height: 24),

                  Flexible(
                    child: SingleChildScrollView(
                      child: AddDestinationLivedForm(
                        startDateLabel: _formatDate(_startDate),
                        endDateLabel: _formatDate(_endDate),
                        onStartDateTap: _pickStartDate,
                        onEndDateTap: _pickEndDate,
                        note: _note,
                        onNoteChanged: _onNoteChanged,
                        enabled: !isBusy,
                        showDateErrors: false,
                        startDateMissing: false,
                        endDateMissing: false,
                      ),
                    ),
                  ),

                  if (_validationError != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _validationError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],

                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      state.errorMessage!,
                      key: const Key('editResidenceError'),
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        key: const Key('cancelEditResidence'),
                        onPressed: isBusy
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),

                      const SizedBox(width: 12),

                      FilledButton(
                        key: const Key('saveEditResidence'),
                        onPressed:
                            isBusy ||
                                !_hasChanges ||
                                state.isSuccess ||
                                state.requiresConfirmation
                            ? null
                            : _save,
                        child: Text(
                          state.isSubmitting ? 'Saving...' : 'Save Changes',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
