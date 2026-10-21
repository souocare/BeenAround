import 'dart:async';

import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/pages/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeExploreRepository implements CountriesRepository {
  FakeExploreRepository({this.countries = const [], this.visits = const []});

  List<Country> countries;
  List<CountryVisit> visits;

  Future<List<Country>> Function()? countriesHandler;

  int loadCount = 0;

  @override
  Future<List<Country>> getCountries() {
    loadCount++;

    if (countriesHandler != null) {
      return countriesHandler!();
    }

    return Future.value(countries);
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    throw UnimplementedError(
      'Country visit creation is not used by this test.',
    );
  }

  @override
  Future<List<CountryVisit>> getCountryVisits() async => visits;
}

const portugal = Country(code: 'PT', name: 'Portugal', alpha3Code: 'PRT');

const spain = Country(code: 'ES', name: 'Spain', alpha3Code: 'ESP');

CountryVisit visit(String id, String countryCode) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
  );
}

void main() {
  Future<void> pumpExplore(WidgetTester tester, ExploreCubit cubit) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(value: cubit, child: const ExplorePage()),
        ),
      ),
    );
  }

  testWidgets('shows loading state', (tester) async {
    final pending = Completer<List<Country>>();

    final repository = FakeExploreRepository()
      ..countriesHandler = () => pending.future;

    final cubit = ExploreCubit(repository: repository);

    addTearDown(cubit.close);

    await pumpExplore(tester, cubit);

    final loading = cubit.load();

    await tester.pump();

    expect(find.text('Loading your travel history...'), findsOneWidget);

    pending.complete([]);

    await loading;
  });

  testWidgets('shows empty state when there are no visits', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(countries: [portugal, spain]),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    expect(find.text('No countries visited yet'), findsOneWidget);
    expect(find.text('Countries visited'), findsOneWidget);
    expect(find.text('Total visits'), findsOneWidget);
  });

  testWidgets('shows visited countries and statistics', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT'), visit('2', 'PT'), visit('3', 'ES')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);

    expect(find.text('2 visits'), findsOneWidget);
    expect(find.text('1 visit'), findsOneWidget);

    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows error state and retries', (tester) async {
    final repository = FakeExploreRepository();

    repository.countriesHandler = () async {
      throw const FormatException('Invalid response');
    };

    final cubit = ExploreCubit(repository: repository);

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    expect(find.text('Unable to load Explore'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    repository.countriesHandler = () async => [portugal];

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(find.text('No countries visited yet'), findsOneWidget);
    expect(repository.loadCount, 2);
  });

  testWidgets('keeps existing data during refresh', (tester) async {
    final repository = FakeExploreRepository(
      countries: [portugal],
      visits: [visit('1', 'PT')],
    );

    final cubit = ExploreCubit(repository: repository);

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    final pending = Completer<List<Country>>();

    repository.countriesHandler = () => pending.future;

    final refresh = cubit.refresh();

    await tester.pump();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    pending.complete([portugal]);

    await refresh;
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
  testWidgets('searches visited countries by name', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT'), visit('2', 'ES')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('visitedCountriesSearch')),
      'port',
    );

    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    // A pesquisa não altera as estatísticas globais.
    expect(cubit.state.visitedCountryCount, 2);
  });
  testWidgets('searches visited countries by ISO codes', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT'), visit('2', 'ES')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    final search = find.byKey(const Key('visitedCountriesSearch'));

    await tester.enterText(search, 'PRT');
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    await tester.enterText(search, 'ES');
    await tester.pumpAndSettle();

    expect(find.text('Spain'), findsOneWidget);
    expect(find.text('Portugal'), findsNothing);
  });

  testWidgets('filters countries with multiple visits', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT'), visit('2', 'PT'), visit('3', 'ES')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    await tester.tap(find.text('Multiple visits'));
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('Spain'), findsOneWidget);
  });

  testWidgets('shows no matching countries for empty search results', (
    tester,
  ) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [visit('1', 'PT')],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    await tester.enterText(
      find.byKey(const Key('visitedCountriesSearch')),
      'Japan',
    );

    await tester.pumpAndSettle();

    expect(find.text('No matching countries'), findsOneWidget);
    expect(find.text('No countries visited yet'), findsNothing);
  });

  testWidgets('sorts visited countries by number of visits', (tester) async {
    final cubit = ExploreCubit(
      repository: FakeExploreRepository(
        countries: [portugal, spain],
        visits: [
          visit('1', 'PT'),
          visit('2', 'ES'),
          visit('3', 'ES'),
          visit('4', 'ES'),
        ],
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();
    await pumpExplore(tester, cubit);

    await tester.tap(find.text('Name A–Z'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Most visited').last);
    await tester.pumpAndSettle();

    final portugalPosition = tester.getTopLeft(find.text('Portugal')).dy;
    final spainPosition = tester.getTopLeft(find.text('Spain')).dy;

    expect(spainPosition, lessThan(portugalPosition));
  });
}
