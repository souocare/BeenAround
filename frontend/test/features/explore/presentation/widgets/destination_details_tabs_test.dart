import 'package:beenaround/features/explore/presentation/widgets/destination_details_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders all destination tabs', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinationDetailsTabs(
            labels: const ['Overview', 'Visits', 'Cities', 'Trips'],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Visits'), findsOneWidget);
    expect(find.text('Cities'), findsOneWidget);
    expect(find.text('Trips'), findsOneWidget);
  });

  testWidgets('marks only the selected tab', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinationDetailsTabs(
            labels: const ['Overview', 'Visits', 'Trips'],
            selectedIndex: 1,
            tabKeyPrefix: 'testTab',
            onSelected: (_) {},
          ),
        ),
      ),
    );

    final overview = tester.widget<Semantics>(
      find.byKey(const Key('testTab-overview')),
    );

    final visits = tester.widget<Semantics>(
      find.byKey(const Key('testTab-visits')),
    );

    final trips = tester.widget<Semantics>(
      find.byKey(const Key('testTab-trips')),
    );

    expect(overview.properties.selected, isFalse);
    expect(visits.properties.selected, isTrue);
    expect(trips.properties.selected, isFalse);
  });

  testWidgets('notifies parent when selecting a tab', (tester) async {
    int? selectedIndex;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DestinationDetailsTabs(
            labels: const ['Overview', 'Visits', 'Trips'],
            selectedIndex: 0,
            onSelected: (index) {
              selectedIndex = index;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Trips'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
  });

  testWidgets('supports country and city tab configurations', (tester) async {
    Future<void> pumpTabs(List<String> labels) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DestinationDetailsTabs(
              labels: labels,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
    }

    await pumpTabs(['Overview', 'Visits', 'Cities', 'Trips']);

    expect(find.text('Cities'), findsOneWidget);

    await pumpTabs(['Overview', 'Visits', 'Trips']);

    expect(find.text('Cities'), findsNothing);
    expect(find.text('Trips'), findsOneWidget);
  });
}
