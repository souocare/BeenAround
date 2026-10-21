import 'package:beenaround/features/explore/application/explore_cubit.dart';
import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/explore/presentation/pages/explore_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beenaround/core/network/api_exception.dart';

class FakeCountriesRepository implements CountriesRepository {
  FakeCountriesRepository({
    required this.countries,
    required List<CountryVisit> visits,
  }) : visits = List.of(visits);

  final List<Country> countries;
  final List<CountryVisit> visits;

  int updateCalls = 0;

  String? receivedVisitId;
  DateTime? receivedStartedOn;
  DateTime? receivedEndedOn;

  Future<CountryVisit> Function()? updateHandler;

  @override
  Future<List<Country>> getCountries() async => countries;

  @override
  Future<List<CountryVisit>> getCountryVisits() async =>
      List.unmodifiable(visits);

  @override
  Future<CountryVisit> updateCountryVisit({
    required String visitId,
    DateTime? startedOn,
    DateTime? endedOn,
  }) async {
    updateCalls++;

    receivedVisitId = visitId;
    receivedStartedOn = startedOn;
    receivedEndedOn = endedOn;

    if (updateHandler != null) {
      return updateHandler!();
    }

    final index = visits.indexWhere((visit) => visit.id == visitId);

    if (index == -1) {
      throw StateError('Visit not found.');
    }

    final previous = visits[index];

    final updated = CountryVisit(
      id: previous.id,
      countryCode: previous.countryCode,
      startedOn: startedOn,
      endedOn: endedOn,
      createdAt: previous.createdAt,
      updatedAt: DateTime(2026, 10, 22),
    );

    visits[index] = updated;

    return updated;
  }

  @override
  Future<CountryVisit> createCountryVisit({
    required String countryCode,
    DateTime? startedOn,
    DateTime? endedOn,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCountryVisit({required String visitId}) {
    throw UnimplementedError(
      'Country visit deletion is not used by this test.',
    );
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
    FakeCountriesRepository? repository,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final effectiveRepository =
        repository ??
        FakeCountriesRepository(countries: [portugal], visits: visits);

    final cubit = ExploreCubit(repository: effectiveRepository);

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
  testWidgets('opens edit visit with existing dates', (tester) async {
    await pumpExplore(
      tester,
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit visit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Visit'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    expect(find.text('15/10/2026'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
  });
  testWidgets('clears visit dates and refreshes country details', (
    tester,
  ) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitClearDates')));
    await tester.pumpAndSettle();

    expect(find.text('Not set'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedVisitId, 'visit-1');
    expect(repository.receivedStartedOn, isNull);
    expect(repository.receivedEndedOn, isNull);

    expect(find.text('Edit Visit'), findsNothing);
    expect(find.text('Dates not specified'), findsOneWidget);
  });
  testWidgets('updates visit start date', (tester) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitStartDate')));
    await tester.pumpAndSettle();

    // O calendário abre em outubro de 2026.
    // Selecionamos o dia 12.
    await tester.tap(find.text('12').last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('12/10/2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedStartedOn, DateTime(2026, 10, 12));
    expect(repository.receivedEndedOn, DateTime(2026, 10, 15));

    expect(find.text('12/10/2026 – 15/10/2026'), findsOneWidget);
  });
  testWidgets('keeps edit form open when update fails', (tester) async {
    final repository = FakeCountriesRepository(
      countries: [portugal],
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    repository.updateHandler = () async {
      throw const ApiException(
        type: ApiErrorType.server,
        message: 'Server unavailable.',
      );
    };

    await pumpExplore(
      tester,
      visits: repository.visits,
      repository: repository,
    );

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editVisitSaveButton')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(find.text('Edit Visit'), findsOneWidget);
    expect(find.text('Server unavailable.'), findsOneWidget);

    expect(find.text('10/10/2026'), findsOneWidget);
    expect(find.text('15/10/2026'), findsOneWidget);

    expect(find.text('Save Changes'), findsOneWidget);
  });
  testWidgets('opens edit visit as dialog on desktop', (tester) async {
    await pumpExplore(
      tester,
      size: const Size(1200, 900),
      visits: [
        visit(
          id: 'visit-1',
          countryCode: 'PT',
          startedOn: DateTime(2026, 10, 10),
        ),
      ],
    );

    await tester.tap(find.text('Portugal'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit visit'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Edit Visit'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
  });
}
