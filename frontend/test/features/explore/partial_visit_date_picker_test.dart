import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/presentation/widgets/partial_visit_date_picker.dart';
import 'package:cupertino_calendar_picker/cupertino_calendar_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

void main() {
  Future<PartialVisitDate?> openPicker(
    WidgetTester tester, {
    PartialVisitDate? initialValue,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    PartialVisitDate? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(
                    context: context,
                    initialValue: initialValue,
                    firstDate: firstDate,
                    lastDate: lastDate,
                  );
                },
                child: const Text('Open picker'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    return result;
  }

  testWidgets('shows precision options', (tester) async {
    await openPicker(tester);

    expect(find.text('How precise is your date?'), findsOneWidget);
    expect(find.text('Exact date'), findsOneWidget);
    expect(find.text('Month and year'), findsOneWidget);
    expect(find.text('Year only'), findsOneWidget);
  });

  testWidgets('opens year picker', (tester) async {
    await openPicker(
      tester,
      initialValue: PartialVisitDate(
        date: DateTime(2024, 1, 1),
        precision: VisitDatePrecision.year,
      ),
    );

    await tester.tap(find.text('Year only'));
    await tester.pumpAndSettle();

    expect(find.text('Select year'), findsOneWidget);
    expect(find.byType(YearPicker), findsOneWidget);
  });

  testWidgets('opens month and year picker', (tester) async {
    await openPicker(
      tester,
      initialValue: PartialVisitDate(
        date: DateTime(2024, 6, 1),
        precision: VisitDatePrecision.month,
      ),
    );

    await tester.tap(find.text('Month and year'));
    await tester.pumpAndSettle();

    expect(find.text('Select month and year'), findsOneWidget);
    expect(find.byType(DropdownButton<int>), findsNWidgets(2));
  });

  testWidgets('returns canonical month date', (tester) async {
    PartialVisitDate? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(
                    context: context,
                    initialValue: PartialVisitDate(
                      date: DateTime(2024, 6, 15),
                      precision: VisitDatePrecision.month,
                    ),
                  );
                },
                child: const Text('Open picker'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Month and year'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.precision, VisitDatePrecision.month);
    expect(result!.date, DateTime(2024, 6, 1));
  });

  testWidgets('returns canonical year date', (tester) async {
    PartialVisitDate? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(
                    context: context,
                    initialValue: PartialVisitDate(
                      date: DateTime(2024, 6, 15),
                      precision: VisitDatePrecision.year,
                    ),
                  );
                },
                child: const Text('Open picker'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Year only'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('2024').last);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.precision, VisitDatePrecision.year);
    expect(result!.date, DateTime(2024, 1, 1));
  });

  testWidgets('canceling precision selection returns null', (tester) async {
    PartialVisitDate? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(context: context);
                },
                child: const Text('Open picker'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('How precise is your date?'), findsNothing);
  });
  testWidgets('iOS month and year picker shows independent wheels', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      PartialVisitDate? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    result = await showPartialVisitDatePicker(
                      context: context,
                      initialValue: PartialVisitDate(
                        date: DateTime(2024, 5),
                        precision: VisitDatePrecision.month,
                      ),
                    );
                  },
                  child: const Text('Pick date'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick date'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Month and year'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cupertinoMonthPicker')), findsOneWidget);

      expect(find.byKey(const Key('cupertinoYearPicker')), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirmCupertinoPeriod')));

      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.precision, VisitDatePrecision.month);
      expect(result!.date.year, 2024);
      expect(result!.date.month, 5);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('iOS year only picker shows a single year wheel', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      PartialVisitDate? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return TextButton(
                  onPressed: () async {
                    result = await showPartialVisitDatePicker(
                      context: context,
                      initialValue: PartialVisitDate(
                        date: DateTime(2020),
                        precision: VisitDatePrecision.year,
                      ),
                    );
                  },
                  child: const Text('Pick date'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick date'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Year only'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cupertinoYearPicker')), findsOneWidget);

      expect(find.byKey(const Key('cupertinoMonthPicker')), findsNothing);

      await tester.tap(find.byKey(const Key('confirmCupertinoPeriod')));

      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.precision, VisitDatePrecision.year);
      expect(result!.date.year, 2020);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('iOS month and year wheels update independently', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      PartialVisitDate? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(
                    context: context,
                    initialValue: PartialVisitDate(
                      date: DateTime(2024, 5),
                      precision: VisitDatePrecision.month,
                    ),
                  );
                },
                child: const Text('Pick date'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick date'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Month and year'));
      await tester.pumpAndSettle();

      final monthPicker = tester.widget<CupertinoPicker>(
        find.byKey(const Key('cupertinoMonthPicker')),
      );

      final yearPicker = tester.widget<CupertinoPicker>(
        find.byKey(const Key('cupertinoYearPicker')),
      );

      final monthController =
          monthPicker.scrollController! as FixedExtentScrollController;

      final yearController =
          yearPicker.scrollController! as FixedExtentScrollController;

      // September (month index 8).
      monthController.jumpToItem(8);

      await tester.pumpAndSettle();

      // Changing the month must preserve the original year.
      expect(monthController.selectedItem, 8);
      expect(yearController.selectedItem, 2024 - 1900);

      // Change year to 2022.
      yearController.jumpToItem(2022 - 1900);

      await tester.pumpAndSettle();

      // Changing the year must preserve September.
      expect(monthController.selectedItem, 8);
      expect(yearController.selectedItem, 2022 - 1900);

      await tester.tap(find.byKey(const Key('confirmCupertinoPeriod')));

      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.precision, VisitDatePrecision.month);
      expect(result!.date.year, 2022);
      expect(result!.date.month, 9);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('iOS year wheel returns selected year', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      PartialVisitDate? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(
                    context: context,
                    initialValue: PartialVisitDate(
                      date: DateTime(2020),
                      precision: VisitDatePrecision.year,
                    ),
                    firstDate: DateTime(2010),
                    lastDate: DateTime(2030),
                  );
                },
                child: const Text('Pick date'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick date'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Year only'));
      await tester.pumpAndSettle();

      final picker = tester.widget<CupertinoPicker>(
        find.byKey(const Key('cupertinoYearPicker')),
      );

      final controller =
          picker.scrollController! as FixedExtentScrollController;

      // Select 2025 (index relative to firstDate: 2010).
      controller.jumpToItem(2025 - 2010);

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmCupertinoPeriod')));

      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.precision, VisitDatePrecision.year);
      expect(result!.date.year, 2025);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('iOS period picker cancel does not return a date', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      PartialVisitDate? result;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(
                    context: context,
                    initialValue: PartialVisitDate(
                      date: DateTime(2024, 5),
                      precision: VisitDatePrecision.month,
                    ),
                  );

                  completed = true;
                },
                child: const Text('Pick date'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick date'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Month and year'));
      await tester.pumpAndSettle();

      final picker = tester.widget<CupertinoPicker>(
        find.byKey(const Key('cupertinoMonthPicker')),
      );

      final controller =
          picker.scrollController! as FixedExtentScrollController;

      controller.jumpToItem(10);

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('cancelCupertinoPeriod')));

      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('iOS exact date uses Cupertino calendar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await openPicker(
        tester,
        initialValue: PartialVisitDate(
          date: DateTime(2024, 5, 15),
          precision: VisitDatePrecision.day,
        ),
      );

      await tester.tap(find.byKey(const Key('datePrecision_day')));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('beenAroundCupertinoCalendar')),
        findsOneWidget,
      );

      expect(find.byType(DatePickerDialog), findsNothing);

      expect(find.byType(CupertinoDatePicker), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('iOS calendar confirms selected exact date', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      PartialVisitDate? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(
                    context: context,
                    initialValue: PartialVisitDate(
                      date: DateTime(2024, 5, 15),
                      precision: VisitDatePrecision.day,
                    ),
                  );
                },
                child: const Text('Pick date'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick date'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('datePrecision_day')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirmCupertinoCalendar')));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.precision, VisitDatePrecision.day);
      expect(result!.date, DateTime(2024, 5, 15));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('iOS exact date cancellation preserves existing value', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      PartialVisitDate? result;
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showPartialVisitDatePicker(
                    context: context,
                    initialValue: PartialVisitDate(
                      date: DateTime(2024, 5, 15),
                      precision: VisitDatePrecision.day,
                    ),
                  );

                  completed = true;
                },
                child: const Text('Pick date'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick date'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('datePrecision_day')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('beenAroundCupertinoCalendar')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('cancelCupertinoCalendar')));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(result, isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('iOS calendar respects configured date boundaries', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    try {
      await openPicker(
        tester,
        initialValue: PartialVisitDate(
          date: DateTime(2024, 5, 15),
          precision: VisitDatePrecision.day,
        ),
        firstDate: DateTime(2024, 5, 10),
        lastDate: DateTime(2024, 5, 20),
      );

      await tester.tap(find.byKey(const Key('datePrecision_day')));
      await tester.pumpAndSettle();

      final calendar = tester.widget<CupertinoCalendar>(
        find.byKey(const Key('beenAroundCupertinoCalendar')),
      );

      expect(calendar.minimumDateTime, DateTime(2024, 5, 10));

      expect(calendar.maximumDateTime, DateTime(2024, 5, 20));

      expect(calendar.initialDateTime, DateTime(2024, 5, 15));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('Android exact date uses Material calendar', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      await openPicker(
        tester,
        initialValue: PartialVisitDate(
          date: DateTime(2024, 5, 15),
          precision: VisitDatePrecision.day,
        ),
      );

      await tester.tap(find.byKey(const Key('datePrecision_day')));
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      expect(
        find.byKey(const Key('beenAroundCupertinoCalendar')),
        findsNothing,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
