import 'package:flutter/material.dart';

import '../../../../core/models/partial_visit_date.dart';
import '../../../../core/models/visit_date_precision.dart';
import 'adaptive_visit_date_picker.dart';

Future<PartialVisitDate?> showPartialVisitDatePicker({
  required BuildContext context,
  PartialVisitDate? initialValue,
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final minimum = firstDate ?? DateTime(1900);
  final maximum = lastDate ?? DateTime(2100, 12, 31);

  final requestedInitial = initialValue?.date ?? DateTime.now();

  final initial = requestedInitial.isBefore(minimum)
      ? minimum
      : requestedInitial.isAfter(maximum)
      ? maximum
      : requestedInitial;
  final initialPrecision = initialValue?.precision ?? VisitDatePrecision.day;

  final precision = await showModalBottomSheet<VisitDatePrecision>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How precise is your date?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              for (final option in VisitDatePrecision.values)
                ListTile(
                  title: Text(switch (option) {
                    VisitDatePrecision.day => 'Exact date',
                    VisitDatePrecision.month => 'Month and year',
                    VisitDatePrecision.year => 'Year only',
                  }),
                  trailing: option == initialPrecision
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, option),
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
