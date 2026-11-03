import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddDestinationLivedForm extends StatelessWidget {
  const AddDestinationLivedForm({
    required this.startDateLabel,
    required this.endDateLabel,
    required this.onStartDateTap,
    required this.onEndDateTap,
    required this.note,
    required this.onNoteChanged,
    required this.enabled,
    required this.showDateErrors,
    required this.startDateMissing,
    required this.endDateMissing,
    super.key,
  });

  final String startDateLabel;
  final String endDateLabel;

  final VoidCallback onStartDateTap;
  final VoidCallback onEndDateTap;

  final String note;
  final ValueChanged<String> onNoteChanged;

  final bool enabled;
  final bool showDateErrors;
  final bool startDateMissing;
  final bool endDateMissing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHEN DID YOU LIVE HERE?',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Start and end dates are required. '
          'Choose an exact date or a month and year.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _ResidenceDateField(
                label: 'START DATE',
                value: startDateLabel,
                onTap: enabled ? onStartDateTap : null,
                hasError: showDateErrors && startDateMissing,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _ResidenceDateField(
                label: 'END DATE',
                value: endDateLabel,
                onTap: enabled ? onEndDateTap : null,
                hasError: showDateErrors && endDateMissing,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Text(
          'NOTE (OPTIONAL)',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),

        const SizedBox(height: 10),

        TextFormField(
          key: const Key('residenceNoteField'),
          initialValue: note,
          enabled: enabled,
          minLines: 3,
          maxLines: 4,
          maxLength: 1000,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            hintText: 'What do you remember about living here?',
            filled: true,
            fillColor: colors.surfaceContainerLow,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.all(16),
          ),
          onChanged: onNoteChanged,
        ),
      ],
    );
  }
}

class _ResidenceDateField extends StatelessWidget {
  const _ResidenceDateField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.hasError,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelSmall),

        const SizedBox(height: 8),

        OutlinedButton(
          key: Key(
            label == 'START DATE' ? 'residenceStartDate' : 'residenceEndDate',
          ),
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            alignment: Alignment.centerLeft,
            side: BorderSide(
              color: hasError ? colors.error : colors.outlineVariant,
            ),
          ),
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),

        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            'Required',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        ],
      ],
    );
  }
}
