import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/pages/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCountriesRepository implements CountriesRepository {
  FakeCountriesRepository({required this.countries, required this.visits});

  final List<Country> countries;
  final List<CountryVisit> visits;

  @override
  Future<List<Country>> getCountries() async => countries;

  @override
  Future<List<CountryVisit>> getCountryVisits() async => visits;

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    throw UnimplementedError(
      'Country visit updates are not used by this test.',
    );
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    throw UnimplementedError();
  }
}

CountryVisit visit({
  required String id,
  required String countryCode,
  DateTime? startedOn,
  DateTime? endedOn,
}) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: DateTime(2026, 10, 21),
    updatedAt: DateTime(2026, 10, 21),
  );
}

void main() {
  const portugal = Country(code: 'PT', name: 'Portugal', alpha3Code: 'PRT');

  Future<void> pumpExplore(
    WidgetTester tester, {
    required List<CountryVisit> visits,
  }) async {
    final cubit = ExploreCubit(
      repository: FakeCountriesRepository(
        countries: [portugal],
        visits: visits,
      ),
    );

    addTearDown(cubit.close);

    await cubit.load();

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: cubit,
          child: const Scaffold(body: ExplorePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('opens country details from Explore', (tester) async {
    await pumpExplore(
      tester,
      visits: [visit(id: '1', countryCode: 'PT')],
    );

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    expect(find.text('Visit history'), findsOneWidget);
    expect(find.text('Total visits'), findsOneWidget);
    expect(find.text('Dates not specified'), findsOneWidget);
  });

  testWidgets('shows multiple visits with dates', (tester) async {
    await pumpExplore(
      tester,
      visits: [
        visit(
          id: '1',
          countryCode: 'PT',
          startedOn: DateTime(2024, 6, 2),
          endedOn: DateTime(2024, 6, 8),
        ),
        visit(
          id: '2',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    expect(find.text('Visit 1'), findsOneWidget);
    expect(find.text('Visit 2'), findsOneWidget);

    expect(find.text('10/10/2026 – 15/10/2026'), findsOneWidget);
    expect(find.text('02/06/2024 – 08/06/2024'), findsOneWidget);
  });

  testWidgets('supports visits without an end date', (tester) async {
    await pumpExplore(
      tester,
      visits: [
        visit(id: '1', countryCode: 'PT', startedOn: DateTime(2025, 3, 12)),
      ],
    );

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    expect(find.text('From 12/03/2025'), findsOneWidget);
  });
}
