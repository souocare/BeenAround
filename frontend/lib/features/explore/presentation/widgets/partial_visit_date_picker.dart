import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';
import 'adaptive_visit_date_picker.dart';
import 'cupertino_partial_date_wheel_picker.dart';

Future<PartialVisitDate?> showPartialVisitDatePicker({
  required BuildContext context,
  PartialVisitDate? initialValue,
  DateTime? firstDate,
  DateTime? lastDate,
  List<VisitDatePrecision> allowedPrecisions = const [
    VisitDatePrecision.day,
    VisitDatePrecision.month,
    VisitDatePrecision.year,
  ],
}) async {
  assert(allowedPrecisions.isNotEmpty);
  final useCupertino = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final minimum = firstDate ?? DateTime(1900);
  final maximum = lastDate ?? DateTime(2100, 12, 31);

  final requestedInitial = initialValue?.date ?? DateTime.now();

  final initial = requestedInitial.isBefore(minimum)
      ? minimum
      : requestedInitial.isAfter(maximum)
      ? maximum
      : requestedInitial;

  final precision = await showModalBottomSheet<VisitDatePrecision>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      final colors = theme.colorScheme;

      String titleFor(VisitDatePrecision precision) {
        return switch (precision) {
          VisitDatePrecision.day => 'Exact date',
          VisitDatePrecision.month => 'Month and year',
          VisitDatePrecision.year => 'Year only',
        };
      }

      String subtitleFor(VisitDatePrecision precision) {
        return switch (precision) {
          VisitDatePrecision.day => 'Choose a specific day',
          VisitDatePrecision.month => 'When you only know the month',
          VisitDatePrecision.year => 'When you only know the year',
        };
      }

      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How precise is your date?',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose how much detail you remember.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 20),

              Material(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < allowedPrecisions.length;
                      index++
                    ) ...[
                      if (index > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          indent: 16,
                          endIndent: 16,
                          color: colors.outlineVariant,
                        ),

                      ListTile(
                        key: Key(
                          'datePrecision_${allowedPrecisions[index].name}',
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),

                        title: Text(
                          titleFor(allowedPrecisions[index]),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(subtitleFor(allowedPrecisions[index])),
                        ),

                        onTap: () {
                          Navigator.of(
                            sheetContext,
                          ).pop(allowedPrecisions[index]);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (precision == null || !context.mounted) return null;

  if (precision == VisitDatePrecision.day) {
    final selected = await showAdaptiveVisitDatePicker(
      context: context,
      initialDate: initial.isBefore(minimum)
          ? minimum
          : initial.isAfter(maximum)
          ? maximum
          : initial,
      firstDate: minimum,
      lastDate: maximum,
    );

    if (selected == null) return null;

    return PartialVisitDate(
      date: DateTime(selected.year, selected.month, selected.day),
      precision: VisitDatePrecision.day,
    );
  }

  if (precision == VisitDatePrecision.year) {
    if (useCupertino) {
      final selected = await showCupertinoPartialDateWheelPicker(
        context: context,
        initialDate: initial,
        firstDate: minimum,
        lastDate: maximum,
        mode: CupertinoPeriodPickerMode.yearOnly,
      );

      if (selected == null) return null;

      return PartialVisitDate(
        date: DateTime(selected.year),
        precision: VisitDatePrecision.year,
      );
    }

    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Select year'),
          content: SizedBox(
            width: 300,
            height: 300,
            child: YearPicker(
              firstDate: minimum,
              lastDate: maximum,
              selectedDate: initial,
              onChanged: (date) {
                Navigator.pop(dialogContext, date.year);
              },
            ),
          ),
        );
      },
    );

    if (selected == null) return null;

    return PartialVisitDate(
      date: DateTime(selected),
      precision: VisitDatePrecision.year,
    );
  }

  if (useCupertino) {
    final selected = await showCupertinoPartialDateWheelPicker(
      context: context,
      initialDate: initial,
      firstDate: minimum,
      lastDate: maximum,
      mode: CupertinoPeriodPickerMode.monthAndYear,
    );

    if (selected == null) return null;

    return PartialVisitDate(
      date: DateTime(selected.year, selected.month),
      precision: VisitDatePrecision.month,
    );
  }

  final selected = await showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      var selectedYear = initial.year;
      var selectedMonth = initial.month;

      return StatefulBuilder(
        builder: (context, setDialogState) {
          final availableMonths = [
            for (var month = 1; month <= 12; month++)
              if (!DateTime(selectedYear, month + 1, 0).isBefore(minimum) &&
                  !DateTime(selectedYear, month, 1).isAfter(maximum))
                month,
          ];

          return AlertDialog(
            title: const Text('Select month and year'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<int>(
                  value: selectedYear,
                  isExpanded: true,
                  items: [
                    for (var year = minimum.year; year <= maximum.year; year++)
                      DropdownMenuItem(value: year, child: Text('$year')),
                  ],
                  onChanged: (year) {
                    if (year == null) return;

                    setDialogState(() {
                      selectedYear = year;

                      final months = [
                        for (var month = 1; month <= 12; month++)
                          if (!DateTime(year, month + 1, 0).isBefore(minimum) &&
                              !DateTime(year, month, 1).isAfter(maximum))
                            month,
                      ];

                      if (!months.contains(selectedMonth)) {
                        selectedMonth = months.first;
                      }
                    });
                  },
                ),
                DropdownButton<int>(
                  value: selectedMonth,
                  isExpanded: true,
                  items: [
                    for (final month in availableMonths)
                      DropdownMenuItem(
                        value: month,
                        child: Text(
                          MaterialLocalizations.of(
                            context,
                          ).formatMonthYear(DateTime(selectedYear, month)),
                        ),
                      ),
                  ],
                  onChanged: (month) {
                    if (month == null) return;

                    setDialogState(() {
                      selectedMonth = month;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                    DateTime(selectedYear, selectedMonth),
                  );
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );
    },
  );

  if (selected == null) return null;

  return PartialVisitDate(date: selected, precision: VisitDatePrecision.month);
}
