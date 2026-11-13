import 'package:beenaround/features/flights/domain/airline.dart';
import 'package:beenaround/features/flights/domain/airline_repository.dart';
import 'package:beenaround/features/flights/domain/airline_selection.dart';
import 'package:beenaround/features/flights/presentation/widgets/airline_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAirlineRepository implements AirlineRepository {
  final List<String> queries = [];
  final List<int> offsets = [];

  @override
  Future<AirlinePage> search({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    queries.add(query ?? '');
    offsets.add(offset);

    if (query == 'error') {
      throw StateError('Network unavailable');
    }

    const airline = Airline(
      id: 10,
      name: 'TAP Air Portugal',
      iataCode: 'TP',
      icaoCode: 'TAP',
      countryName: 'Portugal',
    );

    final matches = query?.toLowerCase() == 'tap' ? [airline] : <Airline>[];

    return AirlinePage(
      items: matches,
      total: matches.length,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<Airline> getAirline({required int airlineId}) {
    throw UnimplementedError();
  }
}

class PaginatedAirlineRepository extends FakeAirlineRepository {
  @override
  Future<AirlinePage> search({
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    queries.add(query ?? '');
    offsets.add(offset);

    const airlines = [
      Airline(id: 1, name: 'Airline Alpha', iataCode: 'AA'),
      Airline(id: 2, name: 'Airline Beta', iataCode: 'BB'),
      Airline(id: 3, name: 'Airline Gamma', iataCode: 'GG'),
    ];

    // Simulate server-side pagination.
    const pageLength = 2;

    final pageItems = airlines
        .skip(offset)
        .take(pageLength)
        .toList(growable: false);

    return AirlinePage(
      items: pageItems,
      total: airlines.length,
      limit: pageLength,
      offset: offset,
    );
  }
}

void main() {
  late FakeAirlineRepository repository;
  AirlineSelection? selected;

  setUp(() {
    repository = FakeAirlineRepository();
    selected = null;
  });

  Future<void> openPicker(
    WidgetTester tester, {
    AirlineRepository? airlineRepository,
  }) async {
    await tester.pumpWidget(
      RepositoryProvider<AirlineRepository>.value(
        value: airlineRepository ?? repository,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selected = await showAirlinePicker(context);
                },
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

  testWidgets('opens airline search', (tester) async {
    await openPicker(tester);

    expect(find.text('Select Airline'), findsOneWidget);
    expect(find.byKey(const Key('airlineSearchField')), findsOneWidget);
    expect(find.text('Enter airline manually'), findsOneWidget);
  });

  testWidgets('does not search with fewer than two characters', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byKey(const Key('airlineSearchField')), 'T');

    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.queries, ['']);
  });

  testWidgets('searches and displays matching airlines', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byKey(const Key('airlineSearchField')), 'TAP');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(repository.queries, ['', 'TAP']);

    expect(find.text('TAP Air Portugal'), findsOneWidget);
    expect(find.byKey(const ValueKey('airline-10')), findsOneWidget);
  });

  testWidgets('returns a catalog airline selection', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byKey(const Key('airlineSearchField')), 'TAP');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('airline-10')));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.airlineId, 10);
    expect(selected!.airlineName, isNull);
  });

  testWidgets('allows manual airline entry', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('enterManualAirline')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('manualAirlineNameField')),
      'Air Berlin',
    );

    await tester.tap(find.byKey(const Key('confirmManualAirline')));
    await tester.pumpAndSettle();

    expect(selected, isNotNull);
    expect(selected!.airlineId, isNull);
    expect(selected!.airlineName, 'Air Berlin');
  });

  testWidgets('rejects an empty manual airline name', (tester) async {
    await openPicker(tester);

    await tester.tap(find.byKey(const Key('enterManualAirline')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmManualAirline')));
    await tester.pump();

    expect(find.text('Enter an airline name.'), findsOneWidget);
    expect(selected, isNull);
  });

  testWidgets('shows empty search results', (tester) async {
    await openPicker(tester);

    await tester.enterText(find.byKey(const Key('airlineSearchField')), 'XYZ');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.textContaining('No airlines found'), findsOneWidget);
    expect(find.text('Enter airline manually'), findsOneWidget);
  });

  testWidgets('keeps manual entry available after search failure', (
    tester,
  ) async {
    await openPicker(tester);

    await tester.enterText(
      find.byKey(const Key('airlineSearchField')),
      'error',
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.textContaining('Unable to search airlines'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Enter airline manually'), findsOneWidget);
  });
  testWidgets('loads more airlines without replacing existing results', (
    tester,
  ) async {
    final paginatedRepository = PaginatedAirlineRepository();

    await openPicker(tester, airlineRepository: paginatedRepository);

    expect(find.text('Airline Alpha'), findsOneWidget);
    expect(find.text('Airline Beta'), findsOneWidget);
    expect(find.text('Airline Gamma'), findsNothing);

    expect(find.byKey(const Key('loadMoreAirlines')), findsOneWidget);

    await tester.tap(find.byKey(const Key('loadMoreAirlines')));

    await tester.pumpAndSettle();

    expect(find.text('Airline Alpha'), findsOneWidget);
    expect(find.text('Airline Beta'), findsOneWidget);
    expect(find.text('Airline Gamma'), findsOneWidget);

    expect(paginatedRepository.offsets, [0, 2]);

    expect(find.byKey(const Key('loadMoreAirlines')), findsNothing);
  });
  testWidgets('new search resets previously loaded airlines', (tester) async {
    final paginatedRepository = PaginatedAirlineRepository();

    await openPicker(tester, airlineRepository: paginatedRepository);

    await tester.tap(find.byKey(const Key('loadMoreAirlines')));

    await tester.pumpAndSettle();

    expect(find.text('Airline Gamma'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('airlineSearchField')), 'TAP');

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(paginatedRepository.offsets.last, 0);
  });
}
