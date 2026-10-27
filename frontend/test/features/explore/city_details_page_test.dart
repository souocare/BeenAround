import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/visited_cities_cubit.dart';
import 'package:beenaround/features/explore/domain/visited_city.dart';
import 'package:beenaround/features/explore/presentation/pages/city_details_page.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  FakeCityVisitsRepository({required this.visits});

  List<CityVisit> visits;
  int loadCalls = 0;

  int deleteCalls = 0;
  String? receivedDeletedVisitId;

  Future<void> Function()? deleteHandler;

  @override
  Future<List<CityVisit>> getCityVisits() async {
    loadCalls++;
    return List.unmodifiable(visits);
  }

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    DateTime? startedOn,
    DateTime? endedOn,
    VisitDatePrecision? startedOnPrecision,
    VisitDatePrecision? endedOnPrecision,
  }) {
    throw UnimplementedError();
  }

  int updateCalls = 0;

  String? receivedVisitId;
  Map<String, dynamic>? receivedChanges;

  Future<CityVisit> Function()? updateHandler;

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) async {
    updateCalls++;
    receivedVisitId = visitId;
    receivedChanges = Map.of(changes);

    if (updateHandler != null) {
      return updateHandler!();
    }

    final index = visits.indexWhere((visit) => visit.id == visitId);

    if (index == -1) {
      throw StateError('Visit not found.');
    }

    final previous = visits[index];

    final updated = CityVisit(
      id: previous.id,
      cityId: previous.cityId,
      cityName: previous.cityName,
      countryCode: previous.countryCode,
      countryName: previous.countryName,
      startedOn: changes.containsKey('started_on')
          ? changes['started_on'] as DateTime?
          : previous.startedOn,
      endedOn: changes.containsKey('ended_on')
          ? changes['ended_on'] as DateTime?
          : previous.endedOn,
      startedOnPrecision: changes.containsKey('started_on_precision')
          ? changes['started_on_precision'] as VisitDatePrecision?
          : previous.startedOnPrecision,
      endedOnPrecision: changes.containsKey('ended_on_precision')
          ? changes['ended_on_precision'] as VisitDatePrecision?
          : previous.endedOnPrecision,
      createdAt: previous.createdAt,
      updatedAt: DateTime(2026, 10, 24),
    );

    visits[index] = updated;

    return updated;
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) async {
    deleteCalls++;
    receivedDeletedVisitId = visitId;

    if (deleteHandler != null) {
      await deleteHandler!();
      return;
    }

    visits.removeWhere((visit) => visit.id == visitId);
  }
}

