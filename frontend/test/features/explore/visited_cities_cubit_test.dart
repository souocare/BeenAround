import 'dart:async';

import 'package:beenaround/core/models/visit_date_precision.dart';
import 'package:beenaround/features/explore/application/visited_cities_cubit.dart';
import 'package:beenaround/features/explore/application/visited_cities_state.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/geography/domain/country_visit_date_expansion.dart';
import 'package:beenaround/features/geography/domain/new_country_visit_input.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCityVisitsRepository implements CityVisitsRepository {
  List<CityVisit> visits = [];
  Object? error;
  Completer<List<CityVisit>>? pendingLoad;

  int loadCalls = 0;

  @override
  Future<List<CityVisit>> getCityVisits() {
    loadCalls++;

    if (pendingLoad != null) {
      return pendingLoad!.future;
    }

    if (error != null) {
      return Future.error(error!);
    }

    return Future.value(visits);
  }

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
  Future<void> deleteCityVisit({required String visitId}) {
    throw UnimplementedError();
  }
}

CityVisit makeVisit(String id) {
  return CityVisit(
    id: id,
    cityId: 2267057,
    cityName: 'Lisbon',
    countryCode: 'PT',
    countryName: 'Portugal',
    startedOn: null,
    endedOn: null,
    createdAt: DateTime(2026, 10, 24),
    updatedAt: DateTime(2026, 10, 24),
  );
}

void main() {
  test('loads city visits successfully', () async {
    final repository = FakeCityVisitsRepository()
      ..visits = [makeVisit('1'), makeVisit('2')];

    final cubit = VisitedCitiesCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(repository.loadCalls, 1);
    expect(cubit.state.phase, VisitedCitiesPhase.ready);
    expect(cubit.state.totalVisits, 2);
    expect(cubit.state.visitedCityCount, 1);
  });

  test('exposes loading state while request is pending', () async {
    final repository = FakeCityVisitsRepository()
      ..pendingLoad = Completer<List<CityVisit>>();

    final cubit = VisitedCitiesCubit(repository: repository);
    addTearDown(cubit.close);

    final loading = cubit.load();

    expect(cubit.state.phase, VisitedCitiesPhase.loading);

    repository.pendingLoad!.complete([makeVisit('1')]);

    await loading;

    expect(cubit.state.phase, VisitedCitiesPhase.ready);
  });

  test('handles repository failures', () async {
    final repository = FakeCityVisitsRepository()
      ..error = StateError('Network unavailable');

    final cubit = VisitedCitiesCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state.phase, VisitedCitiesPhase.failure);
    expect(cubit.state.errorMessage, isNotNull);
  });

  test('preserves existing visits when refresh fails', () async {
    final repository = FakeCityVisitsRepository()..visits = [makeVisit('1')];

    final cubit = VisitedCitiesCubit(repository: repository);
    addTearDown(cubit.close);

    await cubit.load();

    repository.error = StateError('Network unavailable');

    await cubit.load();

    expect(cubit.state.phase, VisitedCitiesPhase.failure);
    expect(cubit.state.totalVisits, 1);
  });

  test('does not emit after being closed during loading', () async {
    final repository = FakeCityVisitsRepository()
      ..pendingLoad = Completer<List<CityVisit>>();

    final cubit = VisitedCitiesCubit(repository: repository);

    final loading = cubit.load();

    await cubit.close();

    repository.pendingLoad!.complete([makeVisit('1')]);

    await loading;

    expect(cubit.isClosed, isTrue);
  });
}
