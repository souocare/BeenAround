import 'package:beenaround/core/models/partial_visit_date.dart';
import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/presentation/widgets/partial_visit_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
