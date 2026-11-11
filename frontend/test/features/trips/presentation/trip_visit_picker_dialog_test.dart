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
  required ValueChanged<List<String>?> onSelected,
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

  List<String>? selectedVisitIds;
  bool selectionCompleted = false;

  setUp(() {
    countriesRepository = FakePickerCountriesRepository();
    cityVisitsRepository = FakePickerCityVisitsRepository();

    selectedVisitIds = null;
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
          selectedVisitIds = value;
          selectionCompleted = true;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('openTripVisitPickerButton')));

    await tester.pumpAndSettle();
  }

  Future<void> selectVisit(WidgetTester tester, String visitId) async {
    final finder = find.byKey(Key('tripVisitOption-$visitId'));

    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();

    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> confirmSelection(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('confirmTripVisitPickerButton')));

    await tester.pumpAndSettle();
  }

  group('Trip country visit picker', () {
    testWidgets('shows existing country visits', (tester) async {
      countriesRepository.visits.add(countryVisit(id: firstCountryVisitId));

      await openPicker(tester, isCountryPicker: true);

      expect(find.text('Add country visits'), findsOneWidget);

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

      await selectVisit(tester, firstCountryVisitId);
      await selectVisit(tester, secondCountryVisitId);

      await confirmSelection(tester);

      expect(selectedVisitIds, [firstCountryVisitId, secondCountryVisitId]);
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

    testWidgets('returns selected country visit IDs', (tester) async {
      countriesRepository.visits.addAll([
        countryVisit(id: firstCountryVisitId),
        countryVisit(id: secondCountryVisitId),
      ]);

      await openPicker(tester, isCountryPicker: true);

      await selectVisit(tester, firstCountryVisitId);
      await selectVisit(tester, secondCountryVisitId);

      // Selecting options does not close the picker.
      expect(selectionCompleted, isFalse);

      expect(find.text('2 visits selected'), findsOneWidget);

      await confirmSelection(tester);

      expect(selectionCompleted, isTrue);

      expect(selectedVisitIds, [firstCountryVisitId, secondCountryVisitId]);
    });

    testWidgets('cancel returns null', (tester) async {
      countriesRepository.visits.add(countryVisit(id: firstCountryVisitId));

      await openPicker(tester, isCountryPicker: true);

      await selectVisit(tester, firstCountryVisitId);

      await tester.tap(find.byKey(const Key('cancelTripVisitPickerButton')));

      await tester.pumpAndSettle();

      expect(selectionCompleted, isTrue);
      expect(selectedVisitIds, isNull);
    });

    testWidgets('confirm is disabled without selection', (tester) async {
      countriesRepository.visits.add(countryVisit(id: firstCountryVisitId));

      await openPicker(tester, isCountryPicker: true);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('confirmTripVisitPickerButton')),
      );

      expect(button.onPressed, isNull);
      expect(selectionCompleted, isFalse);
    });

    testWidgets('selecting again deselects a visit', (tester) async {
      countriesRepository.visits.add(countryVisit(id: firstCountryVisitId));

      await openPicker(tester, isCountryPicker: true);

      await selectVisit(tester, firstCountryVisitId);

      expect(find.text('1 visit selected'), findsOneWidget);

      await selectVisit(tester, firstCountryVisitId);

      expect(find.text('0 visits selected'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('confirmTripVisitPickerButton')),
      );

      expect(button.onPressed, isNull);
    });

    testWidgets('preserves selection while searching', (tester) async {
      countriesRepository.visits.addAll([
        countryVisit(id: firstCountryVisitId, countryCode: 'JP'),
        countryVisit(id: secondCountryVisitId, countryCode: 'PT'),
      ]);

      await openPicker(tester, isCountryPicker: true);

      await selectVisit(tester, firstCountryVisitId);

      await tester.enterText(
        find.byKey(const Key('tripVisitPickerSearch')),
        'portugal',
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('tripVisitOption-country-visit-1')),
        findsNothing,
      );

      await selectVisit(tester, secondCountryVisitId);

      await confirmSelection(tester);

      expect(selectedVisitIds, [firstCountryVisitId, secondCountryVisitId]);
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

    testWidgets('displays country names instead of ISO codes', (tester) async {
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

    testWidgets('searches by full country name', (tester) async {
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

  group('Trip city visit picker', () {
    testWidgets('shows existing city visits', (tester) async {
      cityVisitsRepository.visits.add(cityVisit(id: firstCityVisitId));

      await openPicker(tester, isCountryPicker: false);

      expect(find.text('Add city visits'), findsOneWidget);

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

    testWidgets('returns multiple city visit IDs', (tester) async {
      cityVisitsRepository.visits.addAll([
        cityVisit(id: firstCityVisitId, cityName: 'Tokyo'),
        cityVisit(id: secondCityVisitId, cityName: 'Kyoto'),
      ]);

      await openPicker(tester, isCountryPicker: false);

      await selectVisit(tester, firstCityVisitId);
      await selectVisit(tester, secondCityVisitId);

      expect(selectionCompleted, isFalse);

      await confirmSelection(tester);

      expect(selectionCompleted, isTrue);

      expect(selectedVisitIds, [firstCityVisitId, secondCityVisitId]);
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
  });

  group('Adaptive picker presentation', () {
    testWidgets('uses a bottom sheet on narrow screens', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await openPicker(tester, isCountryPicker: true);

      expect(find.byType(BottomSheet), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('uses a dialog on wide screens', (tester) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await openPicker(tester, isCountryPicker: true);

      expect(find.byType(Dialog), findsOneWidget);

      expect(tester.takeException(), isNull);
    });
  });
}
