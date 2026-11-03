import 'package:flutter/material.dart';

import '../../../../core/models/visit_date_precision.dart';
import '../../../residences/domain/residence_overlap.dart';

Future<bool> showResidenceOverlapConfirmationDialog(
  BuildContext context, {
  required ResidenceOverlapProposal proposal,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return PopScope(
        canPop: false,
        child: ResidenceOverlapConfirmationDialog(proposal: proposal),
      );
    },
  );

  return confirmed ?? false;
}

class ResidenceOverlapConfirmationDialog extends StatelessWidget {
  const ResidenceOverlapConfirmationDialog({required this.proposal, super.key});

  final ResidenceOverlapProposal proposal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Overlapping residence periods',
              style: TextStyle(fontSize: 19),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(proposal.message, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 20),

              Text(
                'NEW RESIDENCE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              _ResidencePeriodCard(
                key: const Key('requestedResidencePeriod'),
                location: proposal.requested,
              ),

              const SizedBox(height: 22),

              Text(
                'OVERLAPPING RESIDENCES',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              for (final overlap in proposal.overlaps) ...[
                _ResidencePeriodCard(
                  key: Key('overlappingResidence-${overlap.residenceId}'),
                  location: overlap.location,
                  overlapKind: overlap.kind,
                ),
                const SizedBox(height: 8),
              ],

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Both residence periods will be kept. '
                        'Existing residences will not be changed.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('cancelResidenceOverlap'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirmResidenceOverlap'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Save Anyway'),
        ),
      ],
    );
  }
}

class _ResidencePeriodCard extends StatelessWidget {
  const _ResidencePeriodCard({
    required this.location,
    this.overlapKind,
    super.key,
  });

  final ResidenceOverlapLocation location;
  final String? overlapKind;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            location.cityId == null
                ? 'Country: ${location.countryCode}'
                : 'Country: ${location.countryCode} · City ID: ${location.cityId}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            '${_formatDate(location.startedOn, location.startedOnPrecision)}'
            ' – '
            '${_formatDate(location.endedOn, location.endedOnPrecision)}',
            style: theme.textTheme.bodyMedium,
          ),

          if (overlapKind != null) ...[
            const SizedBox(height: 8),
            Text(
              'Overlap: $overlapKind',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String rawDate, VisitDatePrecision precision) {
    final date = DateTime.parse(rawDate);

    switch (precision) {
      case VisitDatePrecision.day:
        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        return '$day/$month/${date.year}';

      case VisitDatePrecision.month:
        final month = date.month.toString().padLeft(2, '0');
        return '$month/${date.year}';

      case VisitDatePrecision.year:
        return '${date.year}';
    }
  }
}
