import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/delete_city_visit_cubit.dart';
import 'package:beenaround/features/explore/domain/visited_city.dart';
import 'package:beenaround/features/explore/presentation/widgets/delete_city_visit_dialog.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  int deleteCalls = 0;
  String? receivedVisitId;

  Future<void> Function()? deleteHandler;

  @override
  Future<List<CityVisit>> getCityVisits() async => const [];

  @override
  Future<CityVisit> createCityVisit({
    required int cityId,
    required DateTime startedOn,
    required DateTime endedOn,
    VisitDatePrecision startedOnPrecision = VisitDatePrecision.day,
    VisitDatePrecision endedOnPrecision = VisitDatePrecision.day,
    String? countryVisitId,
    NewCountryVisitInput? newCountryVisit,
    CountryVisitDateExpansion? countryDateExpansion,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<CityVisit> updateCityVisit({
    required String visitId,
    required Map<String, dynamic> changes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteCityVisit({required String visitId}) async {
    deleteCalls++;
    receivedVisitId = visitId;

    if (deleteHandler != null) {
      await deleteHandler!();
    }
  }
}

CityVisit makeVisit({DateTime? startedOn, DateTime? endedOn}) {
  return CityVisit(
    id: 'visit-1',
    cityId: 2267057,
    cityName: 'Lisbon',
    countryCode: 'PT',
    countryName: 'Portugal',
    startedOn: startedOn,
    endedOn: endedOn,
    createdAt: DateTime(2026, 10, 20),
    updatedAt: DateTime(2026, 10, 24),
  );
}

void main() {
  Future<void> pumpDialog(
    WidgetTester tester, {
    required FakeCityVisitsRepository repository,
    required CityVisit visit,
  }) async {
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
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) {
                          return BlocProvider(
                            create: (_) =>
                                DeleteCityVisitCubit(repository: repository),
                            child: DeleteCityVisitDialog(
                              city: city,
                              visit: visit,
                            ),
                          );
                        },
                      );
                    },
                    child: const Text('Open dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows city, country, dates and warning', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpDialog(
      tester,
      repository: repository,
      visit: makeVisit(
        startedOn: DateTime(2026, 10, 10),
        endedOn: DateTime(2026, 10, 15),
      ),
    );

    expect(find.textContaining('Lisbon, Portugal'), findsOneWidget);

    expect(find.text('10/10/2026 – 15/10/2026'), findsOneWidget);

    expect(find.text('This action cannot be undone.'), findsOneWidget);
  });

  testWidgets('supports visits without dates', (tester) async {
    await pumpDialog(
      tester,
      repository: FakeCityVisitsRepository(),
      visit: makeVisit(),
    );

    expect(find.text('Dates not specified'), findsOneWidget);
  });

  testWidgets('cancel does not delete visit', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpDialog(tester, repository: repository, visit: makeVisit());

    await tester.tap(find.byKey(const Key('cancelDeleteCityVisit')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
    expect(find.text('Delete visit?'), findsNothing);
  });

  testWidgets('confirm deletes the correct visit', (tester) async {
    final repository = FakeCityVisitsRepository();

    await pumpDialog(tester, repository: repository, visit: makeVisit());

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));

    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 1);
    expect(repository.receivedVisitId, 'visit-1');
    expect(find.text('Delete visit?'), findsNothing);
  });

  testWidgets('disables actions during deletion', (tester) async {
    final repository = FakeCityVisitsRepository();
    final pending = Completer<void>();

    repository.deleteHandler = () => pending.future;

    await pumpDialog(tester, repository: repository, visit: makeVisit());

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));

    await tester.pump();

    final confirmButton = tester.widget<FilledButton>(
      find.byKey(const Key('confirmDeleteCityVisit')),
    );

    final cancelButton = tester.widget<TextButton>(
      find.byKey(const Key('cancelDeleteCityVisit')),
    );

    expect(confirmButton.onPressed, isNull);
    expect(cancelButton.onPressed, isNull);
    expect(repository.deleteCalls, 1);

    pending.complete();

    await tester.pumpAndSettle();
  });

  testWidgets('shows repository errors and remains open', (tester) async {
    final repository = FakeCityVisitsRepository();

    repository.deleteHandler = () async {
      throw StateError('Unexpected failure');
    };

    await pumpDialog(tester, repository: repository, visit: makeVisit());

    await tester.tap(find.byKey(const Key('confirmDeleteCityVisit')));

    await tester.pumpAndSettle();

    expect(
      find.text('Unable to delete your visit. Please try again.'),
      findsOneWidget,
    );

    expect(find.text('Delete visit?'), findsOneWidget);
    expect(repository.deleteCalls, 1);
  });
}
