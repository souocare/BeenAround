import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beenaround/features/map/application/map_search_results.dart';
import 'package:beenaround/features/map/application/map_search_state.dart';
import 'package:beenaround/features/map/domain/map_search_destination.dart';
import 'package:beenaround/features/map/presentation/widgets/map_search_results_panel.dart';

void main() {
  Widget buildTestWidget({
    required MapSearchState state,
    ValueChanged<MapSearchDestination>? onSelected,
    VoidCallback? onRetry,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 350,
            child: MapSearchResultsPanel(
              state: state,
              onDestinationSelected: onSelected ?? (_) {},
              onRetry: onRetry ?? () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows grouped geographic results', (tester) async {
    final state = MapSearchState(
      query: 'Lis',
      phase: MapSearchPhase.ready,
      results: MapSearchResults(
        cities: const [
          MapSearchDestination(
            type: MapSearchDestinationType.city,
            id: 'city:123',
            title: 'Lisbon',
            subtitle: 'Portugal',
          ),
        ],
        airports: const [
          MapSearchDestination(
            type: MapSearchDestinationType.airport,
            id: 'airport:456',
            title: 'Humberto Delgado Airport',
            subtitle: 'LIS · Lisbon, Portugal',
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildTestWidget(state: state));

    expect(find.text('CITIES'), findsOneWidget);
    expect(find.text('AIRPORTS'), findsOneWidget);

    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Humberto Delgado Airport'), findsOneWidget);

    expect(find.text('COUNTRIES'), findsNothing);
  });

  testWidgets('reports the selected destination', (tester) async {
    const destination = MapSearchDestination(
      type: MapSearchDestinationType.city,
      id: 'city:123',
      title: 'Lisbon',
      subtitle: 'Portugal',
    );

    MapSearchDestination? selected;

    final state = MapSearchState(
      query: 'Lisbon',
      phase: MapSearchPhase.ready,
      results: MapSearchResults(cities: [destination]),
    );

    await tester.pumpWidget(
      buildTestWidget(state: state, onSelected: (value) => selected = value),
    );

    await tester.tap(find.text('Lisbon'));
    await tester.pump();

    expect(selected, same(destination));
  });

  testWidgets('shows an empty state', (tester) async {
    final state = MapSearchState(
      query: 'Unknown',
      phase: MapSearchPhase.ready,
      results: MapSearchResults(),
    );

    await tester.pumpWidget(buildTestWidget(state: state));

    expect(find.text('No destinations found'), findsOneWidget);
  });

  testWidgets('allows retry after failure', (tester) async {
    var retryCount = 0;

    final state = MapSearchState(
      query: 'Lisbon',
      phase: MapSearchPhase.failure,
      results: MapSearchResults(
        failedCategories: MapSearchCategory.values.toSet(),
      ),
    );

    await tester.pumpWidget(
      buildTestWidget(state: state, onRetry: () => retryCount++),
    );

    await tester.tap(find.text('Try again'));

    expect(retryCount, 1);
  });
  testWidgets('shows a compact skeleton while searching', (tester) async {
    final state = MapSearchState(
      query: 'Lis',
      phase: MapSearchPhase.loading,
      results: MapSearchResults(),
    );

    await tester.pumpWidget(buildTestWidget(state: state));

    expect(find.byType(CircularProgressIndicator), findsNothing);

    expect(find.byType(MapSearchResultsPanel), findsOneWidget);

    expect(find.text('Searching destinations...'), findsNothing);
  });
}
