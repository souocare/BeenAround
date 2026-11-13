import 'package:beenaround/features/flights/domain/airport.dart';
import 'package:beenaround/features/flights/domain/airport_repository.dart';
import 'package:beenaround/features/flights/presentation/widgets/airport_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';

class FakeAirportRepository implements AirportRepository {
  final List<String> queries = [];
  final List<String?> countryCodes = [];
  final List<int> offsets = [];

  @override
  Future<AirportPage> search({
    String? query,
    String? countryCode,
    bool scheduledOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    queries.add(query ?? '');
    countryCodes.add(countryCode);
    offsets.add(offset);

    if (query == 'error') {
      throw StateError('Network unavailable');
    }

    final airport = Airport(
      id: 100,
      ident: 'LPPT',
      iataCode: 'LIS',
      icaoCode: 'LPPT',
      name: 'Lisbon Humberto Delgado Airport',
      municipality: 'Lisbon',
      countryName: 'Portugal',
      countryCode: 'PT',
      type: 'large_airport',
      scheduledService: true,
    );

    final matches = query?.toLowerCase() == 'lis' || countryCode == 'PT'
        ? [airport]
        : <Airport>[];

    return AirportPage(
      items: matches,
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Airport> getAirport({required int airportId}) {
    throw UnimplementedError();
  }
}

class FakeAirportCountriesRepository extends Fake
    implements CountriesRepository {
  @override
  Future<List<Country>> getCountries() async {
    return const [
      Country(
        code: 'PT',
        name: 'Portugal',
        alpha3Code: 'PRT',
        continent: 'Europe',
      ),
      Country(
        code: 'ES',
        name: 'Spain',
        alpha3Code: 'ESP',
        continent: 'Europe',
      ),
    ];
  }
}

void main() {
  late FakeAirportRepository repository;

  setUp(() {
    repository = FakeAirportRepository();
  });

  Future<void> openPicker(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<AirportRepository>.value(value: repository),
          RepositoryProvider<CountriesRepository>.value(
            value: FakeAirportCountriesRepository(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAirportPicker(context),
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Picker'));
    await tester.pumpAndSettle();
  }

  testWidgets('opens airport search', (tester) async {
    await openPicker(tester);

    expect(find.text('Select Airport'), findsOneWidget);
    expect(find.byKey(const Key('airportSearchField')), findsOneWidget);
  });

  testWidgets('does not search with fewer than two characters', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byKey(const Key('airportSearchField')), 'L');

    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.queries, isEmpty);
  });

  testWidgets('searches and displays matching airports', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byKey(const Key('airportSearchField')), 'LIS');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(repository.queries, ['LIS']);

    expect(find.text('Lisbon Humberto Delgado Airport'), findsOneWidget);

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('airport-100')),
        matching: find.text('LIS'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows an empty state for unmatched searches', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byKey(const Key('airportSearchField')), 'XYZ');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('No airports found.'), findsOneWidget);
  });

  testWidgets('shows errors without closing the picker', (tester) async {
    await openPicker(tester);

    await tester.enterText(
      find.byKey(const Key('airportSearchField')),
      'error',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.textContaining('Unable to search airports'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Select Airport'), findsOneWidget);
  });
  testWidgets('shows countries without searching airports', (tester) async {
    await openPicker(tester);

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);

    expect(repository.queries, isEmpty);
  });
  testWidgets('opens airports for a selected country', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const ValueKey('airport-country-PT')));

    await tester.pumpAndSettle();

    expect(repository.queries, ['']);
    expect(repository.countryCodes, ['PT']);

    expect(find.byKey(const ValueKey('airport-100')), findsOneWidget);

    expect(find.text('LIS'), findsOneWidget);
  });

  testWidgets('back returns to countries', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const ValueKey('airport-country-PT')));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('flightPickerBackButton')));

    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);

    expect(find.byKey(const ValueKey('airport-100')), findsNothing);
  });

  testWidgets('search is global even inside a country', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const ValueKey('airport-country-PT')));

    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('airportSearchField')), 'LIS');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(repository.queries, ['', 'LIS']);
    expect(repository.countryCodes, ['PT', null]);
  });

  testWidgets('clearing search restores selected country', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const ValueKey('airport-country-PT')));

    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('airportSearchField')), 'XYZ');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.text('No airports found.'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();

    expect(repository.countryCodes.last, 'PT');
    expect(find.byKey(const ValueKey('airport-100')), findsOneWidget);
  });
}
