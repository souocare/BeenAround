import 'package:beenaround/features/explore/presentation/widgets/country_visit_date_expansion_dialog.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CountryVisitDateExpansion sampleExpansion() {
  return CountryVisitDateExpansion.fromJson({
    'country_visit_id': '550e8400-e29b-41d4-a716-446655440001',
    'current': {
      'started_on': '2025-06-10',
      'started_on_precision': 'day',
      'ended_on': '2025-06-15',
      'ended_on_precision': 'day',
    },
    'proposed': {
      'started_on': '2025-06-10',
      'started_on_precision': 'day',
      'ended_on': '2025-06-18',
      'ended_on_precision': 'day',
    },
  });
}

void main() {
  testWidgets('shows current and proposed dates', (tester) async {
    final expansion = sampleExpansion();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountryVisitDateExpansionDialog(expansion: expansion),
        ),
      ),
    );

    expect(find.text('Extend country visit dates?'), findsOneWidget);

    expect(
      find.byKey(const Key('countryExpansionCurrentDates')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('countryExpansionProposedDates')),
      findsOneWidget,
    );

    expect(find.textContaining('15'), findsOneWidget);

    expect(find.textContaining('18'), findsOneWidget);
  });

  testWidgets('cancel returns false', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showCountryVisitDateExpansionDialog(
                  context,
                  expansion: sampleExpansion(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cancelCountryExpansion')));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('confirm returns true', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showCountryVisitDateExpansionDialog(
                  context,
                  expansion: sampleExpansion(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmCountryExpansion')));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('shows month and year precisions correctly', (tester) async {
    final expansion = CountryVisitDateExpansion.fromJson({
      'country_visit_id': '550e8400-e29b-41d4-a716-446655440001',
      'current': {
        'started_on': '2024-01-01',
        'started_on_precision': 'year',
        'ended_on': '2024-06-01',
        'ended_on_precision': 'month',
      },
      'proposed': {
        'started_on': '2023-01-01',
        'started_on_precision': 'year',
        'ended_on': '2024-08-01',
        'ended_on_precision': 'month',
      },
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CountryVisitDateExpansionDialog(expansion: expansion),
        ),
      ),
    );

    expect(find.textContaining('2023'), findsOneWidget);
    expect(find.textContaining('2024'), findsWidgets);
  });
}
