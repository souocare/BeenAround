import 'package:beenaround/app/widgets/country_flag.dart';
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
  testWidgets('displays a country flag next to its ISO code', (tester) async {
    final state = MapSearchState(
      query: 'Portugal',
      phase: MapSearchPhase.ready,
      results: MapSearchResults(
        countries: [MapSearchDestination.country(code: 'PT', name: 'Portugal')],
      ),
    );

    await tester.pumpWidget(buildTestWidget(state: state));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('PT'), findsOneWidget);

    expect(find.byType(CountryFlag), findsOneWidget);

    final flag = tester.widget<CountryFlag>(find.byType(CountryFlag));

    expect(flag.countryCode, 'PT');
  });
  testWidgets('displays a city country flag', (tester) async {
    const destination = MapSearchDestination(
      type: MapSearchDestinationType.city,
      id: 'city:123',
      title: 'Porto Alegre',
      subtitle: 'Brazil',
      countryCode: 'BR',
    );

    final state = MapSearchState(
      query: 'Porto Alegre',
      phase: MapSearchPhase.ready,
      results: MapSearchResults(cities: [destination]),
    );

    await tester.pumpWidget(buildTestWidget(state: state));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Porto Alegre'), findsOneWidget);
    expect(find.text('Brazil'), findsOneWidget);

    final flag = tester.widget<CountryFlag>(find.byType(CountryFlag));

    expect(flag.countryCode, 'BR');
  });
  testWidgets('displays structured airport location with country flag', (
    tester,
  ) async {
    const destination = MapSearchDestination(
      type: MapSearchDestinationType.airport,
      id: 'airport:456',
      title: 'Madeira Airport',
      subtitle: 'FNC · Funchal, Portugal',
      countryCode: 'PT',
      airportCode: 'FNC',
      airportLocation: 'Funchal, Portugal',
    );

    final state = MapSearchState(
      query: 'FNC',
      phase: MapSearchPhase.ready,
      results: MapSearchResults(airports: [destination]),
    );

    await tester.pumpWidget(buildTestWidget(state: state));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Madeira Airport'), findsOneWidget);
    expect(find.text('FNC'), findsOneWidget);
    expect(find.text('Funchal, Portugal'), findsOneWidget);

    final flag = tester.widget<CountryFlag>(find.byType(CountryFlag));

    expect(flag.countryCode, 'PT');
  });
  testWidgets('supports legacy airport subtitles', (tester) async {
    const destination = MapSearchDestination(
      type: MapSearchDestinationType.airport,
      id: 'airport:789',
      title: 'Example Airport',
      subtitle: 'ABC · Example City',
    );

    final state = MapSearchState(
      query: 'ABC',
      phase: MapSearchPhase.ready,
      results: MapSearchResults(airports: [destination]),
    );

    await tester.pumpWidget(buildTestWidget(state: state));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('ABC · Example City'), findsOneWidget);
  });
  testWidgets('handles very long airport locations without overflow', (
    tester,
  ) async {
    const destination = MapSearchDestination(
      type: MapSearchDestinationType.airport,
      id: 'airport:999',
      title: 'Very Long International Airport Name',
      subtitle: 'XYZ · Very Long Geographic Location',
      countryCode: 'PT',
      airportCode: 'XYZ',
      airportLocation:
          'An Extremely Long Geographic Location With Many Words, Portugal',
    );

    final state = MapSearchState(
      query: 'XYZ',
      phase: MapSearchPhase.ready,
      results: MapSearchResults(airports: [destination]),
    );

    await tester.pumpWidget(buildTestWidget(state: state));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);

    expect(find.text('XYZ'), findsOneWidget);
    expect(find.byType(CountryFlag), findsOneWidget);
  });
}
