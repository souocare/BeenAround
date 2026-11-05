import 'package:beenaround/features/explore/data/countries_repository.dart';
import 'package:beenaround/features/explore/domain/country.dart';
import 'package:beenaround/features/explore/domain/country_visit.dart';
import 'package:beenaround/features/geography/domain/city_visit.dart';
import 'package:beenaround/features/geography/domain/city_visits_repository.dart';
import 'package:beenaround/features/trips/presentation/widgets/trip_visit_picker_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const firstCountryVisitId = 'country-visit-1';
const secondCountryVisitId = 'country-visit-2';

const firstCityVisitId = 'city-visit-1';
const secondCityVisitId = 'city-visit-2';

CountryVisit countryVisit({
  required String id,
  String countryCode = 'JP',
  DateTime? startedOn,
  DateTime? endedOn,
}) {
  return CountryVisit(
    id: id,
    countryCode: countryCode,
    startedOn: startedOn ?? DateTime(2027, 4, 10),
    endedOn: endedOn ?? DateTime(2027, 4, 25),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

CityVisit cityVisit({
  required String id,
  String cityName = 'Tokyo',
  String countryName = 'Japan',
  String countryCode = 'JP',
}) {
  return CityVisit(
    id: id,
    cityId: 1850147,
    cityName: cityName,
    countryCode: countryCode,
    countryName: countryName,
    startedOn: DateTime(2027, 4, 10),
    endedOn: DateTime(2027, 4, 15),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

/// Test double for loading existing country visits.
///
/// Other repository operations are deliberately unsupported.
class FakePickerCountriesRepository extends Fake
    implements CountriesRepository {
  FakePickerCountriesRepository({
    List<CountryVisit> visits = const [],
    List<Country>? countries,
  }) : visits = List.of(visits),
       countries = List.of(
         countries ??
             const [
               Country(
                 code: 'JP',
                 name: 'Japan',
                 alpha3Code: 'JPN',
                 continent: 'AS',
               ),
               Country(
                 code: 'PT',
                 name: 'Portugal',
                 alpha3Code: 'PRT',
                 continent: 'EU',
               ),
             ],
       );

  final List<CountryVisit> visits;
  final List<Country> countries;

  int loadCount = 0;
  int catalogLoadCount = 0;

  bool failNextLoad = false;

  @override
  Future<List<Country>> getCountries() async {
    catalogLoadCount++;

    return List.unmodifiable(countries);
  }

  @override
  Future<List<CountryVisit>> getCountryVisits() async {
    loadCount++;

    if (failNextLoad) {
      failNextLoad = false;
      throw Exception('Unable to load country visits.');
    }

    return List.unmodifiable(visits);
  }
}

/// Test double for loading existing city visits.
class FakePickerCityVisitsRepository extends Fake
    implements CityVisitsRepository {
  FakePickerCityVisitsRepository({List<CityVisit> visits = const []})
    : visits = List.of(visits);

  final List<CityVisit> visits;

  int loadCount = 0;
  bool failNextLoad = false;

  @override
  Future<List<CityVisit>> getCityVisits() async {
    loadCount++;

    if (failNextLoad) {
      failNextLoad = false;
      throw Exception('Unable to load city visits.');
    }

    return List.unmodifiable(visits);
  }
}

Widget buildPickerTestApp({
  required CountriesRepository countriesRepository,
  required CityVisitsRepository cityVisitsRepository,
  required bool isCountryPicker,
  required Set<String> excludedVisitIds,
  required ValueChanged<String?> onSelected,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<CountriesRepository>.value(value: countriesRepository),
      RepositoryProvider<CityVisitsRepository>.value(
        value: cityVisitsRepository,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return Center(
              child: FilledButton(
                key: const Key('openTripVisitPickerButton'),
                onPressed: () async {
                  final selected = isCountryPicker
                      ? await showTripCountryVisitPicker(
                          context: context,
                          excludedVisitIds: excludedVisitIds,
                        )
                      : await showTripCityVisitPicker(
                          context: context,
                          excludedVisitIds: excludedVisitIds,
                        );

                  onSelected(selected);
                },
                child: const Text('Open picker'),
              ),
            );
          },
        ),
      ),
    ),
  );
}

void main() {
  late FakePickerCountriesRepository countriesRepository;
  late FakePickerCityVisitsRepository cityVisitsRepository;

  String? selectedVisitId;
  bool selectionCompleted = false;

  setUp(() {
    countriesRepository = FakePickerCountriesRepository();
    cityVisitsRepository = FakePickerCityVisitsRepository();

    selectedVisitId = null;
    selectionCompleted = false;
  });

  Future<void> openPicker(
    WidgetTester tester, {
    required bool isCountryPicker,
    Set<String> excludedVisitIds = const {},
  }) async {
    await tester.pumpWidget(
      buildPickerTestApp(
        countriesRepository: countriesRepository,
        cityVisitsRepository: cityVisitsRepository,
        isCountryPicker: isCountryPicker,
        excludedVisitIds: excludedVisitIds,
        onSelected: (value) {
          selectedVisitId = value;
          selectionCompleted = true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('openTripVisitPickerButton')));

    await tester.pumpAndSettle();
  }

  group('Trip country visit picker', () {
    testWidgets('shows existing country visits', (tester) async {
      countriesRepository.visits.add(countryVisit(id: firstCountryVisitId));

      await openPicker(tester, isCountryPicker: true);

      expect(find.text('Add country visit'), findsOneWidget);

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
        findsOneWidget,
      );

      expect(countriesRepository.loadCount, 1);
    });

    testWidgets('keeps repeated country visits separate', (tester) async {
      countriesRepository.visits.addAll([
        countryVisit(
          id: firstCountryVisitId,
          startedOn: DateTime(2025, 4, 10),
          endedOn: DateTime(2025, 4, 20),
        ),
        countryVisit(
          id: secondCountryVisitId,
          startedOn: DateTime(2027, 4, 10),
          endedOn: DateTime(2027, 4, 25),
        ),
      ]);

      await openPicker(tester, isCountryPicker: true);

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-2')),
        findsOneWidget,
      );
    });

    testWidgets('excludes already associated visits', (tester) async {
      countriesRepository.visits.addAll([
        countryVisit(id: firstCountryVisitId),
        countryVisit(id: secondCountryVisitId),
      ]);

      await openPicker(
        tester,
        isCountryPicker: true,
        excludedVisitIds: {firstCountryVisitId},
      );

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-2')),
        findsOneWidget,
      );
    });

    testWidgets('searches by country code', (tester) async {
      countriesRepository.visits.addAll([
        countryVisit(id: firstCountryVisitId, countryCode: 'JP'),
        countryVisit(id: secondCountryVisitId, countryCode: 'PT'),
      ]);

      await openPicker(tester, isCountryPicker: true);

      await tester.enterText(
        find.byKey(const Key('tripVisitPickerSearch')),
        'pt',
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-2')),
        findsOneWidget,
      );
    });

    testWidgets('returns selected country visit ID', (tester) async {
      countriesRepository.visits.add(countryVisit(id: firstCountryVisitId));

      await openPicker(tester, isCountryPicker: true);

      await tester.tap(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
      );

      await tester.pumpAndSettle();

      expect(selectionCompleted, isTrue);
      expect(selectedVisitId, firstCountryVisitId);
    });

    testWidgets('cancel returns null', (tester) async {
      countriesRepository.visits.add(countryVisit(id: firstCountryVisitId));

      await openPicker(tester, isCountryPicker: true);

      await tester.tap(find.byKey(const Key('cancelTripVisitPickerButton')));

      await tester.pumpAndSettle();

      expect(selectionCompleted, isTrue);
      expect(selectedVisitId, isNull);
    });

    testWidgets('shows empty state', (tester) async {
      await openPicker(tester, isCountryPicker: true);

      expect(find.byKey(const Key('tripVisitPickerEmpty')), findsOneWidget);

      expect(find.text('No country visits available.'), findsOneWidget);
    });

    testWidgets('retries after loading failure', (tester) async {
      countriesRepository.failNextLoad = true;

      countriesRepository.visits.add(countryVisit(id: firstCountryVisitId));

      await openPicker(tester, isCountryPicker: true);

      expect(find.byKey(const Key('tripVisitPickerError')), findsOneWidget);

      await tester.tap(find.byKey(const Key('retryTripVisitPickerButton')));

      await tester.pumpAndSettle();

      expect(countriesRepository.loadCount, 2);

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
        findsOneWidget,
      );
    });
  });

  group('Trip city visit picker', () {
    testWidgets('shows existing city visits', (tester) async {
      cityVisitsRepository.visits.add(cityVisit(id: firstCityVisitId));

      await openPicker(tester, isCountryPicker: false);

      expect(find.text('Add city visit'), findsOneWidget);
      expect(find.text('Tokyo'), findsOneWidget);
      expect(find.text('Japan'), findsOneWidget);
    });

    testWidgets('searches by city name', (tester) async {
      cityVisitsRepository.visits.addAll([
        cityVisit(id: firstCityVisitId, cityName: 'Tokyo'),
        cityVisit(id: secondCityVisitId, cityName: 'Kyoto'),
      ]);

      await openPicker(tester, isCountryPicker: false);

      await tester.enterText(
        find.byKey(const Key('tripVisitPickerSearch')),
        'kyoto',
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tripVisitOption-city-visit-1')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('tripVisitOption-city-visit-2')),
        findsOneWidget,
      );
    });

    testWidgets('searches by country name', (tester) async {
      cityVisitsRepository.visits.addAll([
        cityVisit(
          id: firstCityVisitId,
          cityName: 'Tokyo',
          countryName: 'Japan',
        ),
        cityVisit(
          id: secondCityVisitId,
          cityName: 'Lisbon',
          countryName: 'Portugal',
          countryCode: 'PT',
        ),
      ]);

      await openPicker(tester, isCountryPicker: false);

      await tester.enterText(
        find.byKey(const Key('tripVisitPickerSearch')),
        'portugal',
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tripVisitOption-city-visit-1')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('tripVisitOption-city-visit-2')),
        findsOneWidget,
      );
    });

    testWidgets('excludes associated city visits', (tester) async {
      cityVisitsRepository.visits.addAll([
        cityVisit(id: firstCityVisitId),
        cityVisit(id: secondCityVisitId),
      ]);

      await openPicker(
        tester,
        isCountryPicker: false,
        excludedVisitIds: {firstCityVisitId},
      );

      expect(
        find.byKey(const Key('tripVisitOption-city-visit-1')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('tripVisitOption-city-visit-2')),
        findsOneWidget,
      );
    });

    testWidgets('returns selected city visit ID', (tester) async {
      cityVisitsRepository.visits.add(cityVisit(id: firstCityVisitId));

      await openPicker(tester, isCountryPicker: false);

      await tester.tap(find.byKey(const Key('tripVisitOption-city-visit-1')));

      await tester.pumpAndSettle();

      expect(selectionCompleted, isTrue);
      expect(selectedVisitId, firstCityVisitId);
    });

    testWidgets('shows no matching visits', (tester) async {
      cityVisitsRepository.visits.add(cityVisit(id: firstCityVisitId));

      await openPicker(tester, isCountryPicker: false);

      await tester.enterText(
        find.byKey(const Key('tripVisitPickerSearch')),
        'nonexistent',
      );

      await tester.pumpAndSettle();

      expect(find.text('No matching visits.'), findsOneWidget);
    });
    testWidgets('displays country names instead of only ISO codes', (
      tester,
    ) async {
      countriesRepository.visits.addAll([
        countryVisit(id: firstCountryVisitId, countryCode: 'JP'),
        countryVisit(id: secondCountryVisitId, countryCode: 'PT'),
      ]);

      await openPicker(tester, isCountryPicker: true);

      expect(find.text('Japan'), findsOneWidget);
      expect(find.text('Portugal'), findsOneWidget);

      expect(countriesRepository.catalogLoadCount, 1);
      expect(countriesRepository.loadCount, 1);
    });
    testWidgets('searches country visits by full country name', (tester) async {
      countriesRepository.visits.addAll([
        countryVisit(id: firstCountryVisitId, countryCode: 'JP'),
        countryVisit(id: secondCountryVisitId, countryCode: 'PT'),
      ]);

      await openPicker(tester, isCountryPicker: true);

      await tester.enterText(
        find.byKey(const Key('tripVisitPickerSearch')),
        'portugal',
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-2')),
        findsOneWidget,
      );
    });
    testWidgets('falls back to ISO code when country is missing', (
      tester,
    ) async {
      countriesRepository.visits.add(
        countryVisit(id: firstCountryVisitId, countryCode: 'FR'),
      );

      await openPicker(tester, isCountryPicker: true);

      expect(find.text('FR'), findsOneWidget);

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
        findsOneWidget,
      );
    });
  });
}
