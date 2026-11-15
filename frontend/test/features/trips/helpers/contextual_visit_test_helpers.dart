import 'package:beenaround/features/explore/presentation/widgets/add_destination_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> selectContextualVisitMonth(
  WidgetTester tester, {
  required String field,
  required int year,
  required int month,
}) async {
  final form = find.byType(AddDestinationSheet);

  final scrollable = find.descendant(
    of: form,
    matching: find.byType(Scrollable),
  );

  await tester.scrollUntilVisible(
    find.text(field),
    150,
    scrollable: scrollable.last,
  );

  await tester.pumpAndSettle();

  await tester.tap(find.text(field));
  await tester.pumpAndSettle();

  // Select month precision.
  await tester.tap(find.text('Month and year'));
  await tester.pumpAndSettle();

  expect(find.text('Select month and year'), findsOneWidget);

  // Select year.
  final yearDropdown = find.byType(DropdownButton<int>).first;

  final currentYear = tester.widget<DropdownButton<int>>(yearDropdown).value;

  if (currentYear != year) {
    await tester.tap(yearDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('$year').last);
    await tester.pumpAndSettle();
  }

  // Select month.
  final monthDropdown = find.byType(DropdownButton<int>).last;

  final currentMonth = tester.widget<DropdownButton<int>>(monthDropdown).value;

  if (currentMonth != month) {
    final monthLabel = MaterialLocalizations.of(
      tester.element(monthDropdown),
    ).formatMonthYear(DateTime(year, month));

    await tester.tap(monthDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text(monthLabel).last);
    await tester.pumpAndSettle();
  }

  await tester.tap(find.text('Done'));
  await tester.pumpAndSettle();
}

Future<void> createContextualCountryVisit(WidgetTester tester) async {
  // The contextual country form must already be open.
  expect(find.byType(AddDestinationSheet), findsOneWidget);

  // Select Portugal.
  await tester.tap(find.text('Select a country'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Portugal').last);
  await tester.pumpAndSettle();

  // Select visit dates.
  await selectContextualVisitMonth(
    tester,
    field: 'START DATE',
    year: 2024,
    month: 6,
  );

  await selectContextualVisitMonth(
    tester,
    field: 'END DATE',
    year: 2024,
    month: 8,
  );

  // Save the independent visit.
  await tester.tap(find.text('Save Visit'));
  await tester.pumpAndSettle();
}

Future<void> createContextualCityVisit(
  WidgetTester tester, {
  String cityName = 'Lisbon',
  VoidCallback? afterSearch,
}) async {
  expect(find.byType(AddDestinationSheet), findsOneWidget);

  // The contextual form is already locked to City / Been.
  // Do not tap the standard Add Destination type selectors.
  await tester.tap(find.text('Select a city'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('destinationCitySearch')),
    cityName.toLowerCase(),
  );

  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  afterSearch?.call();

  final cityOption = find.text(cityName);

  expect(
    cityOption,
    findsWidgets,
    reason:
        'The contextual city search must return $cityName '
        'before selecting it.',
  );

  await tester.tap(cityOption.last);
  await tester.pumpAndSettle();
  await tester.pumpAndSettle();

  await selectContextualVisitMonth(
    tester,
    field: 'START DATE',
    year: 2024,
    month: 6,
  );

  await selectContextualVisitMonth(
    tester,
    field: 'END DATE',
    year: 2024,
    month: 8,
  );

  // No Country Visit association is selected.
  // Creating a city must not implicitly mark its country as visited.
  await tester.tap(find.text('Save Visit'));
  await tester.pumpAndSettle();
}
