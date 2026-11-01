import 'package:flutter/material.dart';

import '../../../../core/models/visit_date_precision.dart';
import '../../../geography/domain/country_visit_date_expansion.dart';

/// Asks the user to explicitly approve a backend-proposed expansion
/// of an existing country visit.
///
/// Returns true only when the user selects Confirm.
Future<bool> showCountryVisitDateExpansionDialog(
  BuildContext context, {
  required CountryVisitDateExpansion expansion,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CountryVisitDateExpansionDialog(expansion: expansion),
  );

  return confirmed ?? false;
}

class CountryVisitDateExpansionDialog extends StatelessWidget {
  const CountryVisitDateExpansionDialog({required this.expansion, super.key});

  final CountryVisitDateExpansion expansion;

  String _formatDate(
    BuildContext context,
    DateTime date,
    VisitDatePrecision precision,
  ) {
    switch (precision) {
      case VisitDatePrecision.day:
        return MaterialLocalizations.of(context).formatMediumDate(date);

      case VisitDatePrecision.month:
        return MaterialLocalizations.of(context).formatMonthYear(date);

      case VisitDatePrecision.year:
        return '${date.year}';
    }
  }

  String _formatPeriod(BuildContext context, CountryVisitDateState dates) {
    final start = _formatDate(
      context,
      dates.startedOn,
      dates.startedOnPrecision,
    );

    final end = _formatDate(context, dates.endedOn, dates.endedOnPrecision);

    return '$start – $end';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AlertDialog(
      title: const Text('Extend country visit dates?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your city visit extends beyond the dates of the '
            'selected country visit.',
          ),
          const SizedBox(height: 20),

          Text(
            'CURRENT DATES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPeriod(context, expansion.current),
            key: const Key('countryExpansionCurrentDates'),
            style: theme.textTheme.bodyLarge,
          ),

          const SizedBox(height: 16),

          Text(
            'PROPOSED DATES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _formatPeriod(context, expansion.proposed),
            key: const Key('countryExpansionProposedDates'),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Confirming will update the dates of your existing '
            'country visit.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('cancelCountryExpansion'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('confirmCountryExpansion'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