CityVisit cityVisit({
  required String id,
  int cityId = 2267057,
  String cityName = 'Lisbon',
  String countryCode = 'PT',
  String countryName = 'Portugal',
  DateTime? startedOn,
  DateTime? endedOn,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime(2026, 10, 24);

  return CityVisit(
    id: id,
    cityId: cityId,
    cityName: cityName,
    countryCode: countryCode,
    countryName: countryName,
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  const lisbonId = 2267057;

  Future<VisitedCitiesCubit> pumpCityDetails(
    WidgetTester tester,
    FakeCityVisitsRepository repository,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final cubit = VisitedCitiesCubit(repository: repository);
    await cubit.load();

    final city = VisitedCity(
      cityId: lisbonId,
      cityName: 'Lisbon',
      countryCode: 'PT',
      countryName: 'Portugal',
      visits: cubit.state.visitsForCity(lisbonId),
    );

    await tester.pumpWidget(
      RepositoryProvider<CityVisitsRepository>.value(
        value: repository,
        child: BlocProvider<VisitedCitiesCubit>.value(
          value: cubit,
          child: MaterialApp(home: CityDetailsPage(city: city)),
        ),
      ),
    );

    await tester.pumpAndSettle();

    addTearDown(cubit.close);

    return cubit;
  }

  testWidgets('shows city identity and visit count', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1'),
        cityVisit(id: 'visit-2'),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(find.text('City Details'), findsOneWidget);
    expect(find.text('Lisbon'), findsOneWidget);
    expect(find.text('Portugal'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('VISITS'), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-visit-2')), findsOneWidget);
  });

  testWidgets('orders dated visits newest first and undated visits last', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'old', startedOn: DateTime(2024, 6, 10)),
        cityVisit(id: 'undated'),
        cityVisit(id: 'new', startedOn: DateTime(2026, 10, 5)),
      ],
    );

    await pumpCityDetails(tester, repository);

    final newVisit = find.byKey(const Key('cityVisit-new'));
    final oldVisit = find.byKey(const Key('cityVisit-old'));
    final undatedVisit = find.byKey(const Key('cityVisit-undated'));

    expect(newVisit, findsOneWidget);
    expect(oldVisit, findsOneWidget);
    expect(undatedVisit, findsOneWidget);

    expect(
      tester.getTopLeft(newVisit).dy,
      lessThan(tester.getTopLeft(oldVisit).dy),
    );

    expect(
      tester.getTopLeft(oldVisit).dy,
      lessThan(tester.getTopLeft(undatedVisit).dy),
    );
  });

  testWidgets('shows optional visit dates correctly', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'range',
          startedOn: DateTime(2026, 10, 5),
          endedOn: DateTime(2026, 10, 10),
        ),
        cityVisit(id: 'start-only', startedOn: DateTime(2025, 6, 12)),
        cityVisit(id: 'end-only', endedOn: DateTime(2024, 3, 20)),
        cityVisit(id: 'undated'),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(find.text('5 Oct 2026 – 10 Oct 2026'), findsOneWidget);
    expect(find.text('From 12 Jun 2025'), findsOneWidget);
    expect(find.text('Until 20 Mar 2024'), findsOneWidget);
    expect(find.text('Dates not specified'), findsOneWidget);
    expect(find.text('10 Oct 2026'), findsOneWidget);
  });

  testWidgets('shows an empty state when city has no visits', (tester) async {
    final repository = FakeCityVisitsRepository(visits: []);

    await pumpCityDetails(tester, repository);

    expect(find.text('No visits recorded for this city.'), findsOneWidget);

    expect(find.text('0'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('updates displayed visits after cubit reload', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final cubit = await pumpCityDetails(tester, repository);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsOneWidget);

    repository.visits = [cityVisit(id: 'visit-1'), cityVisit(id: 'visit-2')];

    await cubit.load();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cityVisit-visit-2')), findsOneWidget);

    expect(find.text('2'), findsOneWidget);
    expect(repository.loadCalls, 2);
  });

  testWidgets('only displays visits belonging to selected city', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'lisbon-visit'),
        cityVisit(
          id: 'madrid-visit',
          cityId: 3117735,
          cityName: 'Madrid',
          countryCode: 'ES',
          countryName: 'Spain',
        ),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(find.byKey(const Key('cityVisit-lisbon-visit')), findsOneWidget);

    expect(find.byKey(const Key('cityVisit-madrid-visit')), findsNothing);

    expect(find.text('1'), findsOneWidget);
  });
  testWidgets('opens edit sheet for selected city visit', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'visit-1',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit City Visit'), findsOneWidget);
    expect(find.text('10/10/2026'), findsOneWidget);
    expect(find.text('15/10/2026'), findsOneWidget);
  });
  testWidgets('updates city history after editing a visit', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(
          id: 'visit-1',
          startedOn: DateTime(2026, 10, 10),
          endedOn: DateTime(2026, 10, 15),
        ),
      ],
    );

    await pumpCityDetails(tester, repository);

    expect(find.text('10 Oct 2026 – 15 Oct 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    final clearEndButton = find.byKey(const Key('editCityVisitClearEndDate'));

    await tester.ensureVisible(clearEndButton);
    await tester.pumpAndSettle();

    await tester.tap(clearEndButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedVisitId, 'visit-1');

    expect(repository.receivedChanges, {
      'ended_on': null,
      'ended_on_precision': null,
    });

    expect(repository.loadCalls, 2);

    expect(find.text('From 10 Oct 2026'), findsOneWidget);

    expect(find.text('10 Oct 2026 – 15 Oct 2026'), findsNothing);
  });
  testWidgets('does not update visit when editing is cancelled', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1', startedOn: DateTime(2026, 10, 10))],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 0);
    expect(repository.loadCalls, 1);

    expect(find.text('From 10 Oct 2026'), findsOneWidget);
  });
  testWidgets('editing one visit preserves other visits', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1', startedOn: DateTime(2026, 10, 10)),
        cityVisit(id: 'visit-2', startedOn: DateTime(2025, 5, 20)),
      ],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit visit'));
    await tester.pumpAndSettle();

    final clearStartButton = find.byKey(
      const Key('editCityVisitClearStartDate'),
    );

    await tester.ensureVisible(clearStartButton);
    await tester.pumpAndSettle();

    await tester.tap(clearStartButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('editCityVisitSaveButton')));

    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.receivedVisitId, 'visit-1');

    expect(
      repository.visits.singleWhere((visit) => visit.id == 'visit-2').startedOn,
      DateTime(2025, 5, 20),
    );

    expect(find.text('From 20 May 2025'), findsOneWidget);
  });
  testWidgets('deletes selected city visit and refreshes history', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [
        cityVisit(id: 'visit-1', startedOn: DateTime(2026, 10, 10)),
        cityVisit(id: 'visit-2', startedOn: DateTime(2025, 5, 20)),
      ],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    expect(find.text('Delete visit?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.receivedDeletedVisitId, 'visit-1');
    expect(repository.loadCalls, 2);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsNothing);

    expect(find.byKey(const Key('cityVisit-visit-2')), findsOneWidget);

    expect(find.text('1'), findsOneWidget);
  });
  testWidgets('cancelled deletion preserves city visit', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cancelDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(repository.loadCalls, 1);

    expect(find.byKey(const Key('cityVisit-visit-1')), findsOneWidget);
  });
  testWidgets('failed deletion preserves visit and shows error', (
    tester,
  ) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    repository.deleteHandler = () async {
      throw StateError('Unexpected error');
    };

    await pumpCityDetails(tester, repository);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.loadCalls, 1);

    expect(
      find.text('Unable to delete your visit. Please try again.'),
      findsOneWidget,
    );

    expect(find.text('Delete visit?'), findsOneWidget);
  });
  testWidgets('deleting last visit returns to previous page', (tester) async {
    final repository = FakeCityVisitsRepository(
      visits: [cityVisit(id: 'visit-1')],
    );

    final cubit = VisitedCitiesCubit(repository: repository);
    await cubit.load();

    addTearDown(cubit.close);

    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final visit = repository.visits.single;

    final city = VisitedCity(
      cityId: visit.cityId,
      cityName: visit.cityName,
      countryCode: visit.countryCode,
      countryName: visit.countryName,
      visits: [visit],
    );

    await tester.pumpWidget(
      RepositoryProvider<CityVisitsRepository>.value(
        value: repository,
        child: BlocProvider<VisitedCitiesCubit>.value(
          value: cubit,
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CityDetailsPage(city: city),
                        ),
                      );
                    },
                    child: const Text('Open city'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open city'));
    await tester.pumpAndSettle();

    expect(find.text('City Details'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cityVisitMenu-visit-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete visit'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.visits, isEmpty);

    expect(find.text('City Details'), findsNothing);
    expect(find.text('Open city'), findsOneWidget);

    expect(cubit.state.visitedCities, isEmpty);
  });
}
